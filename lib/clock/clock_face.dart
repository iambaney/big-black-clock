import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'face_layout.dart';
import 'seven_segment.dart';
import 'time_format.dart';

/// The time plus the date and next-alarm line, as large as [ClockFace]'s
/// constraints allow.
class ClockFace extends StatelessWidget {
  const ClockFace({
    super.key,
    required this.now,
    required this.use24h,
    required this.color,
    required this.showSeconds,
    required this.showDate,
    this.alarm,
  });

  final DateTime now;
  final bool use24h;
  final Color color;
  final bool showSeconds;
  final bool showDate;

  /// The next alarm, already formatted; null hides it.
  final String? alarm;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final layout = fitFace(
        constraints.biggest,
        seconds: showSeconds,
        period: !use24h,
        date: showDate,
        alarm: alarm != null,
      );
      final fontSize = layout.secondaryFontSize;
      final style = TextStyle(color: color, fontSize: fontSize, height: 1, fontWeight: FontWeight.w500);
      final date = showDate ? Text(dateLabel(now), style: style) : null;
      final alarmText = alarm == null
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
              CustomPaint(size: Size.square(fontSize), painter: BellPainter(color)),
              SizedBox(width: fontSize * 0.3),
              Text(alarm!, style: style),
            ]);
      final lines = layout.secondaryLines == 2
          ? [date!, alarmText!]
          : [
              if (date != null || alarmText != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ?date,
                  if (date != null && alarmText != null) SizedBox(width: fontSize * 1.2),
                  ?alarmText,
                ]),
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
        if (lines.isNotEmpty) SizedBox(height: layout.secondaryGap),
        for (final line in lines)
          SizedBox(
            width: constraints.maxWidth * fillFraction,
            height: layout.digitHeight * Units.secondaryLine,
            child: FittedBox(fit: BoxFit.scaleDown, child: line),
          ),
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

/// Burn-in protection: the face drifts around a small circle, one step a
/// minute, a full lap an hour.
Offset burnInOffset(DateTime t, {double radius = 3}) {
  final angle = 2 * math.pi * (t.minute / 60);
  return Offset(radius * math.cos(angle), radius * math.sin(angle));
}
