import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keySourceCalendarId = 'source_calendar_id';
  static const _keyTargetCalendarId = 'target_calendar_id';
  static const _keySyncEventName = 'sync_event_name';
  static const _keySyncIntervalMinutes = 'sync_interval_minutes';
  static const _keySyncEnabled = 'sync_enabled';

  Future<String?> get sourceCalendarId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySourceCalendarId);
  }

  Future<void> setSourceCalendarId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySourceCalendarId, value);
  }

  Future<void> clearSourceCalendarId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySourceCalendarId);
  }

  Future<String?> get targetCalendarId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTargetCalendarId);
  }

  Future<void> setTargetCalendarId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTargetCalendarId, value);
  }

  Future<void> clearTargetCalendarId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTargetCalendarId);
  }

  Future<String> get syncEventName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySyncEventName) ?? '';
  }

  Future<void> setSyncEventName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncEventName, value);
  }

  Future<void> clearSyncEventName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySyncEventName);
  }

  Future<int> get syncIntervalMinutes async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySyncIntervalMinutes) ?? 60;
  }

  Future<void> setSyncIntervalMinutes(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySyncIntervalMinutes, value);
  }

  Future<void> clearSyncIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySyncIntervalMinutes);
  }

  Future<bool> get syncEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySyncEnabled) ?? false;
  }

  Future<void> setSyncEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySyncEnabled, value);
  }
}
