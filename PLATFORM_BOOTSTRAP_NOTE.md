# Android / iOS 原生壳说明

当前交付包包含完整 Flutter 业务层、UI、网络层、MCP/API/Search/Agent 实现与测试，但交付环境没有安装 Flutter SDK，因此没有伪造或保留不完整的 `android/`、`ios/` 原生工程目录。

在安装 Flutter 3.47.1 的开发机上运行：

```bash
bash tool/bootstrap_platforms.sh
```

脚本会：
1. 使用 `flutter create` 生成 Android 与 iOS 原生壳；
2. 自动补 Android 网络权限与局域网 HTTP 支持；
3. 自动补 iOS Local Network 与 ATS Local Networking 配置；
4. 执行 `flutter pub get`。

随后执行：

```bash
flutter analyze
flutter test
flutter run
```

GitHub Actions 已配置 Android 与 iOS 两个 job，可在有 Flutter/Xcode 的环境继续完成编译级验证。
