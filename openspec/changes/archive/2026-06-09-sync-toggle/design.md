## Context

The sync engine has three entry points — manual "Sync Now" button, reactive ContentObserver trigger, and periodic WorkManager fallback. All three invoke `SyncEngine.runSync()` unconditionally. The settings layer uses `SharedPreferences` via `SettingsService` with four keys. A new `syncEnabled` boolean setting needs to gate all sync entry points.

## Goals / Non-Goals

**Goals:**
- Add a `syncEnabled` boolean to `SettingsService` persisted in SharedPreferences
- Gate all three sync entry points (manual, reactive, periodic) on this flag
- Provide a Switch widget on the home screen to toggle the setting
- Disable the "Sync Now" button visually when sync is off
- Keep the ContentObserver running — only gate the sync callback, not the observer itself

**Non-Goals:**
- Automatic sync on re-enable — toggling on does NOT trigger an immediate sync
- Per-calendar toggles — one global toggle for the entire app
- Affecting the periodic observer-registration worker (native Kotlin, unrelated to sync logic)
- Any change to how settings are stored (still SharedPreferences)

## Decisions

### 1. Gate at the outermost entry point, not inside SyncEngine

**Chosen:** Each caller checks `settingsService.syncEnabled` before calling `SyncEngine.runSync()`.
**Alternative:** Add the check inside `SyncEngine.runSync()` itself. Rejected because the sync engine should remain a pure sync executor — adding a settings check couples it to `SettingsService`.
**Why:** Keeps the sync engine unaware of app-level policy. Each trigger (UI, background, reactive) is responsible for checking whether sync is allowed.

### 2. Keep ContentObserver running when sync is disabled

**Chosen:** The native `CalendarContentObserver` continues to observe calendar changes and fire the MethodChannel callback. The Dart-side handler checks `syncEnabled` and exits early if disabled.
**Alternative:** Unregister the ContentObserver when sync is disabled and re-register on enable. Rejected because unregistering/re-registering adds complexity and edge cases (e.g., observer might not re-register cleanly). The observer itself is lightweight — it only watches a content URI.
**Why:** Simpler implementation and avoids race conditions with Android's observer lifecycle.

### 3. Default to enabled on first launch

**Chosen:** `syncEnabled` defaults to `true`.
**Why:** First-time users expect sync to work out of the box. The toggle is for explicitly pausing, not for requiring opt-in.

### 4. UI placement: Switch above the action buttons

**Chosen:** A `SwitchListTile` (or `Row` with `Switch` + `Text`) placed between the settings section and the "Sync Now" button.
**Alternative:** Place in a separate settings screen. Rejected because the app has a single screen and adding a settings screen for one toggle is over-engineering.
**Why:** Discoverable, adjacent to the button it affects, minimal UI change.

## Risks / Trade-offs

**[R1] User forgets sync is off** → The Switch shows current state prominently. The "Sync Now" button is visibly disabled with a hint. Low risk.

**[R2] Toggle state lost on app reinstall** → Acceptable — SharedPreferences are cleared on uninstall. Default is `true`, so sync works immediately after reinstall.

**[R3] Reactive sync fires right after re-enable if observer already has pending changes** → The 5-second debounce on the reactive handler means old observer events expire naturally. If a change happened while sync was off, the periodic fallback catches it.
