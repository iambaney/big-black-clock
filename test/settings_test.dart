import 'package:bigblackclock/settings/controls.dart';
import 'package:bigblackclock/settings/settings.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test('defaults are red on black with auto brightness', () {
    const s = Settings();
    expect(s.clockColor.toColor(), const Color(0xFFFF0000));
    expect(s.backgroundColor.toColor(), const Color(0xFF000000));
    expect([s.autoBrightness, s.showSeconds, s.showDate, s.showAlarm, s.use24h], [true, false, true, true, null]);
  });

  test('HSV survives a round trip, including hue on black', () {
    const c = HSVColor.fromAHSV(1, 210, 0.5, 0);
    final back = decodeHsv(encodeHsv(c))!;
    expect([back.hue, back.saturation, back.value], [210, 0.5, 0]);
    expect(decodeHsv('nonsense'), isNull);
  });

  test('store round trip', () async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    final store = await SettingsStore.open();
    expect(store.load().use24h, isNull);
    await store.save(const Settings(showSeconds: true, use24h: true, manualLevel: 0.05));
    final again = (await SettingsStore.open()).load();
    expect([again.showSeconds, again.use24h, again.manualLevel], [true, true, 0.05]);
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
