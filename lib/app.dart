import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'brightness/brightness.dart';
import 'clock/clock_face.dart';
import 'clock/time_format.dart';
import 'clock_controller.dart';
import 'settings/settings_panel.dart';

/// The one screen: face, settings panel and dimming scrim.
class ClockApp extends StatefulWidget {
  const ClockApp({super.key, required this.controller});

  final ClockController controller;

  @override
  State<ClockApp> createState() => _ClockAppState();
}

class _ClockAppState extends State<ClockApp> {
  late final AppLifecycleListener _lifecycle;

  /// Opened by tapping the face, closed by tapping the face again (anywhere
  /// outside the panel).
  bool _panelOpen = false;

  ClockController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _show, onPause: _controller.stop);
    _show();
  }

  void _show() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller.start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _togglePanel() => setState(() => _panelOpen = !_panelOpen);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final c = _controller;
          final s = c.settings;
          final use24h = s.use24h ?? MediaQuery.alwaysUse24HourFormatOf(context);
          final next = c.nextAlarm;
          final alarm = s.showAlarm && next != null && next.isAfter(c.now)
              ? alarmLabel(next, c.now, use24h: use24h)
              : null;
          final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;

          return Stack(fit: StackFit.expand, children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePanel,
              child: ColoredBox(
                color: s.backgroundColor.toColor(),
                child: SafeArea(
                  // Just enough margin that the burn-in drift stays on screen.
                  minimum: const EdgeInsets.all(burnInRadius + 1),
                  // In portrait the face sits in the top third, above a dock
                  // and clear of the settings panel.
                  child: Align(
                    alignment: portrait ? const Alignment(0, -2 / 3) : Alignment.center,
                    child: Transform.translate(
                      offset: burnInOffset(c.now),
                      child: ClockFace(
                        now: c.now,
                        use24h: use24h,
                        color: s.clockColor.toColor(),
                        showSeconds: s.showSeconds,
                        showDate: s.showDate,
                        alarm: alarm,
                        battery: s.showBattery ? c.battery : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_panelOpen,
                child: AnimatedSlide(
                  offset: _panelOpen ? Offset.zero : const Offset(0, 1.1),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Center(child: SettingsPanel(controller: c, use24h: use24h)),
                ),
              ),
            ),
            if (kDebugMode && _panelOpen) Positioned(top: 8, left: 8, child: _DebugReadout(c)),
            IgnorePointer(child: ColoredBox(color: Color.fromRGBO(0, 0, 0, c.split.scrim))),
          ]);
        },
      ),
    );
  }
}

/// Brightness internals, shown in debug builds while the panel is open.
class _DebugReadout extends StatelessWidget {
  const _DebugReadout(this.c);

  final ClockController c;

  @override
  Widget build(BuildContext context) {
    String f(double? v, [int digits = 3]) => v == null ? '-' : v.toStringAsFixed(digits);
    final raw = c.rawAmbient;
    final split = c.split;
    return Text(
      'lux ${raw == null ? '-' : approximateLux(raw).toStringAsFixed(1)}  '
      'ambient ${f(raw)}/${f(c.ambient)}  level ${f(c.level)}  '
      'backlight ${f(split.backlight)}  scrim ${f(split.scrim, 2)}',
      style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
    );
  }
}
