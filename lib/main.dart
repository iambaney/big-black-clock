import 'package:flutter/widgets.dart';

import 'app.dart';
import 'clock_controller.dart';
import 'platform/clock_platform.dart';
import 'settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = ChannelClockPlatform();
  final settings = Settings.decode(await platform.loadSettings());
  runApp(ClockApp(controller: ClockController(platform: platform, settings: settings)));
}
