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
}
