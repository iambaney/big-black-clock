import 'package:flutter/widgets.dart';

import 'app.dart';
import 'clock_controller.dart';
import 'platform/clock_platform.dart';
import 'settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SettingsStore.open();
  final controller = ClockController(
    platform: ChannelClockPlatform(),
    settings: store.load(),
    store: store,
  );
  runApp(ClockApp(controller: controller));
}
