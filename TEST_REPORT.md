# TavoLink · 云昭 v1.0 测试报告

测试日期：2026-08-31

## 已在当前执行环境实际运行

### 1. 源码结构自检

命令：

```bash
python3 tool/source_selfcheck.py
```

结果：**PASS — 182/182**

覆盖：

- pubspec / assets；
- 云昭主题接入；
- 空按钮 / Demo 回调残留；
- MCP 2026 / 2025 / direct JSON-RPC 路径；
- MCP Tool Call；
- OpenAI tool_calls；
- Search Tool；
- secure storage；
- 明显硬编码 secret 扫描；
- 全部 Dart 文件分隔符完整性；
- 测试、CI、双端 bootstrap 文件存在性。

### 2. 离线 HTTP 协议契约测试

命令：

```bash
python3 tool/runtime_contract_test.py
```

结果：**PASS — 5/5**

实际启动本地 HTTP Mock Server 并完成：

1. MCP 2026 stateless `tools/list`；
2. MCP `tools/call`；
3. OpenAI-compatible `/v1/models`；
4. OpenAI `tool_calls` 返回格式；
5. SearXNG 搜索结果契约。

全程未使用互联网、真实 API Key 或真实 Tavo 数据。

### 3. 工具脚本检查

实际运行：

```bash
python3 -m py_compile tool/source_selfcheck.py tool/patch_platforms.py tool/runtime_contract_test.py
bash -n tool/bootstrap_platforms.sh
```

结果：**PASS**

GitHub Actions YAML 由 PyYAML 成功解析，检测到 `android` 与 `ios` 两个 job。

## 已编写、但当前容器无法执行的 Flutter 测试

仓库包含：

- `test/mcp_models_test.dart`
- `test/mcp_client_test.dart`
- `test/openai_client_test.dart`

设计用于运行：

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

**当前模型执行容器没有 Flutter/Dart SDK，因此不能诚实地把这些四项标记为已运行通过。** 为避免用静态检查冒充编译测试，已经加入 `.github/workflows/flutter.yml`；在带 Flutter 3.47.1 的 GitHub Actions 或开发机上会真正执行 Android 与 iOS 编译测试。

## 当前判定

- 功能实现完整性：PASS（v1 范围）
- 离线协议契约：PASS
- 源码生成完整性：PASS
- Flutter 编译级验证：PENDING（当前容器缺 Flutter SDK）
- Android 真机：PENDING
- iOS 真机：PENDING

因此本包可以作为 **v1.0 实际实现源码** 交付，但在发 APK / IPA 前仍必须让 Flutter CI 或真机环境完成最后三项。
