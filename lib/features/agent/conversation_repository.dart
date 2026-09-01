import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tavolink/features/agent/agent_models.dart';

class ConversationRepository {
  const ConversationRepository();
  static const _key = 'chat.yunzhao.history';

  Future<List<AgentMessage>> load() async {
    final prefs = SharedPreferencesAsync();
    final raw = await prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<Map>().map((e) => AgentMessage.fromJson(e.cast<String, dynamic>())).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<AgentMessage> messages) async {
    final prefs = SharedPreferencesAsync();
    final trimmed = messages.length > 60 ? messages.sublist(messages.length - 60) : messages;
    await prefs.setString(_key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() => SharedPreferencesAsync().remove(_key);
}
