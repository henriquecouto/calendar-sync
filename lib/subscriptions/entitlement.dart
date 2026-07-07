import 'package:shared_preferences/shared_preferences.dart';

import '../settings/profile_service.dart';
import 'subscription_service.dart';

bool canCreateProfile(SubscriptionService service, int profileCount) {
  return service.isSubscribed || profileCount < 1;
}

bool canEnableProfile(
  SubscriptionService service,
  int profileIndex,
  bool isTurningOn,
) {
  if (!isTurningOn) return true;
  return service.isSubscribed || profileIndex == 0;
}

const _preExpiryEnabledProfilesKey = 'pre_expiry_enabled_profiles';

const subscriptionEntitledKey = 'subscription_entitled';

const lastEntitlementCheckKey = 'last_entitlement_check';

bool canProfileSync(bool isSubscribed, int profileIndex) {
  return isSubscribed || profileIndex == 0;
}

Future<void> handleSubscriptionExpired(ProfileService profileService) async {
  final profiles = await profileService.listProfiles();
  if (profiles.length <= 1) return;

  final enabledIds = profiles
      .where((p) => p.enabled)
      .map((p) => p.id)
      .toList();

  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_preExpiryEnabledProfilesKey, enabledIds);

  for (int i = 1; i < profiles.length; i++) {
    final profile = profiles[i];
    if (profile.enabled) {
      await profileService.updateProfile(profile.copyWith(enabled: false));
    }
  }
}

Future<void> handleSubscriptionRestored(ProfileService profileService) async {
  final prefs = await SharedPreferences.getInstance();
  final enabledIds =
      prefs.getStringList(_preExpiryEnabledProfilesKey) ?? [];

  if (enabledIds.isEmpty) return;

  for (final id in enabledIds) {
    final profile = await profileService.getProfile(id);
    if (profile != null && !profile.enabled) {
      await profileService.updateProfile(profile.copyWith(enabled: true));
    }
  }

  await prefs.remove(_preExpiryEnabledProfilesKey);
}
