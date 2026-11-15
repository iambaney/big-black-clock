import 'package:flutter/services.dart';

/// What the current platform can do. iOS (no native side written yet)
/// reports nothing available, and the app treats that as an ordinary state.
class Capabilities {
  const Capabilities({this.ambientLight = false, this.nextAlarm = false, this.battery = false});

  final bool ambientLight;
  final bool nextAlarm;
  final bool battery;
}

/// Battery charge in percent, and whether a charger is connected.
typedef Battery = ({int percent, bool charging});

/// Everything the clock needs from the operating system.
abstract interface class ClockPlatform {
  Future<Capabilities> capabilities();

  /// Ambient light normalized to 0..1 on a log scale (0 is darkness, 1 is
  /// daylight). The platform does the normalizing, because iOS would derive
  /// it from something other than lux.
  Stream<double> ambient();

  /// The next alarm clock set on the device, re-sent whenever it changes;
  /// null when there is none.
  Stream<DateTime?> nextAlarm();

  /// The battery, sent at once and again whenever the percentage or the
  /// charger changes.
  Stream<Battery> battery();

  /// Sets this app's window brightness, 0..1; null hands control back to the
  /// system.
  Future<void> setBrightness(double? level);

  /// This build's version name, such as "1.0.0"; null if unknown.
  Future<String?> appVersion();

  /// Opens [url] in the browser; false if nothing could open it.
  Future<bool> openUrl(String url);

  /// The settings as [saveSettings] last stored them; null if never saved.
  Future<String?> loadSettings();

  /// Stores the encoded settings in this app's private storage.
  Future<void> saveSettings(String encoded);
}

/// [ClockPlatform] over the channels implemented in
/// android/app/src/main/kotlin/zip/iambaney/bigblackclock/ClockBridge.kt.
class ChannelClockPlatform implements ClockPlatform {
  static const _prefix = 'zip.iambaney.bigblackclock';
  static const _methods = MethodChannel('$_prefix/platform');
  static const _ambient = EventChannel('$_prefix/ambient');
  static const _alarm = EventChannel('$_prefix/alarm');
  static const _battery = EventChannel('$_prefix/battery');

  @override
  Future<Capabilities> capabilities() async {
    try {
      final caps = await _methods.invokeMapMethod<String, bool>('capabilities') ?? {};
      return Capabilities(
        ambientLight: caps['ambientLight'] ?? false,
        nextAlarm: caps['nextAlarm'] ?? false,
        battery: caps['battery'] ?? false,
      );
    } on MissingPluginException {
      return const Capabilities();
    }
  }

  @override
  Stream<double> ambient() => _ambient.receiveBroadcastStream().map((v) => (v as num).toDouble());

  @override
  Stream<DateTime?> nextAlarm() => _alarm
      .receiveBroadcastStream()
      .map((ms) => ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int));

  @override
  Stream<Battery> battery() => _battery.receiveBroadcastStream().map((v) {
        final m = v as Map;
        return (percent: m['percent'] as int, charging: m['charging'] as bool);
      });

  @override
  Future<void> setBrightness(double? level) async {
    try {
      await _methods.invokeMethod<void>('setBrightness', level);
    } on MissingPluginException {
      // No native side on this platform; the scrim still dims.
    }
  }

  @override
  Future<String?> appVersion() async {
    try {
      return await _methods.invokeMethod<String>('appVersion');
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> openUrl(String url) async {
    try {
      return await _methods.invokeMethod<bool>('openUrl', url) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String?> loadSettings() async {
    try {
      return await _methods.invokeMethod<String>('loadSettings');
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> saveSettings(String encoded) async {
    try {
      await _methods.invokeMethod<void>('saveSettings', encoded);
    } on MissingPluginException {
      // No native side on this platform; settings last until the app closes.
    }
  }
}
