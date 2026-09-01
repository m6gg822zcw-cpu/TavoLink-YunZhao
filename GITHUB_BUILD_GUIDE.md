# TavoLink · 云昭：无需 ChatGPT GitHub 连接器的构建方法

这个工程不依赖 ChatGPT 的 GitHub 连接器。只要把**解压后的工程文件**上传到一个 GitHub 仓库，GitHub Actions 就会在 GitHub 自己的 Ubuntu/macOS 机器上完成 Android 与 iOS 构建。

## 1. 上传仓库

1. 在 GitHub 新建一个空仓库，例如 `TavoLink-YunZhao`。
2. 下载并解压本构建包。
3. 把解压目录中的**全部内容**上传到仓库根目录。必须保留 `.github/workflows/` 目录。
4. 确认仓库根目录能看到 `pubspec.yaml`、`lib/`、`tool/`、`.github/`。

> 不要只把本 ZIP 当成一个文件上传到仓库。Actions 需要读取 ZIP 里面的工程文件。

## 2. 一键构建 APK + IPA

进入仓库：

`Actions` → `Build TavoLink APK + IPA` → `Run workflow` → `Run workflow`

工作流会自动：

- 安装当前 Flutter stable；
- 在隔离临时目录生成 Android/iOS 原生壳，不覆盖业务源码；
- 执行 `flutter analyze`；
- 执行 `flutter test`；
- 执行 MCP/API/Search 与智能学习契约测试；
- Android 构建 Release APK；
- iOS 在 macOS + Xcode 上构建 Release `Runner.app` 并封装 unsigned IPA；
- 为两端产物生成 SHA-256 文件。

## 3. 下载构建产物

Action 两个 Job 都变绿后，在该次运行页面底部 `Artifacts` 下载：

- `TavoLink-YunZhao-Android-<版本>` → `TavoLink-YunZhao-<版本>.apk`
- `TavoLink-YunZhao-iOS-<版本>-unsigned` → `TavoLink-YunZhao-<版本>-unsigned.ipa`

## 4. IPA 为什么是 unsigned

GitHub 的 macOS Runner 能编译 iOS，但 Apple 不允许在没有你的开发者证书和 Provisioning Profile 的情况下生成可直接安装/上架的签名包。因此默认产物是**真实编译出的 unsigned IPA**，不是伪造文件。

要安装到普通 iPhone / TestFlight / App Store，需要进一步配置你的 Apple Developer 签名。不要把 `.p12` 密码、证书或 Provisioning Profile 直接提交到仓库；应放入 GitHub Actions Secrets。

## 5. 如果 Actions 没出现

检查：

- `.github/workflows/release-mobile.yml` 是否真的在仓库中；
- 仓库 Actions 是否被组织策略禁用；
- 首次进入 Actions 时是否需要点击 `I understand my workflows, go ahead and enable them`。

## 6. 日常质量检查

每次 push 后，`TavoLink Quality Gate` 会自动执行 Android/iOS 的分析、测试和基础构建。正式 APK/IPA 工作流只在手动触发或推送 `v*` Tag 时运行。
