# Build artifacts status · 2026-08-31

## Local verification

- Host: Linux x86_64
- Flutter SDK: 3.47.2 / Dart 3.13.2
- Android SDK: API 36 / Build Tools 36.0.0 / NDK 28.2.13676358
- Xcode / xcodebuild: unavailable
- `flutter analyze --fatal-infos`: PASS, no issues
- `flutter test`: PASS, 11 tests
- Python source / protocol / learning contracts: PASS

## Result

- Local Android release compilation reached Gradle, but this execution sandbox blocks JVM access to external Gradle/Maven repositories. The authoritative APK build runs on GitHub `ubuntu-latest`.
- iOS compilation requires macOS + Xcode. The authoritative unsigned IPA build runs on GitHub `macos-latest`.

No placeholder or fake APK/IPA has been created.

## Automated build path included

`.github/workflows/release-mobile.yml` builds the same source on the correct runners:

- Android: GitHub `ubuntu-latest` → release APK.
- iOS: GitHub `macos-latest` → iOS release app → unsigned IPA package; optional signed IPA when Apple Secrets are present.

For a directly installable / distributable iOS IPA, configure Apple signing credentials and provisioning in a macOS build environment and use `flutter build ipa`.
