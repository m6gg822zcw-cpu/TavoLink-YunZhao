# TavoLink 云昭 v1.1 最终测试报告

- Host: `Linux 6.18.35 x86_64`
- Version: `1.1.0+2`

- **PASS** — Source self-check
- **PASS** — HTTP protocol contracts
- **PASS** — Learning contracts
- **BLOCKED** — Flutter analyze / tests
  - Flutter SDK is not installed in this execution environment.
- **BLOCKED** — Android release APK build
  - Flutter SDK and Android SDK are not installed; external downloads are unavailable from the container.
- **BLOCKED** — iOS release / IPA build
  - IPA compilation requires macOS + Xcode. Current host is Linux and xcodebuild=False.
