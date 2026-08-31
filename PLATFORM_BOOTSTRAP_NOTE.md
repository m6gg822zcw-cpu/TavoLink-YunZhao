# Android / iOS 原生壳说明

仓库已提交由 Flutter 3.47.2 生成并审查的完整 `android/`、`ios/` 原生工程。Android 包含联网权限、局域网 HTTP 调试策略和可选 release 签名；iOS 包含 Local Network、ATS 本地网络说明与 unsigned 构建路径。

正常开发不需要 bootstrap：

```bash
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
```

只有 `android/` 或 `ios/` 被意外删除时才运行：

```bash
bash tool/bootstrap_platforms.sh
```

脚本仅恢复缺失平台并重新应用 `tool/patch_platforms.py`，不会覆盖仍然存在的原生目录。
