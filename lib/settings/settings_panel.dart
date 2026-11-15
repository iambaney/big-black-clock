import 'package:flutter/widgets.dart';

import 'controls.dart';
import 'settings.dart';

/// The seven-item panel. Every change is applied as it happens.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.use24h,
    required this.brightness,
    required this.onBrightness,
    required this.autoAvailable,
    required this.alarmAvailable,
  });

  final Settings settings;
  final ValueChanged<Settings> onChanged;

  /// The 24-hour setting in effect, which may come from the system.
  final bool use24h;
  final double brightness;
  final ValueChanged<double> onBrightness;
  final bool autoAvailable;
  final bool alarmAvailable;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  /// Which color row is expanded: 0 clock, 1 background, null neither.
  int? _expanded;

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final colors = panelColors(s.clockColor, s.backgroundColor);
    final fg = colors.fg, bg = colors.bg;
    final set = widget.onChanged;

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

    final brightness = SizedBox(
      height: 44,
      child: Row(children: [
        const Text('Brightness'),
        Expanded(
          child: TrackSlider(
            value: widget.brightness,
            onChanged: widget.onBrightness,
            track: [fg.withValues(alpha: 0.2), fg],
            thumb: fg,
            ring: bg,
          ),
        ),
        if (widget.autoAvailable)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => set(s.copyWith(autoBrightness: !s.autoBrightness)),
            child: Row(children: [
              const Text('Auto  '),
              Toggle(value: s.autoBrightness, fg: fg, bg: bg),
            ]),
          ),
      ]),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * 0.85),
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
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                color('Clock color', 0, s.clockColor, (c) => set(s.copyWith(clockColor: c))),
                color('Background color', 1, s.backgroundColor, (c) => set(s.copyWith(backgroundColor: c))),
                brightness,
                toggle('24-hour time', widget.use24h, (v) => set(s.copyWith(use24h: v))),
                toggle('Show seconds', s.showSeconds, (v) => set(s.copyWith(showSeconds: v))),
                toggle('Show date', s.showDate, (v) => set(s.copyWith(showDate: v))),
                if (widget.alarmAvailable) toggle('Show next alarm', s.showAlarm, (v) => set(s.copyWith(showAlarm: v))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
