import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/core/widgets/glass_card.dart';
import 'package:tavolink/core/widgets/status_pill.dart';
import 'package:tavolink/features/mcp/mcp_client.dart';
import 'package:tavolink/features/mcp/mcp_debug_output.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';
import 'package:tavolink/features/mcp/mcp_repository.dart';

class McpDeveloperPage extends StatefulWidget {
  const McpDeveloperPage({
    this.repository = const McpConfigRepository(),
    this.clientFactory,
    super.key,
  });

  final McpConfigRepository repository;
  final McpClient Function(McpServerConfig)? clientFactory;

  @override
  State<McpDeveloperPage> createState() => _McpDeveloperPageState();
}

class _McpDeveloperPageState extends State<McpDeveloperPage> {
  final _arguments = TextEditingController(text: '{}');
  final _logs = <String>[];
  McpClient? _client;
  McpDebugOutput? _output;
  McpTool? _selected;
  List<McpTool> _tools = const [];
  bool _busy = false;
  String _connection = '尚未连接；使用 MCP 配置中已保存的地址和 Token';
  String? _error;
  String _result = '';
  int _generation = 0;

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  String _render(Object? value) => _output?.render(value) ?? '暂时无法显示调试数据';

  void _record(String message) {
    final time = TimeOfDay.now().format(context);
    _logs.insert(0, '$time · $message');
    if (_logs.length > 20) _logs.removeLast();
  }

  void _disconnect() {
    if (_busy) return;
    _dismissKeyboard();
    _client?.close();
    _client = null;
    _output = null;
    setState(() {
      _tools = const [];
      _selected = null;
      _connection = '已主动断开';
      _error = null;
      _record('已断开连接');
    });
  }

  void _fillArgumentsTemplate() {
    final tool = _selected;
    if (_busy || tool == null) return;
    final template = _schemaTemplate(tool.inputSchema);
    _arguments.text = const JsonEncoder.withIndent('  ').convert(template);
    setState(() {
      _error = null;
      _result = '';
    });
  }

  Object? _schemaTemplate(Object? schema, [int depth = 0]) {
    if (depth >= 4 || schema is! Map) return null;
    if (schema.containsKey('default')) return schema['default'];
    if (schema.containsKey('example')) return schema['example'];
    final values = schema['enum'];
    if (values is List && values.isNotEmpty) return values.first;
    final type = schema['type']?.toString();
    if (type == 'array') return <Object?>[];
    if (type == 'boolean') return false;
    if (type == 'integer' || type == 'number') return 0;
    if (type == 'string') return '';
    final properties = schema['properties'];
    if (type == 'object' || properties is Map) {
      if (properties is! Map) return <String, Object?>{};
      return <String, Object?>{
        for (final entry in properties.entries.take(30))
          entry.key.toString(): _schemaTemplate(entry.value, depth + 1),
      };
    }
    return <String, Object?>{};
  }

