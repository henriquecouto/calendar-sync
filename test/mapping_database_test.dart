import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:calendar_sync/sync/mapping_database.dart';
import 'package:calendar_sync/sync/database_provider.dart';
import 'test_helpers.dart';

void main() {
  DatabaseProvider.setTestPath('test_mapping.db');
  initTestDb();  late MappingDatabase mappingDb;
  late Database db;

  setUp(() async {
    mappingDb = MappingDatabase();
    db = await mappingDb.database;

    await db.delete('sync_status');
    await db.delete('sync_mappings');
  });

  group('Status history', () {
    test('insertStatus with profileId persists correctly', () async {
      await mappingDb.insertStatus(
        profileId: 'prof-1',
        timestamp: '2026-06-17T10:00:00',
        synced: 3, deleted: 1, skipped: 2, updated: 0, errors: 0,
      );

      final history = await mappingDb.getStatusHistory();
      expect(history.length, 1);
      expect(history.first['profile_id'], 'prof-1');
      expect(history.first['synced'], 3);
      expect(history.first['deleted'], 1);
    });

    test('getStatusHistory filtered by profileId returns only that profile', () async {
      await mappingDb.insertStatus(
        profileId: 'prof-A', timestamp: '2026-06-17T10:00:00',
        synced: 1, deleted: 0, skipped: 0, updated: 0, errors: 0,
      );
      await mappingDb.insertStatus(
        profileId: 'prof-B', timestamp: '2026-06-17T11:00:00',
        synced: 5, deleted: 0, skipped: 0, updated: 0, errors: 0,
      );

      final filtered = await mappingDb.getStatusHistory(profileId: 'prof-A');
      expect(filtered.length, 1);
      expect(filtered.first['profile_id'], 'prof-A');
    });

    test('getStatusHistory without filter returns all profiles', () async {
      await mappingDb.insertStatus(
        profileId: 'prof-A', timestamp: '2026-06-17T10:00:00',
        synced: 1, deleted: 0, skipped: 0, updated: 0, errors: 0,
      );
      await mappingDb.insertStatus(
        profileId: 'prof-B', timestamp: '2026-06-17T11:00:00',
        synced: 2, deleted: 0, skipped: 0, updated: 0, errors: 0,
      );

      final all = await mappingDb.getStatusHistory();
      expect(all.length, 2);
    });

    test('status capped at 20 rows per profile', () async {
      for (int i = 0; i < 25; i++) {
        await mappingDb.insertStatus(
          profileId: 'prof-1', timestamp: '2026-06-17T$i:00:00',
          synced: 1, deleted: 0, skipped: 0, updated: 0, errors: 0,
        );
      }

      final history = await mappingDb.getStatusHistory(profileId: 'prof-1');
      expect(history.length, 20);
    });

    test('status cap is per-profile, not global', () async {
      for (int i = 0; i < 25; i++) {
        await mappingDb.insertStatus(
          profileId: 'prof-A', timestamp: '2026-06-17T${i}A:00:00',
          synced: 1, deleted: 0, skipped: 0, updated: 0, errors: 0,
        );
        await mappingDb.insertStatus(
          profileId: 'prof-B', timestamp: '2026-06-17T${i}B:00:00',
          synced: 1, deleted: 0, skipped: 0, updated: 0, errors: 0,
        );
      }

      final historyA = await mappingDb.getStatusHistory(profileId: 'prof-A');
      final historyB = await mappingDb.getStatusHistory(profileId: 'prof-B');

      expect(historyA.length, 20);
      expect(historyB.length, 20);
    });
  });

  group('Per-instance mappings', () {
    Future<void> insert(String profileId, String sourceEventId,
        {String? sourceInstanceId, String? targetEventId}) async {
      await mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: 'cal-a',
        sourceEventId: sourceEventId,
        sourceInstanceId: sourceInstanceId,
        targetCalendarId: 'cal-b',
        targetEventId: targetEventId ?? 'tgt-$sourceEventId-${sourceInstanceId ?? 'x'}',
        syncedAt: '2026-06-17T10:00:00',
      );
    }

    test('insertMapping stores source_instance_id for occurrences', () async {
      await insert('prof-1', '100', sourceInstanceId: '100@t1');

      final rows = await mappingDb.listMappingsForCalendar('prof-1', 'cal-a');
      expect(rows, hasLength(1));
      expect(rows.first['source_event_id'], '100');
      expect(rows.first['source_instance_id'], '100@t1');
    });

    test('insertMapping stores null instance id for non-recurring events', () async {
      await insert('prof-1', 'src-1');

      final rows = await mappingDb.listMappingsForCalendar('prof-1', 'cal-a');
      expect(rows, hasLength(1));
      expect(rows.first['source_instance_id'], isNull);
    });

    test('two occurrences of the same series map independently', () async {
      await insert('prof-1', '100', sourceInstanceId: '100@t1');
      await insert('prof-1', '100', sourceInstanceId: '100@t2');

      final rows = await mappingDb.listMappingsForCalendar('prof-1', 'cal-a');
      expect(rows, hasLength(2));
    });

    test('same instance twice is prevented by the UNIQUE constraint', () async {
      await insert('prof-1', '100', sourceInstanceId: '100@t1');
      await insert('prof-1', '100', sourceInstanceId: '100@t1');

      final rows = await mappingDb.listMappingsForCalendar('prof-1', 'cal-a');
      expect(rows, hasLength(1));
    });

    test('isEventSynced distinguishes instances of the same series', () async {
      await insert('prof-1', '100', sourceInstanceId: '100@t1');

      expect(
        await mappingDb.isEventSynced('prof-1', 'cal-a', '100',
            sourceInstanceId: '100@t1'),
        isTrue,
      );
      expect(
        await mappingDb.isEventSynced('prof-1', 'cal-a', '100',
            sourceInstanceId: '100@t2'),
        isFalse,
      );
      expect(
        await mappingDb.isEventSynced('prof-1', 'cal-a', '100'),
        isFalse,
      );
    });

    test('non-recurring event is still found without instance id', () async {
      await insert('prof-1', 'src-1');

      expect(
        await mappingDb.isEventSynced('prof-1', 'cal-a', 'src-1'),
        isTrue,
      );
    });
  });
}
