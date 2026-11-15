import 'dart:math' as math;

/// Brightness is one level from 0 (darkest) to 1 (full), delivered first by
/// the window backlight and, below [knee], by a black scrim over the face.

/// Lowest window brightness used. Exactly 0 can switch some backlights off.
const backlightFloor = 0.004;

/// Levels below this hold the backlight at its floor and dim with the scrim.
const knee = 0.3;

/// Scrim opacity at level 0: the face at a tenth of the floor brightness.
const maxScrim = 0.9;

typedef Split = ({double backlight, double scrim});

Split splitLevel(double level) {
  level = level.clamp(0.0, 1.0);
  if (level >= knee) {
    // Squared so equal slider steps look roughly equal; backlight output is
    // close to linear in light, and the eye is not.
    final t = (level - knee) / (1 - knee);
    return (backlight: backlightFloor + (1 - backlightFloor) * t * t, scrim: 0);
  }
  return (backlight: backlightFloor, scrim: maxScrim * (1 - level / knee));
}

/// Auto brightness is a fixed curve over normalized ambient light (see
/// ClockPlatform.ambient), calibrated by Anthony on his phone on 14 November:
/// [darkRoomLevel] at or below [darkAmbient] (about 1 lux), full brightness
/// at or above [brightAmbient] (about 100 lux, an ordinary lit room as a
/// phone lying on a table sees it), and straight between them over log-lux,
/// which is roughly how the eye judges light.
const darkAmbient = 0.075;
const brightAmbient = 0.5;
const darkRoomLevel = 0.4;

double autoLevel(double ambient) {
  final t = ((ambient - darkAmbient) / (brightAmbient - darkAmbient)).clamp(0.0, 1.0);
  return darkRoomLevel + (1 - darkRoomLevel) * t;
}

/// Inverse of the platform's normalization, for the debug readout only.
double approximateLux(double ambient) => math.pow(10001, ambient) - 1;

/// Steadies the ambient signal: a low-pass filter, then hysteresis so small
/// wobbles (including the screen's own glow reflecting into the sensor) do
/// not move the brightness.
class AmbientFilter {
  AmbientFilter({this.smoothing = 0.3, this.hysteresis = 0.04});

  final double smoothing;
  final double hysteresis;
  double? _filtered;
  double? _output;

  double? get value => _output;

  /// Feeds one reading and returns the value to use.
  double add(double reading) {
    final f = _filtered == null ? reading : _filtered! + (reading - _filtered!) * smoothing;
    _filtered = f;
    if (_output == null || (f - _output!).abs() >= hysteresis) _output = f;
    return _output!;
  }

  void reset() {
    _filtered = null;
    _output = null;
  }
}
