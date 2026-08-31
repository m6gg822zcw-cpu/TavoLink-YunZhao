import 'dart:math' as math;

enum MemoryKind { preference, fact, project, style, toolLesson }

extension MemoryKindX on MemoryKind {
  String get label => switch (this) {
    MemoryKind.preference => '偏好',
    MemoryKind.fact => '稳定事实',
    MemoryKind.project => '项目上下文',
    MemoryKind.style => '交互风格',
    MemoryKind.toolLesson => '工具经验',
  };

  static MemoryKind parse(Object? value) {
    final raw = value?.toString().trim().toLowerCase();
    return MemoryKind.values.firstWhere(
      (e) => e.name.toLowerCase() == raw,
      orElse: () => MemoryKind.fact,
    );
  }
}

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.kind,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.confidence = .6,
    this.strength = 1,
    this.accessCount = 0,
    this.lastAccessedAt,
    this.pinned = false,
    this.tags = const [],
    this.source = 'conversation',
  });

  final String id;
  final MemoryKind kind;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double confidence;
  final int strength;
  final int accessCount;
  final DateTime? lastAccessedAt;
  final bool pinned;
  final List<String> tags;
  final String source;

  MemoryEntry copyWith({
    String? id,
    MemoryKind? kind,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? confidence,
    int? strength,
    int? accessCount,
    DateTime? lastAccessedAt,
    bool? pinned,
    List<String>? tags,
    String? source,
  }) {
    return MemoryEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      confidence: confidence ?? this.confidence,
      strength: strength ?? this.strength,
      accessCount: accessCount ?? this.accessCount,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      pinned: pinned ?? this.pinned,
      tags: tags ?? this.tags,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'confidence': confidence,
    'strength': strength,
    'accessCount': accessCount,
    'lastAccessedAt': lastAccessedAt?.toIso8601String(),
    'pinned': pinned,
    'tags': tags,
    'source': source,
  };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) => MemoryEntry(
    id: json['id']?.toString() ?? '',
    kind: MemoryKindX.parse(json['kind']),
    content: json['content']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.now(),
    confidence: _asDouble(json['confidence'], .6).clamp(0.0, 1.0).toDouble(),
    strength: _asInt(json['strength'], 1).clamp(1, 99).toInt(),
    accessCount: _asInt(json['accessCount'], 0).clamp(0, 999999).toInt(),
    lastAccessedAt: DateTime.tryParse(json['lastAccessedAt']?.toString() ?? ''),
    pinned: json['pinned'] == true,
    tags: (json['tags'] is List)
        ? (json['tags'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : const [],
    source: json['source']?.toString() ?? 'conversation',
  );

  static double _asDouble(Object? value, double fallback) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? fallback;
  static int _asInt(Object? value, int fallback) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? fallback;
}

class LearningConfig {
  const LearningConfig({
    this.enabled = true,
    this.aiExtraction = true,
    this.injectRelevantMemories = true,
    this.learnToolExperience = true,
    this.maxMemories = 240,
  });

  final bool enabled;
  final bool aiExtraction;
  final bool injectRelevantMemories;
  final bool learnToolExperience;
  final int maxMemories;

  LearningConfig copyWith({
    bool? enabled,
    bool? aiExtraction,
    bool? injectRelevantMemories,
    bool? learnToolExperience,
    int? maxMemories,
  }) => LearningConfig(
    enabled: enabled ?? this.enabled,
    aiExtraction: aiExtraction ?? this.aiExtraction,
    injectRelevantMemories:
        injectRelevantMemories ?? this.injectRelevantMemories,
    learnToolExperience: learnToolExperience ?? this.learnToolExperience,
    maxMemories: maxMemories ?? this.maxMemories,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'aiExtraction': aiExtraction,
    'injectRelevantMemories': injectRelevantMemories,
    'learnToolExperience': learnToolExperience,
    'maxMemories': maxMemories,
  };

  factory LearningConfig.fromJson(Map<String, dynamic> json) => LearningConfig(
    enabled: json['enabled'] != false,
    aiExtraction: json['aiExtraction'] != false,
    injectRelevantMemories: json['injectRelevantMemories'] != false,
    learnToolExperience: json['learnToolExperience'] != false,
    maxMemories: _readMax(json['maxMemories']),
  );

  static int _readMax(Object? value) {
    final number = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 240;
    return math.max(40, math.min(1000, number));
  }
}

class ToolExperience {
  const ToolExperience({
    required this.toolName,
    this.successes = 0,
    this.failures = 0,
    this.totalElapsedMs = 0,
    this.lastError,
    this.updatedAt,
  });

  final String toolName;
  final int successes;
  final int failures;
  final int totalElapsedMs;
  final String? lastError;
  final DateTime? updatedAt;

  int get totalCalls => successes + failures;
  double get successRate => totalCalls == 0 ? 0 : successes / totalCalls;
  int? get averageElapsedMs =>
      totalCalls == 0 ? null : (totalElapsedMs / totalCalls).round();

  ToolExperience record({
    required bool success,
    required int elapsedMs,
    String? error,
  }) => ToolExperience(
    toolName: toolName,
    successes: successes + (success ? 1 : 0),
    failures: failures + (success ? 0 : 1),
    totalElapsedMs: totalElapsedMs + math.max(0, elapsedMs),
    lastError: success ? lastError : error,
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'toolName': toolName,
    'successes': successes,
    'failures': failures,
    'totalElapsedMs': totalElapsedMs,
    'lastError': lastError,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory ToolExperience.fromJson(Map<String, dynamic> json) => ToolExperience(
    toolName: json['toolName']?.toString() ?? '',
    successes: MemoryEntry._asInt(json['successes'], 0),
    failures: MemoryEntry._asInt(json['failures'], 0),
    totalElapsedMs: MemoryEntry._asInt(json['totalElapsedMs'], 0),
    lastError: json['lastError']?.toString(),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
  );
}
