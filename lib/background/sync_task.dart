import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import '../sync/mapping_database.dart';
import '../sync/sync_engine.dart';
import '../calendar/calendar_service.dart';
import '../settings/settings_service.dart';
import '../permissions/permission_service.dart';

final _notifications = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    await _ensureChannel();
    return _doSync();
  });
}

Future<void> _ensureChannel() async {
  await _notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'calendar_sync',
          'Calendar Sync',
          importance: Importance.defaultImportance,
        ),
      );
}

Future<bool> _doSync() async {
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

    await _notifications.show(
      0,
      'Calendar Sync',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'calendar_sync',
          'Calendar Sync',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  return true;
}
