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
      await engine.runSync(
        sourceCalendarId: sourceId,
        targetCalendarId: targetId,
        syncEventName: syncName,
      );
    } catch (_) {}

    return true;
  });
}
