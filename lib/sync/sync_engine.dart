import 'dart:collection';

import 'package:device_calendar_plus/device_calendar_plus.dart';
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
  final DateTime projectedStart;
  final DateTime projectedEnd;
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

  Future<void> _processOrphanMappings({
    required Set<String> sourceEventIds,
    required String sourceCalendarId,
    required String targetCalendarId,
    required List<Map<String, Object?>> mappings,
    required List<Event> sourceEvents,
    required List<Map<String, Object?>> toDelete,
    required List<String> errors,
  }) async {
    for (final mapping in mappings) {
      final sourceEventId = mapping['source_event_id'] as String;

      if (!sourceEventIds.contains(sourceEventId)) {
        final targetEventId = mapping['target_event_id'] as String;
        try {
          final targetEvent = await _calendarService.getEvent(
            targetEventId,
          );

          if (targetEvent == null) {
            final mappingId = mapping['id'] as int;
            await _mappingDb.deleteMapping(mappingId);
            continue;
          }

          final threshold = DateTime.now().subtract(const Duration(days: 7));
          if (targetEvent.endDate.isBefore(threshold)) {
            continue;
          }

          final sourceEvent = await _calendarService.getEvent(
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

    final sourceEventIds = sourceEvents.map((e) => e.eventId).toSet();

    final mappings = await _mappingDb.listMappingsForCalendar(
      sourceCalendarId,
    );

    await _processOrphanMappings(
      sourceEventIds: sourceEventIds,
      sourceCalendarId: sourceCalendarId,
      targetCalendarId: targetCalendarId,
      mappings: mappings,
      sourceEvents: sourceEvents,
      toDelete: toDelete,
      errors: errors,
    );

    for (final event in sourceEvents) {
      final eventId = event.eventId;

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
            targetEventId,
          );

          if (targetEvent == null) {
            toSkip.add(event);
            continue;
          }

          final timeChanged =
              event.startDate.millisecondsSinceEpoch !=
                      targetEvent.startDate.millisecondsSinceEpoch ||
                  event.endDate.millisecondsSinceEpoch !=
                      targetEvent.endDate.millisecondsSinceEpoch;
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

        toCreate.add(ToCreateEntry(
          sourceEvent: event,
          projectedTitle: syncEventName,
          projectedDescription: event.title,
          projectedStart: event.startDate,
          projectedEnd: event.endDate,
          projectedAllDay: event.isAllDay,
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

      try {
        await _calendarService.deleteEvent(targetEventId);
        await _mappingDb.deleteMapping(mappingId);
        deleted.add(sourceEventId);
      } catch (e) {
        errors.add('$sourceEventId: delete failed: $e');
      }
    }

    for (final entry in plan.toCreate) {
      final event = entry.sourceEvent;
      final eventId = event.eventId;

      try {
        final targetEventId = await _calendarService.createEvent(
          targetCalendarId,
          syncEventName,
          entry.projectedStart,
          entry.projectedEnd,
          description: event.title,
          isAllDay: entry.projectedAllDay,
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
          syncedAt: DateTime.now().toIso8601String(),
        );

        synced.add(eventId);
      } catch (e) {
        errors.add('$eventId: $e');
      }
    }

    for (final entry in plan.toUpdate) {
      final event = entry.sourceEvent;
      final eventId = event.eventId;
      final mapping = entry.mapping;
      final targetEventId = mapping['target_event_id'] as String;

      try {
        final newTargetEventId = await _calendarService.createEvent(
          targetCalendarId,
          syncEventName,
          event.startDate,
          event.endDate,
          description: event.title,
          isAllDay: event.isAllDay,
        );

        if (newTargetEventId == null) {
          errors.add('$eventId: failed to create replacement');
          continue;
        }

        await _calendarService.deleteEvent(targetEventId);

        await _mappingDb.insertMapping(
          sourceCalendarId: sourceCalendarId,
          sourceEventId: eventId,
          targetCalendarId: targetCalendarId,
          targetEventId: newTargetEventId,
          syncedAt: DateTime.now().toIso8601String(),
        );

        updated.add(eventId);
      } catch (e) {
        errors.add('$eventId: $e');
      }
    }

    for (final event in plan.toSkip) {
      skipped.add(event.eventId);
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
