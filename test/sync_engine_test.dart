import 'package:calendar_sync/calendar/calendar_service.dart';
import 'package:calendar_sync/sync/mapping_database.dart';
import 'package:calendar_sync/sync/sync_engine.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart';

class MockCalendarService extends Mock implements CalendarService {}

class MockMappingDatabase extends Mock implements MappingDatabase {}

void main() {
  initializeTimeZones();
  setLocalLocation(UTC);
  late MockCalendarService calendarService;
  late MockMappingDatabase mappingDb;
  late SyncEngine engine;

  final sourceCalId = 'src-cal';
  final targetCalId = 'tgt-cal';
  final syncName = 'Busy';

  final futureEnd = TZDateTime.utc(2027, 1, 1);
  final oldEnd = TZDateTime.utc(2020, 1, 1);

  Event makeEvent(String id, {required TZDateTime end, TZDateTime? start}) {
    return Event(
      sourceCalId,
      eventId: id,
      title: 'Test Event',
      start: start,
      end: end,
    );
  }

  setUp(() {
    calendarService = MockCalendarService();
    mappingDb = MockMappingDatabase();
    engine = SyncEngine(calendarService, mappingDb);
  });

  group('Deletion pass 7-day threshold + source-by-ID', () {
    test('old past event (target.end < now-7d) → skipped, no source fetch', () async {
      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => []);

      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'source_event_id': 'src-1',
            'target_event_id': 'tgt-1',
            'target_calendar_id': targetCalId,
          },
        ],
      );

      when(() => calendarService.getEvent(targetCalId, 'tgt-1')).thenAnswer(
        (_) async => makeEvent('tgt-1', end: oldEnd, start: oldEnd.subtract(const Duration(hours: 1))),
      );

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
    });

    test('recent event with source exists → re-classified, not deleted', () async {
      final srcEvent = makeEvent('src-1',
          end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1)));

      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => []);

      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'source_event_id': 'src-1',
            'target_event_id': 'tgt-1',
            'target_calendar_id': targetCalId,
          },
        ],
      );

      when(() => calendarService.getEvent(sourceCalId, 'src-1'))
          .thenAnswer((_) async => srcEvent);

      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      when(() => calendarService.getEvent(targetCalId, 'tgt-1')).thenAnswer(
        (_) async => makeEvent('tgt-1', end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1))),
      );

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
    });

    test('recent event with source gone → deleted', () async {
      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => []);

      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'source_event_id': 'src-1',
            'target_event_id': 'tgt-1',
            'target_calendar_id': targetCalId,
          },
        ],
      );

      when(() => calendarService.getEvent(targetCalId, 'tgt-1')).thenAnswer(
        (_) async => makeEvent('tgt-1', end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1))),
      );

      when(() => calendarService.getEvent(sourceCalId, 'src-1'))
          .thenAnswer((_) async => null);

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, hasLength(1));
      expect(plan.toDelete.first['source_event_id'], 'src-1');
    });
  });

  group('Null safety for target event times', () {
    test('target event with null start/end is skipped without crashing', () async {
      final srcEvent = makeEvent('src-1',
          end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1)));

      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'source_event_id': 'src-1',
            'target_event_id': 'tgt-1',
            'target_calendar_id': targetCalId,
          },
        ],
      );

      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      when(() => calendarService.getEvent(targetCalId, 'tgt-1')).thenAnswer(
        (_) async => makeEvent('tgt-1', end: futureEnd, start: null),
      );

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
    });
  });

  group('All-day event sync', () {
    final day1 = TZDateTime.utc(2026, 6, 23);
    final day3 = TZDateTime.utc(2026, 6, 25);
    final localDay1 = day1.add(-DateTime.now().timeZoneOffset);

    Event allDaySource(String id, TZDateTime start, TZDateTime end) {
      return Event(
        sourceCalId,
        eventId: id,
        title: 'All Day Test',
        start: start,
        end: end,
        allDay: true,
      );
    }

    test('single-day all-day source creates timed target with correct dates', () async {
      final srcEvent = allDaySource('src-1', day1, day1);

      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(sourceCalId))
          .thenAnswer((_) async => []);

      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toCreate, hasLength(1));
      final entry = plan.toCreate.first;
      expect(entry.projectedAllDay, false);
      expect(entry.projectedStart, localDay1);
      expect(entry.projectedEnd, localDay1.add(const Duration(days: 1)));
    });

    test('multi-day all-day source creates timed target spanning full days', () async {
      final srcEvent = allDaySource('src-1', day1, day3);
      final localDay3 = day3.add(-DateTime.now().timeZoneOffset);

      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(sourceCalId))
          .thenAnswer((_) async => []);

      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toCreate, hasLength(1));
      final entry = plan.toCreate.first;
      expect(entry.projectedAllDay, false);
      expect(entry.projectedStart, localDay1);
      expect(entry.projectedEnd, localDay3.add(const Duration(days: 1)));
    });

    test('all-day change detection: skip when date and duration match', () async {
      final srcEvent = allDaySource('src-1', day1, day1);
      final tgtStart = day1;
      final tgtEnd = day1.add(const Duration(days: 1));

      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'source_event_id': 'src-1',
            'target_event_id': 'tgt-1',
            'target_calendar_id': targetCalId,
          },
        ],
      );

      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      when(() => calendarService.getEvent(targetCalId, 'tgt-1')).thenAnswer(
        (_) async => Event(
          targetCalId,
          eventId: 'tgt-1',
          title: 'All Day Test',
          description: 'All Day Test',
          start: tgtStart,
          end: tgtEnd,
          allDay: false,
        ),
      );

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toUpdate, isEmpty);
      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
    });

    test('all-day change detection: update when date changes', () async {
      final srcEvent = allDaySource('src-1', day3, day3);
      final tgtStart = day1;
      final tgtEnd = day1.add(const Duration(days: 1));

      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'source_event_id': 'src-1',
            'target_event_id': 'tgt-1',
            'target_calendar_id': targetCalId,
          },
        ],
      );

      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      when(() => calendarService.getEvent(targetCalId, 'tgt-1')).thenAnswer(
        (_) async => Event(
          targetCalId,
          eventId: 'tgt-1',
          title: 'All Day Test',
          description: 'All Day Test',
          start: tgtStart,
          end: tgtEnd,
          allDay: false,
        ),
      );

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toUpdate, hasLength(1));
      expect(plan.toUpdate.first.sourceEvent.eventId, 'src-1');
    });

    test('timed source event is copied as-is (regression)', () async {
      final start = TZDateTime.utc(2026, 6, 23, 14, 0);
      final end = TZDateTime.utc(2026, 6, 23, 15, 0);
      final srcEvent = Event(
        sourceCalId,
        eventId: 'src-1',
        title: 'Timed Event',
        start: start,
        end: end,
        allDay: false,
      );

      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(sourceCalId))
          .thenAnswer((_) async => []);

      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toCreate, hasLength(1));
      final entry = plan.toCreate.first;
      expect(entry.projectedAllDay, false);
      expect(entry.projectedStart, start);
      expect(entry.projectedEnd, end);
    });
  });

  group('Safety net — _execute paths', () {
    final start = TZDateTime.utc(2026, 6, 23, 14, 0);
    final end = TZDateTime.utc(2026, 6, 23, 15, 0);

    test('create path: createEvent is called with correct values', () async {
      final srcEvent = Event(
        sourceCalId, eventId: 'src-1', title: 'Test',
        start: start, end: end, allDay: false,
      );

      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test', allDay: false,
      )).thenAnswer((_) async => 'new-id-1');
      when(() => mappingDb.insertMapping(
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-1',
        targetCalendarId: targetCalId,
        targetEventId: 'new-id-1',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});

      final result = await engine.runSync(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test', allDay: false,
      )).called(1);
      expect(result.synced, ['src-1']);
    });

    test('update path: old event deleted then new event created', () async {
      final srcEvent = Event(
        sourceCalId, eventId: 'src-1', title: 'Test',
        start: start, end: end, allDay: false,
      );
      // Target has different end time → triggers update
      final tgtEnd = end.subtract(const Duration(hours: 1));

      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);
      when(() => calendarService.getEvent(targetCalId, 'tgt-1')).thenAnswer(
        (_) async => Event(targetCalId, eventId: 'tgt-1', title: 'Test',
            start: start, end: tgtEnd,
            description: 'Test'),
      );
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test', allDay: false,
      )).thenAnswer((_) async => 'new-id-2');
      when(() => calendarService.deleteEvent(targetCalId, 'tgt-1'))
          .thenAnswer((_) async => true);
      when(() => mappingDb.insertMapping(
        sourceCalendarId: sourceCalId, sourceEventId: 'src-1',
        targetCalendarId: targetCalId, targetEventId: 'new-id-2',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});

      final result = await engine.runSync(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => calendarService.deleteEvent(targetCalId, 'tgt-1')).called(1);
      verify(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test', allDay: false,
      )).called(1);
      expect(result.updated, ['src-1']);
    });

    test('delete path: deleteEvent and deleteMapping are called', () async {
      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      // Target exists, end is recent, source is gone
      when(() => calendarService.getEvent(targetCalId, 'tgt-1')).thenAnswer(
        (_) async => makeEvent('tgt-1', end: futureEnd,
            start: futureEnd.subtract(const Duration(hours: 1))),
      );
      when(() => calendarService.getEvent(sourceCalId, 'src-1'))
          .thenAnswer((_) async => null);
      when(() => calendarService.deleteEvent(targetCalId, 'tgt-1'))
          .thenAnswer((_) async => true);
      when(() => mappingDb.deleteMapping(1))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => calendarService.deleteEvent(targetCalId, 'tgt-1')).called(1);
      verify(() => mappingDb.deleteMapping(1)).called(1);
      expect(result.deleted, ['src-1']);
    });

    test('errors path: plan.errors non-empty → returns empty SyncResult', () async {
      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => []);
      // getEvent throws inside the orphan loop's try-catch → adds to errors
      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => calendarService.getEvent(targetCalId, 'tgt-1'))
          .thenThrow(Exception('boom'));

      final result = await engine.runSync(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(result.synced, isEmpty);
      expect(result.skipped, isEmpty);
      expect(result.deleted, isEmpty);
      expect(result.updated, isEmpty);
      expect(result.errors, isNotEmpty);
    });
  });

  group('Safety net — orphan mappings', () {
    final day1 = TZDateTime.utc(2026, 6, 23);

    test('target event is null → mapping deleted, no crash', () async {
      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => calendarService.getEvent(targetCalId, 'tgt-1'))
          .thenAnswer((_) async => null);
      when(() => mappingDb.deleteMapping(1))
          .thenAnswer((_) async {});

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => mappingDb.deleteMapping(1)).called(1);
      expect(plan.errors, isEmpty);
    });

    test('all-day target with end=null → mapping preserved, not deleted', () async {
      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => calendarService.getEvent(targetCalId, 'tgt-1')).thenAnswer(
        (_) async => Event(targetCalId, eventId: 'tgt-1',
            start: day1, end: null, allDay: true),
      );

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verifyNever(() => mappingDb.deleteMapping(any()));
      expect(plan.errors, isEmpty);
    });
  });
}
