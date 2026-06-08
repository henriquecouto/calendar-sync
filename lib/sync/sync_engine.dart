import 'dart:collection';

import 'package:device_calendar/device_calendar.dart';
import '../calendar/calendar_service.dart';
import 'mapping_database.dart';

class SyncEngine {
  final CalendarService _calendarService;
  final MappingDatabase _mappingDb;

  SyncEngine(this._calendarService, this._mappingDb);

  Future<SyncResult> runSync({
    required String sourceCalendarId,
    required String targetCalendarId,
    required String syncEventName,
  }) async {
    final synced = <String>[];
    final skipped = <String>[];
    final errors = <String>[];

    final sourceEvents = await _calendarService.listEvents(sourceCalendarId);

    for (final event in sourceEvents) {
      final eventId = event.eventId;
      if (eventId == null || event.eventId == null) continue;

      try {
        final alreadySynced = await _mappingDb.isEventSynced(
          sourceCalendarId,
          eventId,
        );

        if (alreadySynced) {
          skipped.add(eventId);
          continue;
        }

        if (event.start == null || event.end == null) {
          errors.add('$eventId: missing start or end');
          continue;
        }

        final targetEventId = await _calendarService.createEvent(
          targetCalendarId,
          syncEventName,
          event.start!,
          event.end!,
        );

        if (targetEventId == null) {
          errors.add('$eventId: failed to create');
          continue;
        }

        await _mappingDb.insertMapping(
          sourceCalendarId: sourceCalendarId,
          sourceEventId: eventId,
          targetCalendarId: targetCalendarId,
          targetEventId: targetEventId,
          syncedAt: TZDateTime.now(local).toString(),
        );

        synced.add(eventId);
      } catch (e) {
        errors.add('$eventId: $e');
      }
    }

    return SyncResult(
      synced: UnmodifiableListView(synced),
      skipped: UnmodifiableListView(skipped),
      errors: UnmodifiableListView(errors),
    );
  }
}

class SyncResult {
  final UnmodifiableListView<String> synced;
  final UnmodifiableListView<String> skipped;
  final UnmodifiableListView<String> errors;

  const SyncResult({
    required this.synced,
    required this.skipped,
    required this.errors,
  });
}
