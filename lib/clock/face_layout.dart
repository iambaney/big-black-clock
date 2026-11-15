import 'dart:math' as math;
import 'dart:ui';

/// Proportions of the time block, in multiples of the digit height.
abstract final class Units {
  static const digitWidth = 0.5;
  static const digitGap = 0.1;
  static const stroke = 0.12;
  static const colonWidth = 0.28;

  /// Seconds digits relative to the main digits.
  static const smallScale = 0.42;
  static const sideGap = 0.1;
  static const periodFont = 0.2;
  static const periodWidth = 0.34;

  static const secondaryGap = 0.08;
  static const secondaryFont = 0.16;
  static const secondaryLine = 0.2;

  static const pairWidth = 2 * digitWidth + digitGap;
  static const smallPairWidth = pairWidth * smallScale;
}

class FaceLayout {
  const FaceLayout({
    required this.digitHeight,
    required this.timeSize,
    required this.sideColumnWidth,
    required this.hasSecondary,
  });

  final double digitHeight;

  /// Size of the painted time block, including the side column.
  final Size timeSize;

  /// Width of the column beside the minutes that holds seconds and AM/PM, in
  /// pixels; zero when neither is shown.
  final double sideColumnWidth;

  /// Whether the date, alarm and battery line sits under the time.
  final bool hasSecondary;

  double get secondaryFontSize => digitHeight * Units.secondaryFont;
  double get secondaryGap => digitHeight * Units.secondaryGap;
  double get secondaryHeight => hasSecondary ? digitHeight * (Units.secondaryGap + Units.secondaryLine) : 0;
}

/// The digit height that makes the time, always on one line, as large as
/// possible inside [area] with the date, alarm and battery line (if any)
/// below it.
/// Sizes come from the widest possible time, so the result does not change
/// from minute to minute.
FaceLayout fitFace(
  Size area, {
  required bool seconds,
  required bool period,
  required bool date,
  required bool alarm,
  required bool battery,
}) {
  final side = seconds
      ? Units.sideGap + Units.smallPairWidth
      : period
          ? Units.sideGap + Units.periodWidth
          : 0.0;
  final hasSecondary = date || alarm || battery;
  final width = 2 * Units.pairWidth + Units.colonWidth + side;
  final height = 1 + (hasSecondary ? Units.secondaryGap + Units.secondaryLine : 0);
  final h = math.min(area.width / width, area.height / height);
  return FaceLayout(
    digitHeight: h,
    timeSize: Size(width * h, h),
    sideColumnWidth: side * h,
    hasSecondary: hasSecondary,
  );
}
