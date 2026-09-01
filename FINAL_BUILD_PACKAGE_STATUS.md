# Final GitHub Build Package Status

- Package: TavoLink · 云昭 v1.1.0
- Purpose: GitHub upload → automatic APK + unsigned IPA build
- ChatGPT GitHub connector: **not required**
- Android runner: `ubuntu-latest`
- iOS runner: `macos-latest`
- Flutter: current `stable` channel at build time
- Version naming: read automatically from `pubspec.yaml`
- Native platform scaffolds: generated in an isolated temp project, then copied into the app
- Android output: release APK + SHA-256
- iOS output: genuinely compiled unsigned IPA + SHA-256
- Installable/signed iOS distribution: requires the user's Apple Developer signing material
