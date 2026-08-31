import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/core/widgets/glass_card.dart';
import 'package:tavolink/core/widgets/yunzhao_avatar.dart';
import 'package:tavolink/features/learning/learning_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final learning = const LearningRepository();
  int memoryCount = 0;
  bool learningEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadLearning();
  }

  Future<void> _loadLearning() async {
    final config = await learning.loadConfig();
    final memories = await learning.loadMemories();
    if (!mounted) return;
    setState(() {
      memoryCount = memories.length;
      learningEnabled = config.enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    '云昭设置',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text(
                    'TavoLink v1.1 · Learning Core',
                    style: TextStyle(color: TavoPalette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GlassCard(
          highlight: true,
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.psychology_alt_rounded,
                title: '云昭智能学习',
                subtitle:
                    '${learningEnabled ? '已开启' : '已关闭'} · $memoryCount 条长期记忆 · 可查看、固定、删除与清空',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: TavoPalette.muted,
                ),
                onTap: () async {
                  await context.push('/learning');
                  await _loadLearning();
                },
              ),
              const Divider(height: 28),
              const _SettingRow(
                icon: Icons.security_rounded,
                title: '工具权限',
                subtitle: '高风险操作由客户端权限层控制；学习模块不能绕过执行边界',
              ),
              const Divider(height: 28),
              const _SettingRow(
                icon: Icons.lock_rounded,
                title: '敏感信息',
                subtitle: 'API Key 与 Bearer Token 使用系统安全存储；学习提取器拒绝保存凭据',
              ),
              const Divider(height: 28),
              const _SettingRow(
                icon: Icons.public_rounded,
                title: '网络模式',
                subtitle: '公网优先 HTTPS；局域网 Tavo 可使用明确配置的 HTTP',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: TavoPalette.gold),
                  SizedBox(width: 8),
                  Text('关于云昭', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              SizedBox(height: 10),
              Text(
                '云昭是 TavoLink 内置狐妖智能体。她通过你配置的模型 API 推理，通过 MCP 与 Tavo 交互，通过独立 Search Tool 联网，并使用本地长期记忆逐步学习稳定偏好与工具经验。',
                style: TextStyle(color: TavoPalette.muted, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('v1.1 实际能力', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text(
                '• OpenAI-compatible 对话与函数调用\n• MCP Stateless / Direct JSON-RPC / 2025 回退\n• MCP tools/list 与 tools/call\n• Tavily / Brave / SearXNG / Custom 搜索\n• 云昭分层长期记忆与相关记忆检索\n• AI 对话记忆提取、相似记忆合并\n• MCP / Search 成功率与失败经验学习\n• 本地聊天记录\n• Keychain / Keystore 安全密钥',
                style: TextStyle(color: TavoPalette.muted, height: 1.65),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: onTap == null
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 2),
      child: Row(
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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}
