import 'package:flutter/foundation.dart';
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
      debugPrint('[BG-SYNC] task started: $taskName');
      final profileService = ProfileService();
      final profiles = await profileService.listEnabledProfiles();

      debugPrint('[BG-SYNC] ${profiles.length} enabled profile(s) found');
      if (profiles.isEmpty) {
        debugPrint('[BG-SYNC] no enabled profiles → exiting');
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
        debugPrint('[BG-SYNC] syncing profile "${profile.name}" (${profile.id})');
        final sourceId = profile.sourceCalendarId;
        final targetId = profile.targetCalendarId;
        final syncName = profile.eventName.trim();

        if (sourceId == null || targetId == null || syncName.isEmpty || profile.intervalMinutes <= 0) {
          debugPrint('[BG-SYNC] profile "${profile.name}" → SKIP (not configured or manual-only)');
          continue;
        }

        try {
          final result = await engine.runSync(
            profileId: profile.id,
            sourceCalendarId: sourceId,
            targetCalendarId: targetId,
            syncEventName: syncName,
          );

          debugPrint('[BG-SYNC] profile "${profile.name}" → synced=${result.synced.length} updated=${result.updated.length} deleted=${result.deleted.length} skipped=${result.skipped.length} errors=${result.errors.length}');

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

      debugPrint('[BG-SYNC] all profiles done → signaling completion');
      await _signalDone();
    } catch (e) {
      debugPrint('[BG-SYNC] unhandled error: $e');
    }

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
