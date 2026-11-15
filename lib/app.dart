import 'dart:async';

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
  static const _panelTimeout = Duration(seconds: 4);

  late final AppLifecycleListener _lifecycle;
  bool _panelOpen = false;
  Timer? _hideTimer;
  int _pointersDown = 0;

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
    _hideTimer?.cancel();
    super.dispose();
  }

  void _togglePanel() {
    setState(() => _panelOpen = !_panelOpen);
    _panelOpen ? _scheduleHide() : _hideTimer?.cancel();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_panelTimeout, () => setState(() => _panelOpen = false));
  }

  // The panel stays open while a finger is down on it, and for the timeout
  // after the last touch.
  void _pointerDown(PointerDownEvent _) {
    _pointersDown++;
    _hideTimer?.cancel();
  }

  void _pointerUp(PointerEvent _) {
    if (_pointersDown > 0) _pointersDown--;
    if (_pointersDown == 0 && _panelOpen) _scheduleHide();
  }

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

          return Stack(fit: StackFit.expand, children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePanel,
              child: ColoredBox(
                color: s.backgroundColor.toColor(),
                child: SafeArea(
                  child: Center(
                    child: Transform.translate(
                      offset: burnInOffset(c.now),
                      child: ClockFace(
                        now: c.now,
                        use24h: use24h,
                        color: s.clockColor.toColor(),
                        showSeconds: s.showSeconds,
                        showDate: s.showDate,
                        alarm: alarm,
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
                  child: Listener(
                    onPointerDown: _pointerDown,
                    onPointerUp: _pointerUp,
                    onPointerCancel: _pointerUp,
                    child: Center(
                      child: SettingsPanel(
                        settings: s,
                        onChanged: c.update,
                        use24h: use24h,
                        brightness: c.sliderLevel,
                        onBrightness: c.setSliderLevel,
                        autoAvailable: c.capabilities.ambientLight,
                        alarmAvailable: c.capabilities.nextAlarm,
                      ),
                    ),
                  ),
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
      'backlight ${f(split.backlight)}  scrim ${f(split.scrim, 2)}  '
      'anchors ${f(c.settings.darkLevel, 2)}/${f(c.settings.brightLevel, 2)}',
      style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
    );
  }
}
