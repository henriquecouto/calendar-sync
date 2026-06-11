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

  const ToCreateEntry({
    required this.sourceEvent,
    required this.projectedTitle,
    required this.projectedDescription,
    required this.projectedStart,
    required this.projectedEnd,
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
        toDelete.add(mapping);
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

          final timeChanged = event.start!.millisecondsSinceEpoch !=
                  targetEvent.start!.millisecondsSinceEpoch ||
              event.end!.millisecondsSinceEpoch !=
                  targetEvent.end!.millisecondsSinceEpoch;
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

        toCreate.add(ToCreateEntry(
          sourceEvent: event,
          projectedTitle: syncEventName,
          projectedDescription: event.title ?? '',
          projectedStart: event.start!,
          projectedEnd: event.end!,
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

    for (final entry in plan.toUpdate) {
      final event = entry.sourceEvent;
      final eventId = event.eventId!;
      final mapping = entry.mapping;
      final targetEventId = mapping['target_event_id'] as String;

      try {
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
