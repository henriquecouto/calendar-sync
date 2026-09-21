import 'package:flutter_test/flutter_test.dart';

class TestCalendarItem {
  final String id;
  final String name;
  final String? accountName;
  final bool readOnly;

  const TestCalendarItem(
    this.id,
    this.name, {
    this.accountName,
    this.readOnly = false,
  });

  String get displayName =>
      accountName != null && accountName!.isNotEmpty && accountName != name
          ? '$name ($accountName)'
          : name;
}

void main() {
  group('Calendar Item Display Name and Attributes', () {
    test('displayName includes accountName when distinct', () {
      const item = TestCalendarItem(
        '1',
        'Phone-Synced',
        accountName: 'user@example.com',
      );
      expect(item.displayName, 'Phone-Synced (user@example.com)');
    });

    test('displayName omits accountName when equal to name', () {
      const item = TestCalendarItem(
        '2',
        'user@example.com',
        accountName: 'user@example.com',
      );
      expect(item.displayName, 'user@example.com');
    });

    test('displayName omits accountName when null or empty', () {
      const item1 = TestCalendarItem('3', 'Local', accountName: null);
      const item2 = TestCalendarItem('4', 'Local', accountName: '');
      expect(item1.displayName, 'Local');
      expect(item2.displayName, 'Local');
    });

    test('readOnly flag defaults to false and preserves true', () {
      const writable = TestCalendarItem('5', 'Work');
      const readOnly = TestCalendarItem('6', 'Holidays', readOnly: true);
      expect(writable.readOnly, isFalse);
      expect(readOnly.readOnly, isTrue);
    });
  });
}
