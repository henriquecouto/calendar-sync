import 'package:calendar_sync/calendar/calendar_service.dart';
import 'package:calendar_sync/sync/mapping_database.dart';
import 'package:calendar_sync/sync/sync_engine.dart';
import 'package:crypto/crypto.dart';
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
  final profileId = 'test-profile';

  final futureEnd = DateTime.utc(2027, 1, 1);
  final oldEnd = DateTime.utc(2020, 1, 1);

  setUp(() {
    calendarService = MockCalendarService();
    mappingDb = MockMappingDatabase();
    engine = SyncEngine(calendarService, mappingDb);
  });

  group('Deletion pass 7-day threshold + source-by-ID', () {
    test('old past event (target.end < now-7d) -> skipped, no source fetch', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
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
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
    });

    test('recent event with source exists -> re-classified, not deleted', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
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
        (_) async => Event(
          eventId: 'tgt-1',
          instanceId: 'tgt-1',
          calendarId: targetCalId,
          title: 'Busy',
          description: 'Test Event\n---\n🔃 Automatically created by CalSync',
          startDate: futureEnd.subtract(const Duration(hours: 1)),
          endDate: futureEnd,
          isAllDay: false,
          availability: EventAvailability.busy,
          status: EventStatus.none,
          isRecurring: false,
        ),
      );

      when(() => calendarService.getEvent('src-1')).thenAnswer(
        (_) async => _makeEvent('src-1', end: futureEnd,
            start: futureEnd.subtract(const Duration(hours: 1))),
      );

      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
      verify(() => calendarService.getEvent('src-1')).called(1);
    });

    test('recent event with source gone -> deleted', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
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
        (_) async => _makeEvent('tgt-1', end: futureEnd,
            start: futureEnd.subtract(const Duration(hours: 1))),
      );

      when(() => calendarService.getEvent('src-1'))
          .thenAnswer((_) async => null);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, hasLength(1));
      expect(plan.toDelete.first['source_event_id'], 'src-1');
      verify(() => calendarService.getEvent('src-1')).called(1);
    });

    test('recent event source found -> re-classified (skip when unchanged)', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
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
        (_) async => Event(
          eventId: 'tgt-1',
          instanceId: 'tgt-1',
          calendarId: targetCalId,
          title: 'Busy',
          description: 'Test Event\n---\n🔃 Automatically created by CalSync',
          startDate: futureEnd.subtract(const Duration(hours: 1)),
          endDate: futureEnd,
          isAllDay: false,
          availability: EventAvailability.busy,
          status: EventStatus.none,
          isRecurring: false,
        ),
      );

      when(() => calendarService.getEvent('src-1')).thenAnswer(
        (_) async => _makeEvent('src-1', end: futureEnd,
            start: futureEnd.subtract(const Duration(hours: 1))),
      );

      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
      expect(plan.toUpdate, isEmpty);
      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
      verify(() => calendarService.getEvent('src-1')).called(1);
    });

    test('recent event source found with changed time -> classified as toUpdate', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'source_event_id': 'src-1',
            'target_event_id': 'tgt-1',
            'target_calendar_id': targetCalId,
          },
        ],
      );

      final changedStart = futureEnd.subtract(const Duration(hours: 2));

      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => Event(
          eventId: 'tgt-1',
          instanceId: 'tgt-1',
          calendarId: targetCalId,
          title: 'Busy',
          description: 'Test Event\n---\n🔃 Automatically created by CalSync',
          startDate: futureEnd.subtract(const Duration(hours: 1)),
          endDate: futureEnd,
          isAllDay: false,
          availability: EventAvailability.busy,
          status: EventStatus.none,
          isRecurring: false,
        ),
      );

      when(() => calendarService.getEvent('src-1')).thenAnswer(
        (_) async => _makeEvent('src-1', end: futureEnd, start: changedStart),
      );

      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
      expect(plan.toUpdate, hasLength(1));
      expect(plan.toUpdate.first.sourceEvent.eventId, 'src-1');
      verify(() => calendarService.getEvent('src-1')).called(1);
    });
  });

  group('Null safety for target event times', () {
    test('target event not found is skipped without crashing', () async {
      final srcEvent = _makeEvent('src-1',
          end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1)));

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'source_event_id': 'src-1',
            'target_event_id': 'tgt-1',
            'target_calendar_id': targetCalId,
          },
        ],
      );

      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      when(() => calendarService.getEvent('tgt-1'))
          .thenAnswer((_) async => null);

      final plan = await engine.runDryRun(
        profileId: profileId,
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

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);

      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        profileId: profileId,
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

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);

      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        profileId: profileId,
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

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'source_event_id': 'src-1',
            'target_event_id': 'tgt-1',
            'target_calendar_id': targetCalId,
          },
        ],
      );

      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
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
        profileId: profileId,
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

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'source_event_id': 'src-1',
            'target_event_id': 'tgt-1',
            'target_calendar_id': targetCalId,
          },
        ],
      );

      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
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
        profileId: profileId,
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

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);

      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);

      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        profileId: profileId,
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

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync', isAllDay: false,
      )).thenAnswer((_) async => 'new-id-1');
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-1',
        targetCalendarId: targetCalId,
        targetEventId: 'new-id-1',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id-1'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync', isAllDay: false,
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

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
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
        description: 'Test\n---\n🔃 Automatically created by CalSync', isAllDay: false,
      )).thenAnswer((_) async => 'new-id-2');
      when(() => calendarService.deleteEvent('tgt-1'))
                    .thenAnswer((_) async => const CalendarDeleteResult(success: true));
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId, sourceEventId: 'src-1',
        targetCalendarId: targetCalId, targetEventId: 'new-id-2',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.deleteCreatedEvent(targetCalId, 'tgt-1'))
          .thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id-2'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => calendarService.deleteEvent('tgt-1')).called(1);
      verify(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync', isAllDay: false,
      )).called(1);
      expect(result.updated, ['src-1']);
    });

    test('delete path: deleteEvent and deleteMapping are called', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
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
                    .thenAnswer((_) async => const CalendarDeleteResult(success: true));
      when(() => mappingDb.deleteMapping(1))
          .thenAnswer((_) async {});
      when(() => mappingDb.deleteCreatedEvent(targetCalId, 'tgt-1'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => calendarService.deleteEvent('tgt-1')).called(1);
      verify(() => mappingDb.deleteMapping(1)).called(1);
      verify(() => calendarService.getEvent('src-1')).called(1);
      expect(result.deleted, ['src-1']);
    });

    test('errors path: plan.errors non-empty -> returns empty SyncResult', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => calendarService.getEvent('tgt-1'))
          .thenThrow(Exception('boom'));

      final result = await engine.runSync(
        profileId: profileId,
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
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => calendarService.getEvent('tgt-1'))
          .thenAnswer((_) async => null);
      when(() => mappingDb.deleteMapping(1))
          .thenAnswer((_) async {});
      when(() => mappingDb.deleteCreatedEvent(targetCalId, 'tgt-1'))
          .thenAnswer((_) async {});

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => mappingDb.deleteMapping(1)).called(1);
      expect(plan.errors, isEmpty);
    });

    test('all-day target with far-future end -> source missing, target deleted', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
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
      when(() => calendarService.getEvent('src-1'))
          .thenAnswer((_) async => null);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, hasLength(1));
      expect(plan.errors, isEmpty);
    });
  });

  group('Sync loop prevention', () {
    test('event in sync_created_events is skipped', () async {
      final srcEvent = _makeEvent('src-1', end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1)));

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toCreate, isEmpty);
      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
    });

    test('event NOT in sync_created_events is classified normally', () async {
      final srcEvent = _makeEvent('src-1', end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1)));

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toCreate, hasLength(1));
    });

    test('event with marker in description is skipped (description-based detection)', () async {
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Test',
        startDate: futureEnd.subtract(const Duration(hours: 1)),
        endDate: futureEnd,
        description: 'Test\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toCreate, isEmpty);
      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
    });

    test('user event without marker is classified normally', () async {
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Test',
        startDate: futureEnd.subtract(const Duration(hours: 1)),
        endDate: futureEnd,
        description: 'User created event',
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toCreate, hasLength(1));
    });

    test('update detection correctly handles marked description via contains', () async {
      final start = DateTime.utc(2026, 6, 23, 14, 0);
      final end = DateTime.utc(2026, 6, 23, 15, 0);
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Test Event',
        startDate: start,
        endDate: end,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);
      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => Event(
          eventId: 'tgt-1',
          instanceId: 'tgt-1',
          calendarId: targetCalId,
          title: 'Busy',
          description: 'Test Event\n---\n🔃 Automatically created by CalSync',
          startDate: start,
          endDate: end,
          isAllDay: false,
          availability: EventAvailability.busy,
          status: EventStatus.none,
          isRecurring: false,
        ),
      );

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toUpdate, isEmpty);
      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
    });

    test('null description does not crash (falls back to sync_created_events)', () async {
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Test',
        startDate: futureEnd.subtract(const Duration(hours: 1)),
        endDate: futureEnd,
        description: null,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toCreate, isEmpty);
      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
    });

    test('HTML-wrapped description is recognized as unchanged via contains', () async {
      final start = DateTime.utc(2026, 6, 23, 14, 0);
      final end = DateTime.utc(2026, 6, 23, 15, 0);
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Doctor Appointment',
        startDate: start,
        endDate: end,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);
      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => Event(
          eventId: 'tgt-1',
          instanceId: 'tgt-1',
          calendarId: targetCalId,
          title: 'Busy',
          description: '<html><body>Doctor Appointment<br>---<br>🔃 Automatically created by CalSync</body></html>',
          startDate: start,
          endDate: end,
          isAllDay: false,
          availability: EventAvailability.busy,
          status: EventStatus.none,
          isRecurring: false,
        ),
      );

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toUpdate, isEmpty);
      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
    });

    test('after CREATE, sync_created_events is called with target calendar and event', () async {
      final srcEvent = _makeEvent('src-1', end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1)));

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, any(), any(),
        description: 'Test Event\n---\n🔃 Automatically created by CalSync', isAllDay: false,
      )).thenAnswer((_) async => 'new-id');
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-1',
        targetCalendarId: targetCalId,
        targetEventId: 'new-id',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id'))
          .thenAnswer((_) async {});

      await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id')).called(1);
    });

    test('after orphan DELETE, sync_created_events is removed', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => null,
      );
      when(() => mappingDb.deleteMapping(1))
          .thenAnswer((_) async {});
      when(() => mappingDb.deleteCreatedEvent(targetCalId, 'tgt-1'))
          .thenAnswer((_) async {});

      await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => mappingDb.deleteCreatedEvent(targetCalId, 'tgt-1')).called(1);
    });

    test('after UPDATE, old createdEvent removed and new inserted', () async {
      final start = DateTime.utc(2026, 6, 23, 14, 0);
      final end = DateTime.utc(2026, 6, 23, 15, 0);
      final srcEvent = Event(
        eventId: 'src-1', instanceId: 'src-1', calendarId: sourceCalId,
        title: 'Test', startDate: start, endDate: end,
        isAllDay: false, availability: EventAvailability.busy,
        status: EventStatus.none, isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).thenAnswer(
        (_) async => [{
          'id': 1, 'source_event_id': 'src-1',
          'target_event_id': 'tgt-1', 'target_calendar_id': targetCalId,
        }],
      );
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);
      when(() => calendarService.getEvent('tgt-1')).thenAnswer(
        (_) async => _makeEvent('tgt-1', end: end.subtract(const Duration(minutes: 30)),
            start: start.add(const Duration(minutes: 30))),
      );
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync', isAllDay: false,
      )).thenAnswer((_) async => 'new-id');
      when(() => calendarService.deleteEvent('tgt-1'))
                    .thenAnswer((_) async => const CalendarDeleteResult(success: true));
      when(() => mappingDb.deleteCreatedEvent(targetCalId, 'tgt-1'))
          .thenAnswer((_) async {});
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId, sourceEventId: 'src-1',
        targetCalendarId: targetCalId, targetEventId: 'new-id',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id'))
          .thenAnswer((_) async {});

      await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => mappingDb.deleteCreatedEvent(targetCalId, 'tgt-1')).called(1);
      verify(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id')).called(1);
    });

    test('bidirectional: profile A creates in B, profile B scanning B skips it', () async {
      final otherProfileId = 'other-profile';
      final srcEvent = _makeEvent('src-1', end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1)));

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(otherProfileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);

      final plan = await engine.runDryRun(
        profileId: otherProfileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toCreate, isEmpty);
      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
    });
  });

  group('Profile-scoped mappings', () {
    final otherProfileId = 'other-profile';

    test('same source event synced by 2 profiles creates independent mappings', () async {
      final start = DateTime.utc(2026, 6, 23, 14, 0);
      final end = DateTime.utc(2026, 6, 23, 15, 0);
      final srcEvent = Event(
        eventId: 'src-1', instanceId: 'src-1', calendarId: sourceCalId,
        title: 'Test', startDate: start, endDate: end,
        isAllDay: false, availability: EventAvailability.busy,
        status: EventStatus.none, isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync', isAllDay: false,
      )).thenAnswer((_) async => 'tgt-A');
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-1',
        targetCalendarId: targetCalId,
        targetEventId: 'tgt-A',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'tgt-A'))
          .thenAnswer((_) async {});

      await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-1',
        targetCalendarId: targetCalId,
        targetEventId: 'tgt-A',
        syncedAt: any(named: 'syncedAt'),
      )).called(1);

      verifyNever(() => mappingDb.insertMapping(
        profileId: otherProfileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-1',
        targetCalendarId: targetCalId,
        targetEventId: any(named: 'targetEventId'),
        syncedAt: any(named: 'syncedAt'),
      ));
    });

    test('isEventSynced is called with the correct profile ID', () async {
      final srcEvent = _makeEvent('src-1', end: futureEnd, start: futureEnd.subtract(const Duration(hours: 1)));

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1')).called(1);
    });

    test('listMappingsForCalendar is called with the correct profile ID', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);

      await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId)).called(1);
    });
  });

  group('Recurring events expand to independent instances', () {
    final start = DateTime.utc(2026, 6, 23, 14, 0);
    final end = DateTime.utc(2026, 6, 23, 15, 0);

    Event occurrence(String id, String instanceId,
        {DateTime? startDate, DateTime? endDate}) {
      return Event(
        eventId: id,
        instanceId: instanceId,
        calendarId: sourceCalId,
        title: 'Weekly Standup',
        startDate: startDate ?? start,
        endDate: endDate ?? end,
        isAllDay: false,
        isRecurring: true,
        recurrenceRule: null,
        availability: EventAvailability.busy,
        status: EventStatus.none,
      );
    }

    Event targetEvent(String id, {DateTime? endDate}) {
      return Event(
        eventId: id,
        instanceId: id,
        calendarId: targetCalId,
        title: 'Busy',
        description: 'Weekly Standup\n---\n🔃 Automatically created by CalSync',
        startDate: start,
        endDate: endDate ?? futureEnd,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );
    }

    test('occurrence creates standalone target without recurrence rule', () async {
      final srcEvent = occurrence('src-1', 'src-1@t1');

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1',
              sourceInstanceId: 'src-1@t1'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Weekly Standup\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
      )).thenAnswer((_) async => 'new-id-1');
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-1',
        sourceInstanceId: 'src-1@t1',
        targetCalendarId: targetCalId,
        targetEventId: 'new-id-1',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id-1'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Weekly Standup\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
      )).called(1);
      expect(result.synced, ['src-1']);
    });

    test('5 instances create 5 independent targets and 5 mappings', () async {
      final instances = List.generate(
        5,
        (i) => occurrence('src-1', 'src-1@t$i'),
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => instances);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(
            profileId,
            sourceCalId,
            'src-1',
            sourceInstanceId: any(named: 'sourceInstanceId'),
          )).thenAnswer((_) async => false);

      var createCount = 0;
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: any(named: 'description'),
        isAllDay: false,
      )).thenAnswer((_) async {
        createCount++;
        return 'new-id-$createCount';
      });
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-1',
        sourceInstanceId: any(named: 'sourceInstanceId'),
        targetCalendarId: targetCalId,
        targetEventId: any(named: 'targetEventId'),
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(
            targetCalId,
            any(),
          )).thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => calendarService.createEvent(
            targetCalId, syncName, start, end,
            description: any(named: 'description'),
            isAllDay: false,
          )).called(5);
      verify(() => mappingDb.insertMapping(
            profileId: profileId,
            sourceCalendarId: sourceCalId,
            sourceEventId: 'src-1',
            sourceInstanceId: any(named: 'sourceInstanceId'),
            targetCalendarId: targetCalId,
            targetEventId: any(named: 'targetEventId'),
            syncedAt: any(named: 'syncedAt'),
          )).called(5);
      expect(result.synced.length, 5);
    });

    test('moved occurrence: old slot deleted, new slot created', () async {
      final newOccurrence = occurrence('src-1', 'src-1@t2');

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [newOccurrence]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'source_event_id': 'src-1',
                  'source_instance_id': 'src-1@t1',
                  'target_event_id': 'tgt-old',
                  'target_calendar_id': targetCalId,
                },
              ]);
      when(() => calendarService.getEvent('tgt-old'))
          .thenAnswer((_) async => targetEvent('tgt-old'));
      when(() => calendarService.getEvent('src-1'))
          .thenAnswer((_) async => targetEvent('src-1'));
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1',
              sourceInstanceId: 'src-1@t2'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, hasLength(1));
      expect(plan.toDelete.first['source_instance_id'], 'src-1@t1');
      expect(plan.toCreate, hasLength(1));
      expect(plan.toCreate.first.sourceInstanceId, 'src-1@t2');
    });

    test('deleted occurrence exception removes only its target', () async {
      final inst2 = occurrence('src-1', 'src-1@t2');
      final inst3 = occurrence('src-1', 'src-1@t3');

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [inst2, inst3]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'source_event_id': 'src-1',
                  'source_instance_id': 'src-1@t1',
                  'target_event_id': 'tgt-1',
                  'target_calendar_id': targetCalId,
                },
                {
                  'id': 2,
                  'source_event_id': 'src-1',
                  'source_instance_id': 'src-1@t2',
                  'target_event_id': 'tgt-2',
                  'target_calendar_id': targetCalId,
                },
              ]);
      when(() => calendarService.getEvent('tgt-1'))
          .thenAnswer((_) async => targetEvent('tgt-1'));
      when(() => calendarService.getEvent('tgt-2'))
          .thenAnswer((_) async => targetEvent('tgt-2'));
      when(() => calendarService.getEvent('src-1'))
          .thenAnswer((_) async => targetEvent('src-1'));
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1',
              sourceInstanceId: any(named: 'sourceInstanceId')))
          .thenAnswer((_) async => true);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, hasLength(1));
      expect(plan.toDelete.first['source_instance_id'], 'src-1@t1');
    });

    test('deleted series removes all its instance mappings', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'source_event_id': 'src-1',
                  'source_instance_id': 'src-1@t1',
                  'target_event_id': 'tgt-1',
                  'target_calendar_id': targetCalId,
                },
                {
                  'id': 2,
                  'source_event_id': 'src-1',
                  'source_instance_id': 'src-1@t2',
                  'target_event_id': 'tgt-2',
                  'target_calendar_id': targetCalId,
                },
              ]);
      when(() => calendarService.getEvent('tgt-1'))
          .thenAnswer((_) async => targetEvent('tgt-1'));
      when(() => calendarService.getEvent('tgt-2'))
          .thenAnswer((_) async => targetEvent('tgt-2'));
      when(() => calendarService.getEvent('src-1'))
          .thenAnswer((_) async => null);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, hasLength(2));
    });

    test('aged-out occurrence is kept', () async {
      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => []);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'source_event_id': 'src-1',
                  'source_instance_id': 'src-1@t1',
                  'target_event_id': 'tgt-1',
                  'target_calendar_id': targetCalId,
                },
              ]);
      when(() => calendarService.getEvent('tgt-1'))
          .thenAnswer((_) async => targetEvent('tgt-1', endDate: oldEnd));

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
      verifyNever(() => calendarService.getEvent('src-1'));
    });

    test('legacy series mapping is lazily replaced', () async {
      final inst1 = occurrence('src-1', 'src-1@t1');
      final inst2 = occurrence('src-1', 'src-1@t2');

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [inst1, inst2]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'source_event_id': 'src-1',
                  'source_instance_id': null,
                  'target_event_id': 'tgt-series',
                  'target_calendar_id': targetCalId,
                },
              ]);
      when(() => calendarService.getEvent('tgt-series'))
          .thenAnswer((_) async => targetEvent('tgt-series'));
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1',
              sourceInstanceId: any(named: 'sourceInstanceId')))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, hasLength(1));
      expect(plan.toDelete.first['target_event_id'], 'tgt-series');
      expect(plan.toCreate, hasLength(2));
    });

    test('legacy non-recurring mapping is untouched', () async {
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Doctor Appointment',
        startDate: start,
        endDate: end,
        isAllDay: false,
        isRecurring: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'source_event_id': 'src-1',
                  'source_instance_id': null,
                  'target_event_id': 'tgt-1',
                  'target_calendar_id': targetCalId,
                },
              ]);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => true);
      when(() => calendarService.getEvent('tgt-1'))
          .thenAnswer((_) async => Event(
                eventId: 'tgt-1',
                instanceId: 'tgt-1',
                calendarId: targetCalId,
                title: 'Busy',
                description:
                    'Doctor Appointment\n---\n🔃 Automatically created by CalSync',
                startDate: start,
                endDate: end,
                isAllDay: false,
                availability: EventAvailability.busy,
                status: EventStatus.none,
                isRecurring: false,
              ));

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      expect(plan.toDelete, isEmpty);
      expect(plan.toSkip.any((e) => e.eventId == 'src-1'), isTrue);
    });

    test('failed legacy deletion keeps mapping for retry', () async {
      final inst1 = occurrence('src-1', 'src-1@t1');

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [inst1]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'source_event_id': 'src-1',
                  'source_instance_id': null,
                  'target_event_id': 'tgt-series',
                  'target_calendar_id': targetCalId,
                },
              ]);
      when(() => calendarService.getEvent('tgt-series'))
          .thenAnswer((_) async => targetEvent('tgt-series'));
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1',
              sourceInstanceId: 'src-1@t1'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: any(named: 'description'),
        isAllDay: false,
      )).thenAnswer((_) async => 'new-id-1');
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-1',
        sourceInstanceId: any(named: 'sourceInstanceId'),
        targetCalendarId: targetCalId,
        targetEventId: any(named: 'targetEventId'),
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(
            targetCalId,
            any(),
          )).thenAnswer((_) async {});
      when(() => calendarService.deleteEvent('tgt-series')).thenAnswer(
          (_) async => const CalendarDeleteResult(success: false));

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verifyNever(() => mappingDb.deleteMapping(1));
      expect(result.errors, isNotEmpty);
    });
  });

  group('Original event name (empty syncEventName)', () {
    test('empty syncEventName uses source event title as projectedTitle', () async {
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Doctor Appointment',
        startDate: futureEnd.subtract(const Duration(hours: 1)),
        endDate: futureEnd,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: '',
      );

      expect(plan.toCreate, hasLength(1));
      expect(plan.toCreate.first.projectedTitle, 'Doctor Appointment');
    });

    test('non-empty syncEventName uses syncEventName as projectedTitle', () async {
      final srcEvent = _makeEvent('src-1', end: futureEnd,
          start: futureEnd.subtract(const Duration(hours: 1)));

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);

      final plan = await engine.runDryRun(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: 'Busy',
      );

      expect(plan.toCreate, hasLength(1));
      expect(plan.toCreate.first.projectedTitle, 'Busy');
    });
  });

  group('copyDescription', () {
    final start = DateTime.utc(2027, 6, 1, 10, 0);
    final end = DateTime.utc(2027, 6, 1, 11, 0);

    test('create path with copyDescription=true includes source description', () async {
      final srcEvent = Event(
        eventId: 'src-1',
        instanceId: 'src-1',
        calendarId: sourceCalId,
        title: 'Test',
        description: 'Q3 planning notes',
        startDate: start,
        endDate: end,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-1'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Q3 planning notes\n\nTest\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
      )).thenAnswer((_) async => 'new-id-1');
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId, sourceEventId: 'src-1',
        targetCalendarId: targetCalId, targetEventId: 'new-id-1',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id-1'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
        copyDescription: true,
      );

      verify(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Q3 planning notes\n\nTest\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
      )).called(1);
      expect(result.synced, ['src-1']);
    });

    test('copyDescription=true with null source description falls back to standard', () async {
      final srcEvent = Event(
        eventId: 'src-2',
        instanceId: 'src-2',
        calendarId: sourceCalId,
        title: 'Test',
        description: null,
        startDate: start,
        endDate: end,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-2'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-2'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
      )).thenAnswer((_) async => 'new-id-2');
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId, sourceEventId: 'src-2',
        targetCalendarId: targetCalId, targetEventId: 'new-id-2',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id-2'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
        copyDescription: true,
      );

      verify(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
      )).called(1);
      expect(result.synced, ['src-2']);
    });
  });

  group('copyLocation', () {
    final start = DateTime.utc(2027, 6, 1, 10, 0);
    final end = DateTime.utc(2027, 6, 1, 11, 0);

    test('create path with copyLocation=true passes location to createEvent', () async {
      final srcEvent = Event(
        eventId: 'src-3',
        instanceId: 'src-3',
        calendarId: sourceCalId,
        title: 'Test',
        location: 'Conference Room A',
        startDate: start,
        endDate: end,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-3'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-3'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
        location: 'Conference Room A',
      )).thenAnswer((_) async => 'new-id-3');
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId, sourceEventId: 'src-3',
        targetCalendarId: targetCalId, targetEventId: 'new-id-3',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id-3'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
        copyLocation: true,
      );

      verify(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
        location: 'Conference Room A',
      )).called(1);
      expect(result.synced, ['src-3']);
    });

    test('create path with copyLocation=false does not pass location', () async {
      final srcEvent = Event(
        eventId: 'src-4',
        instanceId: 'src-4',
        calendarId: sourceCalId,
        title: 'Test',
        location: 'Conference Room A',
        startDate: start,
        endDate: end,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-4'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-4'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
        location: null,
      )).thenAnswer((_) async => 'new-id-4');
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId, sourceEventId: 'src-4',
        targetCalendarId: targetCalId, targetEventId: 'new-id-4',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-id-4'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
      );

      verify(() => calendarService.createEvent(
        targetCalId, syncName, start, end,
        description: 'Test\n---\n🔃 Automatically created by CalSync',
        isAllDay: false,
        location: null,
      )).called(1);
      expect(result.synced, ['src-4']);
    });
  });

  group('omitSourceTitle', () {
    final start = DateTime.utc(2027, 6, 1, 10, 0);
    final end = DateTime.utc(2027, 6, 1, 11, 0);
    const marker = '🔃 Automatically created by CalSync';
    final expectedHash =
        'de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333';

    Event makeEvent(String id, String title) {
      return Event(
        eventId: id,
        instanceId: id,
        calendarId: sourceCalId,
        title: title,
        startDate: start,
        endDate: end,
        isAllDay: false,
        availability: EventAvailability.busy,
        status: EventStatus.none,
        isRecurring: false,
      );
    }

    test('create path with omitSourceTitle=true embeds SHA256, not plaintext title',
        () async {
      final srcEvent = makeEvent('src-priv-1', 'Doctor Appointment');

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => []);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-priv-1'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-priv-1'))
          .thenAnswer((_) async => false);
      when(() => calendarService.createEvent(
        targetCalId,
        syncName,
        start,
        end,
        description: '$expectedHash\n---\n$marker',
        isAllDay: false,
      )).thenAnswer((_) async => 'new-priv-1');
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-priv-1',
        targetCalendarId: targetCalId,
        targetEventId: 'new-priv-1',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-priv-1'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
        omitSourceTitle: true,
      );

      verify(() => calendarService.createEvent(
        targetCalId,
        syncName,
        start,
        end,
        description: '$expectedHash\n---\n$marker',
        isAllDay: false,
      )).called(1);
      expect(result.synced, ['src-priv-1']);
    });

    test('title change triggers update when omitSourceTitle=true', () async {
      final srcEvent = makeEvent('src-priv-2', 'Doctor Visit');

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => [
            {
              'id': 1,
              'profile_id': profileId,
              'source_calendar_id': sourceCalId,
              'source_event_id': 'src-priv-2',
              'target_calendar_id': targetCalId,
              'target_event_id': 'old-priv-2',
              'synced_at': '2027-01-01T00:00:00Z',
              'canonical_time': null,
            }
          ]);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-priv-2'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-priv-2'))
          .thenAnswer((_) async => true);
      // Old target description contains the SHA256 of the OLD title, not the new one
      final oldHash =
          'de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333';
      when(() => calendarService.getEvent('old-priv-2')).thenAnswer((_) async =>
          Event(
            eventId: 'old-priv-2',
            instanceId: 'old-priv-2',
            calendarId: targetCalId,
            title: syncName,
            description: '$oldHash\n---\n$marker',
            startDate: start,
            endDate: end,
            isAllDay: false,
            availability: EventAvailability.busy,
            status: EventStatus.none,
            isRecurring: false,
          ));
      // New title hash
      final newHash =
          sha256.convert('Doctor Visit'.codeUnits).toString();
      when(() => calendarService.createEvent(
        targetCalId,
        syncName,
        start,
        end,
        description: '$newHash\n---\n$marker',
        isAllDay: false,
      )).thenAnswer((_) async => 'new-priv-2');
      when(() => calendarService.deleteEvent('old-priv-2'))
          .thenAnswer((_) async => const CalendarDeleteResult(success: true));
      when(() => mappingDb.deleteCreatedEvent(targetCalId, 'old-priv-2'))
          .thenAnswer((_) async {});
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-priv-2',
        targetCalendarId: targetCalId,
        targetEventId: 'new-priv-2',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-priv-2'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
        omitSourceTitle: true,
      );

      verify(() => calendarService.createEvent(
        targetCalId,
        syncName,
        start,
        end,
        description: '$newHash\n---\n$marker',
        isAllDay: false,
      )).called(1);
      expect(result.updated, ['src-priv-2']);
    });

    test('toggling omitSourceTitle from false to true cleans up plaintext title',
        () async {
      final srcEvent = makeEvent('src-priv-3', 'Doctor Appointment');

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => [
            {
              'id': 2,
              'profile_id': profileId,
              'source_calendar_id': sourceCalId,
              'source_event_id': 'src-priv-3',
              'target_calendar_id': targetCalId,
              'target_event_id': 'old-priv-3',
              'synced_at': '2027-01-01T00:00:00Z',
              'canonical_time': null,
            }
          ]);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-priv-3'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-priv-3'))
          .thenAnswer((_) async => true);
      // Old target still has plaintext title (from omitSourceTitle=false era)
      when(() => calendarService.getEvent('old-priv-3')).thenAnswer((_) async =>
          Event(
            eventId: 'old-priv-3',
            instanceId: 'old-priv-3',
            calendarId: targetCalId,
            title: syncName,
            description: 'Doctor Appointment\n---\n$marker',
            startDate: start,
            endDate: end,
            isAllDay: false,
            availability: EventAvailability.busy,
            status: EventStatus.none,
            isRecurring: false,
          ));
      when(() => calendarService.createEvent(
        targetCalId,
        syncName,
        start,
        end,
        description: '$expectedHash\n---\n$marker',
        isAllDay: false,
      )).thenAnswer((_) async => 'new-priv-3');
      when(() => calendarService.deleteEvent('old-priv-3'))
          .thenAnswer((_) async => const CalendarDeleteResult(success: true));
      when(() => mappingDb.deleteCreatedEvent(targetCalId, 'old-priv-3'))
          .thenAnswer((_) async {});
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-priv-3',
        targetCalendarId: targetCalId,
        targetEventId: 'new-priv-3',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-priv-3'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
        omitSourceTitle: true,
      );

      verify(() => calendarService.createEvent(
        targetCalId,
        syncName,
        start,
        end,
        description: '$expectedHash\n---\n$marker',
        isAllDay: false,
      )).called(1);
      expect(result.updated, ['src-priv-3']);
    });

    test('toggling omitSourceTitle from true to false cleans up fingerprint',
        () async {
      final srcEvent = makeEvent('src-priv-4', 'Doctor Appointment');

      when(() => calendarService.listEvents(sourceCalId, end: any(named: 'end')))
          .thenAnswer((_) async => [srcEvent]);
      when(() => mappingDb.listMappingsForCalendar(profileId, sourceCalId))
          .thenAnswer((_) async => [
            {
              'id': 3,
              'profile_id': profileId,
              'source_calendar_id': sourceCalId,
              'source_event_id': 'src-priv-4',
              'target_calendar_id': targetCalId,
              'target_event_id': 'old-priv-4',
              'synced_at': '2027-01-01T00:00:00Z',
              'canonical_time': null,
            }
          ]);
      when(() => mappingDb.isEventCreatedBySync(sourceCalId, 'src-priv-4'))
          .thenAnswer((_) async => false);
      when(() => mappingDb.isEventSynced(profileId, sourceCalId, 'src-priv-4'))
          .thenAnswer((_) async => true);
      // Old target has the SHA256 (from omitSourceTitle=true era)
      when(() => calendarService.getEvent('old-priv-4')).thenAnswer((_) async =>
          Event(
            eventId: 'old-priv-4',
            instanceId: 'old-priv-4',
            calendarId: targetCalId,
            title: syncName,
            description: '$expectedHash\n---\n$marker',
            startDate: start,
            endDate: end,
            isAllDay: false,
            availability: EventAvailability.busy,
            status: EventStatus.none,
            isRecurring: false,
          ));
      when(() => calendarService.createEvent(
        targetCalId,
        syncName,
        start,
        end,
        description: 'Doctor Appointment\n---\n$marker',
        isAllDay: false,
      )).thenAnswer((_) async => 'new-priv-4');
      when(() => calendarService.deleteEvent('old-priv-4'))
          .thenAnswer((_) async => const CalendarDeleteResult(success: true));
      when(() => mappingDb.deleteCreatedEvent(targetCalId, 'old-priv-4'))
          .thenAnswer((_) async {});
      when(() => mappingDb.insertMapping(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        sourceEventId: 'src-priv-4',
        targetCalendarId: targetCalId,
        targetEventId: 'new-priv-4',
        syncedAt: any(named: 'syncedAt'),
      )).thenAnswer((_) async {});
      when(() => mappingDb.insertCreatedEvent(targetCalId, 'new-priv-4'))
          .thenAnswer((_) async {});

      final result = await engine.runSync(
        profileId: profileId,
        sourceCalendarId: sourceCalId,
        targetCalendarId: targetCalId,
        syncEventName: syncName,
        omitSourceTitle: false,
      );

      verify(() => calendarService.createEvent(
        targetCalId,
        syncName,
        start,
        end,
        description: 'Doctor Appointment\n---\n$marker',
        isAllDay: false,
      )).called(1);
      expect(result.updated, ['src-priv-4']);
    });
  });

  group('buildDescription', () {
    const marker = '🔃 Automatically created by CalSync';

    test('copyDescription=false returns standard format', () {
      final result = buildDescription('Doctor Appointment', 'Q3 notes', false);
      expect(result, 'Doctor Appointment\n---\n$marker');
    });

    test('copyDescription=true with non-empty description prepends it', () {
      final result = buildDescription('Doctor Appointment', 'Q3 notes', true);
      expect(result, 'Q3 notes\n\nDoctor Appointment\n---\n$marker');
    });

    test('copyDescription=true with null description returns standard format', () {
      final result = buildDescription('Doctor Appointment', null, true);
      expect(result, 'Doctor Appointment\n---\n$marker');
    });

    test('copyDescription=true with empty description returns standard format', () {
      final result = buildDescription('Doctor Appointment', '', true);
      expect(result, 'Doctor Appointment\n---\n$marker');
    });

    test('copyDescription=false with null description returns standard format', () {
      final result = buildDescription('Doctor Appointment', null, false);
      expect(result, 'Doctor Appointment\n---\n$marker');
    });

    test('omitSourceTitle=true replaces title with SHA256 fingerprint', () {
      final result = buildDescription(
        'Doctor Appointment',
        'Q3 notes',
        false,
        omitSourceTitle: true,
      );
      expect(
        result,
        'de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333\n---\n$marker',
      );
    });

    test('omitSourceTitle=true with copyDescription prepends source description', () {
      final result = buildDescription(
        'Doctor Appointment',
        'Q3 notes',
        true,
        omitSourceTitle: true,
      );
      expect(
        result,
        'Q3 notes\n\nde691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333\n---\n$marker',
      );
    });

    test('omitSourceTitle=true with copyDescription and null source description', () {
      final result = buildDescription(
        'Doctor Appointment',
        null,
        true,
        omitSourceTitle: true,
      );
      expect(
        result,
        'de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333\n---\n$marker',
      );
    });

    test('omitSourceTitle=true with copyDescription and empty source description', () {
      final result = buildDescription(
        'Doctor Appointment',
        '',
        true,
        omitSourceTitle: true,
      );
      expect(
        result,
        'de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333\n---\n$marker',
      );
    });

    test('omitSourceTitle=true with empty title uses well-known SHA256 of empty string', () {
      final result = buildDescription(
        '',
        null,
        false,
        omitSourceTitle: true,
      );
      expect(
        result,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\n---\n$marker',
      );
    });

    test('omitSourceTitle=true with known title matches hardcoded SHA256', () {
      // Locks the algorithm: any change to the hashing approach will fail this test.
      // SHA256 of "Doctor Appointment" computed via: echo -n "Doctor Appointment" | sha256sum
      final result = buildDescription(
        'Doctor Appointment',
        null,
        false,
        omitSourceTitle: true,
      );
      expect(
        result,
        'de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333\n---\n$marker',
      );
    });
  });
}
