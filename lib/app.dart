import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
          // Just enough margin that the burn-in drift stays on screen. In
          // portrait the top and bottom match, so a camera cutout does not
          // push the centered face below the middle of the screen.
          const margin = burnInRadius + 1;
          final inset = MediaQuery.paddingOf(context);
          final vertical = portrait ? math.max(margin, math.max(inset.top, inset.bottom)) : margin;

          return Stack(fit: StackFit.expand, children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePanel,
              child: ColoredBox(
                color: s.backgroundColor.toColor(),
                child: SafeArea(
                  minimum: EdgeInsets.symmetric(horizontal: margin, vertical: vertical),
                  // In portrait the face sits where the user puts it, by
                  // default in the top third, above a dock and clear of the
                  // settings panel.
                  child: Align(
                    alignment: portrait ? Alignment(0, s.portraitPosition * 2 - 1) : Alignment.center,
                    child: Transform.translate(
                      offset: burnInOffset(c.now),
                      // Its own layer, so dimming and the panel sliding do not
                      // repaint the digits.
                      child: RepaintBoundary(
                        child: ClockFace(
                          now: c.now,
                          use24h: use24h,
                          color: s.clockColor.toColor(),
                          showSeconds: s.showSeconds,
                          showDate: s.showDate,
                          lineAtBottom: !portrait,
                          alarm: alarm,
                          battery: s.showBattery ? c.battery : null,
                        ),
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
            IgnorePointer(child: ColoredBox(color: Color.fromRGBO(0, 0, 0, c.split.scrim))),
          ]);
        },
      ),
    );
  }
}

