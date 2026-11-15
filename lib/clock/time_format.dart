/// The pieces of the time as the face draws them.
class ClockTime {
  const ClockTime({
    required this.hours,
    required this.minutes,
    required this.seconds,
    this.period,
  });

  /// "9" or "12" in 12-hour mode, always two digits in 24-hour mode.
  final String hours;
  final String minutes;
  final String seconds;

  /// "AM" or "PM" in 12-hour mode, null in 24-hour mode.
  final String? period;

  @override
  bool operator ==(Object other) =>
      other is ClockTime &&
      other.hours == hours &&
      other.minutes == minutes &&
      other.seconds == seconds &&
      other.period == period;

  @override
  int get hashCode => Object.hash(hours, minutes, seconds, period);
}

String _two(int n) => n.toString().padLeft(2, '0');

ClockTime clockTime(DateTime t, {required bool use24h}) {
  if (use24h) {
    return ClockTime(hours: _two(t.hour), minutes: _two(t.minute), seconds: _two(t.second));
  }
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return ClockTime(
    hours: '$h',
    minutes: _two(t.minute),
    seconds: _two(t.second),
    period: t.hour < 12 ? 'AM' : 'PM',
  );
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Sat, Nov 14".
String dateLabel(DateTime t) => '${_weekdays[t.weekday - 1]}, ${_months[t.month - 1]} ${t.day}';

/// "6:30 AM" or "06:30".
String timeLabel(DateTime t, {required bool use24h}) {
  final c = clockTime(t, use24h: use24h);
  return c.period == null ? '${c.hours}:${c.minutes}' : '${c.hours}:${c.minutes} ${c.period}';
}

/// The next alarm: just the time when it is less than a day away, otherwise
/// prefixed with the weekday ("Tue 6:30 AM").
String alarmLabel(DateTime alarm, DateTime now, {required bool use24h}) {
  final time = timeLabel(alarm, use24h: use24h);
  if (alarm.difference(now) < const Duration(hours: 24)) return time;
  return '${_weekdays[alarm.weekday - 1]} $time';
}
