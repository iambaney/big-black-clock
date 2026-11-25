import 'package:bigblackclock/clock/clock_face.dart';
import 'package:bigblackclock/clock/face_layout.dart';
import 'package:bigblackclock/clock/seven_segment.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

FaceLayout fit(
  Size area, {
  bool seconds = false,
  bool period = true,
  bool date = true,
  bool alarm = true,
  bool battery = false,
}) =>
    fitFace(area, seconds: seconds, period: period, date: date, alarm: alarm, battery: battery);

void main() {
  test('the face always fits inside the area, with the time on one line', () {
    for (final area in const [Size(800, 360), Size(360, 800), Size(2000, 200), Size(200, 2000), Size(500, 500)]) {
      for (final seconds in [false, true]) {
        for (final secondary in [false, true]) {
          final l = fit(area, seconds: seconds, date: secondary, alarm: secondary);
          expect(l.timeSize.height, l.digitHeight, reason: 'one line of digits');
          expect(l.timeSize.width, lessThanOrEqualTo(area.width + 1e-6), reason: '$area');
          expect(l.timeSize.height + l.secondaryHeight, lessThanOrEqualTo(area.height + 1e-6), reason: '$area');
        }
      }
    }
  });

  test('fills the binding dimension completely', () {
    // Portrait: width binds.
    expect(fit(const Size(360, 800)).timeSize.width, closeTo(360, 1e-6));
    // Very wide: height binds.
    final wide = fit(const Size(2000, 200));
    expect(wide.timeSize.height + wide.secondaryHeight, closeTo(200, 1e-6));
  });

  test('hiding the date and alarm line makes the digits bigger when height binds', () {
    expect(
      fit(const Size(800, 300), date: false, alarm: false).digitHeight,
      greaterThan(fit(const Size(800, 300)).digitHeight),
    );
  });

  test('12-hour digits are as big as 24-hour digits', () {
    for (final area in const [Size(800, 360), Size(360, 800), Size(2000, 200)]) {
      for (final seconds in [false, true]) {
        expect(
          fit(area, seconds: seconds, period: true).digitHeight,
          fit(area, seconds: seconds, period: false).digitHeight,
          reason: '$area, seconds: $seconds',
        );
      }
    }
    // "12:59 PM", centered on the 1's lit edge, is exactly as wide as "23:59".
    expect(Units.pairWidth - Units.oneBlank + Units.sideGap + Units.periodWidth, closeTo(Units.pairWidth, 1e-9));
  });

  test('the battery alone keeps the line under the time', () {
    expect(fit(const Size(800, 300), date: false, alarm: false, battery: true).hasSecondary, isTrue);
  });

  Future<({Rect face, Rect time, Rect bell})> pumpFace(
    WidgetTester tester, {
    required bool lineAtBottom,
    bool use24h = true,
    bool seconds = false,
    String alarm = '6:30',
    Size size = const Size(764, 352),
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints.loose(size),
            child: ClockFace(
              now: DateTime(2026, 11, 24, 22, 30),
              use24h: use24h,
              color: const Color(0xFFFFFFFF),
              showSeconds: seconds,
              showDate: false,
              lineAtBottom: lineAtBottom,
              alarm: alarm,
            ),
          ),
        ),
      ),
    );
    Rect painted<T>() => tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is T));
    return (
      face: tester.getRect(find.byType(Column)),
      time: painted<TimePainter>(),
      bell: painted<BellPainter>(),
    );
  }

  testWidgets('the line under the time ends exactly at the bottom of the face', (tester) async {
    for (final lineAtBottom in [false, true]) {
      for (final alarm in ['6:30', '6:30 +2 days']) {
        final f = await pumpFace(tester, lineAtBottom: lineAtBottom, alarm: alarm);
        // The bell is drawn down to 95% of its box. A letter's tail reaches
        // the bottom of the box, so then the whole box has to fit. The text's
        // height is a whole number of pixels, hence the tolerance.
        final drawn = alarm.contains('y') ? 1.0 : 0.95;
        expect(f.bell.top + f.bell.height * drawn, closeTo(f.face.bottom, 0.5), reason: alarm);
      }
    }
  });

  testWidgets('a line at the bottom stays put when the time changes size', (tester) async {
    for (final size in const [Size(764, 352), Size(640, 352), Size(800, 600)]) {
      for (final use24h in [false, true]) {
        final big = await pumpFace(tester, lineAtBottom: true, use24h: use24h, size: size);
        final small = await pumpFace(tester, lineAtBottom: true, use24h: use24h, size: size, seconds: true);
        expect(small.time.height, lessThan(big.time.height));
        expect(small.face.bottom, closeTo(big.face.bottom, 1e-6));
        expect(small.bell, rectMoreOrLessEquals(big.bell, epsilon: 1e-6), reason: '$size');
        // Still inside the face, and clear of the line.
        expect(small.time.top, greaterThanOrEqualTo(small.face.top));
        expect(small.time.bottom, lessThan(small.bell.top));
      }
    }
  });

  testWidgets('a line under the time keeps its distance and shrinks with the time', (tester) async {
    const size = Size(352, 744);
    for (final seconds in [false, true]) {
      final f = await pumpFace(tester, lineAtBottom: false, seconds: seconds, size: size);
      final h = f.time.height;
      expect(f.face.top, f.time.top);
      expect(f.bell.top - f.time.bottom, closeTo(h * Units.secondaryGap, 1e-6));
      expect(f.bell.height, closeTo(h * Units.secondaryFont, 1e-6));
    }
  });
}
