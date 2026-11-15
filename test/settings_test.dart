import 'package:bigblackclock/settings/controls.dart';
import 'package:bigblackclock/settings/settings.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are red on black with auto brightness', () {
    const s = Settings();
    expect(s.clockColor.toColor(), const Color(0xFFFF0000));
    expect(s.backgroundColor.toColor(), const Color(0xFF000000));
    expect(
      [s.autoBrightness, s.showSeconds, s.showDate, s.showAlarm, s.showBattery, s.use24h],
      [true, false, true, true, true, null],
    );
  });

  test('settings survive encoding, including hue on a color turned to black', () {
    final s = Settings.decode(const Settings(
      backgroundColor: HSVColor.fromAHSV(1, 210, 0.5, 0),
      showSeconds: true,
      use24h: true,
      manualLevel: 0.05,
      showBattery: false,
    ).encode());
    expect([s.backgroundColor.hue, s.backgroundColor.saturation, s.backgroundColor.value], [210, 0.5, 0]);
    expect([s.showSeconds, s.use24h, s.manualLevel, s.showBattery], [true, true, 0.05, false]);
  });

  test('missing or unreadable settings fall back to the defaults', () {
    for (final encoded in [null, '', 'nonsense', '[1, 2]', '{"clockColor": "red", "showDate": 3, "manualLevel": "x"}']) {
      final s = Settings.decode(encoded);
      expect([s.clockColor, s.showDate, s.manualLevel, s.use24h], [const Settings().clockColor, true, 0.5, null],
          reason: '$encoded');
    }
  });

  group('panel colors', () {
    const red = HSVColor.fromAHSV(1, 0, 1, 1);
    const black = HSVColor.fromAHSV(1, 0, 0, 0);

    const white = HSVColor.fromAHSV(1, 0, 0, 1);

    test('dim white text on a dark background', () {
      expect(panelColors(red, black).fg, const Color(0xFFC0C0C0));
    });

    test('dark text on a light background', () {
      expect(panelColors(red, white).fg, const Color(0xFF303030));
    });

    test('text stays readable whatever the colors', () {
      for (final clock in [red, black, white, red.withValue(0.3)]) {
        for (final background in [red, black, white, red.withValue(0.3)]) {
          final p = panelColors(clock, background);
          expect(contrastRatio(p.fg, p.bg), greaterThanOrEqualTo(3), reason: '$clock on $background');
        }
      }
    });
  });
}
