# Build artifacts status · 2026-08-31

## Current execution host

- Host: Linux x86_64
- Flutter SDK: unavailable
- Android SDK: unavailable
- Xcode / xcodebuild: unavailable
- Container external toolchain download: unavailable

## Result

- `TavoLink-YunZhao-v1.1.0.apk`: **NOT GENERATED** in this host.
- `TavoLink-YunZhao-v1.1.0-unsigned.ipa`: **NOT GENERATED** in this host.

No placeholder or fake APK/IPA has been created.

## Automated build path included

`.github/workflows/release-mobile.yml` builds the same source on the correct runners:

- Android: GitHub `ubuntu-latest` → release APK.
- iOS: GitHub `macos-15` → iOS release app → unsigned IPA package.

For a directly installable / distributable iOS IPA, configure Apple signing credentials and provisioning in a macOS build environment and use `flutter build ipa`.
