import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keySourceCalendarId = 'source_calendar_id';
  static const _keyTargetCalendarId = 'target_calendar_id';
  static const _keySyncEventName = 'sync_event_name';

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
}
