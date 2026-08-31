import 'package:flutter/material.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/core/widgets/glass_card.dart';
import 'package:tavolink/core/widgets/yunzhao_avatar.dart';
import 'package:tavolink/features/learning/learning_models.dart';
import 'package:tavolink/features/learning/learning_repository.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  final repository = const LearningRepository();
  LearningConfig config = const LearningConfig();
  List<MemoryEntry> memories = const [];
  Map<String, ToolExperience> tools = const {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final values = await Future.wait<Object>([
      repository.loadConfig(),
      repository.loadMemories(),
      repository.loadToolExperience(),
    ]);
    if (!mounted) return;
    setState(() {
      config = values[0] as LearningConfig;
      memories = values[1] as List<MemoryEntry>;
      tools = values[2] as Map<String, ToolExperience>;
      loading = false;
    });
  }

  Future<void> _save(LearningConfig next) async {
    await repository.saveConfig(next);
    if (!mounted) return;
    setState(() => config = next);
  }

  Future<void> _clearAll() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空云昭学习记忆？'),
        content: const Text('这会删除长期记忆与工具经验，但不会删除普通聊天记录、API 或 MCP 配置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await repository.clearMemories();
    await repository.clearToolExperience();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <MemoryKind, int>{
      for (final kind in MemoryKind.values)
        kind: memories.where((e) => e.kind == kind).length,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Row(
          children: [
            const YunZhaoAvatar(size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '云昭 · 智能学习',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    loading
                        ? '正在读取记忆…'
                        : '${memories.length} 条长期记忆 · ${tools.length} 个工具经验',
                    style: const TextStyle(color: TavoPalette.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          highlight: true,
          child: Column(
            children: [
              _LearningSwitch(
                icon: Icons.psychology_alt_rounded,
                title: '智能学习总开关',
                subtitle: '关闭后不再读取或新增长期记忆；已有记忆仍保留',
                value: config.enabled,
                onChanged: (v) => _save(config.copyWith(enabled: v)),
              ),
              const Divider(height: 28),
              _LearningSwitch(
                icon: Icons.auto_awesome_rounded,
                title: 'AI 记忆提取',
                subtitle: '从对话中抽取长期偏好、项目上下文与交互风格',
                value: config.aiExtraction,
                onChanged: config.enabled
                    ? (v) => _save(config.copyWith(aiExtraction: v))
                    : null,
              ),
              const Divider(height: 28),
              _LearningSwitch(
                icon: Icons.manage_search_rounded,
                title: '回答前检索记忆',
                subtitle: '仅把与当前请求相关的少量记忆注入云昭上下文',
                value: config.injectRelevantMemories,
                onChanged: config.enabled
                    ? (v) => _save(config.copyWith(injectRelevantMemories: v))
                    : null,
              ),
              const Divider(height: 28),
              _LearningSwitch(
                icon: Icons.hub_rounded,
                title: '学习 MCP / 搜索经验',
                subtitle: '记录工具成功率、耗时和失败教训，失败不会被当作成功经验',
                value: config.learnToolExperience,
                onChanged: config.enabled
                    ? (v) => _save(config.copyWith(learnToolExperience: v))
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_tree_rounded, color: TavoPalette.cyan),
                  SizedBox(width: 8),
                  Text('分层记忆', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in MemoryKind.values)
                    _CountChip(label: kind.label, value: grouped[kind] ?? 0),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '设计参考 Letta/MemGPT 的持久分层记忆与 LangMem 的提取/合并思想；移动端实现为本地、可解释、可删除的轻量学习层。',
                style: TextStyle(
                  color: TavoPalette.muted,
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('最近记忆', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: memories.isEmpty ? null : _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('全部清空'),
            ),
          ],
        ),
        if (!loading && memories.isEmpty)
          const GlassCard(
            child: Text(
              '还没有形成长期记忆。继续与云昭对话后，值得长期保留的信息会出现在这里。',
              style: TextStyle(color: TavoPalette.muted, height: 1.5),
            ),
          )
        else
          for (final entry in [
            ...memories,
          ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))) ...[
            _MemoryCard(
              entry: entry,
              onPinned: (value) async {
                await repository.setPinned(entry.id, value);
                await _reload();
              },
              onDelete: () async {
                await repository.deleteMemory(entry.id);
                await _reload();
              },
            ),
            const SizedBox(height: 9),
          ],
        if (tools.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('工具经验', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 9),
          for (final item
              in tools.values.toList()
                ..sort((a, b) => b.totalCalls.compareTo(a.totalCalls))) ...[
            GlassCard(
              padding: const EdgeInsets.all(13),
              radius: 18,
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: TavoPalette.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.toolName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '调用 ${item.totalCalls} · 成功率 ${(item.successRate * 100).round()}% · 平均 ${item.averageElapsedMs ?? 0}ms',
                          style: const TextStyle(
                            color: TavoPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _LearningSwitch extends StatelessWidget {
  const _LearningSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: TavoPalette.violet.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: TavoPalette.cyan, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: TavoPalette.cyan.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: TavoPalette.line),
    ),
    child: Text(
      '$label  $value',
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.entry,
    required this.onPinned,
    required this.onDelete,
  });
  final MemoryEntry entry;
  final ValueChanged<bool> onPinned;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(13),
    radius: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TavoPalette.violet.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                entry.kind.label,
                style: const TextStyle(
                  color: TavoPalette.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '置信 ${(entry.confidence * 100).round()}% · 强度 ${entry.strength}',
              style: const TextStyle(color: TavoPalette.muted, fontSize: 10),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => onPinned(!entry.pinned),
              tooltip: entry.pinned ? '取消固定' : '固定',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                entry.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                size: 18,
                color: entry.pinned ? TavoPalette.gold : TavoPalette.muted,
              ),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: '删除',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: TavoPalette.muted,
              ),
            ),
          ],
        ),
        Text(entry.content, style: const TextStyle(height: 1.5)),
        if (entry.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            entry.tags.take(6).map((e) => '#$e').join('  '),
            style: const TextStyle(color: TavoPalette.muted, fontSize: 10),
          ),
        ],
      ],
    ),
  );
}
