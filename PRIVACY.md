# Big Black Clock privacy policy

Effective 15 November 2026.

Big Black Clock does not collect, share or sell any personal data.

- **No internet access.** The app does not request Android's internet permission, so it cannot send anything off your phone.
- **No accounts, ads, analytics or crash reporting.**
- **Settings stay on your phone.** Your colors, brightness and display choices are saved in the app's own storage. If you use Android's device backup, your backup may include them; Google stores that backup under your account, and the developer has no access to it.

## What the app reads, and why

Everything below stays on your phone and is used only to draw the clock. None of it is saved or sent anywhere.

- **The light sensor**, to set the screen brightness.
- **The battery level and whether a charger is connected**, to draw the battery.
- **Your next alarm**, to show it under the time. By default the app uses the next-alarm information Android gives every app. If you choose to grant two optional permissions over USB (`DUMP` and `PACKAGE_USAGE_STATS`, described in the [README](README.md)), it reads the system's list of scheduled alarms instead. That list also names the apps that set each alarm; the app uses only the alarm times and whether each alarm opens an alarm screen. Android requires `PACKAGE_USAGE_STATS` for reading that list; the app does not read your app usage history.

## Changes

If this policy changes, the new version will be posted here with a new effective date.

## Contact

Questions about this policy: open an issue at <https://github.com/iambaney/big-black-clock/issues>.
