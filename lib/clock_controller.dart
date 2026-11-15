import 'dart:async';

import 'package:flutter/foundation.dart';

import 'brightness/brightness.dart';
import 'platform/clock_platform.dart';
import 'settings/settings.dart';

/// The single state holder: current time, settings, next alarm, ambient light
/// and the brightness level being applied. Runs only between [start] and
/// [stop], which follow the app being visible.
class ClockController extends ChangeNotifier {
  ClockController({
    required this._platform,
    required this._settings,
    this._store,
    DateTime Function() clock = DateTime.now,
  })  : _clock = clock,
        _now = clock();

  final ClockPlatform _platform;
  final SettingsStore? _store;
  final DateTime Function() _clock;

  Settings _settings;
  Settings get settings => _settings;

  DateTime _now;
  DateTime get now => _now;

  DateTime? _nextAlarm;
  DateTime? get nextAlarm => _nextAlarm;

  Capabilities _capabilities = const Capabilities();
  Capabilities get capabilities => _capabilities;

  final _ambient = AmbientFilter();

  /// Smoothed ambient light, null until the first reading.
  double? get ambient => _ambient.value;

  /// Latest unsmoothed reading, for the debug readout.
  double? rawAmbient;

  double _level = 0.5;

  /// The brightness level currently applied (it ramps toward [targetLevel]).
  double get level => _level;
  Split get split => splitLevel(_level);

  /// Whether brightness follows the light sensor (auto is on and the device
  /// has one).
  bool get autoAvailable => _capabilities.ambientLight;
  bool get autoOn => _settings.autoBrightness && autoAvailable;

  /// While a brightness slider is held, the screen shows that slider's level
  /// so it can be judged directly, even when tuning the dark-room level in a
  /// lit room.
  double? _preview;

  bool _running = false;
  bool _snapOnNextReading = false;
  Timer? _tick;
  Timer? _ramp;
  Timer? _save;
  double? _appliedBacklight;
  StreamSubscription<double>? _ambientSub;
  StreamSubscription<DateTime?>? _alarmSub;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _capabilities = await _platform.capabilities();
    if (!_running) return;
    _tickNow();
    _snapOnNextReading = true;
    if (_capabilities.nextAlarm) {
      _alarmSub = _platform.nextAlarm().listen((t) {
        _nextAlarm = t;
        notifyListeners();
      });
    }
    if (_capabilities.ambientLight) _ambientSub = _platform.ambient().listen(_onAmbient);
    _snapToTarget();
  }

  void stop() {
    _running = false;
    _tick?.cancel();
    _ramp?.cancel();
    _ramp = null;
    _ambientSub?.cancel();
    _alarmSub?.cancel();
    _ambientSub = null;
    _alarmSub = null;
    _appliedBacklight = null;
    _flushSave();
  }

  void update(Settings s) {
    final secondsChanged = s.showSeconds != _settings.showSeconds;
    _settings = s;
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 300), _flushSave);
    if (secondsChanged && _running) _tickNow();
    _rampToTarget();
    notifyListeners();
  }

  /// A brightness slider moved: the manual level, or one end of the auto
  /// range. Shown at once, without the ramp, until [endBrightnessPreview].
  void setManualLevel(double level) => _showWhileHeld(level, _settings.copyWith(manualLevel: level));
  void setDarkLevel(double level) => _showWhileHeld(level, _settings.copyWith(darkLevel: level));
  void setBrightLevel(double level) => _showWhileHeld(level, _settings.copyWith(brightLevel: level));

  void _showWhileHeld(double level, Settings s) {
    _preview = level;
    update(s);
    _snapToTarget();
  }

  /// The slider was released: ease back to what the room calls for.
  void endBrightnessPreview() {
    _preview = null;
    _rampToTarget();
  }

  void _flushSave() {
    _save?.cancel();
    _save = null;
    _store?.save(_settings);
  }

  void _tickNow() {
    _now = _clock();
    notifyListeners();
    _tick?.cancel();
    final ms = _settings.showSeconds
        ? 1000 - _now.millisecond
        : 60000 - (_now.second * 1000 + _now.millisecond);
    _tick = Timer(Duration(milliseconds: ms + 5), _tickNow);
  }

  void _onAmbient(double reading) {
    rawAmbient = reading;
    if (_snapOnNextReading) {
      // First reading since the app became visible: the room may have changed
      // while it was away, so jump straight to the right level.
      _snapOnNextReading = false;
      _ambient.reset();
      _ambient.add(reading);
      _snapToTarget();
      return;
    }
    final before = _ambient.value;
    if (_ambient.add(reading) != before) _rampToTarget();
    if (kDebugMode) notifyListeners();
  }

  /// Null when auto brightness has no reading yet; the system's brightness
  /// stays in charge until one arrives.
  double? _targetLevel() {
    final s = _settings;
    if (_preview != null) return _preview;
    if (autoOn) {
      final a = _ambient.value;
      return a == null ? null : autoLevel(a, dark: s.darkLevel, bright: s.brightLevel);
    }
    return s.manualLevel;
  }

  void _snapToTarget() {
    final target = _targetLevel();
    if (target == null) return;
    _ramp?.cancel();
    _ramp = null;
    _level = target;
    _apply();
    notifyListeners();
  }

  /// Eases toward the target over about a second.
  void _rampToTarget() {
    if (!_running || _ramp != null) return;
    _ramp = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final target = _targetLevel();
      if (target == null) return;
      final d = target - _level;
      if (d.abs() < 0.003) {
        _level = target;
        _ramp?.cancel();
        _ramp = null;
      } else {
        _level += d * 0.12;
      }
      _apply();
      notifyListeners();
    });
  }

  void _apply() {
    if (!_running) return;
    final backlight = split.backlight;
    if (_appliedBacklight != null && (backlight - _appliedBacklight!).abs() < 0.0005) return;
    _appliedBacklight = backlight;
    _platform.setBrightness(backlight);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
