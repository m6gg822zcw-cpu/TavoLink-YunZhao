import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tavolink/core/network/url_policy.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/core/widgets/glass_card.dart';
import 'package:tavolink/core/widgets/status_pill.dart';
import 'package:tavolink/features/providers/api_provider_repository.dart';
import 'package:tavolink/features/providers/openai_compatible_client.dart';
import 'package:tavolink/features/providers/provider_models.dart';

class ProvidersPage extends StatefulWidget {
  const ProvidersPage({super.key});

  @override
  State<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<ProvidersPage> {
  final repo = const ApiProviderRepository();
  final name = TextEditingController(text: 'OpenAI Compatible');
  final baseUrl = TextEditingController(text: 'https://api.openai.com/v1/');
  final key = TextEditingController();
  final model = TextEditingController();
  final headers = TextEditingController(text: '{}');
  bool loading = false;
  bool configured = false;
  String? status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await repo.load();
    if (!mounted || config == null) return;
    name.text = config.name;
    baseUrl.text = config.baseUrl.toString();
    model.text = config.model;
    headers.text = const JsonEncoder.withIndent('  ').convert(config.extraHeaders);
    setState(() => configured = true);
  }

  ApiProviderConfig? _readConfig({bool requireModel = true}) {
    final uri = Uri.tryParse(baseUrl.text.trim());
    if (uri == null || !isAllowedEndpoint(uri)) {
      _toast('Base URL 无效；公网 API 必须使用 HTTPS');
      return null;
    }
    if (requireModel && model.text.trim().isEmpty) {
      _toast('请输入模型名称');
      return null;
    }
    Map<String, String> extra = {};
    try {
      final decoded = jsonDecode(headers.text.trim().isEmpty ? '{}' : headers.text);
      if (decoded is! Map) throw const FormatException();
      extra = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      _toast('自定义 Headers 必须是 JSON 对象');
      return null;
    }
    return ApiProviderConfig(
      name: name.text.trim().isEmpty ? 'OpenAI Compatible' : name.text.trim(),
      baseUrl: uri,
      model: requireModel ? model.text.trim() : (model.text.trim().isEmpty ? 'placeholder' : model.text.trim()),
      apiKey: key.text.trim().isEmpty ? null : key.text.trim(),
      extraHeaders: extra,
    );
  }

  Future<void> _save() async {
    final config = _readConfig();
    if (config == null) return;
    setState(() => loading = true);
    try {
      await repo.save(config);
      if (!mounted) return;
      setState(() {
        configured = true;
        status = '已安全保存';
      });
    } catch (e) {
      _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _models() async {
    final config = _readConfig(requireModel: false);
    if (config == null) return;
    setState(() => loading = true);
    try {
      final existing = await repo.load();
      final effective = config.copyWith(apiKey: config.apiKey ?? existing?.apiKey);
      final models = await OpenAiCompatibleClient(effective).listModels();
      if (!mounted) return;
      if (models.isEmpty) {
        _toast('连接成功，但没有返回模型');
      } else {
        model.text = models.first;
        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: TavoPalette.panel,
          showDragHandle: true,
          builder: (_) => SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: models.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(models[index]),
                trailing: model.text == models[index] ? const Icon(Icons.check_rounded, color: TavoPalette.jade) : null,
                onTap: () {
                  model.text = models[index];
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        );
      }
    } catch (e) {
      _toast('获取模型失败：$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    name.dispose();
    baseUrl.dispose();
    key.dispose();
    model.dispose();
    headers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('API 灵契', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('云昭的模型能力由你独立配置', style: TextStyle(color: TavoPalette.muted)),
          ])),
          StatusPill(label: configured ? '已配置' : '未配置', active: configured),
        ]),
        const SizedBox(height: 18),
        GlassCard(
          highlight: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.auto_awesome_rounded, color: TavoPalette.gold), SizedBox(width: 10), Text('OpenAI Compatible', style: TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 18),
            TextField(controller: name, decoration: const InputDecoration(labelText: '配置名称')),
            const SizedBox(height: 12),
            TextField(controller: baseUrl, keyboardType: TextInputType.url, autocorrect: false, decoration: const InputDecoration(labelText: 'API Base URL', hintText: 'https://api.example.com/v1/')),
            const SizedBox(height: 12),
            TextField(controller: key, obscureText: true, autocorrect: false, decoration: const InputDecoration(labelText: 'API Key', hintText: '留空则沿用已保存密钥')),
            const SizedBox(height: 12),
            TextField(controller: model, autocorrect: false, decoration: const InputDecoration(labelText: '模型')),
            const SizedBox(height: 12),
            TextField(controller: headers, minLines: 2, maxLines: 5, autocorrect: false, decoration: const InputDecoration(labelText: '额外 Headers（JSON）')),
            if (status != null) ...[const SizedBox(height: 10), Text(status!, style: const TextStyle(color: TavoPalette.jade, fontSize: 12))],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: loading ? null : _models, icon: const Icon(Icons.cloud_sync_rounded), label: const Text('获取模型'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(onPressed: loading ? null : _save, icon: const Icon(Icons.lock_rounded), label: Text(loading ? '处理中…' : '保存配置'))),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        const GlassCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.shield_moon_rounded, color: TavoPalette.cyan),
          SizedBox(width: 12),
          Expanded(child: Text('API Key 写入 iOS Keychain / Android Keystore 对应的安全存储；普通配置只保存 URL、模型和非敏感 Header。', style: TextStyle(color: TavoPalette.muted))),
        ])),
      ],
    );
  }
}
