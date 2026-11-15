# big-black-clock

A huge, quiet, ad-free desk and nightstand clock for Android. Seven-segment digits in your own colors, brightness that follows the room, the next alarm and the battery on the face, and an eight-item settings panel. No ads, no accounts, and no internet access.

Built with Flutter. The Android-only features (light sensor, window brightness, next alarm, battery) are a small amount of Kotlin in `android/app/src/main/kotlin/` behind a platform channel, with no third-party plugins.

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
2. Run `flutter build appbundle` and upload `build/app/outputs/bundle/release/app-release.aab`.

Release builds are signed with the upload key named in `android/key.properties`, which git ignores:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Keep the keystore and its password backed up somewhere other than this machine. Without `key.properties`, release builds fall back to the debug key, which Play rejects.

The store listing (text, icon, feature graphic and screenshots) is in `fastlane/metadata/android/en-US/`, and the privacy policy is [PRIVACY.md](PRIVACY.md).

## Test

```sh
flutter test
```
