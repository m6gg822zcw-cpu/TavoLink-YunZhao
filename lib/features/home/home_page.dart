import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/core/widgets/glass_card.dart';
import 'package:tavolink/core/widgets/status_pill.dart';
import 'package:tavolink/core/widgets/yunzhao_avatar.dart';
import 'package:tavolink/features/mcp/mcp_controller.dart';
import 'package:tavolink/features/mcp/mcp_repository.dart';
import 'package:tavolink/features/providers/api_provider_repository.dart';
import 'package:tavolink/features/search/search_repository.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mcpState = ref.watch(mcpControllerProvider);
    final liveMcp = switch (mcpState) {
      AsyncData(:final value) => value,
      _ => null,
    };
    return FutureBuilder<List<Object?>>(
      future: Future.wait<Object?>([
        const McpConfigRepository().load(),
        const ApiProviderRepository().load(),
        const SearchRepository().load(),
      ]),
      builder: (context, snapshot) {
        final values = snapshot.data;
        final mcpConfigured = values != null && values[0] != null;
        final apiConfigured = values != null && values[1] != null;
        final searchConfigured = values != null && values[2] != null;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Row(
              children: [
                const YunZhaoAvatar(size: 44),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TavoLink',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Text(
                        '云昭 · 智能体',
                        style: TextStyle(
                          color: TavoPalette.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HeroCard(onChat: () => context.go('/chat')),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatusAction(
                    icon: Icons.hub_rounded,
                    title: 'MCP 状态',
                    value: liveMcp != null
                        ? '${liveMcp.toolCount} 个工具'
                        : (mcpConfigured ? '已配置' : '未配置'),
                    active: liveMcp != null,
                    button: liveMcp != null ? '查看灵桥' : '连接 Tavo',
                    onTap: () => context.go('/mcp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatusAction(
                    icon: Icons.auto_awesome_rounded,
                    title: 'API 状态',
                    value: apiConfigured ? '模型已就绪' : '尚未配置',
                    active: apiConfigured,
                    button: 'API 配置',
                    onTap: () => context.go('/providers'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlassCard(
              onTap: () => context.go('/search'),
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: TavoPalette.violet.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.travel_explore_rounded,
                      color: TavoPalette.cyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '联网搜索 · 狐火寻迹',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          searchConfigured
                              ? '搜索工具已配置，可由云昭自动调用'
                              : '配置 Tavily / Brave / SearXNG / 自定义接口',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: searchConfigured ? '已配置' : '设置',
                    active: searchConfigured,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('云昭能力', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(
                  child: _AbilityCard(
                    icon: Icons.forum_rounded,
                    title: '自然对话',
                    caption: '独立模型 API',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _AbilityCard(
                    icon: Icons.hub_rounded,
                    title: 'Tavo 工具',
                    caption: 'MCP Tool Calling',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(
                  child: _AbilityCard(
                    icon: Icons.public_rounded,
                    title: '实时联网',
                    caption: '独立 Search Tool',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _AbilityCard(
                    icon: Icons.lock_rounded,
                    title: '安全密钥',
                    caption: 'Keychain / Keystore',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onChat});
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: TavoPalette.violet.withValues(alpha: .42)),
        boxShadow: [
          BoxShadow(
            color: TavoPalette.violet.withValues(alpha: .20),
            blurRadius: 34,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/yunzhao_hero.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(.12, -.2),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x14000000),
                  Color(0x22050A1A),
                  Color(0xE8050A1A),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xAA081126),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: TavoPalette.line),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 15,
                    color: TavoPalette.gold,
                  ),
                  SizedBox(width: 5),
                  Text(
                    '云昭 · 狐灵 Agent',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '夜色很好。',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  '要让云昭替你查些什么，还是去 Tavo 里做点什么？',
                  style: TextStyle(color: Color(0xFFD8DDF2), height: 1.45),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onChat,
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text('开始对话'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusAction extends StatelessWidget {
  const _StatusAction({
    required this.icon,
    required this.title,
    required this.value,
    required this.active,
    required this.button,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final bool active;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: active ? TavoPalette.cyan : TavoPalette.muted,
                size: 20,
              ),
              const Spacer(),
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: active ? TavoPalette.jade : TavoPalette.muted,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              child: Text(button, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilityCard extends StatelessWidget {
  const _AbilityCard({
    required this.icon,
    required this.title,
    required this.caption,
  });
  final IconData icon;
  final String title;
  final String caption;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: TavoPalette.blue.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: TavoPalette.cyan),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: const TextStyle(color: TavoPalette.muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
