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
    await store.save(const Settings(showSeconds: true, use24h: true, darkLevel: 0.05));
    final again = (await SettingsStore.open()).load();
    expect([again.showSeconds, again.use24h, again.darkLevel], [true, true, 0.05]);
  });

  group('panel colors', () {
    const red = HSVColor.fromAHSV(1, 0, 1, 1);
    const black = HSVColor.fromAHSV(1, 0, 0, 0);

    test('use the clock color when it reads against the background', () {
      expect(panelColors(red, black).fg, red.toColor());
    });

    test('a very dark clock color falls back to its full-brightness hue, not white', () {
      final dimRed = red.withValue(0.15);
      expect(panelColors(dimRed, black).fg, red.toColor());
    });

    test('identical colors still give readable controls', () {
      final p = panelColors(red, red);
      expect(contrastRatio(p.fg, p.bg), greaterThanOrEqualTo(1.8));
    });
  });
}
