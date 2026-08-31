# TavoLink 云昭 v1.1 最终测试报告

- 日期：`2026-08-31`
- 主机：`Linux x86_64`
- Flutter：`3.47.2`
- Dart：`3.13.2`
- 版本：`1.1.0+2`

- **PASS** — Source self-check：233/233
- **PASS** — HTTP protocol contracts：5/5
- **PASS** — Learning contracts：10/10
- **PASS** — Dart formatting：40 files, 0 changes
- **PASS** — `flutter analyze --fatal-infos`：No issues found
- **PASS** — `flutter test`：11 tests passed
- **BLOCKED (host)** — Android release APK：已配置 API 36 / Build Tools 36.0.0 / NDK 28.2.13676358；当前沙箱阻止 JVM 访问外部 Gradle/Maven 源，交由 GitHub Ubuntu runner 完成。
- **BLOCKED (host)** — iOS release / IPA：当前主机没有 macOS + Xcode，交由 GitHub macOS runner 完成。

APK/IPA 只接受 GitHub Actions 的真实编译结果，不创建占位产物。
