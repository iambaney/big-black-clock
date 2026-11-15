import 'dart:ui';

import 'package:bigblackclock/clock/face_layout.dart';
import 'package:flutter_test/flutter_test.dart';

FaceLayout fit(Size area, {bool seconds = false, bool period = true, bool date = true, bool alarm = true}) =>
    fitFace(area, seconds: seconds, period: period, date: date, alarm: alarm);

void main() {
  test('landscape phone uses one row', () {
    expect(fit(const Size(800, 360)).arrangement, Arrangement.row);
  });

  test('portrait phone stacks hours over minutes for bigger digits', () {
    final layout = fit(const Size(360, 800));
    expect(layout.arrangement, Arrangement.stacked);
    expect(layout.secondaryLines, 2);
  });

  test('the face always fits inside the area', () {
    for (final area in const [Size(800, 360), Size(360, 800), Size(2000, 200), Size(200, 2000), Size(500, 500)]) {
      for (final seconds in [false, true]) {
        for (final secondary in [false, true]) {
          final l = fit(area, seconds: seconds, date: secondary, alarm: secondary);
          final height = l.timeSize.height +
              (l.secondaryLines == 0 ? 0 : l.secondaryGap + l.secondaryLines * l.digitHeight * Units.secondaryLine);
          expect(l.timeSize.width, lessThanOrEqualTo(area.width * fillFraction + 1e-6), reason: '$area');
          expect(height, lessThanOrEqualTo(area.height * fillFraction + 1e-6), reason: '$area');
        }
      }
    }
  });

  test('hiding the secondary line makes the digits bigger when height binds', () {
    expect(
      fit(const Size(800, 300), date: false, alarm: false).digitHeight,
      greaterThan(fit(const Size(800, 300)).digitHeight),
    );
  });
}
