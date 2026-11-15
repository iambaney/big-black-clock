import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The seven settings, plus the manual level behind setting 3.
class Settings {
  const Settings({
    this.clockColor = const HSVColor.fromAHSV(1, 0, 1, 1),
    this.backgroundColor = const HSVColor.fromAHSV(1, 0, 0, 0),
    this.autoBrightness = true,
    this.manualLevel = 0.5,
    this.use24h,
    this.showSeconds = false,
    this.showDate = true,
    this.showAlarm = true,
  });

  /// Kept as HSV so hue and saturation survive a color turned all the way to
  /// black.
  final HSVColor clockColor;
  final HSVColor backgroundColor;

  final bool autoBrightness;

  /// Brightness level when auto brightness is off.
  final double manualLevel;

  /// Null until the user picks; until then the system's 24-hour setting applies.
  final bool? use24h;
  final bool showSeconds;
  final bool showDate;
  final bool showAlarm;

  Settings copyWith({
    HSVColor? clockColor,
    HSVColor? backgroundColor,
    bool? autoBrightness,
    double? manualLevel,
    bool? use24h,
    bool? showSeconds,
    bool? showDate,
    bool? showAlarm,
  }) =>
      Settings(
        clockColor: clockColor ?? this.clockColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        autoBrightness: autoBrightness ?? this.autoBrightness,
        manualLevel: manualLevel ?? this.manualLevel,
        use24h: use24h ?? this.use24h,
        showSeconds: showSeconds ?? this.showSeconds,
        showDate: showDate ?? this.showDate,
        showAlarm: showAlarm ?? this.showAlarm,
      );
}

/// Persists [Settings] as individual preference keys.
class SettingsStore {
  SettingsStore._(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<SettingsStore> open() async => SettingsStore._(
        await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions()),
      );

  Settings load() {
    const d = Settings();
    return Settings(
      clockColor: _color('clockColor') ?? d.clockColor,
      backgroundColor: _color('backgroundColor') ?? d.backgroundColor,
      autoBrightness: _prefs.getBool('autoBrightness') ?? d.autoBrightness,
      manualLevel: _prefs.getDouble('manualLevel') ?? d.manualLevel,
      use24h: _prefs.getBool('use24h'),
      showSeconds: _prefs.getBool('showSeconds') ?? d.showSeconds,
      showDate: _prefs.getBool('showDate') ?? d.showDate,
      showAlarm: _prefs.getBool('showAlarm') ?? d.showAlarm,
    );
  }

  Future<void> save(Settings s) => Future.wait([
        _prefs.setString('clockColor', encodeHsv(s.clockColor)),
        _prefs.setString('backgroundColor', encodeHsv(s.backgroundColor)),
        _prefs.setBool('autoBrightness', s.autoBrightness),
        _prefs.setDouble('manualLevel', s.manualLevel),
        if (s.use24h != null) _prefs.setBool('use24h', s.use24h!),
        _prefs.setBool('showSeconds', s.showSeconds),
        _prefs.setBool('showDate', s.showDate),
        _prefs.setBool('showAlarm', s.showAlarm),
      ]);

  HSVColor? _color(String key) {
    final value = _prefs.getString(key);
    return value == null ? null : decodeHsv(value);
  }
}

String encodeHsv(HSVColor c) => '${c.hue},${c.saturation},${c.value}';

HSVColor? decodeHsv(String s) {
  final parts = s.split(',').map(double.tryParse).toList();
  if (parts.length != 3 || parts.contains(null)) return null;
  return HSVColor.fromAHSV(1, parts[0]!.clamp(0, 360), parts[1]!.clamp(0, 1), parts[2]!.clamp(0, 1));
}
