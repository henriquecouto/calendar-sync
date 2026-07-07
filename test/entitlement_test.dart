import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calendar_sync/subscriptions/entitlement.dart';
import 'package:calendar_sync/settings/profile_service.dart';
import 'package:calendar_sync/sync/database_provider.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('canProfileSync', () {
    test('first profile is allowed even when not subscribed', () {
      expect(canProfileSync(false, 0), isTrue);
    });

    test('extra profile is blocked when not subscribed', () {
      expect(canProfileSync(false, 1), isFalse);
      expect(canProfileSync(false, 2), isFalse);
      expect(canProfileSync(false, 10), isFalse);
    });

    test('any profile is allowed when subscribed', () {
      expect(canProfileSync(true, 0), isTrue);
      expect(canProfileSync(true, 1), isTrue);
      expect(canProfileSync(true, 5), isTrue);
      expect(canProfileSync(true, 100), isTrue);
    });

    test('negative index is treated as not allowed', () {
      expect(canProfileSync(false, -1), isFalse);
    });
  });

  group('handleSubscriptionExpired', () {
    DatabaseProvider.setTestPath('test_entitlement.db');
    initTestDb();
    late ProfileService profileService;

    setUp(() async {
      profileService = ProfileService();
      final db = await profileService.database;
      await db.delete('sync_profiles');
    });

    test('single profile is not disabled', () async {
      final profile = await profileService.createProfile(
        name: 'Test Profile',
        sourceCalendarId: 'cal-A',
        targetCalendarId: 'cal-B',
        eventName: '',
        intervalMinutes: 60,
        enabled: true,
        copyDescription: false,
        copyLocation: false,
      );
      var savedProfile = await profileService.getProfile(profile.id);
      expect(savedProfile!.enabled, isTrue);

      await handleSubscriptionExpired(profileService);

      savedProfile = await profileService.getProfile(profile.id);
      expect(savedProfile!.enabled, isTrue);
    });

    test('extra profiles are disabled, first profile unchanged', () async {
      final p1 = await profileService.createProfile(
        name: 'Alpha',
        sourceCalendarId: 'cal-A',
        targetCalendarId: 'cal-B',
        eventName: '',
        intervalMinutes: 60,
        enabled: true,
        copyDescription: false,
        copyLocation: false,
      );
      final p2 = await profileService.createProfile(
        name: 'Beta',
        sourceCalendarId: 'cal-C',
        targetCalendarId: 'cal-D',
        eventName: '',
        intervalMinutes: 60,
        enabled: true,
        copyDescription: false,
        copyLocation: false,
      );
      final p3 = await profileService.createProfile(
        name: 'Gamma',
        sourceCalendarId: 'cal-E',
        targetCalendarId: 'cal-F',
        eventName: '',
        intervalMinutes: 60,
        enabled: true,
        copyDescription: false,
        copyLocation: false,
      );

      await handleSubscriptionExpired(profileService);

      final r1 = await profileService.getProfile(p1.id);
      final r2 = await profileService.getProfile(p2.id);
      final r3 = await profileService.getProfile(p3.id);

      expect(r1!.enabled, isTrue);
      expect(r2!.enabled, isFalse);
      expect(r3!.enabled, isFalse);
    });

    test('manually disabled extra profile stays disabled', () async {
      final p1 = await profileService.createProfile(
        name: 'Alpha',
        sourceCalendarId: 'cal-A',
        targetCalendarId: 'cal-B',
        eventName: '',
        intervalMinutes: 60,
        enabled: true,
        copyDescription: false,
        copyLocation: false,
      );
      final p2 = await profileService.createProfile(
        name: 'Beta',
        sourceCalendarId: 'cal-C',
        targetCalendarId: 'cal-D',
        eventName: '',
        intervalMinutes: 60,
        enabled: true,
        copyDescription: false,
        copyLocation: false,
      );
      await profileService.updateProfile(p2.copyWith(enabled: false));

      await handleSubscriptionExpired(profileService);

      final r1 = await profileService.getProfile(p1.id);
      final r2 = await profileService.getProfile(p2.id);

      expect(r1!.enabled, isTrue);
      expect(r2!.enabled, isFalse);
    });
  });
}
