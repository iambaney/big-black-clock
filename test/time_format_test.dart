import 'package:bigblackclock/clock/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clockTime', () {
    test('12-hour mode has no leading zero and a period', () {
      final t = clockTime(DateTime(2026, 11, 14, 9, 5, 7), use24h: false);
      expect([t.hours, t.minutes, t.seconds, t.period], ['9', '05', '07', 'AM']);
    });

    test('midnight and noon read 12 in 12-hour mode', () {
      expect(clockTime(DateTime(2026, 1, 1, 0, 0), use24h: false).hours, '12');
      expect(clockTime(DateTime(2026, 1, 1, 0, 0), use24h: false).period, 'AM');
      expect(clockTime(DateTime(2026, 1, 1, 12, 0), use24h: false).hours, '12');
      expect(clockTime(DateTime(2026, 1, 1, 12, 0), use24h: false).period, 'PM');
    });

    test('24-hour mode pads hours and has no period', () {
      final t = clockTime(DateTime(2026, 1, 1, 0, 3), use24h: true);
      expect([t.hours, t.minutes, t.period], ['00', '03', null]);
      expect(clockTime(DateTime(2026, 1, 1, 23, 59), use24h: true).hours, '23');
    });
  });

  test('dateLabel', () {
    expect(dateLabel(DateTime(2026, 11, 14)), 'Sat, Nov 14');
  });

  group('alarmLabel', () {
    // Saturday evening.
    final now = DateTime(2026, 11, 14, 22, 0);

    test('just the time when it is the next occurrence of that time', () {
      expect(alarmLabel(DateTime(2026, 11, 15, 6, 30), now, use24h: false), '6:30 AM');
      expect(alarmLabel(DateTime(2026, 11, 15, 6, 30), now, use24h: true), '06:30');
      expect(alarmLabel(DateTime(2026, 11, 14, 23, 0), now, use24h: true), '23:00');
    });

    test('+N counts the occurrences of that time it skips', () {
      // Monday 8:00 from Saturday night: Sunday 8:00 comes first.
      expect(alarmLabel(DateTime(2026, 11, 16, 8, 0), now, use24h: false), '8:00 AM +1');
      // Sunday 22:00 from Saturday 22:00: tonight's 22:00 has passed, so it is next.
      expect(alarmLabel(DateTime(2026, 11, 15, 22, 0), now, use24h: true), '22:00');
      expect(alarmLabel(DateTime(2026, 11, 21, 22, 30), now, use24h: true), '22:30 +7');
    });

    test('across a month boundary', () {
      expect(alarmExtraDays(DateTime(2026, 12, 2, 7, 0), DateTime(2026, 11, 30, 9, 0)), 1);
    });
  });
}
