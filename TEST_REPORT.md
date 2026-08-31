# TavoLink · 云昭 v1.1 测试报告

测试日期：2026-08-31

## 已在当前执行环境实际运行

### 1. 源码结构自检

命令：

```bash
python3 tool/source_selfcheck.py
```

结果：**PASS — 233/233**

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

### 4. Flutter 静态分析与单元测试

```bash
flutter analyze --fatal-infos
flutter test
```

结果：**PASS — No issues found / 11 tests passed**（Flutter 3.47.2、Dart 3.13.2）。

覆盖 MCP 模型与双协议回退、OpenAI tool calls、长期学习 Evidence/Secret Guard、中文相似度和 URL 安全策略。

### 5. 移动端构建

- Android release：本地已完成 SDK/NDK 配置并进入 Gradle；当前沙箱阻止 JVM 访问外部 Gradle/Maven 仓库，因此以 GitHub Ubuntu runner 的构建结果为准。
- iOS release：需要 macOS + Xcode，以 GitHub macOS runner 的 unsigned IPA 结果为准。

## 当前判定

- 功能实现完整性：PASS（v1 范围）
- 离线协议契约：PASS
- 源码生成完整性：PASS
- Flutter 分析与单元测试：PASS
- Android / iOS CI 编译：由两个 GitHub Actions 工作流作为最终门禁
- Android 真机：PENDING
- iOS 真机：PENDING

因此源码与运行时契约已通过本地验证；APK/IPA 仅在对应 Actions job 成功后交付，不生成占位文件。
