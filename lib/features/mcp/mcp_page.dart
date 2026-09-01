import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tavolink/core/network/url_policy.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/core/widgets/glass_card.dart';
import 'package:tavolink/core/widgets/status_pill.dart';
import 'package:tavolink/features/mcp/mcp_controller.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';

class McpPage extends ConsumerStatefulWidget {
  const McpPage({super.key});

  @override
  ConsumerState<McpPage> createState() => _McpPageState();
}

class _McpPageState extends ConsumerState<McpPage> {
  final name = TextEditingController(text: 'Tavo MCP');
  final url = TextEditingController(text: 'http://127.0.0.1:5177/mcp');
  final token = TextEditingController();
  final headers = TextEditingController(text: '{}');
  McpTransport transport = McpTransport.auto;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final config = await ref
          .read(mcpControllerProvider.notifier)
          .loadConfig();
      if (!mounted || config == null) return;
      name.text = config.name;
      url.text = config.url.toString();
      headers.text = const JsonEncoder.withIndent('  ').convert(config.headers);
      setState(() => transport = config.transport);
    });
  }

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    token.dispose();
    headers.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final uri = Uri.tryParse(url.text.trim());
    if (uri == null || !isAllowedEndpoint(uri)) {
      _toast('MCP 地址无效；公网必须使用 HTTPS，HTTP 仅允许 localhost / 私有局域网地址');
      return;
    }
    Map<String, String> extra = {};
    try {
      final raw = jsonDecode(headers.text.trim().isEmpty ? '{}' : headers.text);
      if (raw is! Map) throw const FormatException();
      extra = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      _toast('Headers 必须是 JSON 对象');
      return;
    }
    await ref
        .read(mcpControllerProvider.notifier)
        .saveAndTest(
          McpServerConfig(
            name: name.text.trim().isEmpty ? 'Tavo MCP' : name.text.trim(),
            url: uri,
            transport: transport,
            bearerToken: token.text.trim().isEmpty ? null : token.text.trim(),
            headers: extra,
          ),
        );
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mcpControllerProvider);
    final online = switch (state) {
      AsyncData(:final value) => value != null,
      _ => false,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MCP 配置',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '连接 Tavo，让云昭获得真实工具能力',
                    style: TextStyle(color: TavoPalette.muted),
                  ),
                ],
              ),
            ),
            StatusPill(label: online ? '已连接' : '未连接', active: online),
          ],
        ),
        const SizedBox(height: 18),
        GlassCard(
          highlight: true,
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TavoPalette.blue.withValues(alpha: .32),
                      TavoPalette.violet.withValues(alpha: .24),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TavoPalette.line),
                ),
                child: const Icon(Icons.hub_rounded, color: TavoPalette.cyan),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MCP 连接状态',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      online ? '灵桥已建立，云昭可以调用工具' : '等待连接 Tavo MCP 服务器',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                online
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: online ? TavoPalette.jade : TavoPalette.muted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          highlight: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_rounded, color: TavoPalette.cyan),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tavo MCP 服务器',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '服务器名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: 'http://设备地址:5177/mcp',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: token,
                obscureText: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Bearer Token',
                  hintText: '留空则沿用已保存 Token',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<McpTransport>(
                initialValue: transport,
                decoration: const InputDecoration(labelText: '连接模式'),
                items: McpTransport.values
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => transport = value ?? transport),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: headers,
                minLines: 2,
                maxLines: 5,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '自定义 Headers（JSON）',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.isLoading ? null : _test,
                  icon: state.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt_rounded),
                  label: Text(state.isLoading ? '云昭正在探测灵桥…' : '保存并测试连接'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        state.when(
          data: (snapshot) => snapshot == null
              ? const _CompatibilityCard()
              : _SnapshotCard(snapshot: snapshot),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => GlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: TavoPalette.danger,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '连接失败',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TavoPalette.danger,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        error.toString(),
                        style: const TextStyle(color: TavoPalette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompatibilityCard extends StatelessWidget {
  const _CompatibilityCard();
  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, color: TavoPalette.violet),
              SizedBox(width: 8),
              Text('自动兼容策略', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '自动模式依次探测 MCP 2026-07-28、Tavo 常见 HTTP JSON-RPC、MCP 2025-11-25 会话模式。',
            style: TextStyle(color: TavoPalette.muted),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot});
  final McpServerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: TavoPalette.jade),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  snapshot.serverName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const StatusPill(label: '测试通过'),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('协议', snapshot.protocolVersion),
              _chip('工具', '${snapshot.toolCount}'),
              _chip('资源', '${snapshot.resourceCount}'),
              _chip('Prompts', '${snapshot.promptCount}'),
              _chip('延迟', '${snapshot.latencyMs} ms'),
            ],
          ),
          if (snapshot.tools.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('已发现工具', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final tool in snapshot.tools.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: TavoPalette.cyan,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tool.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (snapshot.tools.length > 8)
              Text(
                '还有 ${snapshot.tools.length - 8} 个工具',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String key, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TavoPalette.line),
    ),
    child: Text('$key  $value', style: const TextStyle(fontSize: 12)),
  );
}
