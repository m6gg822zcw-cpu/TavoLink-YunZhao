enum AgentMessageRole { user, assistant }

class AgentMessage {
  const AgentMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });
  final AgentMessageRole role;
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AgentMessage.fromJson(Map<String, dynamic> json) => AgentMessage(
    role: json['role'] == 'user'
        ? AgentMessageRole.user
        : AgentMessageRole.assistant,
    content: json['content']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
  );
}

enum ToolActivityStatus { running, success, failed }

class ToolActivity {
  const ToolActivity({
    required this.id,
    required this.name,
    required this.label,
    required this.status,
    this.detail = '',
    this.elapsedMs,
  });

  final String id;
  final String name;
  final String label;
  final ToolActivityStatus status;
  final String detail;
  final int? elapsedMs;

  ToolActivity copyWith({
    ToolActivityStatus? status,
    String? detail,
    int? elapsedMs,
  }) => ToolActivity(
    id: id,
    name: name,
    label: label,
    status: status ?? this.status,
    detail: detail ?? this.detail,
    elapsedMs: elapsedMs ?? this.elapsedMs,
  );
}

class AgentTurnResult {
  const AgentTurnResult({required this.content, this.warnings = const []});
  final String content;
  final List<String> warnings;
}
