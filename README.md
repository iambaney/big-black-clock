<img width="1920" height="1080" alt="1" src="https://github.com/user-attachments/assets/93f089f2-84ef-4e55-80e6-1d96c31e2319" />

# Big Black Clock

A huge, quiet desk and nightstand clock for Android. Seven-segment digits in your own colors, brightness that follows the room, and the date, next alarm and battery under the time. One small settings panel; no ads, no accounts and no internet access.

Built with Flutter and no packages beyond the SDK. Everything Android-specific (light sensor, window brightness, next alarm, battery, settings storage, opening the privacy policy) is one Kotlin file behind a platform channel. iOS is planned; until it has a native side, those features report themselves unavailable.

## Layout

- `lib/clock/`: the face (seven-segment painter, layout, time and alarm labels).
- `lib/brightness/`: the auto-brightness curve and the backlight/scrim split.
- `lib/settings/`: the settings, their encoding, and the settings panel.
- `lib/platform/`: the Dart side of the platform channel.
- `lib/clock_controller.dart`: the app's state; `lib/app.dart`: the one screen.
- `android/app/src/main/kotlin/zip/iambaney/bigblackclock/ClockBridge.kt`: the Android side.
- `test/`: unit tests. `tool/`: the icon, store graphic and screenshot generators.
- `fastlane/metadata/android/en-US/`: the Google Play listing. `PRIVACY.md`: the privacy policy.

## Develop on a phone

1. Enable Developer options on the phone, then connect it by USB, or pair it over Wi-Fi: turn on Wireless debugging, choose "Pair device with pairing code", and run `adb pair <ip>:<port> <code>`.
2. Check that `flutter devices` lists the phone.
3. Run `flutter run -d <device-id>`. Press `r` to hot-reload after editing Dart code, or `R` to hot-restart. Kotlin or manifest changes need a fresh `flutter run`.

## Install for everyday use

Debug builds are slower. For the nightstand, install a release build:

```sh
flutter build apk --release --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

With `android/key.properties` in place (see [Release on Google Play](#release-on-google-play)), release builds are signed with the upload key and debug builds with Android's debug key. Android will not install one over the other, so switching between them takes `adb uninstall zip.iambaney.bigblackclock` first, which erases the settings and the grants below. Avoid `--split-per-abi` too: it raises the version code to 2001, which blocks installing a debug build over it even with the same key.

## Accurate next alarm (optional, one time)

Android only tells apps about the earliest "alarm clock" on the phone, and some apps register background timers that way (on Samsung phones, Find My Mobile does it all day). Without help, the clock shows the next alarm only when the earliest entry is a real one, and nothing otherwise. To let it read the full alarm list instead, grant two permissions over USB once after installing, then close and reopen the app:

```sh
adb shell pm grant zip.iambaney.bigblackclock android.permission.DUMP
adb shell pm grant zip.iambaney.bigblackclock android.permission.PACKAGE_USAGE_STATS
```

Updates keep the grants; uninstalling removes them. Neither permission gives network access; the app has none.

## Release on Google Play

1. Raise the version in `pubspec.yaml`. It reads `name+build`, for example `1.0.0+1`. Google Play needs a higher build number for every upload, so raise both together: `1.0.1+2`, then `1.1.0+3`, and so on. Put the release notes in `fastlane/metadata/android/en-US/changelogs/<build>.txt`.
2. Run `flutter build appbundle --split-debug-info=build/symbols` and upload `build/app/outputs/bundle/release/app-release.aab`. Splitting out the debug symbols makes the app about 0.3 MB smaller; Dart stack traces then need `flutter symbolize` with that build's symbols.

Release builds are signed with the upload key named in `android/key.properties`, which git ignores:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Keep the keystore and its password backed up somewhere other than this machine. Without `key.properties`, release builds fall back to the debug key, which Play rejects.

## Icons, store graphics and screenshots

Every image is drawn from the face's own seven-segment geometry: the launcher icon, the iOS app icons, and the Play icon, feature graphics and screenshots. To regenerate them (needs Python 3 with Pillow):

```sh
flutter test tool/screenshots_test.dart   # only to redo the screenshots
python3 tool/graphics.py
```

The screenshots are rendered from the app's real widgets with a fixed time, alarm and battery. They use 24-hour time, because the test environment cannot draw the face's AM/PM in Roboto.

## Test

```sh
flutter test
```