  Future<void> _connect() async {
    if (_busy) return;
    _dismissKeyboard();
    setState(() {
      _busy = true;
      _error = null;
      _result = '';
      _tools = const [];
      _selected = null;
      _generation++;
      _connection = '正在读取安全配置并连接…';
    });
    _client?.close();
    _client = null;
    _output = null;
    final watch = Stopwatch()..start();
    McpClient? pending;
    try {
      final config = await widget.repository.load();
      if (!mounted) return;
      if (config == null) {
        setState(() {
          _connection = '尚未配置服务器';
          _error = '请先在「MCP 配置」保存服务器地址和 Token。';
        });
        return;
      }
      _output = McpDebugOutput(config);
      final client = widget.clientFactory?.call(config) ?? McpClient(config);
      pending = client;
      _client = client;
      final connection = await client.connect();
      final tools = await client.listTools();
      final visibleTools = tools.take(200).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _tools = visibleTools;
        _selected = visibleTools.isEmpty ? null : visibleTools.first;
        _arguments.text = '{}';
        _connection = _output!.render(
          '${connection.serverName} · ${connection.protocolVersion} · '
          '${tools.length} 个工具${tools.length > visibleTools.length ? '（页面展示前 200 个）' : ''}',
        );
        _record('连接成功 · ${watch.elapsedMilliseconds} ms');
      });
    } catch (error) {
      pending?.close();
      _client = null;
      if (!mounted) return;
      setState(() {
        // Before credentials are available, do not print arbitrary storage errors.
        _error = _output == null
            ? '无法读取安全配置，请在 MCP 配置页重新保存。'
            : _output!.render('连接失败：$error');
        _connection = '未连接';
        _record('连接失败 · ${watch.elapsedMilliseconds} ms');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _callTool() async {
    final client = _client;
    final tool = _selected;
    final output = _output;
    if (_busy || client == null || tool == null || output == null) return;
    _dismissKeyboard();
    if (_arguments.text.length > 64 * 1024) {
      setState(() => _error = '参数超过 64 KiB，请缩小后再调用。');
      return;
    }
    Map<String, dynamic> arguments;
    try {
      final decoded = jsonDecode(_arguments.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      arguments = decoded;
      final required = tool.inputSchema['required'];
      if (required is List &&
          required.any((key) => !arguments.containsKey(key))) {
        setState(() => _error = '缺少必填参数，请对照 inputSchema 填写。');
        return;
      }
    } on FormatException {
      setState(() => _error = '参数必须是有效的 JSON 对象，不能是数组或纯文本。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认调用 MCP 工具'),
          content: SingleChildScrollView(
            child: Text(
              '工具：${output.render(tool.name)}\n\n参数：${output.render(arguments)}\n\n'
              '该调用会真实发送到服务器，可能修改或删除 Tavo 数据。'
              '请确认工具用途和参数；本页不会自动重试。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认执行'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final watch = Stopwatch()..start();
      try {
        final response = await client.callTool(tool.name, arguments);
        if (!mounted) return;
        setState(() {
          _result = output.render(response);
          final status = response['isError'] == true ? '工具返回错误' : '调用完成';
          if (response['isError'] == true) _error = '工具返回 isError，请查看结果。';
          _record(
            output.render(
              '$status · ${tool.name} · ${watch.elapsedMilliseconds} ms',
            ),
          );
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _result = '';
          _error = output.render('调用失败或响应中断：$error\n服务器可能已执行操作，请先确认结果再重试。');
          _record('调用异常 · ${watch.elapsedMilliseconds} ms');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _client?.close();
    _arguments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '返回 MCP 配置',
              onPressed: () {
                _dismissKeyboard();
                context.go('/mcp');
              },
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                'MCP 开发',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            StatusPill(label: _busy ? '处理中' : '调试工作台', active: _client != null),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          highlight: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '云昭 · MCP 工具开发与联调',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(_connection),
              const SizedBox(height: 8),
              const Text(
                '自动读取已保存 Token，不显示凭据。工具调用仅由你手动确认发起。',
                style: TextStyle(color: TavoPalette.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _connect,
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(_busy ? '处理中…' : '连接 / 刷新工具'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            _dismissKeyboard();
                            context.go('/mcp');
                          },
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('管理 Token'),
                  ),
                  if (_client != null)
                    TextButton.icon(
                      onPressed: _busy ? null : _disconnect,
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('断开'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: TavoPalette.danger)),
        ],
        if (_tools.isNotEmpty) ...[
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<McpTool>(
                  key: ValueKey(_generation),
                  initialValue: _selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '选择工具'),
                  items: _tools
                      .map(
                        (tool) => DropdownMenuItem(
                          value: tool,
                          child: Text(
                            _render(tool.name),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (tool) => setState(() {
                          _selected = tool;
                          _arguments.text = '{}';
                          _error = null;
                          _result = '';
                        }),
                ),
                const SizedBox(height: 10),
                Text(_render(_selected?.description ?? '服务器未提供工具说明')),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('参数说明 · inputSchema'),
                  children: [
                    SelectableText(_render(_selected?.inputSchema ?? const {})),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _arguments,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  minLines: 4,
                  maxLines: 10,
                  onTapOutside: (_) => _dismissKeyboard(),
                  decoration: const InputDecoration(labelText: '工具参数（JSON 对象）'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _callTool,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('调用工具'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _fillArgumentsTemplate,
                      icon: const Icon(Icons.data_object_rounded),
                      label: const Text('生成参数模板'),
                    ),
                    TextButton.icon(
                      onPressed: _dismissKeyboard,
                      icon: const Icon(Icons.keyboard_hide_rounded),
                      label: const Text('收起键盘'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (_result.isNotEmpty) ...[
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '调用结果 · 已隐藏已知凭据',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                SelectableText(_result),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('调试记录 · 仅保留本页最近 20 条')),
                  IconButton(
                    tooltip: '清空调试记录',
                    onPressed: () => setState(() {
                      _logs.clear();
                      _result = '';
                      _error = null;
                    }),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const Text(
                '记录与结果不写入文件、不上传、不加入长期记忆；退出页面即清除。',
                style: TextStyle(color: TavoPalette.muted),
              ),
              const SizedBox(height: 8),
              if (_logs.isEmpty) const Text('暂无调用'),
              for (final log in _logs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(log),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
