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
    test('anchors apply in full at the ends', () {
      expect(autoLevel(0, dark: 0.1, bright: 0.9), 0.1);
      expect(autoLevel(1, dark: 0.1, bright: 0.9), 0.9);
    });

    test('an ordinary lit room already gets the bright-room level', () {
      // About 100 lux, normalized the way the Android side does it.
      final ambient = math.log(101) / math.log(10001);
      expect(autoLevel(ambient, dark: 0.1, bright: 0.9), closeTo(0.9, 0.01));
    });

    test('in between, the level moves steadily from one end to the other', () {
      var last = 0.0;
      for (var a = 0.0; a <= 1; a += 0.05) {
        final level = autoLevel(a, dark: 0.1, bright: 0.9);
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
