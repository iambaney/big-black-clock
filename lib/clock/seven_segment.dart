import 'package:flutter/rendering.dart';

import 'face_layout.dart';
import 'time_format.dart';

/// Lit segments per digit, bits a..g = 0..6: a top, b upper right, c lower
/// right, d bottom, e lower left, f upper left, g middle.
const _segments = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F];

/// Draws one seven-segment digit in a cell of [height] × [height] *
/// [Units.digitWidth] whose top-left corner is [origin].
void paintDigit(Canvas canvas, Paint paint, Offset origin, double height, int digit) {
  final w = height * Units.digitWidth;
  final t = height * Units.stroke;
  final gap = t * 0.12;
  final l = origin.dx + t / 2, r = origin.dx + w - t / 2;
  final top = origin.dy + t / 2, mid = origin.dy + height / 2, bottom = origin.dy + height - t / 2;
  final bits = _segments[digit];

  void horizontal(double y) {
    final x0 = l + gap, x1 = r - gap;
    canvas.drawPath(
      Path()
        ..moveTo(x0, y)
        ..lineTo(x0 + t / 2, y - t / 2)
        ..lineTo(x1 - t / 2, y - t / 2)
        ..lineTo(x1, y)
        ..lineTo(x1 - t / 2, y + t / 2)
        ..lineTo(x0 + t / 2, y + t / 2)
        ..close(),
      paint,
    );
  }

  void vertical(double x, double y0, double y1) {
    y0 += gap;
    y1 -= gap;
    canvas.drawPath(
      Path()
        ..moveTo(x, y0)
        ..lineTo(x + t / 2, y0 + t / 2)
        ..lineTo(x + t / 2, y1 - t / 2)
        ..lineTo(x, y1)
        ..lineTo(x - t / 2, y1 - t / 2)
        ..lineTo(x - t / 2, y0 + t / 2)
        ..close(),
      paint,
    );
  }

  if (bits & 0x01 != 0) horizontal(top);
  if (bits & 0x02 != 0) vertical(r, top, mid);
  if (bits & 0x04 != 0) vertical(r, mid, bottom);
  if (bits & 0x08 != 0) horizontal(bottom);
  if (bits & 0x10 != 0) vertical(l, mid, bottom);
  if (bits & 0x20 != 0) vertical(l, top, mid);
  if (bits & 0x40 != 0) horizontal(mid);
}

/// Draws a run of digits into fixed-width slots starting at [origin].
void paintDigits(Canvas canvas, Paint paint, Offset origin, double height, String digits) {
  final step = height * (Units.digitWidth + Units.digitGap);
  for (var i = 0; i < digits.length; i++) {
    paintDigit(canvas, paint, origin + Offset(i * step, 0), height, digits.codeUnitAt(i) - 0x30);
  }
}

double digitsWidth(double height, int count) =>
    count == 0 ? 0 : height * (count * Units.digitWidth + (count - 1) * Units.digitGap);

/// Paints the time block described by a [FaceLayout].
class TimePainter extends CustomPainter {
  TimePainter({
    required this.time,
    required this.layout,
    required this.color,
    required this.showSeconds,
  });

  final ClockTime time;
  final FaceLayout layout;
  final Color color;
  final bool showSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final h = layout.digitHeight;
    final small = h * Units.smallScale;
    final side = layout.sideColumnWidth;

    // The visible content is centered, so a one-digit hour shifts the time by
    // half a digit twice a day; the digit size never changes. A 12-hour "1x"
    // is centered on the 1's lit edge, which makes room for AM/PM.
    final hoursW = digitsWidth(h, time.hours.length);
    final blank = time.period != null && time.hours.length == 2 ? h * Units.oneBlank : 0.0;
    final colon = h * Units.colonWidth;
    final contentW = hoursW - blank + colon + digitsWidth(h, 2) + side;
    var x = (size.width - contentW) / 2 - blank;
    paintDigits(canvas, paint, Offset(x, 0), h, time.hours);
    x += hoursW;
    final dot = h * Units.stroke;
    for (final y in [0.32, 0.68]) {
      canvas.drawRect(Rect.fromCenter(center: Offset(x + colon / 2, h * y), width: dot, height: dot), paint);
    }
    x += colon;
    paintDigits(canvas, paint, Offset(x, 0), h, time.minutes);
    x += digitsWidth(h, 2) + h * Units.sideGap;
    _paintPeriod(canvas, Offset(x, 0));
    if (showSeconds) paintDigits(canvas, paint, Offset(x, h - small), small, time.seconds);
  }

  void _paintPeriod(Canvas canvas, Offset at) {
    final period = time.period;
    if (period == null) return;
    var fontSize = layout.digitHeight * Units.periodFont;
    TextPainter text() => TextPainter(
          text: TextSpan(
            text: period,
            style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, height: 1),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    var painter = text();
    // A system font wider than Roboto is scaled down to fit its column.
    final room = layout.digitHeight * Units.periodWidth;
    if (painter.width > room) {
      fontSize *= room / painter.width;
      painter = text();
    }
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(TimePainter old) =>
      old.time != time || old.color != color || old.showSeconds != showSeconds || old.layout != layout;
}
