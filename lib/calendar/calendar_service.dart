import 'package:flutter/services.dart';
import 'package:device_calendar_plus/device_calendar_plus.dart';

class CalendarService {
  final DeviceCalendar _plugin = DeviceCalendar.instance;
  static const _channel = MethodChannel('calsync/calendar');

  Future<List<Calendar>> listCalendars() async {
    try {
      return await _plugin.listCalendars();
    } on DeviceCalendarException {
      return [];
    }
  }

  Future<List<Event>> listEvents(String calendarId, {DateTime? end}) async {
    final now = DateTime.now();
    final endDate = end ?? now.add(const Duration(days: 30));
    try {
      return await _plugin.listEvents(
        now,
        endDate,
        calendarIds: [calendarId],
      );
    } on DeviceCalendarException {
      return [];
    }
  }

  Future<String?> createEvent(
    String calendarId,
    String title,
    DateTime start,
    DateTime end, {
    String? description,
    bool? isAllDay,
    String? location,
  }) async {
    try {
      return await _plugin.createEvent(
        calendarId: calendarId,
        title: title,
        startDate: start,
        endDate: end,
        description: description,
        isAllDay: isAllDay ?? false,
        location: location,
      );
    } on DeviceCalendarException {
      return null;
    }
  }

  Future<Event?> getEvent(String eventId) async {
    try {
      return await _plugin.getEvent(eventId);
    } on DeviceCalendarException {
      return null;
    }
  }

  Future<CalendarDeleteResult> deleteEvent(String eventId) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'deleteEvent',
        {'eventId': eventId},
      );
      return CalendarDeleteResult(success: ok == true);
    } catch (_) {
      return const CalendarDeleteResult(success: false);
    }
  }
}

class CalendarDeleteResult {
  final bool success;

  const CalendarDeleteResult({
    required this.success,
  });
}
