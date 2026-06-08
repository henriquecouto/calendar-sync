import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calendar_sync/settings/settings_service.dart';

void main() {
  test('SettingsService round-trips values', () async {
    SharedPreferences.setMockInitialValues({});

    final service = SettingsService();

    await service.setSourceCalendarId('cal-1');
    await service.setTargetCalendarId('cal-2');
    await service.setSyncEventName('Busy');

    expect(await service.sourceCalendarId, 'cal-1');
    expect(await service.targetCalendarId, 'cal-2');
    expect(await service.syncEventName, 'Busy');

    await service.clearSourceCalendarId();
    expect(await service.sourceCalendarId, isNull);
    expect(await service.targetCalendarId, 'cal-2');
  });
}
