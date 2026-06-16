import 'package:calendar_sync/calendar/calendar_service.dart';
import 'package:calendar_sync/sync/mapping_database.dart';
import 'package:calendar_sync/sync/sync_engine.dart';
import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCalendarService extends Mock implements CalendarService {}

class MockMappingDatabase extends Mock implements MappingDatabase {}

Event _makeEvent(String id, {required DateTime end, DateTime? start}) {
  final s = start ?? end.subtract(const Duration(hours: 1));
  return Event(
    eventId: id,
    instanceId: id,
    calendarId: 'cal-1',
    title: 'Test Event',
    startDate: s,
    endDate: end,
    isAllDay: false,
    availability: EventAvailability.busy,
    status: EventStatus.none,
    isRecurring: false,
  );
}

Event _allDayEvent(String id, DateTime start, DateTime end) {
  return Event(
    eventId: id,
    instanceId: id,
    calendarId: 'cal-1',
    title: 'All Day Test',
    startDate: start,
    endDate: end,
    isAllDay: true,
    availability: EventAvailability.busy,
    status: EventStatus.none,
    isRecurring: false,
  );
}

void main() {
  late MockCalendarService calendarService;
  late MockMappingDatabase mappingDb;
  late SyncEngine engine;

  final sourceCalId = 'src-cal';
  final targetCalId = 'tgt-cal';
  final syncName = 'Busy';

  final futureEnd = DateTime.utc(2027, 1, 1);
  final oldEnd = DateTime.utc(2020, 1, 1);

  setUp(() {
    calendarService = MockCalendarService();
    mappingDb = MockMappingDatabase();
    engine = SyncEngine(calendarService, mappingDb);
  });

  group('Deletion pass 7-day threshold + source-by-ID', () {
    test('old past event (target.end < now-7d) -> skipped, no source fetch', () async {
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

      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => _makeEvent('tgt-1', end: oldEnd, start: oldEnd.subtract(const Duration(hours: 1))),
      );

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
    });

    test('recent event with source exists -> re-classified, not deleted', () async {
      final srcEvent = _makeEvent('src-1',
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

      when(() => calendarService.getEvent('src-1'))
          .thenAnswer((_) async => srcEvent);

      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => _makeEvent('tgt-1', end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1))),
      );

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
    });

    test('recent event with source gone -> deleted', () async {
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

      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => _makeEvent('tgt-1', end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1))),
      );

      when(() => calendarService.getEvent('src-1'))
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
    test('target event not found is skipped without crashing', () async {
      final srcEvent = _makeEvent('src-1',
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

      when(() => calendarService.getEvent('tgt-1'))
          .thenAnswer((_) async => null);

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
    });
  });

  group('All-day event sync', () {
    final day1 = DateTime.utc(2026, 6, 23);
    final day3 = DateTime.utc(2026, 6, 25);

    test('single-day all-day source creates all-day target with same dates', () async {
      final srcStart = day1;
      final srcEnd = day1.add(const Duration(days: 1));
      final srcEvent = _allDayEvent('src-1', srcStart, srcEnd);

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
      expect(entry.projectedAllDay, true);
      expect(entry.projectedStart, srcStart);
      expect(entry.projectedEnd, srcEnd);
    });

    test('multi-day all-day source creates all-day target with same dates', () async {
      final srcEnd = day3.add(const Duration(days: 1));
      final srcEvent = _allDayEvent('src-1', day1, srcEnd);

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
      expect(entry.projectedAllDay, true);
      expect(entry.projectedStart, day1);
      expect(entry.projectedEnd, srcEnd);
    });

    test('all-day change detection: skip when dates match', () async {
      final srcStart = day1;
      final srcEnd = day1.add(const Duration(days: 1));
      final srcEvent = _allDayEvent('src-1', srcStart, srcEnd);

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

      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => Event(
          eventId: 'tgt-1',
          instanceId: 'tgt-1',
          calendarId: targetCalId,
          title: 'All Day Test',
          description: 'All Day Test',
          startDate: srcStart,
          endDate: srcEnd,
          isAllDay: true,
          availability: EventAvailability.busy,
          status: EventStatus.none,
          isRecurring: false,
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
      final srcStart = day3;
      final srcEnd = day3.add(const Duration(days: 1));
      final srcEvent = _allDayEvent('src-1', srcStart, srcEnd);
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

      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => Event(
          eventId: 'tgt-1',
          instanceId: 'tgt-1',
          calendarId: targetCalId,
          title: 'All Day Test',
          description: 'All Day Test',
          startDate: tgtStart,
          endDate: tgtEnd,
          isAllDay: true,
          availability: EventAvailability.busy,
          status: EventStatus.none,
          isRecurring: false,
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
      final start = DateTime.utc(2026, 6, 23, 14, 0);
      final end = DateTime.utc(2026, 6, 23, 15, 0);
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Timed Event',
        startDate: start,
        endDate: end,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
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

  group('Safety net -- _execute paths', () {
    final start = DateTime.utc(2026, 6, 23, 14, 0);
    final end = DateTime.utc(2026, 6, 23, 15, 0);

    test('create path: createEvent is called with correct values', () async {
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Test',
        startDate: start,
        endDate: end,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test', isAllDay: false,
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
        description: 'Test', isAllDay: false,
      )).called(1);
      expect(result.synced, ['src-1']);
    });

    test('update path: old event deleted then new event created', () async {
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Test',
        startDate: start,
        endDate: end,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );
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
      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => Event(
          eventId: 'tgt-1',
          instanceId: 'tgt-1',
          calendarId: targetCalId,
          title: 'Test',
          startDate: start,
          endDate: tgtEnd,
          description: 'Test',
          isAllDay: false,
          availability: EventAvailability.busy,
          status: EventStatus.none,
          isRecurring: false,
        ),
      );
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test', isAllDay: false,
      )).thenAnswer((_) async => 'new-id-2');
      when(() => calendarService.deleteEvent('tgt-1'))
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

      verify(() => calendarService.deleteEvent('tgt-1')).called(1);
      verify(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test', isAllDay: false,
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
      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => _makeEvent('tgt-1', end: futureEnd,
            start: futureEnd.subtract(const Duration(hours: 1))),
      );
      when(() => calendarService.getEvent('src-1'))
          .thenAnswer((_) async => null);
      when(() => calendarService.deleteEvent('tgt-1'))
          .thenAnswer((_) async => true);
      when(() => mappingDb.deleteMapping(1))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => calendarService.deleteEvent('tgt-1')).called(1);
      verify(() => mappingDb.deleteMapping(1)).called(1);
      expect(result.deleted, ['src-1']);
    });

    test('errors path: plan.errors non-empty -> returns empty SyncResult', () async {
      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => calendarService.getEvent('tgt-1'))
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

  group('Safety net -- orphan mappings', () {
    final day1 = DateTime.utc(2026, 6, 23);

    test('target event is null -> mapping deleted, no crash', () async {
      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => calendarService.getEvent('tgt-1'))
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

    test('all-day target with far-future end -> mapping preserved, not deleted', () async {
      when(() => calendarService.listEvents(sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => calendarService.getEvent('src-1'))
          .thenAnswer((_) async => _makeEvent('src-1', end: futureEnd));
      when(() => mappingDb.isEventSynced(sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);
      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => Event(
          eventId: 'tgt-1',
          instanceId: 'tgt-1',
          calendarId: targetCalId,
          title: 'Test',
          startDate: day1,
          endDate: futureEnd,
          isAllDay: true,
          availability: EventAvailability.busy,
          status: EventStatus.none,
          isRecurring: false,
        ),
      );

      final plan = await engine.runDryRun(
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
      expect(plan.errors, isEmpty);
    });
  });
}
