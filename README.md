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

## Test

```sh
flutter test
```
