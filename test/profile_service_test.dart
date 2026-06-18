import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:calendar_sync/settings/profile_service.dart';
import 'package:calendar_sync/sync/mapping_database.dart';
import 'package:calendar_sync/sync/database_provider.dart';
import 'test_helpers.dart';

void main() {
  DatabaseProvider.setTestPath('test_profiles.db');
  initTestDb();
  late ProfileService profileService;
  late MappingDatabase mappingDb;
  late Database db;

  setUp(() async {
    profileService = ProfileService();
    mappingDb = MappingDatabase();
    db = await profileService.database;

    await db.delete('sync_profiles');
    await db.delete('sync_mappings');
    await db.delete('sync_status');
    await db.delete('sync_created_events');
  });

  group('Profile CRUD', () {
    test('createProfile returns SyncProfile with UUID and correct fields', () async {
      final profile = await profileService.createProfile(
        name: 'Test Profile',
        sourceCalendarId: 'cal-A',
        targetCalendarId: 'cal-B',
        eventName: 'Busy',
        intervalMinutes: 30,
        enabled: true,
      );

      expect(profile.id, isNotEmpty);
      expect(profile.id.length, greaterThan(10));
      expect(profile.name, 'Test Profile');
      expect(profile.sourceCalendarId, 'cal-A');
      expect(profile.targetCalendarId, 'cal-B');
      expect(profile.eventName, 'Busy');
      expect(profile.intervalMinutes, 30);
      expect(profile.enabled, true);
    });

    test('listProfiles returns all profiles ordered by name', () async {
      await profileService.createProfile(name: 'Zebra', eventName: 'E', intervalMinutes: 60, enabled: true);
      await profileService.createProfile(name: 'Alpha', eventName: 'E', intervalMinutes: 60, enabled: true);

      final profiles = await profileService.listProfiles();

      expect(profiles.length, 2);
      expect(profiles.first.name, 'Alpha');
      expect(profiles.last.name, 'Zebra');
    });

    test('getProfile returns specific profile by ID', () async {
      final created = await profileService.createProfile(
        name: 'Target', eventName: 'E', intervalMinutes: 60, enabled: true,
      );

      final found = await profileService.getProfile(created.id);

      expect(found, isNotNull);
      expect(found!.id, created.id);
      expect(found.name, 'Target');
    });

    test('getProfile returns null for non-existent ID', () async {
      final found = await profileService.getProfile('nope');
      expect(found, isNull);
    });

    test('updateProfile persists field changes', () async {
      final profile = await profileService.createProfile(
        name: 'Original', eventName: 'E', intervalMinutes: 60, enabled: true,
      );

      await profileService.updateProfile(profile.copyWith(name: 'Changed', enabled: false));

      final updated = await profileService.getProfile(profile.id);
      expect(updated!.name, 'Changed');
      expect(updated.enabled, false);
    });

    test('deleteProfile removes the profile', () async {
      final profile = await profileService.createProfile(
        name: 'ToDelete', eventName: 'E', intervalMinutes: 60, enabled: true,
      );

      await profileService.deleteProfile(profile.id);

      final found = await profileService.getProfile(profile.id);
      expect(found, isNull);
    });

    test('default values for new profile', () async {
      final profile = await profileService.createProfile(
        name: 'Defaults', eventName: '', intervalMinutes: 60, enabled: false,
      );

      expect(profile.eventName, '');
      expect(profile.intervalMinutes, 60);
      expect(profile.enabled, false);
      expect(profile.sourceCalendarId, isNull);
      expect(profile.targetCalendarId, isNull);
    });
  });

  group('Profile validation', () {
    test('isNameTaken returns true for existing name', () async {
      await profileService.createProfile(name: 'Unique', eventName: 'E', intervalMinutes: 60, enabled: true);

      final taken = await profileService.isNameTaken('Unique');
      expect(taken, isTrue);
    });

    test('isNameTaken returns false for new name', () async {
      final taken = await profileService.isNameTaken('NonExistent');
      expect(taken, isFalse);
    });

    test('isNameTaken with excludeId ignores own profile', () async {
      final profile = await profileService.createProfile(name: 'Self', eventName: 'E', intervalMinutes: 60, enabled: true);

      final taken = await profileService.isNameTaken('Self', excludeId: profile.id);
      expect(taken, isFalse);
    });

    test('isSourceTargetPairTaken returns true for existing pair', () async {
      await profileService.createProfile(
        name: 'Pair1', sourceCalendarId: 'cal-A', targetCalendarId: 'cal-B',
        eventName: 'E', intervalMinutes: 60, enabled: true,
      );

      final taken = await profileService.isSourceTargetPairTaken('cal-A', 'cal-B');
      expect(taken, isTrue);
    });

    test('isSourceTargetPairTaken returns false for reverse direction', () async {
      await profileService.createProfile(
        name: 'Pair1', sourceCalendarId: 'cal-A', targetCalendarId: 'cal-B',
        eventName: 'E', intervalMinutes: 60, enabled: true,
      );

      final taken = await profileService.isSourceTargetPairTaken('cal-B', 'cal-A');
      expect(taken, isFalse);
    });

    test('isSourceTargetPairTaken with excludeId ignores own profile', () async {
      final profile = await profileService.createProfile(
        name: 'Self2', sourceCalendarId: 'cal-A', targetCalendarId: 'cal-B',
        eventName: 'E', intervalMinutes: 60, enabled: true,
      );

      final taken = await profileService.isSourceTargetPairTaken('cal-A', 'cal-B', excludeId: profile.id);
      expect(taken, isFalse);
    });
  });

  group('Filters', () {
    test('listEnabledProfiles returns only enabled=true', () async {
      await profileService.createProfile(name: 'Enabled1', eventName: 'E', intervalMinutes: 60, enabled: true);
      await profileService.createProfile(name: 'Disabled1', eventName: 'E', intervalMinutes: 60, enabled: false);
      await profileService.createProfile(name: 'Enabled2', eventName: 'E', intervalMinutes: 60, enabled: true);

      final enabled = await profileService.listEnabledProfiles();

      expect(enabled.length, 2);
      expect(enabled.any((p) => p.name == 'Enabled1'), isTrue);
      expect(enabled.any((p) => p.name == 'Enabled2'), isTrue);
    });

    test('listEnabledProfiles returns empty when all disabled', () async {
      await profileService.createProfile(name: 'D1', eventName: 'E', intervalMinutes: 60, enabled: false);

      final enabled = await profileService.listEnabledProfiles();

      expect(enabled, isEmpty);
    });
  });

  group('Cascade delete', () {
    test('deleteProfile removes mappings from that profile', () async {
      final profile = await profileService.createProfile(
        name: 'Cascade', sourceCalendarId: 'cal-A', targetCalendarId: 'cal-B',
        eventName: 'Busy', intervalMinutes: 60, enabled: true,
      );

      await mappingDb.insertMapping(
        profileId: profile.id,
        sourceCalendarId: 'cal-A',
        sourceEventId: 'evt-1',
        targetCalendarId: 'cal-B',
        targetEventId: 'tgt-1',
        syncedAt: DateTime.now().toIso8601String(),
      );

      await profileService.deleteProfile(profile.id);

      final mappings = await mappingDb.listMappingsForProfile(profile.id);
      expect(mappings, isEmpty);
    });

    test('deleteProfile removes status entries from that profile', () async {
      final profile = await profileService.createProfile(
        name: 'StatusCascade', sourceCalendarId: 'cal-A', targetCalendarId: 'cal-B',
        eventName: 'Busy', intervalMinutes: 60, enabled: true,
      );

      await mappingDb.insertStatus(
        profileId: profile.id,
        timestamp: DateTime.now().toIso8601String(),
        synced: 5, deleted: 0, skipped: 0, updated: 0, errors: 0,
      );

      await profileService.deleteProfile(profile.id);

      final status = await mappingDb.getStatusHistory(profileId: profile.id);
      expect(status, isEmpty);
    });

    test('deleteProfile removes sync_created_events for the profile target events', () async {
      final profile = await profileService.createProfile(
        name: 'CECascade', sourceCalendarId: 'cal-A', targetCalendarId: 'cal-B',
        eventName: 'Busy', intervalMinutes: 60, enabled: true,
      );

      await mappingDb.insertCreatedEvent('cal-B', 'tgt-1');
      await mappingDb.insertMapping(
        profileId: profile.id,
        sourceCalendarId: 'cal-A',
        sourceEventId: 'evt-1',
        targetCalendarId: 'cal-B',
        targetEventId: 'tgt-1',
        syncedAt: DateTime.now().toIso8601String(),
      );

      final exists = await mappingDb.isEventCreatedBySync('cal-B', 'tgt-1');
      expect(exists, isTrue);

      await profileService.deleteProfile(profile.id);

      final gone = await mappingDb.isEventCreatedBySync('cal-B', 'tgt-1');
      expect(gone, isFalse);
    });

    test('deleteProfile does NOT remove sync_created_events from other profiles', () async {
      final profile1 = await profileService.createProfile(
        name: 'Keep', sourceCalendarId: 'cal-A', targetCalendarId: 'cal-B',
        eventName: 'Busy', intervalMinutes: 60, enabled: true,
      );
      final profile2 = await profileService.createProfile(
        name: 'Delete', sourceCalendarId: 'cal-C', targetCalendarId: 'cal-D',
        eventName: 'Busy', intervalMinutes: 60, enabled: true,
      );

      await mappingDb.insertCreatedEvent('cal-B', 'tgt-keep');
      await mappingDb.insertMapping(
        profileId: profile1.id,
        sourceCalendarId: 'cal-A',
        sourceEventId: 'evt-keep',
        targetCalendarId: 'cal-B',
        targetEventId: 'tgt-keep',
        syncedAt: DateTime.now().toIso8601String(),
      );

      await profileService.deleteProfile(profile2.id);

      final stillExists = await mappingDb.isEventCreatedBySync('cal-B', 'tgt-keep');
      expect(stillExists, isTrue);
    });
  });
}
