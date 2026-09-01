# TavoLink · 云昭 v1.1

TavoLink 是面向 Android / iOS 的 Tavo-first MCP 移动客户端。内置二次元狐妖智能体 **云昭**，使用用户自己配置的 OpenAI-compatible API，并可在同一轮 Agent 对话中调用 Tavo MCP、独立联网搜索以及本地长期学习模块。

## v1.1 已实现

### 云昭智能体

- 狐妖主题：首页主视觉、头像、对话身份、狐火 / 星夜视觉系统。
- OpenAI-compatible API：Base URL、API Key、自定义 Header、模型配置、`/models` 与 `/chat/completions`。
- Agent Tool Calling：模型自动选择 MCP / Search 工具，执行结果回填后继续推理，最多 6 轮工具循环。

### Tavo MCP

- MCP `2026-07-28` stateless HTTP。
- Tavo direct HTTP JSON-RPC。
- MCP `2025-11-25` initialize/session 回退。
- `tools/list` / `tools/call` / `resources/list` / `prompts/list`。
- JSON 与 request-scoped SSE 返回解析。
- 工具名由服务器动态发现，不在 App 内硬编码。

### 联网搜索

- Tavily
- Brave Search
- SearXNG
- 自定义 GET Search API

### 云昭智能学习中枢

- 分层长期记忆：偏好、稳定事实、项目上下文、交互风格、工具经验。
- 回答前只检索相关记忆，不把整个记忆库塞入上下文。
- 相似记忆自动合并、置信度 / 强度 / 最近使用 / 固定状态参与排序。
- MCP / Search 工具成功率与耗时独立学习。
- Evidence Guard：AI 提取的长期记忆必须包含真实存在于用户原话中的逐字证据。
- Secret Guard：Key、Token、密码等不会进入长期记忆。
- Memory Poisoning Guard：工具返回不直接沉淀成用户事实；长期记忆永远不能覆盖系统规则、本轮用户指令或工具真实结果。
- 设置页可查看、固定、删除、清空、关闭学习。

设计来源和安全边界见 `LEARNING_ARCHITECTURE.md`。

## 安全存储与网络

- API Key / MCP Bearer Token：`flutter_secure_storage`（Android Keystore / iOS Keychain）。
- 普通设置、聊天历史、长期记忆：SharedPreferences。
- 公网 endpoint 必须 HTTPS；HTTP 仅允许 localhost、`.local`、RFC1918 私有网段。

## 首次运行

推荐 Flutter `3.47.1` 或同系列兼容稳定版：

```bash
bash tool/bootstrap_platforms.sh
flutter run
```

脚本会生成标准 Android / iOS platform scaffold，并自动补充 Android Internet / 局域网网络策略与 iOS Local Network / ATS 本地网络说明。

## 使用顺序

1. `API`：填 OpenAI-compatible Base URL、Key、模型。
2. `MCP`：填 Tavo MCP 地址与 Bearer Token，执行连接测试。
3. `搜索`：按需配置搜索 Provider。
4. `设置 → 云昭智能学习`：决定是否启用长期学习。
5. `对话`：MCP、联网、学习三个能力都可逐轮开关。

Tavo MCP 局域网示例：

```text
名称: Tavo MCP
URL:  http://192.168.1.10:5177/mcp
模式: 自动兼容
认证: Bearer Token（如服务器要求）
```

## 测试

```bash
python3 tool/source_selfcheck.py
python3 tool/runtime_contract_test.py
python3 tool/learning_contract_test.py
python3 tool/final_test.py
flutter analyze
flutter test
```

`runtime_contract_test.py` 会真实启动本地 Mock HTTP Server 测试 MCP / OpenAI-compatible / SearXNG 契约；`learning_contract_test.py` 验证长期记忆检索、证据守卫、密钥过滤、记忆合并以及“学习失败不能中断聊天”等约束。

当前执行环境的最终结果见 `test-results/FINAL_TEST_REPORT.md`。

## APK / IPA Release CI

仓库已包含 `.github/workflows/release-mobile.yml`：

- Ubuntu runner：`flutter analyze` + `flutter test` + 三套契约测试 + `flutter build apk --release`，上传 `TavoLink-YunZhao-v1.1.0.apk`。
- macOS runner：同样完成测试后执行 iOS Release no-codesign 构建，并打包 `TavoLink-YunZhao-v1.1.0-unsigned.ipa`。

> unsigned IPA 是构建产物，不等于可直接安装的正式发行包。安装到普通 iPhone / TestFlight / App Store 仍需要 Apple Development / Distribution Certificate、Provisioning Profile 与 Team 配置。

## 目录

```text
lib/
  core/
  features/
    agent/              云昭 Agent 编排
    chat/               对话页
    home/               首页
    learning/           长期记忆、检索、Evidence Guard、学习 UI
    mcp/                MCP client / repository / UI
    providers/          模型 API
    search/             联网搜索
    settings/           设置
assets/images/          云昭视觉资源
test/                   Flutter 单元测试
tool/                   bootstrap / 协议契约 / 学习契约 / 最终测试
.github/workflows/       Android / iOS CI 与 Release
```

## v1.1 边界

- 当前对话为非流式 Chat Completions；协议层可继续扩展 token SSE。
- 长期记忆 v1.1 使用轻量本地词项 + 中文 bigram 检索，避免引入大模型/embedding 包体；后续可切换本地 embedding + SQLite vector store。
- 高风险 MCP Tool 仍建议在后续版本加入更严格的执行前权限确认与风险分类。
