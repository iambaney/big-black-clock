import 'dart:math' as math;

import 'package:bigblackclock/brightness/brightness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitLevel', () {
    test('full level is full backlight and no scrim', () {
      expect(splitLevel(1), (backlight: 1.0, scrim: 0.0));
    });

    test('below the knee the backlight holds at its floor and the scrim takes over', () {
      final s = splitLevel(knee / 2);
      expect(s.backlight, backlightFloor);
      expect(s.scrim, closeTo(maxScrim / 2, 1e-9));
      expect(splitLevel(0).scrim, maxScrim);
    });

    test('continuous at the knee', () {
      expect(splitLevel(knee).backlight, closeTo(backlightFloor, 1e-9));
      expect(splitLevel(knee - 1e-9).scrim, closeTo(0, 1e-6));
    });

    test('darker level never means more light', () {
      double light(double level) {
        final s = splitLevel(level);
        return s.backlight * (1 - s.scrim);
      }

      for (var i = 0; i < 100; i++) {
        expect(light(i / 100), lessThanOrEqualTo(light((i + 1) / 100)));
      }
    });
  });

  group('auto curve', () {
    // Normalized the way the Android side does it.
    double lux(double l) => math.log(l + 1) / math.log(10001);

    test('a dark room gets the calibrated dark-room level', () {
      expect(autoLevel(lux(0)), darkRoomLevel);
      expect(autoLevel(lux(0.5)), darkRoomLevel);
    });

    test('an ordinary lit room gets full brightness', () {
      expect(autoLevel(lux(100)), closeTo(1, 0.01));
      expect(autoLevel(lux(5000)), 1);
    });

    test('in between, the level rises steadily with the light', () {
      var last = 0.0;
      for (var a = 0.0; a <= 1; a += 0.05) {
        final level = autoLevel(a);
        expect(level, greaterThanOrEqualTo(last));
        last = level;
      }
    });
  });

  group('AmbientFilter', () {
    test('first reading passes straight through', () {
      expect(AmbientFilter().add(0.5), 0.5);
    });

    test('small wobbles are ignored', () {
      final f = AmbientFilter()..add(0.5);
      for (final r in [0.52, 0.48, 0.51, 0.49]) {
        expect(f.add(r), 0.5);
      }
    });

    test('a real change gets through after smoothing', () {
      final f = AmbientFilter()..add(0.1);
      double last = 0.1;
      for (var i = 0; i < 20; i++) {
        last = f.add(0.8);
      }
      expect(last, closeTo(0.8, 0.05));
    });
  });
}
