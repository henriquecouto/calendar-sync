## Context

The current `Calendar Sync` app has a manual "Sync Now" button. `SyncEngine`, `MappingDatabase`, `CalendarService`, and `SettingsService` are implemented. The sync cycle creates target events for new source events but does NOT handle deletions — once synced, an event stays in the target calendar forever.

## Goals / Non-Goals

**Goals:**
- React to calendar changes within seconds (not minutes) via Android ContentObserver
- Propagate deletions: when a source event is removed, delete its synced target event and clean up the mapping
- Keep a 6-hour periodic fallback as a safety net
- User can disable background sync entirely (`sync_interval_minutes = 0`)
- Manual "Sync Now" continues to work alongside automatic sync
- Zero new Flutter dependencies beyond `workmanager`

**Non-Goals:**
- iOS support (Android-only)
- Push notifications or foreground services
- User-facing sync history or logs

## Decisions

### Hybrid architecture: ContentObserver (primary) + PeriodicWorkRequest (fallback)

```
 CALENDAR PROVIDER (Android)
      │
      ▼
 ContentObserver ──(debounce 5s)──▶ OneTimeWorkRequest ──▶ BackgroundWorker ──▶ callbackDispatcher()
                                                                   
 PeriodicWorkRequest (every 6h) ─────────────────────────────────▶ callbackDispatcher()
```

The ContentObserver fires on every add/update/delete in any calendar. A 5-second debounce + `ExistingWorkPolicy.REPLACE` batches rapid changes into a single sync. The periodic fallback catches edge cases (observer deregistration, WorkManager state loss after app data clear).

### Reuse the `workmanager` plugin's BackgroundWorker

The `workmanager` Flutter plugin registers a public `dev.fluttercommunity.workmanager.BackgroundWorker` class. Our native Kotlin code can enqueue `OneTimeWorkRequest` instances using this same class. The plugin handles all the complexity: creating a headless FlutterEngine, resolving the Dart callback handle from SharedPreferences, and invoking `callbackDispatcher`.

```kotlin
val request = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
    .setInputData(Data.Builder()
        .putString("dev.fluttercommunity.workmanager.DART_TASK", "syncTask")
        .build())
    .setInitialDelay(5, TimeUnit.SECONDS)
    .build()

WorkManager.getInstance(context)
    .enqueueUniqueWork("calendar-sync", ExistingWorkPolicy.REPLACE, request)
```

### Native ContentObserver in Kotlin

A new file `android/app/src/main/kotlin/.../CalendarContentObserver.kt`:

```kotlin
class CalendarContentObserver(
    private val context: Context,
    handler: Handler,
) : ContentObserver(handler) {
    
    override fun onChange(selfChange: Boolean, uri: Uri?) {
        scheduleSyncWork(context)
    }

    companion object {
        fun register(context: Context) {
            context.contentResolver.registerContentObserver(
                CalendarContract.Events.CONTENT_URI,
                true, // notifyForDescendants
                CalendarContentObserver(context, Handler(Looper.getMainLooper()))
            )
        }

        fun scheduleSyncWork(context: Context) {
            val inputData = Data.Builder()
                .putString(BackgroundWorker.DART_TASK_KEY, "syncTask")
                .build()
            val request = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
                .setInputData(inputData)
                .setInitialDelay(5, TimeUnit.SECONDS)
                .build()
            WorkManager.getInstance(context)
                .enqueueUniqueWork("calendar-sync", ExistingWorkPolicy.REPLACE, request)
        }
    }
}
```

### Delete propagation in SyncEngine

The `runSync()` method gains a new step between "check mappings" and "create new events":

```
runSync(sourceCal, targetCal, syncName):
  1. List source events
  2. Query ALL mappings for sourceCal from MappingDatabase
  3. NEW — Deletion pass:
     For each mapping:
       If source_event_id NOT in current source events list:
         → deleteEvent(targetCal, mapping.target_event_id)
         → deleteMapping(mapping.id)
  4. Creation pass:
     For each source event:
       If not in mappings:
         → createEvent(targetCal, syncName, event.start, event.end)
         → insertMapping(...)
```

A new method `listMappingsForCalendar(sourceCalendarId)` is added to `MappingDatabase`, and `deleteMapping(id)` to remove individual rows after target event deletion.

### Settings: `sync_interval_minutes`

Added to `SettingsService`. Default 60. Value 0 disables background sync entirely (both ContentObserver and periodic fallback are not registered). The periodic fallback uses this value as its interval. The ContentObserver path is NOT interval-based — it fires on change, but is also disabled when the setting is 0.

### callbackDispatcher stays simple

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final settings = SettingsService();
      final interval = await settings.syncIntervalMinutes;
      if (interval == 0) return true;

      final sourceId = await settings.sourceCalendarId;
      final targetId = await settings.targetCalendarId;
      final syncName = await settings.syncEventName;
      if (sourceId == null || targetId == null || syncName.isEmpty) return true;

      final permService = PermissionService();
      if (!await permService.areCalendarPermissionsGranted) return true;

      final engine = SyncEngine(CalendarService(), MappingDatabase());
      await engine.runSync(
        sourceCalendarId: sourceId,
        targetCalendarId: targetId,
        syncEventName: syncName,
      );
    } catch (_) {}
    return true;
  });
}
```

## Risks / Trade-offs

- [Risk] ContentObserver fires for ALL calendars, not just the configured source. → Mitigation: The sync engine only acts on the configured `sourceCalendarId`. Other calendar changes are observed but ignored at the Dart level (the Flutter engine wake-up is wasted, but the sync logic returns immediately).
- [Risk] Rapid calendar changes (bulk import) may trigger multiple engine initializations before debounce kicks in. → Mitigation: `ExistingWorkPolicy.REPLACE` cancels the previous pending work. Only the last trigger (after the 5s quiet period) actually runs.
- [Risk] The ContentObserver must be registered at app start and after `Workmanager().initialize()`. If the user force-stops the app, Android unregisters content observers until the app is launched again. → Mitigation: The 6-hour periodic fallback catches any missed changes. The observer is re-registered in `main()` on every app start.
- [Risk] `sqflite` access from both manual sync and background sync concurrently. → Mitigation: The mapping table has UNIQUE constraints. Concurrent syncs will not create duplicate mappings; at worst, one sync's createEvent succeeds and the other's insertMapping is ignored. The database is SQLite in WAL mode by default, which handles concurrent reads/writes.
- [Risk] Deleting the target event may fail if the event was already deleted manually by the user. → Mitigation: `deleteEvent` in CalendarService already handles non-existent events gracefully (returns false, does not throw).

## Open Questions

- Should deleted events in the source calendar also be deleted from the target? **Resolved: Yes.** This is now part of this change.
