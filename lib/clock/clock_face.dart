import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../platform/clock_platform.dart';
import 'face_layout.dart';
import 'seven_segment.dart';
import 'time_format.dart';

/// The time plus the date, next-alarm and battery line, as large as
/// [ClockFace]'s constraints allow.
class ClockFace extends StatelessWidget {
  const ClockFace({
    super.key,
    required this.now,
    required this.use24h,
    required this.color,
    required this.showSeconds,
    required this.showDate,
    this.alarm,
    this.battery,
  });

  final DateTime now;
  final bool use24h;
  final Color color;
  final bool showSeconds;
  final bool showDate;

  /// The next alarm, already formatted; null hides it.
  final String? alarm;

  /// Null hides the battery.
  final Battery? battery;

  @override
  Widget build(BuildContext context) {
    final battery = this.battery;
    return LayoutBuilder(builder: (context, constraints) {
      final layout = fitFace(
        constraints.biggest,
        seconds: showSeconds,
        period: !use24h,
        date: showDate,
        alarm: alarm != null,
        battery: battery != null,
      );
      final fontSize = layout.secondaryFontSize;
      final style = TextStyle(color: color, fontSize: fontSize, height: 1, fontWeight: FontWeight.w500);
      final groups = [
        if (showDate) [Text(dateLabel(now), style: style)],
        if (alarm != null)
          [
            CustomPaint(size: Size.square(fontSize), painter: BellPainter(color)),
            SizedBox(width: fontSize * 0.3),
            Text(alarm!, style: style),
          ],
        if (battery != null)
          [CustomPaint(size: Size(fontSize * 1.85, fontSize * 0.85), painter: BatteryPainter(battery, color))],
      ];

      return Column(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(
          size: layout.timeSize,
          painter: TimePainter(
            time: clockTime(now, use24h: use24h),
            layout: layout,
            color: color,
            showSeconds: showSeconds,
          ),
        ),
        if (layout.hasSecondary) ...[
          SizedBox(height: layout.secondaryGap),
          SizedBox(
            width: constraints.maxWidth,
            height: layout.digitHeight * Units.secondaryLine,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final (i, group) in groups.indexed) ...[
                  if (i > 0) SizedBox(width: fontSize * 1.2),
                  ...group,
                ],
              ]),
            ),
          ),
        ],
      ]);
    });
  }
}

/// A small alarm bell.
class BellPainter extends CustomPainter {
  const BellPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.14, s * 0.76)
        ..quadraticBezierTo(s * 0.26, s * 0.66, s * 0.26, s * 0.46)
        ..cubicTo(s * 0.26, s * 0.18, s * 0.38, s * 0.1, s * 0.5, s * 0.1)
        ..cubicTo(s * 0.62, s * 0.1, s * 0.74, s * 0.18, s * 0.74, s * 0.46)
        ..quadraticBezierTo(s * 0.74, s * 0.66, s * 0.86, s * 0.76)
        ..close(),
      paint,
    );
    canvas.drawCircle(Offset(s * 0.5, s * 0.86), s * 0.09, paint);
  }

  @override
  bool shouldRepaint(BellPainter old) => old.color != color;
}

/// A battery that fills with the charge, with a lightning bolt over it while
/// a charger is connected.
class BatteryPainter extends CustomPainter {
  const BatteryPainter(this.battery, this.color);

  final Battery battery;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final stroke = h * 0.1;
    final nub = h * 0.14;
    final paint = Paint()..color = color;
    final body = Rect.fromLTRB(stroke / 2, stroke / 2, size.width - nub - stroke / 2, h - stroke / 2);
    // On a layer, so the bolt's outline can be cut out of whatever is under it.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * 0.22)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(size.width - nub, h * 0.3, nub, h * 0.4),
        topRight: Radius.circular(nub / 2),
        bottomRight: Radius.circular(nub / 2),
      ),
      paint,
    );
    // The fill sits a stroke's width inside the outline.
    final inner = body.deflate(stroke * 1.5);
    final charge = (battery.percent / 100).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inner.left, inner.top, inner.width * charge, inner.height),
        Radius.circular(h * 0.08),
      ),
      paint,
    );
    if (battery.charging) {
      final bolt = _bolt(Rect.fromCenter(center: body.center, width: h * 0.56, height: h * 0.8));
      canvas.drawPath(
        bolt,
        Paint()
          ..blendMode = BlendMode.clear
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 2
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(bolt, paint);
    }
    canvas.restore();
  }

  /// A lightning bolt filling [r].
  static Path _bolt(Rect r) {
    Offset p(double x, double y) => Offset(r.left + r.width * x, r.top + r.height * y);
    return Path()..addPolygon([p(0.62, 0), p(0.05, 0.58), p(0.45, 0.58), p(0.35, 1), p(0.95, 0.4), p(0.55, 0.4)], true);
  }

  @override
  bool shouldRepaint(BatteryPainter old) => old.battery != battery || old.color != color;
}

/// Burn-in protection: the face drifts around a small circle, one step a
/// minute, a full lap an hour.
const burnInRadius = 3.0;

Offset burnInOffset(DateTime t) {
  final angle = 2 * math.pi * (t.minute / 60);
  return Offset(burnInRadius * math.cos(angle), burnInRadius * math.sin(angle));
}
