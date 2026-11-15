import 'dart:convert';

import 'package:flutter/painting.dart';

/// The eight settings, plus the manual level behind setting 3.
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
    this.showBattery = true,
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
  final bool showBattery;

  Settings copyWith({
    HSVColor? clockColor,
    HSVColor? backgroundColor,
    bool? autoBrightness,
    double? manualLevel,
    bool? use24h,
    bool? showSeconds,
    bool? showDate,
    bool? showAlarm,
    bool? showBattery,
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
        showBattery: showBattery ?? this.showBattery,
      );

  /// One JSON string, which the platform stores as it is.
  String encode() => jsonEncode({
        'clockColor': _encodeHsv(clockColor),
        'backgroundColor': _encodeHsv(backgroundColor),
        'autoBrightness': autoBrightness,
        'manualLevel': manualLevel,
        'use24h': use24h,
        'showSeconds': showSeconds,
        'showDate': showDate,
        'showAlarm': showAlarm,
        'showBattery': showBattery,
      });

  /// Reads what [encode] wrote. Anything missing or unreadable, including the
  /// whole string, falls back to its default.
  static Settings decode(String? encoded) {
    Object? json;
    try {
      json = encoded == null ? null : jsonDecode(encoded);
    } on FormatException {
      json = null;
    }
    final m = json is Map ? json : const {};
    T read<T>(String key, T fallback) => m[key] is T ? m[key] as T : fallback;
    const d = Settings();
    return Settings(
      clockColor: _decodeHsv(m['clockColor']) ?? d.clockColor,
      backgroundColor: _decodeHsv(m['backgroundColor']) ?? d.backgroundColor,
      autoBrightness: read('autoBrightness', d.autoBrightness),
      manualLevel: read<num>('manualLevel', d.manualLevel).toDouble().clamp(0, 1),
      use24h: read<bool?>('use24h', null),
      showSeconds: read('showSeconds', d.showSeconds),
      showDate: read('showDate', d.showDate),
      showAlarm: read('showAlarm', d.showAlarm),
      showBattery: read('showBattery', d.showBattery),
    );
  }
}

List<double> _encodeHsv(HSVColor c) => [c.hue, c.saturation, c.value];

HSVColor? _decodeHsv(Object? json) {
  if (json is! List || json.length != 3 || json.any((v) => v is! num)) return null;
  final [h, s, v] = [for (final n in json) (n as num).toDouble()];
  return HSVColor.fromAHSV(1, h.clamp(0, 360), s.clamp(0, 1), v.clamp(0, 1));
}
