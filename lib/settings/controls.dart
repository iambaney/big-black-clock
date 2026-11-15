import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Panel colors: the user's background, faintly tinted by the clock color,
/// with dim white text (or dark gray on a light background). Readable, but
/// not a bright sheet at night.
({Color fg, Color bg}) panelColors(HSVColor clock, HSVColor background) {
  final bg = Color.lerp(background.toColor(), clock.toColor(), 0.08)!;
  const dimWhite = Color(0xFFC0C0C0), darkGray = Color(0xFF303030);
  Color better(Color a, Color b) => contrastRatio(a, bg) >= contrastRatio(b, bg) ? a : b;
  final fg = better(dimWhite, darkGray);
  // Saturated mid-tones (a bright red background) defeat both grays.
  if (contrastRatio(fg, bg) >= 3) return (fg: fg, bg: bg);
  return (fg: better(const Color(0xFFFFFFFF), const Color(0xFF000000)), bg: bg);
}

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// An on/off pill.
class Toggle extends StatelessWidget {
  const Toggle({super.key, required this.value, required this.fg, required this.bg});

  final bool value;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 44,
      height: 24,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? fg : null,
        border: Border.all(color: fg, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(color: value ? bg : fg, shape: BoxShape.circle),
      ),
    );
  }
}

/// A horizontal slider over a gradient track. Reports 0..1.
class TrackSlider extends StatelessWidget {
  const TrackSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    required this.track,
    required this.thumb,
    required this.ring,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// Called when the finger lifts.
  final VoidCallback? onChangeEnd;

  /// Colors spread evenly along the track.
  final List<Color> track;
  final Color thumb;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      void at(double dx) => onChanged(((dx - _inset) / (width - 2 * _inset)).clamp(0.0, 1.0));
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => at(d.localPosition.dx),
        onTapUp: (_) => onChangeEnd?.call(),
        onTapCancel: () => onChangeEnd?.call(),
        onHorizontalDragStart: (d) => at(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
        onHorizontalDragEnd: (_) => onChangeEnd?.call(),
        onHorizontalDragCancel: () => onChangeEnd?.call(),
        child: CustomPaint(
          size: Size(width, 36),
          painter: _TrackPainter(value.clamp(0.0, 1.0), track, thumb, ring),
        ),
      );
    });
  }
}

const _inset = 12.0;

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.value, this.track, this.thumb, this.ring);

  final double value;
  final List<Color> track;
  final Color thumb;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final rect = Rect.fromLTRB(_inset, y - 4, size.width - _inset, y + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..shader = LinearGradient(colors: track).createShader(rect),
    );
    final x = _inset + value * (size.width - 2 * _inset);
    canvas.drawCircle(Offset(x, y), 10, Paint()..color = thumb);
    canvas.drawCircle(
      Offset(x, y),
      10,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.value != value || old.thumb != thumb || old.ring != ring || !_sameColors(old.track, track);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Hue, saturation and value sliders for one color.
class HsvEditor extends StatelessWidget {
  const HsvEditor({super.key, required this.color, required this.onChanged, required this.ring});

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final c = color;
    final thumb = c.toColor();
    // Tracks are drawn bright enough to see even when the color is near black.
    final visibleValue = math.max(c.value, 0.6);
    return Column(children: [
      TrackSlider(
        value: c.hue / 360,
        onChanged: (v) => onChanged(c.withHue(v * 360)),
        track: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()],
        thumb: thumb,
        ring: ring,
      ),
      TrackSlider(
        value: c.saturation,
        onChanged: (v) => onChanged(c.withSaturation(v)),
        track: [c.withSaturation(0).withValue(visibleValue).toColor(), c.withSaturation(1).withValue(visibleValue).toColor()],
        thumb: thumb,
        ring: ring,
      ),
      TrackSlider(
        value: c.value,
        onChanged: (v) => onChanged(c.withValue(v)),
        track: [const Color(0xFF000000), c.withValue(1).toColor()],
        thumb: thumb,
        ring: ring,
      ),
    ]);
  }
}

String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
