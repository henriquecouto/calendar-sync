import 'package:device_calendar/device_calendar.dart';

class CalendarService {
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  Future<List<Calendar>> listCalendars() async {
    final result = await _plugin.retrieveCalendars();
    if (result.isSuccess && result.data != null) {
      return result.data!.toList();
    }
    return [];
  }

  Future<List<Event>> listEvents(String calendarId) async {
    final now = TZDateTime.now(local);
    final params = RetrieveEventsParams(
      startDate: now,
      endDate: now.add(const Duration(days: 30)),
    );
    final result = await _plugin.retrieveEvents(calendarId, params);
    if (result.isSuccess && result.data != null) {
      return result.data!.toList();
    }
    return [];
  }

  Future<String?> createEvent(
    String calendarId,
    String title,
    TZDateTime start,
    TZDateTime end, {
    String? description,
    bool? allDay,
  }) async {
    final event = Event(
      calendarId,
      title: title,
      start: start,
      end: end,
      description: description,
      allDay: allDay,
    );
    final result = await _plugin.createOrUpdateEvent(event);
    if (result != null && result.isSuccess) {
      return result.data;
    }
    return null;
  }

  Future<Event?> getEvent(String calendarId, String eventId) async {
    final params = RetrieveEventsParams(eventIds: [eventId]);
    final result = await _plugin.retrieveEvents(calendarId, params);
    if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
      return result.data!.first;
    }
    return null;
  }

  Future<bool> deleteEvent(String calendarId, String eventId) async {
    final result = await _plugin.deleteEvent(calendarId, eventId);
    return result.isSuccess && (result.data ?? false);
  }
}
