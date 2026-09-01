import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tavolink/core/network/url_policy.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/core/widgets/glass_card.dart';
import 'package:tavolink/core/widgets/status_pill.dart';
import 'package:tavolink/features/mcp/mcp_controller.dart';
import 'package:tavolink/features/mcp/mcp_credentials.dart';
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
  bool _saving = false;
  bool _loadingConfig = true;
  bool _tokenSaved = false;
  String? _savedUrl;
  String _savedHeaders = '{}';
  bool _endpointEdited = false;

  void _onUrlChanged(String value) {
    if (_endpointEdited && _savedUrl != null && value.trim() == _savedUrl) {
      headers.text = _savedHeaders;
      _endpointEdited = false;
      setState(() {});
      return;
    }
    if (!_endpointEdited && _savedUrl != null && value.trim() != _savedUrl) {
      // Do not carry credentials shown in the previous endpoint's form.
      token.clear();
      headers.text = '{}';
      _endpointEdited = true;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final config = await ref
            .read(mcpControllerProvider.notifier)
            .loadConfig();
        if (!mounted || config == null) return;
        name.text = config.name;
        url.text = config.url.toString();
        headers.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(config.headers);
        _savedHeaders = headers.text;
        setState(() {
          transport = config.transport;
          _savedUrl = config.url.toString();
          _tokenSaved =
              config.bearerToken?.isNotEmpty == true ||
              config.headers.keys.any(
                (key) => key.toLowerCase() == 'authorization',
              );
        });
      } catch (_) {
        if (mounted) _toast('无法读取安全配置，请检查设备安全存储后重试');
      } finally {
        if (mounted) setState(() => _loadingConfig = false);
      }
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

  Future<void> _save({bool testConnection = false}) async {
    if (_saving || _loadingConfig) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final uri = Uri.tryParse(url.text.trim());
    if (uri == null ||
        !isAllowedEndpoint(uri) ||
        hasSensitiveQueryParameter(uri) ||
        uri.fragment.isNotEmpty) {
      _toast('MCP 地址无效；公网必须 HTTPS，Token 请填写在独立安全字段');
      return;
    }
    Map<String, String> extra = {};
    try {
      final raw = jsonDecode(headers.text.trim().isEmpty ? '{}' : headers.text);
      if (raw is! Map) throw const FormatException();
      extra = McpCredentials.normalizeHeaders(raw);
    } on FormatException catch (error) {
      _toast('Headers 无效：${error.message}');
      return;
    }
    setState(() => _saving = true);
    try {
      final controller = ref.read(mcpControllerProvider.notifier);
      final config = McpServerConfig(
        name: name.text.trim().isEmpty ? 'Tavo MCP' : name.text.trim(),
        url: uri,
        transport: transport,
        bearerToken: token.text.trim().isEmpty ? null : token.text.trim(),
        headers: extra,
      );
      if (testConnection) {
        await controller.saveAndTest(config);
      } else {
        await controller.saveConfig(config);
      }
      final saved = await controller.loadConfig();
      if (!mounted) return;
      if (saved == null || saved.url != uri) {
        _toast('未确认保存成功，请检查配置后重试');
        return;
      }
      token.clear();
      setState(() {
        _savedUrl = saved.url.toString();
        _savedHeaders = const JsonEncoder.withIndent(
          '  ',
        ).convert(saved.headers);
        _endpointEdited = false;
        _tokenSaved =
            saved.bearerToken?.isNotEmpty == true ||
            saved.headers.keys.any(
              (key) => key.toLowerCase() == 'authorization',
            );
      });
      _toast(_tokenSaved ? '配置和 Token 已安全保存，下次自动使用' : '服务器配置已保存（未设置 Token）');
    } catch (_) {
      _toast('保存失败，请检查地址、Token 格式及设备安全存储');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearToken() async {
    final uri = Uri.tryParse(url.text.trim());
    if (uri == null ||
        !isAllowedEndpoint(uri) ||
        hasSensitiveQueryParameter(uri) ||
        uri.fragment.isNotEmpty ||
        _saving) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除已保存 Token？'),
        content: const Text(
          '将清除当前服务器的 Token 和自定义 Authorization Header。'
          '其他服务器凭据不会受影响；重新连接时可能需要再次输入。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(mcpControllerProvider.notifier).clearToken(uri);
      if (!mounted) return;
      token.clear();
      final currentHeaders = jsonDecode(
        headers.text.trim().isEmpty ? '{}' : headers.text,
      );
      if (currentHeaders is Map) {
        currentHeaders.removeWhere(
          (key, _) => key.toString().toLowerCase() == 'authorization',
        );
        headers.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(currentHeaders);
      }
      setState(() => _tokenSaved = false);
      _toast('当前服务器 Token 已清除');
    } catch (_) {
      _toast('清除未完全完成，请重新打开配置页检查');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mcpControllerProvider);
    final busy = state.isLoading || _saving || _loadingConfig;
    final tokenSavedHere = _tokenSaved && _savedUrl == url.text.trim();
    final online = switch (state) {
      AsyncData(:final value) => value != null,
      _ => false,
    };
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  context.go('/mcp/develop');
                },
          icon: const Icon(Icons.developer_mode_rounded),
          label: const Text('进入 MCP 开发工作台'),
        ),
        const SizedBox(height: 12),
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
                enabled: !busy,
                decoration: const InputDecoration(labelText: '服务器名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: url,
                enabled: !busy,
                onChanged: _onUrlChanged,
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
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: InputDecoration(
                  labelText: 'Bearer Token',
                  hintText: tokenSavedHere
                      ? '已保存；留空沿用，输入新值替换'
                      : '可粘贴 Token 或 Bearer Token',
                  helperText: '仅保存在本机安全存储，不会写入仓库',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tokenSavedHere
                          ? 'Token 已保存 · 重启后自动读取'
                          : '当前地址未确认保存 Token',
                      style: TextStyle(
                        color: tokenSavedHere
                            ? TavoPalette.jade
                            : TavoPalette.muted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : _clearToken,
                    child: const Text('清除 Token'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<McpTransport>(
                key: ValueKey(transport),
                initialValue: transport,
                decoration: const InputDecoration(labelText: '连接模式'),
                items: McpTransport.values
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) => setState(() => transport = value ?? transport),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: headers,
                enabled: !busy,
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
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => _save(),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('仅保存配置和 Token'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : () => _save(testConnection: true),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt_rounded),
                  label: Text(busy ? '处理中…' : '保存并测试连接'),
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
