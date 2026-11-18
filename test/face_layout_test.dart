import 'dart:ui';

import 'package:bigblackclock/clock/face_layout.dart';
import 'package:flutter_test/flutter_test.dart';

FaceLayout fit(
  Size area, {
  bool seconds = false,
  bool period = true,
  bool date = true,
  bool alarm = true,
  bool battery = false,
}) =>
    fitFace(area, seconds: seconds, period: period, date: date, alarm: alarm, battery: battery);

void main() {
  test('the face always fits inside the area, with the time on one line', () {
    for (final area in const [Size(800, 360), Size(360, 800), Size(2000, 200), Size(200, 2000), Size(500, 500)]) {
      for (final seconds in [false, true]) {
        for (final secondary in [false, true]) {
          final l = fit(area, seconds: seconds, date: secondary, alarm: secondary);
          expect(l.timeSize.height, l.digitHeight, reason: 'one line of digits');
          expect(l.timeSize.width, lessThanOrEqualTo(area.width + 1e-6), reason: '$area');
          expect(l.timeSize.height + l.secondaryHeight, lessThanOrEqualTo(area.height + 1e-6), reason: '$area');
        }
      }
    }
  });

  test('fills the binding dimension completely', () {
    // Portrait: width binds.
    expect(fit(const Size(360, 800)).timeSize.width, closeTo(360, 1e-6));
    // Very wide: height binds.
    final wide = fit(const Size(2000, 200));
    expect(wide.timeSize.height + wide.secondaryHeight, closeTo(200, 1e-6));
  });

  test('hiding the date and alarm line makes the digits bigger when height binds', () {
    expect(
      fit(const Size(800, 300), date: false, alarm: false).digitHeight,
      greaterThan(fit(const Size(800, 300)).digitHeight),
    );
  });

  test('12-hour digits are as big as 24-hour digits', () {
    for (final area in const [Size(800, 360), Size(360, 800), Size(2000, 200)]) {
      for (final seconds in [false, true]) {
        expect(
          fit(area, seconds: seconds, period: true).digitHeight,
          fit(area, seconds: seconds, period: false).digitHeight,
          reason: '$area, seconds: $seconds',
        );
      }
    }
    // "12:59 PM", centered on the 1's lit edge, is exactly as wide as "23:59".
    expect(Units.pairWidth - Units.oneBlank + Units.sideGap + Units.periodWidth, closeTo(Units.pairWidth, 1e-9));
  });

  test('the battery alone keeps the line under the time', () {
    expect(fit(const Size(800, 300), date: false, alarm: false, battery: true).hasSecondary, isTrue);
  });
}
