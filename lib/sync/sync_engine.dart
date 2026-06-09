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
    final deleted = <String>[];
    final updated = <String>[];
    final errors = <String>[];

    final sourceEvents = await _calendarService.listEvents(sourceCalendarId);

    final sourceEventIds = sourceEvents
        .map((e) => e.eventId)
        .where((id) => id != null)
        .toSet();

    final mappings = await _mappingDb.listMappingsForCalendar(
      sourceCalendarId,
    );

    for (final mapping in mappings) {
      final mappingId = mapping['id'] as int;
      final sourceEventId = mapping['source_event_id'] as String;
      final targetEventId = mapping['target_event_id'] as String;
      final targetCalId = mapping['target_calendar_id'] as String;

      if (!sourceEventIds.contains(sourceEventId)) {
        try {
          await _calendarService.deleteEvent(targetCalId, targetEventId);
          await _mappingDb.deleteMapping(mappingId);
          deleted.add(sourceEventId);
        } catch (e) {
          errors.add('$sourceEventId: delete failed: $e');
        }
      }
    }

    for (final event in sourceEvents) {
      final eventId = event.eventId;
      if (eventId == null) continue;

      try {
        final alreadySynced = await _mappingDb.isEventSynced(
          sourceCalendarId,
          eventId,
        );

        if (alreadySynced) {
          final mapping = mappings.cast<Map<String, Object?>>().firstWhere(
            (m) => m['source_event_id'] == eventId,
          );
          final targetEventId = mapping['target_event_id'] as String;

          final targetEvent = await _calendarService.getEvent(
            targetCalendarId,
            targetEventId,
          );

          if (targetEvent == null || event.start == null || event.end == null) {
            skipped.add(eventId);
            continue;
          }

          final timeChanged = event.start!.millisecondsSinceEpoch !=
                  targetEvent.start!.millisecondsSinceEpoch ||
              event.end!.millisecondsSinceEpoch !=
                  targetEvent.end!.millisecondsSinceEpoch;
          final titleChanged = event.title != targetEvent.description;

          if (!timeChanged && !titleChanged) {
            skipped.add(eventId);
            continue;
          }

          final newTargetEventId = await _calendarService.createEvent(
            targetCalendarId,
            syncEventName,
            event.start!,
            event.end!,
            description: event.title,
          );

          if (newTargetEventId == null) {
            errors.add('$eventId: failed to create replacement');
            continue;
          }

          await _calendarService.deleteEvent(targetCalendarId, targetEventId);

          await _mappingDb.insertMapping(
            sourceCalendarId: sourceCalendarId,
            sourceEventId: eventId,
            targetCalendarId: targetCalendarId,
            targetEventId: newTargetEventId,
            syncedAt: TZDateTime.now(local).toString(),
          );

          updated.add(eventId);
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
          description: event.title,
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
      deleted: UnmodifiableListView(deleted),
      updated: UnmodifiableListView(updated),
      errors: UnmodifiableListView(errors),
    );
  }
}

class SyncResult {
  final UnmodifiableListView<String> synced;
  final UnmodifiableListView<String> skipped;
  final UnmodifiableListView<String> deleted;
  final UnmodifiableListView<String> updated;
  final UnmodifiableListView<String> errors;

  const SyncResult({
    required this.synced,
    required this.skipped,
    required this.deleted,
    required this.updated,
    required this.errors,
  });
}
