import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../sync/mapping_database.dart';
import '../sync/sync_engine.dart';
import '../calendar/calendar_service.dart';
import '../settings/settings_service.dart';
import '../permissions/permission_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final settings = SettingsService();
      final syncEnabled = await settings.syncEnabled;
      if (!syncEnabled) return true;

      final interval = await settings.syncIntervalMinutes;
      if (interval == 0) return true;

      final sourceId = await settings.sourceCalendarId;
      final targetId = await settings.targetCalendarId;
      final syncName = await settings.syncEventName;
      if (sourceId == null || targetId == null || syncName.isEmpty) {
        return true;
      }

      final permService = PermissionService();
      if (!await permService.areCalendarPermissionsGranted) {
        return true;
      }

      final engine = SyncEngine(CalendarService(), MappingDatabase());
      final result = await engine.runSync(
        sourceCalendarId: sourceId,
        targetCalendarId: targetId,
        syncEventName: syncName,
      );

      if (result.synced.isNotEmpty || result.deleted.isNotEmpty) {
        var body = 'Synced: ${result.synced.length}, '
            'Deleted: ${result.deleted.length}, '
            'Skipped: ${result.skipped.length}';
        if (result.errors.isNotEmpty) {
          body += ' + ${result.errors.length} errors';
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_sync_notification', body);
      }
    } catch (_) {}

    return true;
  });
}
