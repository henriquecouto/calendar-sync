import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> get areCalendarPermissionsGranted async {
    final status = await Permission.calendarFullAccess.status;
    return status.isGranted;
  }

  Future<bool> requestCalendarPermissions() async {
    final status = await Permission.calendarFullAccess.request();
    return status.isGranted;
  }

  Future<bool> get areCalendarPermissionsPermanentlyDenied async {
    return await Permission.calendarFullAccess.isPermanentlyDenied;
  }

  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
