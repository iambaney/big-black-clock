// Renders the Google Play phone screenshots from the app's own widgets, with a
// fixed time, alarm and battery. Writes 1080x1920 and 1920x1080 PNGs to
// build/screenshots; tool/graphics.py then copies them into the store listing.
//
// Usage, from the repo root: flutter test tool/screenshots_test.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bigblackclock/app.dart';
import 'package:bigblackclock/clock_controller.dart';
import 'package:bigblackclock/platform/clock_platform.dart';
import 'package:bigblackclock/settings/settings.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _out = 'build/screenshots';

/// Roboto, Android's default font, ships with the Flutter SDK; the test runs
/// in `bin/cache/artifacts/engine/<platform>/flutter_tester`.
final _fonts = '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';

/// 1080x1920 pixels is then a 450x800dp screen, tall enough (like the S21's
/// 800dp) that the open panel leaves the date line visible.
const _dpr = 2.4;

const _portrait = Size(1080, 1920);
const _landscape = Size(1920, 1080);

class _FakePlatform implements ClockPlatform {
  _FakePlatform(this._alarm, this._battery);

  final DateTime? _alarm;
  final Battery _battery;

  @override
  Future<Capabilities> capabilities() async =>
      const Capabilities(ambientLight: true, nextAlarm: true, battery: true);

  /// A dim evening room.
  @override
  Stream<double> ambient() => Stream.value(0.42);

  @override
  Stream<DateTime?> nextAlarm() => Stream.value(_alarm);

  @override
  Stream<Battery> battery() => Stream.value(_battery);

  @override
  Future<void> setBrightness(double? level) async {}

  @override
  Future<String?> appVersion() async => '1.0.0';

  @override
  Future<bool> openUrl(String url) async => false;

  @override
  Future<String?> loadSettings() async => null;

  @override
  Future<void> saveSettings(String encoded) async {}
}

/// The test environment draws text that names no font family in a font of
/// blocks, whatever fonts are loaded. Android draws it in Roboto, so name
/// Roboto on every laid-out paragraph.
void _useRoboto(RenderObject node) {
  if (node is RenderParagraph) {
    final span = node.text as TextSpan;
    node.text = TextSpan(
      text: span.text,
      children: span.children,
      style: (span.style ?? const TextStyle()).copyWith(fontFamily: 'Roboto'),
    );
  }
  node.visitChildren(_useRoboto);
}

HSVColor _hsv(double h, double s, double v) => HSVColor.fromAHSV(1, h, s, v);

void main() {
  setUpAll(() async {
    final roboto = FontLoader('Roboto');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      roboto.addFont(Future.value(ByteData.sublistView(File('$_fonts/Roboto-$weight.ttf').readAsBytesSync())));
    }
    await roboto.load();
  });

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required Size size,
    required DateTime now,
    required Settings settings,
    DateTime? alarm,
    Battery battery = (percent: 80, charging: true),
    Future<void> Function()? interact,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    final controller = ClockController(platform: _FakePlatform(alarm, battery), settings: settings, clock: () => now);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: ClockApp(controller: controller)));
    await tester.pump(const Duration(milliseconds: 50));
    if (interact != null) await interact();
    await tester.pump(const Duration(milliseconds: 500));
    _useRoboto(key.currentContext!.findRenderObject()!);
    await tester.pump();
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: _dpr);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_out/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
    controller.stop();
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 20));
    // The first frame starts the slide; the second runs it to the end.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Monday night; the alarm is Tuesday morning.
  final monday = DateTime(2026, 11, 16, 22, 47);
  final tuesday = DateTime(2026, 11, 17, 6, 30);

  testWidgets('1 landscape, red', (tester) async {
    await shoot(tester, '1', size: _landscape, now: monday, alarm: tuesday,
        settings: const Settings(use24h: true));
  });

  // 24-hour: the face paints AM/PM itself, out of reach of _useRoboto.
  testWidgets('2 portrait, amber, alarm days away', (tester) async {
    await shoot(tester, '2', size: _portrait, now: DateTime(2026, 11, 20, 23, 18),
        alarm: DateTime(2026, 11, 23, 7, 0), battery: (percent: 64, charging: true),
        settings: Settings(use24h: true, clockColor: _hsv(38, 1, 1)));
  });

  testWidgets('3 landscape, green with seconds', (tester) async {
    await shoot(tester, '3', size: _landscape, now: DateTime(2026, 11, 17, 14, 5, 36),
        alarm: tuesday.add(const Duration(days: 1)), battery: (percent: 47, charging: false),
        settings: Settings(use24h: true, showSeconds: true, clockColor: _hsv(130, 0.9, 1)));
  });

  testWidgets('4 settings', (tester) async {
    await shoot(tester, '4', size: _portrait, now: monday, alarm: tuesday,
        settings: const Settings(use24h: true), interact: () => openPanel(tester));
  });

  testWidgets('5 colors', (tester) async {
    await shoot(tester, '5', size: _portrait, now: monday, alarm: tuesday,
        settings: Settings(use24h: true, clockColor: _hsv(190, 0.85, 1), backgroundColor: _hsv(225, 0.7, 0.16)),
        interact: () async {
      await openPanel(tester);
      await tester.tap(find.text('Clock color'));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
