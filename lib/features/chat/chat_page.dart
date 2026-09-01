import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/core/widgets/glass_card.dart';
import 'package:tavolink/core/widgets/status_pill.dart';
import 'package:tavolink/core/widgets/yunzhao_avatar.dart';
import 'package:tavolink/features/agent/agent_models.dart';
import 'package:tavolink/features/agent/agent_service.dart';
import 'package:tavolink/features/agent/conversation_repository.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final repository = const ConversationRepository();
  final agent = AgentService();
  final messages = <AgentMessage>[];
  final activities = <ToolActivity>[];
  bool busy = false;
  bool allowMcp = true;
  bool allowSearch = true;
  bool allowLearning = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await repository.load();
    if (!mounted) return;
    setState(() {
      messages
        ..clear()
        ..addAll(saved);
      if (messages.isEmpty) {
        messages.add(AgentMessage(
          role: AgentMessageRole.assistant,
          content: '我是云昭。配置好模型 API 后，我可以陪你聊天，也能通过 Tavo MCP 调用工具、通过联网搜索查找实时信息。',
          createdAt: DateTime.now(),
        ));
      }
    });
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    final historyBeforeUser = List<AgentMessage>.from(messages);
    final userMessage = AgentMessage(role: AgentMessageRole.user, content: text, createdAt: DateTime.now());
    setState(() {
      input.clear();
      busy = true;
      activities.clear();
      messages.add(userMessage);
    });
    unawaited(repository.save(messages));
    _jumpToBottom();
    try {
      final result = await agent.send(
        userText: text,
        history: historyBeforeUser,
        allowMcp: allowMcp,
        allowSearch: allowSearch,
        allowLearning: allowLearning,
        onToolActivity: _onToolActivity,
      );
      if (!mounted) return;
      final prefix = result.warnings.isEmpty ? '' : '${result.warnings.map((e) => '⚠ $e').join('\n')}\n\n';
      setState(() {
        messages.add(AgentMessage(
          role: AgentMessageRole.assistant,
          content: '$prefix${result.content}',
          createdAt: DateTime.now(),
        ));
      });
      await repository.save(messages);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        messages.add(AgentMessage(
          role: AgentMessageRole.assistant,
          content: '这次没有成功完成：$e',
          createdAt: DateTime.now(),
        ));
      });
      await repository.save(messages);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        _jumpToBottom();
      }
    }
  }

  void _onToolActivity(ToolActivity activity) {
    if (!mounted) return;
    setState(() {
      final index = activities.indexWhere((e) => e.id == activity.id);
      if (index >= 0) {
        activities[index] = activity;
      } else {
        activities.add(activity);
      }
    });
    _jumpToBottom();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    });
  }

  Future<void> _clear() async {
    await repository.clear();
    if (!mounted) return;
    setState(() {
      messages
        ..clear()
        ..add(AgentMessage(role: AgentMessageRole.assistant, content: '记忆已经清空。新的对话从这里开始。', createdAt: DateTime.now()));
      activities.clear();
    });
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
          child: Row(children: [
            const YunZhaoAvatar(size: 42),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('与云昭对话', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 1),
              Text(busy ? '正在思考与调用工具…' : '云昭 · TavoLink 智能体', style: Theme.of(context).textTheme.bodySmall),
            ])),
            StatusPill(label: busy ? '忙碌' : '在线', active: true, icon: busy ? Icons.auto_awesome_rounded : Icons.circle),
            IconButton(onPressed: _clear, tooltip: '清空对话', icon: const Icon(Icons.delete_sweep_outlined, color: TavoPalette.muted)),
          ]),
        ),
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            children: [
              for (final message in messages) ...[
                _MessageBubble(message: message),
                const SizedBox(height: 13),
              ],
              if (activities.isNotEmpty) ...[
                for (final activity in activities) ...[
                  _ToolActivityCard(activity: activity),
                  const SizedBox(height: 9),
                ],
              ],
              if (busy) const _ThinkingRow(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(children: [
            Row(children: [
              Expanded(child: _ModeChip(icon: Icons.hub_rounded, label: 'MCP', enabled: allowMcp, onTap: () => setState(() => allowMcp = !allowMcp))),
              const SizedBox(width: 8),
              Expanded(child: _ModeChip(icon: Icons.travel_explore_rounded, label: '联网', enabled: allowSearch, onTap: () => setState(() => allowSearch = !allowSearch))),
              const SizedBox(width: 8),
              Expanded(child: _ModeChip(icon: Icons.psychology_alt_rounded, label: '学习', enabled: allowLearning, onTap: () => setState(() => allowLearning = !allowLearning))),
            ]),
            const SizedBox(height: 8),
            GlassCard(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(10, 7, 7, 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Icon(Icons.local_fire_department_rounded, color: TavoPalette.violet, size: 21)),
                const SizedBox(width: 6),
                Expanded(child: TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration.collapsed(hintText: '发消息给云昭…'),
                  onSubmitted: (_) => _send(),
                )),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: busy ? null : _send, icon: const Icon(Icons.arrow_upward_rounded)),
              ]),
            ),
          ]),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final AgentMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == AgentMessageRole.user;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!user) ...[const YunZhaoAvatar(size: 32), const SizedBox(width: 8)],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  gradient: user
                      ? const LinearGradient(colors: [Color(0xFF6C4FE7), Color(0xFF5378F6)])
                      : LinearGradient(colors: [TavoPalette.panelSoft.withValues(alpha: .92), TavoPalette.navy.withValues(alpha: .88)]),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(user ? 20 : 5),
                    bottomRight: Radius.circular(user ? 5 : 20),
                  ),
                  border: user ? null : Border.all(color: TavoPalette.line),
                  boxShadow: [BoxShadow(color: (user ? TavoPalette.violet : Colors.black).withValues(alpha: .16), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: Text(message.content, style: const TextStyle(height: 1.52)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolActivityCard extends StatelessWidget {
  const _ToolActivityCard({required this.activity});
  final ToolActivity activity;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (activity.status) {
      ToolActivityStatus.running => (Icons.hourglass_top_rounded, TavoPalette.gold, '执行中'),
      ToolActivityStatus.success => (Icons.check_circle_rounded, TavoPalette.jade, '成功'),
      ToolActivityStatus.failed => (Icons.error_rounded, TavoPalette.danger, '失败'),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: GlassCard(
        padding: const EdgeInsets.all(13),
        radius: 18,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.hub_rounded, color: TavoPalette.cyan, size: 17),
            const SizedBox(width: 7),
            Expanded(child: Text(activity.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
            if (activity.elapsedMs != null) Text(' · ${activity.elapsedMs}ms', style: Theme.of(context).textTheme.bodySmall),
          ]),
          if (activity.detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(activity.detail, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TavoPalette.muted, fontFamily: 'monospace', fontSize: 11, height: 1.4)),
          ],
        ]),
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        YunZhaoAvatar(size: 30),
        SizedBox(width: 9),
        SizedBox.square(dimension: 15, child: CircularProgressIndicator(strokeWidth: 2, color: TavoPalette.violet)),
        SizedBox(width: 8),
        Text('狐火正在流转…', style: TextStyle(color: TavoPalette.muted, fontSize: 12)),
      ]),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.icon, required this.label, required this.enabled, this.onTap});
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? TavoPalette.cyan : TavoPalette.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: enabled ? .10 : .04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: enabled ? .30 : .12)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
