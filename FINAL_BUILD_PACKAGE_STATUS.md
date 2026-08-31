# Final GitHub Build Package Status

- Package: TavoLink · 云昭 v1.1.0
- Purpose: GitHub upload → automatic APK + unsigned IPA build
- Android runner: `ubuntu-latest`
- iOS runner: `macos-latest`
- Flutter: fixed `3.47.2`
- Version naming: read automatically from `pubspec.yaml`
- Native platform scaffolds: committed and verified in the repository
- Android output: release APK + SHA-256 + signing-mode record; optional upload-key signing via Secrets
- iOS output: genuinely compiled unsigned IPA + SHA-256; optional signed IPA via Secrets
- Tagged builds: APK/IPA are also attached to a GitHub Release
