import 'package:workmanager/workmanager.dart';
import '../settings/profile_service.dart';

class SyncScheduler {
  static Future<void> updatePeriodicTask() async {
    final profileService = ProfileService();
    final profiles = await profileService.listEnabledProfiles();

    if (profiles.isEmpty) {
      await Workmanager().cancelAll();
      return;
    }

    final minInterval = profiles
        .map((p) => p.intervalMinutes)
        .where((i) => i > 0)
        .fold<int?>(null, (a, b) => a == null ? b : (b < a ? b : a));

    if (minInterval == null || minInterval == 0) {
      await Workmanager().cancelAll();
      return;
    }

    await Workmanager().registerPeriodicTask(
      'calendar_sync_periodic',
      'syncTask',
      frequency: Duration(minutes: minInterval),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}
