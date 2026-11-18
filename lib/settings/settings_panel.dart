import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../clock_controller.dart';
import 'controls.dart';

/// Published from PRIVACY.md at the repo root.
const privacyPolicyUrl = 'https://github.com/iambaney/big-black-clock/blob/main/PRIVACY.md';

/// The nine-item panel, plus a button that closes the app and a line with the
/// privacy policy and version. Every change is applied as it happens.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.controller, required this.use24h});

  final ClockController controller;

  /// The 24-hour setting in effect, which may come from the system.
  final bool use24h;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  /// Which color row is expanded: 0 clock, 1 background, null neither.
  int? _expanded;

  /// A finger is on the position slider; the panel fades so the face shows
  /// through as it moves.
  bool _positioning = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.settings;
    final colors = panelColors(s.clockColor, s.backgroundColor);
    final fg = colors.fg, bg = colors.bg;
    final set = c.update;

    Widget row(String label, Widget control, {VoidCallback? onTap}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Row(children: [Expanded(child: Text(label)), control]),
          ),
        );

    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) =>
        row(label, Toggle(value: value, fg: fg, bg: bg), onTap: () => onChanged(!value));

    Widget color(String label, int index, HSVColor value, ValueChanged<HSVColor> onChanged) {
      final open = _expanded == index;
      return Column(children: [
        row(
          label,
          Row(children: [
            Text(hex(value.toColor()), style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 13)),
            const SizedBox(width: 10),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: value.toColor(),
                border: Border.all(color: fg, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ]),
          onTap: () => setState(() => _expanded = open ? null : index),
        ),
        if (open) HsvEditor(color: value, onChanged: onChanged, ring: fg),
      ]);
    }

    // With auto on, the slider is a meter showing the level the light sensor
    // has chosen; with auto off, it sets the level.
    final brightness = SizedBox(
      height: 44,
      child: Row(children: [
        const Text('Brightness'),
        Expanded(
          child: TrackSlider(
            value: c.autoOn ? c.level : s.manualLevel,
            onChanged: c.autoOn ? null : c.setManualLevel,
            track: [fg.withValues(alpha: 0.2), fg],
            thumb: fg,
            ring: bg,
          ),
        ),
        if (c.autoAvailable)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => c.setAutoBrightness(!s.autoBrightness),
            child: Row(children: [
              const Text('Auto  '),
              Toggle(value: s.autoBrightness, fg: fg, bg: bg),
            ]),
          ),
      ]),
    );

    // Only portrait has room to move the face; landscape fills the screen.
    void positioning(bool on) => setState(() => _positioning = on);
    final position = Listener(
      onPointerDown: (_) => positioning(true),
      onPointerUp: (_) => positioning(false),
      onPointerCancel: (_) => positioning(false),
      child: SizedBox(
        height: 44,
        child: Row(children: [
          const Text('Vertical position'),
          Expanded(
            child: TrackSlider(
              value: s.portraitPosition,
              // A little pull toward the middle, so the face is easy to center.
              onChanged: (v) => set(s.copyWith(portraitPosition: (v - 0.5).abs() < 0.03 ? 0.5 : v)),
              track: [fg.withValues(alpha: 0.4), fg.withValues(alpha: 0.4)],
              thumb: fg,
              ring: bg,
            ),
          ),
        ]),
      ),
    );
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;

    final colorRows = [
      color('Clock color', 0, s.clockColor, (v) => set(s.copyWith(clockColor: v))),
      color('Background color', 1, s.backgroundColor, (v) => set(s.copyWith(backgroundColor: v))),
      brightness,
      if (portrait) position,
    ];
    final toggleRows = [
      toggle('24-hour time', widget.use24h, (v) => set(s.copyWith(use24h: v))),
      toggle('Show seconds', s.showSeconds, (v) => set(s.copyWith(showSeconds: v))),
      toggle('Show date', s.showDate, (v) => set(s.copyWith(showDate: v))),
      if (c.capabilities.nextAlarm) toggle('Show next alarm', s.showAlarm, (v) => set(s.copyWith(showAlarm: v))),
      if (c.capabilities.battery) toggle('Show battery', s.showBattery, (v) => set(s.copyWith(showBattery: v))),
    ];
    // Immersive mode hides the navigation bar, so leaving takes extra swipes
    // without this. iOS does not let apps close themselves.
    final close = defaultTargetPlatform == TargetPlatform.android
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => SystemNavigator.pop(),
            child: Container(
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: fg, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Close app'),
            ),
          )
        : null;
    // Google Play requires the privacy policy to be reachable from the app.
    final small = TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 13);
    final about = SizedBox(
      height: 40,
      child: Row(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => c.openUrl(privacyPolicyUrl),
          child: Center(
            child: Text(
              'Privacy policy',
              style: small.copyWith(decoration: TextDecoration.underline, decorationColor: small.color),
            ),
          ),
        ),
        const Spacer(),
        if (c.appVersion != null) Text('Version ${c.appVersion}', style: small),
      ]),
    );
    // On a wide, short screen, two columns keep the panel low enough that
    // the clock stays visible above it.
    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width >= 640 && screen.width > screen.height;
    final body = wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [...colorRows, ?close, about])),
            const SizedBox(width: 32),
            Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: toggleRows)),
          ])
        : Column(mainAxisSize: MainAxisSize.min, children: [...colorRows, ...toggleRows, ?close, about]);

    final panel = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 820 : 560, maxHeight: screen.height * 0.85),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: fg.withValues(alpha: 0.4))),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: DefaultTextStyle(
              style: TextStyle(color: fg, fontSize: 16, height: 1.2),
              child: body,
            ),
          ),
        ),
      ),
    );
    return AnimatedOpacity(
      opacity: _positioning ? 0.2 : 1,
      duration: const Duration(milliseconds: 150),
      child: panel,
    );
  }
}
