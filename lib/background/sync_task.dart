import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../settings/profile_service.dart';
import '../sync/mapping_database.dart';
import '../sync/sync_engine.dart';
import '../calendar/calendar_service.dart';
import '../permissions/permission_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final profileService = ProfileService();
      final profiles = await profileService.listEnabledProfiles();

      if (profiles.isEmpty) {
        await _signalDone();
        return true;
      }

      final permService = PermissionService();
      if (!await permService.areCalendarPermissionsGranted) {
        await _signalDone();
        return true;
      }

      final engine = SyncEngine(CalendarService(), MappingDatabase());

      for (final profile in profiles) {
        final sourceId = profile.sourceCalendarId;
        final targetId = profile.targetCalendarId;
        final syncName = profile.eventName.trim();

        if (sourceId == null || targetId == null || profile.intervalMinutes <= 0) {
          continue;
        }

        try {
          final result = await engine.runSync(
            profileId: profile.id,
            sourceCalendarId: sourceId,
            targetCalendarId: targetId,
            syncEventName: syncName,
            copyDescription: profile.copyDescription,
            copyLocation: profile.copyLocation,
          );


          await _logStatus(
            profile.id,
            result.synced.length,
            result.deleted.length,
            result.skipped.length,
            result.updated.length,
            result.errors.length,
          );
        } catch (_) {
          await _logStatus(profile.id, 0, 0, 0, 0, 1);
        }
      }

      await _signalDone();
    } catch (_) {}

    return true;
  });
}

Future<void> _logStatus(String profileId, int synced, int deleted, int skipped, int updated, int errors) async {
  final db = MappingDatabase();
  await db.insertStatus(
    profileId: profileId,
    timestamp: DateTime.now().toIso8601String(),
    synced: synced,
    deleted: deleted,
    skipped: skipped,
    updated: updated,
    errors: errors,
  );
}

Future<void> _signalDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('pending_sync_notification', '1');
}
