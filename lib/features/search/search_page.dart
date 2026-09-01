import 'package:flutter/material.dart';
import 'package:tavolink/core/network/url_policy.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/core/widgets/config_tabs.dart';
import 'package:tavolink/core/widgets/glass_card.dart';
import 'package:tavolink/core/widgets/status_pill.dart';
import 'package:tavolink/features/search/search_models.dart';
import 'package:tavolink/features/search/search_repository.dart';
import 'package:tavolink/features/search/search_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final repo = const SearchRepository();
  SearchBackend backend = SearchBackend.duckDuckGo;
  final apiKey = TextEditingController();
  final baseUrl = TextEditingController();
  bool enabled = true;
  bool autoSearch = true;
  bool loading = false;
  bool configured = false;
  List<SearchResultItem> testResults = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await repo.load();
    if (!mounted || config == null) return;
    setState(() {
      backend = config.backend;
      enabled = config.enabled;
      autoSearch = config.autoSearch;
      configured = true;
      baseUrl.text = config.baseUrl?.toString() ?? '';
    });
  }

  SearchConfig? _config() {
    final uri = baseUrl.text.trim().isEmpty
        ? null
        : Uri.tryParse(baseUrl.text.trim());
    if ((backend == SearchBackend.searxng || backend == SearchBackend.custom) &&
        (uri == null || !isAllowedEndpoint(uri))) {
      _toast('搜索地址无效；公网必须使用 HTTPS，HTTP 仅允许私有局域网');
      return null;
    }
    return SearchConfig(
      backend: backend,
      apiKey: apiKey.text.trim().isEmpty ? null : apiKey.text.trim(),
      baseUrl: uri,
      enabled: enabled,
      autoSearch: autoSearch,
    );
  }

  Future<void> _save() async {
    setState(() => loading = true);
    try {
      final config = _config();
      if (config == null) return;
      await repo.save(config);
      if (!mounted) return;
      setState(() => configured = true);
      _toast('搜索配置已保存');
    } catch (e) {
      _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      loading = true;
      testResults = const [];
    });
    try {
      final config = _config();
      if (config == null) return;
      await repo.save(config);
      final effective = await repo.load() ?? config;
      final service = createSearchService(effective);
      late final List<SearchResultItem> results;
      try {
        results = await service.search('Tavo MCP', limit: 3);
      } finally {
        service.close();
      }
      if (!mounted) return;
      setState(() {
        configured = true;
        testResults = results;
      });
      _toast('联网测试成功：${results.length} 条结果');
    } catch (e) {
      _toast('联网测试失败：$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    apiKey.dispose();
    baseUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsKey =
        backend == SearchBackend.tavily ||
        backend == SearchBackend.brave ||
        backend == SearchBackend.custom;
    final needsUrl =
        backend == SearchBackend.searxng || backend == SearchBackend.custom;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const ConfigTabs(searchSelected: true),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '搜索设置',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '狐火寻迹 · 独立联网搜索工具',
                    style: TextStyle(color: TavoPalette.muted),
                  ),
                ],
              ),
            ),
            StatusPill(
              label: configured && enabled ? '已启用' : '未启用',
              active: configured && enabled,
            ),
          ],
        ),
        const SizedBox(height: 18),
        GlassCard(
          highlight: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('搜索源', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              RadioGroup<SearchBackend>(
                groupValue: backend,
                onChanged: (value) =>
                    setState(() => backend = value ?? backend),
                child: Column(
                  children: [
                    for (final item in SearchBackend.values)
                      RadioListTile<SearchBackend>(
                        value: item,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(item.label),
                        subtitle: Text(
                          _caption(item),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              if (needsUrl) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: baseUrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: backend == SearchBackend.searxng
                        ? 'SearXNG 实例 URL'
                        : '自定义搜索 URL',
                  ),
                ),
              ],
              if (needsKey) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: apiKey,
                  obscureText: true,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: '留空则沿用已保存密钥',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: enabled,
                onChanged: (v) => setState(() => enabled = v),
                title: const Text('启用联网搜索'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: autoSearch,
                onChanged: (v) => setState(() => autoSearch = v),
                title: const Text('允许云昭自动搜索'),
                subtitle: const Text('需要最新信息时由 Agent 自动调用 web_search'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : _test,
                      icon: const Icon(Icons.wifi_tethering_rounded),
                      label: const Text('测试搜索'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: loading ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (testResults.isNotEmpty) ...[
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: TavoPalette.jade),
                    SizedBox(width: 8),
                    Text('测试结果', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                for (final item in testResults) ...[
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 20),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _caption(SearchBackend backend) => switch (backend) {
    SearchBackend.duckDuckGo => '无需 API Key · 开箱即用 · 可随时关闭',
    SearchBackend.tavily => 'Agent 友好 · 结构化结果',
    SearchBackend.brave => '独立搜索索引 · 隐私友好',
    SearchBackend.searxng => '开源聚合 · 支持自建实例',
    SearchBackend.custom => '兼容返回 results/items 的 GET 搜索接口',
  };
}
