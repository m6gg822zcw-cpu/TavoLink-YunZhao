# TavoLink · 云昭：GitHub Actions 构建指南

仓库根目录已经包含完整 Flutter、Android、iOS 工程与锁文件。GitHub Actions 会在 Ubuntu/macOS runner 上完成 Android 与 iOS 编译。

## 1. 工程结构要求

根目录必须同时存在 `pubspec.yaml`、`pubspec.lock`、`lib/`、`android/`、`ios/`、`tool/` 与 `.github/workflows/`。不要重新提交旧 ZIP，也不要在 CI 中覆盖已审查的原生工程。

## 2. 一键构建 APK + IPA

进入仓库：

`Actions` → `Build TavoLink APK + IPA` → `Run workflow` → `Run workflow`

工作流会自动：

- 安装固定 Flutter 3.47.2；
- 使用已提交的 Android/iOS 原生工程；
- 通过 `pubspec.lock` 解析依赖；
- 执行 `flutter analyze`；
- 执行 `flutter test`；
- 执行 MCP/API/Search 与智能学习契约测试；
- Android 构建 Release APK；
- iOS 在 macOS + Xcode 上构建 Release `Runner.app` 并封装 unsigned IPA；
- 为两端产物生成 SHA-256 文件。

## 3. 下载构建产物

Action 两个 Job 都变绿后，在该次运行页面底部 `Artifacts` 下载：

- `TavoLink-YunZhao-Android-<版本>` → `TavoLink-YunZhao-<版本>.apk`
- `TavoLink-YunZhao-iOS-<版本>` → `TavoLink-YunZhao-<版本>-unsigned.ipa`，配置 Apple Secrets 时还包含 `-signed.ipa`

## 4. IPA 为什么是 unsigned

GitHub 的 macOS Runner 能编译 iOS，但 Apple 不允许在没有你的开发者证书和 Provisioning Profile 的情况下生成可直接安装/上架的签名包。因此默认产物是**真实编译出的 unsigned IPA**，不是伪造文件。

要安装到普通 iPhone / TestFlight / App Store，需要配置 Apple Developer 签名。不要把证书或 Provisioning Profile 提交到仓库；应设置以下 GitHub Actions Secrets：

- `IOS_CERTIFICATE_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_TEAM_ID`
- `IOS_BUNDLE_ID`
- `IOS_EXPORT_METHOD`（可选，默认 `app-store-connect`）

Android 正式签名可设置：`ANDROID_KEYSTORE_BASE64`、`ANDROID_STORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。未配置时 release APK 使用 debug key fallback，仅适合测试分发。

## 5. 如果 Actions 没出现

检查：

- `.github/workflows/release-mobile.yml` 是否真的在仓库中；
- 仓库 Actions 是否被组织策略禁用；
- 首次进入 Actions 时是否需要点击 `I understand my workflows, go ahead and enable them`。

## 6. 日常质量检查

每次 push 到 `main` 后：

- `TavoLink Quality Gate` 执行分析、测试、Android debug 与 iOS simulator 构建；
- `Build TavoLink APK + IPA` 生成 release APK 与 unsigned IPA，并保留 Artifact 90 天。

推送 `v*` Tag 还会创建 GitHub Release，提供长期下载位置。
