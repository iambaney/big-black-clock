import 'dart:math' as math;
import 'dart:ui';

/// Proportions of the time block, in multiples of the digit height.
abstract final class Units {
  static const digitWidth = 0.5;
  static const digitGap = 0.14;
  static const stroke = 0.12;
  static const colonWidth = 0.32;

  /// Seconds digits relative to the main digits.
  static const smallScale = 0.42;
  static const sideGap = 0.16;
  static const periodFont = 0.2;
  static const periodWidth = 0.34;

  /// Stacked arrangement: gap between the hours row and the minutes row.
  static const rowGap = 0.18;

  static const secondaryGap = 0.12;
  static const secondaryFont = 0.16;
  static const secondaryLine = 0.2;

  static const pairWidth = 2 * digitWidth + digitGap;
  static const smallPairWidth = pairWidth * smallScale;
}

/// Hours and minutes side by side (landscape), or hours above minutes, which
/// gives much bigger digits on a tall screen.
enum Arrangement { row, stacked }

class FaceLayout {
  const FaceLayout({
    required this.arrangement,
    required this.digitHeight,
    required this.timeSize,
    required this.sideColumnWidth,
    required this.secondaryLines,
  });

  final Arrangement arrangement;
  final double digitHeight;

  /// Size of the painted time block, including the side column.
  final Size timeSize;

  /// Width of the column beside the digits that holds seconds and AM/PM, in
  /// pixels; zero when neither is shown.
  final double sideColumnWidth;

  /// Lines of date and alarm text under the time: 0, 1 (row) or 2 (stacked).
  final int secondaryLines;

  double get secondaryFontSize => digitHeight * Units.secondaryFont;
  double get secondaryGap => digitHeight * Units.secondaryGap;
}

/// Fraction of the available width or height the face may fill.
const fillFraction = 0.92;

/// Picks the arrangement and digit height that make the time as large as
/// possible inside [area]. Sizes come from the widest possible time, so the
/// result does not change from minute to minute.
FaceLayout fitFace(
  Size area, {
  required bool seconds,
  required bool period,
  required bool date,
  required bool alarm,
}) {
  final side = seconds
      ? Units.sideGap + Units.smallPairWidth
      : period
          ? Units.sideGap + Units.periodWidth
          : 0.0;
  final hasSecondary = date || alarm;

  FaceLayout fit(Arrangement arrangement) {
    final stacked = arrangement == Arrangement.stacked;
    final lines = !hasSecondary
        ? 0
        : stacked && date && alarm
            ? 2
            : 1;
    final width = (stacked ? Units.pairWidth : 2 * Units.pairWidth + Units.colonWidth) + side;
    final timeHeight = stacked ? 2 + Units.rowGap : 1.0;
    final height = timeHeight + (lines == 0 ? 0 : Units.secondaryGap + lines * Units.secondaryLine);
    final h = math.min(area.width * fillFraction / width, area.height * fillFraction / height);
    return FaceLayout(
      arrangement: arrangement,
      digitHeight: h,
      timeSize: Size(width * h, timeHeight * h),
      sideColumnWidth: side * h,
      secondaryLines: lines,
    );
  }

  final row = fit(Arrangement.row);
  final stacked = fit(Arrangement.stacked);
  return stacked.digitHeight > row.digitHeight ? stacked : row;
}
