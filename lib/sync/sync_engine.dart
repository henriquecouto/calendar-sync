import 'dart:collection';

import 'package:device_calendar_plus/device_calendar_plus.dart';
import '../calendar/calendar_service.dart';
import 'mapping_database.dart';

const _syncMarker = '\u{1F503} Automatically created by CalSync';

String buildDescription(
  String originalTitle,
  String? sourceDescription,
  bool copyDescription,
) {
  String description = '$originalTitle\n---\n$_syncMarker';
  if (copyDescription &&
      sourceDescription != null &&
      sourceDescription.isNotEmpty) {
    description = '$sourceDescription\n\n$description';
  }
  return description;
}

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
  final String projectedTitle;

  const ToUpdateEntry({
    required this.sourceEvent,
    required this.mapping,
    required this.projectedTitle,
  });
}

class SyncEngine {
  final CalendarService _calendarService;
  final MappingDatabase _mappingDb;

  SyncEngine(this._calendarService, this._mappingDb);

  Future<SyncResult> runSync({
    required String profileId,
    required String sourceCalendarId,
    required String targetCalendarId,
    required String syncEventName,
    bool copyDescription = false,
    bool copyLocation = false,
  }) async {
    final plan = await _classify(
      profileId: profileId,
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

    final result = await _execute(
      plan: plan,
      profileId: profileId,
      sourceCalendarId: sourceCalendarId,
      targetCalendarId: targetCalendarId,
      syncEventName: syncEventName,
      copyDescription: copyDescription,
      copyLocation: copyLocation,
    );

    return result;
  }

  Future<SyncPlan> runDryRun({
    required String profileId,
    required String sourceCalendarId,
    required String targetCalendarId,
    required String syncEventName,
  }) async {
    return _classify(
      profileId: profileId,
      sourceCalendarId: sourceCalendarId,
      targetCalendarId: targetCalendarId,
      syncEventName: syncEventName,
    );
  }

  Future<void> _processOrphanMappings({
    required String profileId,
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
            await _mappingDb.deleteCreatedEvent(
              mapping['target_calendar_id'] as String,
              targetEventId,
            );
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
    required String profileId,
    required String sourceCalendarId,
    required String targetCalendarId,
    required String syncEventName,
  }) async {
    final toCreate = <ToCreateEntry>[];
    final toUpdate = <ToUpdateEntry>[];
    final toSkip = <Event>[];
    final toDelete = <Map<String, Object?>>[];
    final errors = <String>[];
    final processedIds = <String>{};

    final sourceEvents = await _calendarService.listEvents(sourceCalendarId);

    final mappings = await _mappingDb.listMappingsForCalendar(
      profileId,
      sourceCalendarId,
    );

    final sourceEventIds = sourceEvents.map((e) => e.eventId).toSet();

    await _processOrphanMappings(
      profileId: profileId,
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
      final isInstance = eventId != event.instanceId;

      if (isInstance) {
        if (processedIds.contains(eventId)) {
          continue;
        }
        final baseEvent = await _calendarService.getEvent(eventId);
        if (baseEvent != null) {
          processedIds.add(eventId);
          final toUse = Event(
            eventId: eventId,
            instanceId: eventId,
            calendarId: sourceCalendarId,
            title: baseEvent.title,
            description: baseEvent.description,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            isRecurring: true,
            recurrenceRule: baseEvent.recurrenceRule,
            availability: EventAvailability.busy,
            status: EventStatus.none,
          );
          await _classifySingle(
            event: toUse,
            toCreate: toCreate,
            toUpdate: toUpdate,
            toSkip: toSkip,
            errors: errors,
            profileId: profileId,
            sourceCalendarId: sourceCalendarId,
            targetCalendarId: targetCalendarId,
            syncEventName: syncEventName,
            mappings: mappings,
          );
        }
        toSkip.add(event);
        continue;
      }

      if (processedIds.contains(eventId)) {
        continue;
      }
      processedIds.add(eventId);
      await _classifySingle(
        event: event,
        toCreate: toCreate,
        toUpdate: toUpdate,
        toSkip: toSkip,
        errors: errors,
        profileId: profileId,
        sourceCalendarId: sourceCalendarId,
        targetCalendarId: targetCalendarId,
        syncEventName: syncEventName,
        mappings: mappings,
      );

    }
    return SyncPlan(
      toCreate: toCreate,
      toUpdate: toUpdate,
      toSkip: toSkip,
      toDelete: toDelete,
      errors: errors,
    );
  }

  Future<void> _classifySingle({
    required Event event,
    required List<ToCreateEntry> toCreate,
    required List<ToUpdateEntry> toUpdate,
    required List<Event> toSkip,
    required List<String> errors,
    required String profileId,
    required String sourceCalendarId,
    required String targetCalendarId,
    required String syncEventName,
    required List<Map<String, Object?>> mappings,
  }) async {
    final eventId = event.eventId;

    try {
      final description = event.description;
      if (description != null && description.contains(_syncMarker)) {
        toSkip.add(event);
        return;
      }

      final createdBySync = await _mappingDb.isEventCreatedBySync(
        sourceCalendarId,
        eventId,
      );
      if (createdBySync) {
        toSkip.add(event);
        return;
      }

      final alreadySynced = await _mappingDb.isEventSynced(
        profileId,
        sourceCalendarId,
        eventId,
      );

      if (alreadySynced) {
        final mapping = mappings.cast<Map<String, Object?>>().firstWhere(
          (m) => m['source_event_id'] == eventId,
          orElse: () => <String, Object?>{},
        );
        if (mapping.isEmpty) {
          toSkip.add(event);
          return;
        }
        final targetEventId = mapping['target_event_id'] as String;

        final targetEvent = await _calendarService.getEvent(
          targetEventId,
        );

        if (targetEvent == null) {
          toSkip.add(event);
          return;
        }

        final isRecurring = event.isRecurring && event.recurrenceRule != null;
        final canonicalTime = mapping['canonical_time'] as String?;
        bool timeChanged;
        if (isRecurring && canonicalTime != null) {
          final currentTime =
              '${event.startDate.hour.toString().padLeft(2, '0')}:${event.startDate.minute.toString().padLeft(2, '0')}';
          timeChanged = currentTime != canonicalTime;
        } else {
          timeChanged =
              event.startDate.millisecondsSinceEpoch !=
                      targetEvent.startDate.millisecondsSinceEpoch ||
                  event.endDate.millisecondsSinceEpoch !=
                      targetEvent.endDate.millisecondsSinceEpoch;
        }
        final titleChanged =
            !(targetEvent.description?.contains(event.title) ?? false);

        if (!timeChanged && !titleChanged) {
          toSkip.add(event);
          return;
        }

        toUpdate.add(ToUpdateEntry(
          sourceEvent: event,
          mapping: Map<String, Object?>.from(mapping),
          projectedTitle: syncEventName.isEmpty ? event.title : syncEventName,
        ));
        return;
      }

      toCreate.add(ToCreateEntry(
        sourceEvent: event,
        projectedTitle: syncEventName.isEmpty ? event.title : syncEventName,
        projectedDescription: event.title,
        projectedStart: event.startDate,
        projectedEnd: event.endDate,
        projectedAllDay: event.isAllDay,
      ));
    } catch (e) {
      errors.add('$eventId: $e');
    }
  }

  Future<SyncResult> _execute({
    required SyncPlan plan,
    required String profileId,
    required String sourceCalendarId,
    required String targetCalendarId,
    required String syncEventName,
    required bool copyDescription,
    required bool copyLocation,
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
        final deleteResult = await _calendarService.deleteEvent(targetEventId);

        if (!deleteResult.success) {
          errors.add('$sourceEventId: deleteEvent failed');
          continue;
        }

        await _mappingDb.deleteMapping(mappingId);
        await _mappingDb.deleteCreatedEvent(targetCalId, targetEventId);
        deleted.add(sourceEventId);
      } catch (e) {
        errors.add('$sourceEventId: delete failed: $e');
      }
    }

    for (final entry in plan.toCreate) {
      final event = entry.sourceEvent;
      final eventId = event.eventId;

      try {
        final hasRecurrence = event.isRecurring && event.recurrenceRule != null;
        final targetEventId = await _calendarService.createEvent(
          targetCalendarId,
          entry.projectedTitle,
          entry.projectedStart,
          entry.projectedEnd,
          description: buildDescription(
            event.title,
            event.description,
            copyDescription,
          ),
          isAllDay: entry.projectedAllDay,
              recurrenceRule:
                  hasRecurrence ? event.recurrenceRule : null,
          location: copyLocation ? event.location : null,
        );

        if (targetEventId == null) {
          errors.add('$eventId: failed to create');
          continue;
        }

        final canonicalTime = hasRecurrence
            ? '${event.startDate.hour.toString().padLeft(2, '0')}:${event.startDate.minute.toString().padLeft(2, '0')}'
            : null;
        await _mappingDb.insertMapping(
          profileId: profileId,
          sourceCalendarId: sourceCalendarId,
          sourceEventId: eventId,
          targetCalendarId: targetCalendarId,
          targetEventId: targetEventId,
          syncedAt: DateTime.now().toIso8601String(),
          canonicalTime: canonicalTime,
        );

        await _mappingDb.insertCreatedEvent(
          targetCalendarId,
          targetEventId,
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
      final targetCalId = mapping['target_calendar_id'] as String;

      try {
        final hasRecurrence = event.isRecurring &&
            event.recurrenceRule != null;
        final newTargetEventId = await _calendarService.createEvent(
          targetCalId,
          entry.projectedTitle,
          event.startDate,
          event.endDate,
          description: buildDescription(
            event.title,
            event.description,
            copyDescription,
          ),
          isAllDay: event.isAllDay,
              recurrenceRule:
                  hasRecurrence ? event.recurrenceRule : null,
          location: copyLocation ? event.location : null,
        );

        if (newTargetEventId == null) {
          errors.add('$eventId: failed to create replacement');
          continue;
        }

        await _calendarService.deleteEvent(targetEventId).then((result) {
          if (!result.success) {
            errors.add('$eventId: failed to delete old target event');
          }
        });
        await _mappingDb.deleteCreatedEvent(targetCalId, targetEventId);

        final canonicalTime = hasRecurrence
            ? '${event.startDate.hour.toString().padLeft(2, '0')}:${event.startDate.minute.toString().padLeft(2, '0')}'
            : null;
        await _mappingDb.insertMapping(
          profileId: profileId,
          sourceCalendarId: sourceCalendarId,
          sourceEventId: eventId,
          targetCalendarId: targetCalId,
          targetEventId: newTargetEventId,
          syncedAt: DateTime.now().toIso8601String(),
          canonicalTime: canonicalTime,
        );

        await _mappingDb.insertCreatedEvent(
          targetCalId,
          newTargetEventId,
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
