import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> get areCalendarPermissionsGranted async {
    final status = await DeviceCalendar.instance.hasPermissions();
    return status == CalendarPermissionStatus.granted;
  }

  Future<bool> requestCalendarPermissions() async {
    final status = await DeviceCalendar.instance.requestPermissions();
    return status == CalendarPermissionStatus.granted;
  }

  Future<bool> get areCalendarPermissionsPermanentlyDenied async {
    return await Permission.calendarFullAccess.isPermanentlyDenied;
  }

  Future<bool> get areNotificationPermissionsGranted async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
  }
}
