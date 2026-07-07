import 'package:workmanager/workmanager.dart';
import '../settings/profile_service.dart';
import '../main.dart';
import '../subscriptions/entitlement.dart';

class SyncScheduler {
  static Future<void> updatePeriodicTask() async {
    final profileService = ProfileService();
    final allProfiles = await profileService.listProfiles();
    final profiles = allProfiles.asMap().entries
        .where((entry) =>
            entry.value.enabled &&
            canProfileSync(subscriptionService.isSubscribed, entry.key))
        .map((entry) => entry.value)
        .toList();

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
