# big-black-clock

A huge, quiet, ad-free desk and nightstand clock for Android. Seven-segment digits in your own colors, brightness that follows the room, the next alarm on the face, and a seven-item settings panel. No ads, no accounts, and no permissions at all in release builds.

Built with Flutter. The Android-only features (light sensor, window brightness, next alarm) are a small amount of Kotlin in `android/app/src/main/kotlin/` behind a platform channel, with no third-party plugins.

## Develop on a phone

1. Enable Developer options on the phone, then connect it by USB, or pair it over Wi-Fi: turn on Wireless debugging, choose "Pair device with pairing code", and run `adb pair <ip>:<port> <code>`.
2. Check that `flutter devices` lists the phone.
3. Run `flutter run -d <device-id>`. Press `r` to hot-reload after editing Dart code, or `R` to hot-restart. Kotlin or manifest changes need a fresh `flutter run`.

## Install for everyday use

Debug builds are slower. For the nightstand, install a release build:

```sh
flutter build apk --release --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Accurate next alarm (optional, one time)

Android only tells apps about the earliest "alarm clock" on the phone, and some apps register background timers that way (on Samsung phones, Find My Mobile does it all day). Without help, the clock shows the next alarm only when the earliest entry is a real one, and nothing otherwise. To let it read the full alarm list instead, grant two permissions over USB once after installing:

```sh
adb shell pm grant zip.iambaney.bigblackclock android.permission.DUMP
adb shell appops set zip.iambaney.bigblackclock GET_USAGE_STATS allow
```

Updates keep the grant; uninstalling removes it. Neither permission gives network access; the app has none.

## Test

```sh
flutter test
```
