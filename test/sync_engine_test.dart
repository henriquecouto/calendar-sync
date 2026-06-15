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
}
