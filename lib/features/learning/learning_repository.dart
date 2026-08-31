import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tavolink/features/learning/learning_models.dart';
import 'package:uuid/uuid.dart';

class LearningRepository {
  const LearningRepository();

  static const _memoriesKey = 'learning.yunzhao.memories.v1';
  static const _configKey = 'learning.yunzhao.config.v1';
  static const _toolsKey = 'learning.yunzhao.tools.v1';
  static const _uuid = Uuid();

  Future<LearningConfig> loadConfig() async {
    final raw = await SharedPreferencesAsync().getString(_configKey);
    if (raw == null || raw.isEmpty) return const LearningConfig();
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? LearningConfig.fromJson(decoded.cast<String, dynamic>())
          : const LearningConfig();
    } catch (_) {
      return const LearningConfig();
    }
  }

  Future<void> saveConfig(LearningConfig config) => SharedPreferencesAsync()
      .setString(_configKey, jsonEncode(config.toJson()));

  Future<List<MemoryEntry>> loadMemories() async {
    final raw = await SharedPreferencesAsync().getString(_memoriesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => MemoryEntry.fromJson(e.cast<String, dynamic>()))
          .where((e) => e.id.isNotEmpty && e.content.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveMemories(
    List<MemoryEntry> memories, {
    int? maxMemories,
  }) async {
    final limit = maxMemories ?? (await loadConfig()).maxMemories;
    final sorted = [...memories]
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final strength = b.strength.compareTo(a.strength);
        if (strength != 0) return strength;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final retained = sorted.take(math.max(40, limit)).toList();
    await SharedPreferencesAsync().setString(
      _memoriesKey,
      jsonEncode(retained.map((e) => e.toJson()).toList()),
    );
  }

  Future<MemoryEntry> upsert({
    required MemoryKind kind,
    required String content,
    double confidence = .65,
    List<String> tags = const [],
    String source = 'conversation',
  }) async {
    final clean = _clean(content);
    if (clean.isEmpty) throw ArgumentError('memory content is empty');
    final memories = await loadMemories();
    final now = DateTime.now();
    var bestIndex = -1;
    var bestSimilarity = 0.0;
    for (var i = 0; i < memories.length; i++) {
      if (memories[i].kind != kind) continue;
      final score = similarity(memories[i].content, clean);
      if (score > bestSimilarity) {
        bestSimilarity = score;
        bestIndex = i;
      }
    }

    late MemoryEntry result;
    if (bestIndex >= 0 && bestSimilarity >= .72) {
      final old = memories[bestIndex];
      result = old.copyWith(
        content: clean.length >= old.content.length ? clean : old.content,
        updatedAt: now,
        confidence: math.min(1, math.max(old.confidence, confidence) + .04),
        strength: math.min(99, old.strength + 1),
        tags: {...old.tags, ...tags}.take(12).toList(),
        source: source,
      );
      memories[bestIndex] = result;
    } else {
      result = MemoryEntry(
        id: _uuid.v4(),
        kind: kind,
        content: clean,
        createdAt: now,
        updatedAt: now,
        confidence: confidence.clamp(0.0, 1.0).toDouble(),
        tags: tags.take(12).toList(),
        source: source,
      );
      memories.add(result);
    }
    await _saveMemories(memories);
    return result;
  }

  Future<List<MemoryEntry>> retrieve(String query, {int limit = 7}) async {
    final memories = await loadMemories();
    if (memories.isEmpty) return const [];
    final now = DateTime.now();
    final scored = memories.map((entry) {
      final lexical = similarity(
        query,
        '${entry.content} ${entry.tags.join(' ')}',
      );
      final ageDays = math.max(0, now.difference(entry.updatedAt).inHours / 24);
      final recency = 1 / (1 + ageDays / 30);
      final strength = math.min(1, entry.strength / 5);
      final pin = entry.pinned ? .16 : 0.0;
      final score =
          lexical * .60 +
          entry.confidence * .18 +
          recency * .10 +
          strength * .12 +
          pin;
      return (entry: entry, score: score);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    final selected = scored
        .where((e) => e.score >= .22 || e.entry.pinned)
        .take(limit)
        .map((e) => e.entry)
        .toList();
    if (selected.isNotEmpty) {
      final selectedIds = selected.map((e) => e.id).toSet();
      final updated = memories.map((e) {
        if (!selectedIds.contains(e.id)) return e;
        return e.copyWith(accessCount: e.accessCount + 1, lastAccessedAt: now);
      }).toList();
      await _saveMemories(updated);
    }
    return selected;
  }

  Future<void> setPinned(String id, bool pinned) async {
    final memories = await loadMemories();
    final now = DateTime.now();
    await _saveMemories(
      memories
          .map(
            (e) => e.id == id ? e.copyWith(pinned: pinned, updatedAt: now) : e,
          )
          .toList(),
    );
  }

  Future<void> deleteMemory(String id) async {
    final memories = await loadMemories();
    await _saveMemories(memories.where((e) => e.id != id).toList());
  }

  Future<void> clearMemories() => SharedPreferencesAsync().remove(_memoriesKey);

  Future<Map<String, ToolExperience>> loadToolExperience() async {
    final raw = await SharedPreferencesAsync().getString(_toolsKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final result = <String, ToolExperience>{};
      for (final item in decoded.entries) {
        if (item.value is Map) {
          final experience = ToolExperience.fromJson(
            (item.value as Map).cast<String, dynamic>(),
          );
          if (experience.toolName.isNotEmpty) {
            result[item.key.toString()] = experience;
          }
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  Future<ToolExperience> recordTool({
    required String toolName,
    required bool success,
    required int elapsedMs,
    String? error,
  }) async {
    final all = {...await loadToolExperience()};
    final current = all[toolName] ?? ToolExperience(toolName: toolName);
    final next = current.record(
      success: success,
      elapsedMs: elapsedMs,
      error: error,
    );
    all[toolName] = next;
    await SharedPreferencesAsync().setString(
      _toolsKey,
      jsonEncode(all.map((key, value) => MapEntry(key, value.toJson()))),
    );
    return next;
  }

  Future<void> clearToolExperience() =>
      SharedPreferencesAsync().remove(_toolsKey);

  static String _clean(String input) =>
      input.replaceAll(RegExp(r'\s+'), ' ').trim();

  static double similarity(String a, String b) {
    final aa = _features(a);
    final bb = _features(b);
    if (aa.isEmpty || bb.isEmpty) return 0;
    final intersection = aa.intersection(bb).length;
    final union = aa.union(bb).length;
    if (union == 0) return 0;
    final jaccard = intersection / union;
    final containment = intersection / math.min(aa.length, bb.length);
    return jaccard * .55 + containment * .45;
  }

  static Set<String> _features(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_\u3400-\u9fff]+', unicode: true), ' ')
        .trim();
    if (normalized.isEmpty) return const {};
    final result = <String>{};
    for (final word in normalized.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      result.add(word);
      final chars = word.runes.toList();
      if (chars.length == 1) {
        result.add(String.fromCharCode(chars.first));
      } else {
        for (var i = 0; i < chars.length - 1; i++) {
          result.add(String.fromCharCodes([chars[i], chars[i + 1]]));
        }
      }
    }
    return result;
  }
}
