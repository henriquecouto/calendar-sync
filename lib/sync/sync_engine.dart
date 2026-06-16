import 'dart:collection';

import 'package:device_calendar/device_calendar.dart';
import '../calendar/calendar_service.dart';
import 'mapping_database.dart';

class SyncPlan {
  final List<ToCreateEntry> toCreate;
  final List<ToUpdateEntry> toUpdate;
  final List<Event> toSkip;
  final List<Map<String, Object?>> toDelete;
  final List<String> errors;

  const SyncPlan({
    required this.toCreate,
    required this.toUpdate,
    required this.toSkip,
    required this.toDelete,
    required this.errors,
  });
}

class ToCreateEntry {
  final Event sourceEvent;
  final String projectedTitle;
  final String projectedDescription;
  final TZDateTime projectedStart;
  final TZDateTime projectedEnd;
  final bool projectedAllDay;

  const ToCreateEntry({
    required this.sourceEvent,
    required this.projectedTitle,
    required this.projectedDescription,
    required this.projectedStart,
    required this.projectedEnd,
    this.projectedAllDay = false,
  });
}

class ToUpdateEntry {
  final Event sourceEvent;
  final Map<String, Object?> mapping;

  const ToUpdateEntry({
    required this.sourceEvent,
    required this.mapping,
  });
}

class SyncEngine {
  final CalendarService _calendarService;
  final MappingDatabase _mappingDb;

  SyncEngine(this._calendarService, this._mappingDb);

  static TZDateTime _localMidnight(int year, int month, int day) {
    return TZDateTime.utc(year, month, day)
        .subtract(DateTime.now().timeZoneOffset);
  }

  Future<SyncResult> runSync({
    required String sourceCalendarId,
    required String targetCalendarId,
    required String syncEventName,
  }) async {
    final plan = await _classify(
      sourceCalendarId: sourceCalendarId,
      targetCalendarId: targetCalendarId,
      syncEventName: syncEventName,
    );

    if (plan.errors.isNotEmpty) {
      return SyncResult(
        synced: UnmodifiableListView([]),
        skipped: UnmodifiableListView([]),
        deleted: UnmodifiableListView([]),
        updated: UnmodifiableListView([]),
        errors: UnmodifiableListView(plan.errors),
      );
    }

    return _execute(
      plan: plan,
      sourceCalendarId: sourceCalendarId,
      targetCalendarId: targetCalendarId,
      syncEventName: syncEventName,
    );
  }

  Future<SyncPlan> runDryRun({
    required String sourceCalendarId,
    required String targetCalendarId,
    required String syncEventName,
  }) async {
    return _classify(
      sourceCalendarId: sourceCalendarId,
      targetCalendarId: targetCalendarId,
      syncEventName: syncEventName,
    );
  }

  Future<SyncPlan> _classify({
    required String sourceCalendarId,
    required String targetCalendarId,
    required String syncEventName,
  }) async {
    final toCreate = <ToCreateEntry>[];
    final toUpdate = <ToUpdateEntry>[];
    final toSkip = <Event>[];
    final toDelete = <Map<String, Object?>>[];
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
      final sourceEventId = mapping['source_event_id'] as String;

      if (!sourceEventIds.contains(sourceEventId)) {
        final targetEventId = mapping['target_event_id'] as String;
        try {
          final targetEvent = await _calendarService.getEvent(
            targetCalendarId,
            targetEventId,
          );

          if (targetEvent == null) {
            final mappingId = mapping['id'] as int;
            await _mappingDb.deleteMapping(mappingId);
            continue;
          }

          if (targetEvent.end == null) {
            if (targetEvent.allDay != true) {
              final mappingId = mapping['id'] as int;
              await _mappingDb.deleteMapping(mappingId);
            }
            continue;
          }

          final threshold = TZDateTime.now(local).subtract(const Duration(days: 7));
          if (targetEvent.end!.isBefore(threshold)) {
            continue;
          }

          final sourceEvent = await _calendarService.getEvent(
            sourceCalendarId,
            sourceEventId,
          );

          if (sourceEvent != null) {
            sourceEvents.add(sourceEvent);
          } else {
            toDelete.add(mapping);
          }
        } catch (e) {
          errors.add('$sourceEventId: $e');
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
            toSkip.add(event);
            continue;
          }

          if (targetEvent.allDay != true &&
              (targetEvent.start == null || targetEvent.end == null)) {
            toSkip.add(event);
            continue;
          }

          final bool timeChanged;
          if (event.allDay == true) {
            if (targetEvent.start == null || targetEvent.end == null) {
              timeChanged = true;
            } else {
              final srcDays =
                  event.end!.difference(event.start!).inDays;
              final tgtDays =
                  targetEvent.end!.difference(targetEvent.start!).inDays;
              timeChanged = event.start!.year != targetEvent.start!.year ||
                  event.start!.month != targetEvent.start!.month ||
                  event.start!.day != targetEvent.start!.day ||
                  srcDays + 1 != tgtDays;
            }
          } else {
            timeChanged = targetEvent.start == null ||
                targetEvent.end == null ||
                event.start!.millisecondsSinceEpoch !=
                    targetEvent.start!.millisecondsSinceEpoch ||
                event.end!.millisecondsSinceEpoch !=
                    targetEvent.end!.millisecondsSinceEpoch;
          }
          final titleChanged = event.title != targetEvent.description;

          if (!timeChanged && !titleChanged) {
            toSkip.add(event);
            continue;
          }

          toUpdate.add(ToUpdateEntry(
            sourceEvent: event,
            mapping: Map<String, Object?>.from(mapping),
          ));
          continue;
        }

        if (event.start == null || event.end == null) {
          errors.add('$eventId: missing start or end');
          continue;
        }

        final projectedStart = event.allDay == true
            ? _localMidnight(
                event.start!.year, event.start!.month, event.start!.day)
            : event.start!;
        final projectedEnd = event.allDay == true
            ? _localMidnight(
                event.end!.year, event.end!.month, event.end!.day)
                .add(const Duration(days: 1))
            : event.end!;

        toCreate.add(ToCreateEntry(
          sourceEvent: event,
          projectedTitle: syncEventName,
          projectedDescription: event.title ?? '',
          projectedStart: projectedStart,
          projectedEnd: projectedEnd,
        ));
      } catch (e) {
        errors.add('$eventId: $e');
      }
    }

    return SyncPlan(
      toCreate: toCreate,
      toUpdate: toUpdate,
      toSkip: toSkip,
      toDelete: toDelete,
      errors: errors,
    );
  }

  Future<SyncResult> _execute({
    required SyncPlan plan,
    required String sourceCalendarId,
    required String targetCalendarId,
    required String syncEventName,
  }) async {
    final synced = <String>[];
    final skipped = <String>[];
    final deleted = <String>[];
    final updated = <String>[];
    final errors = <String>[];

    for (final entry in plan.toDelete) {
      final mappingId = entry['id'] as int;
      final sourceEventId = entry['source_event_id'] as String;
      final targetEventId = entry['target_event_id'] as String;
      final targetCalId = entry['target_calendar_id'] as String;

      try {
        await _calendarService.deleteEvent(targetCalId, targetEventId);
        await _mappingDb.deleteMapping(mappingId);
        deleted.add(sourceEventId);
      } catch (e) {
        errors.add('$sourceEventId: delete failed: $e');
      }
    }

    for (final entry in plan.toCreate) {
      final event = entry.sourceEvent;
      final eventId = event.eventId!;

      try {
        final targetEventId = await _calendarService.createEvent(
          targetCalendarId,
          syncEventName,
          entry.projectedStart,
          entry.projectedEnd,
          description: event.title,
          allDay: entry.projectedAllDay,
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

    for (final entry in plan.toUpdate) {
      final event = entry.sourceEvent;
      final eventId = event.eventId!;
      final mapping = entry.mapping;
      final targetEventId = mapping['target_event_id'] as String;

      try {
        final updateStart = event.allDay == true
            ? _localMidnight(
                event.start!.year, event.start!.month, event.start!.day)
            : event.start!;
        final updateEnd = event.allDay == true
            ? _localMidnight(
                event.end!.year, event.end!.month, event.end!.day)
                .add(const Duration(days: 1))
            : event.end!;

        final newTargetEventId = await _calendarService.createEvent(
          targetCalendarId,
          syncEventName,
          updateStart,
          updateEnd,
          description: event.title,
          allDay: false,
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
      } catch (e) {
        errors.add('$eventId: $e');
      }
    }

    for (final event in plan.toSkip) {
      final eventId = event.eventId;
      if (eventId != null) {
        skipped.add(eventId);
      }
    }

    errors.addAll(plan.errors);

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
