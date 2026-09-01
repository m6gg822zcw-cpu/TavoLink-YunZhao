class LearningGuard {
  const LearningGuard();

  bool acceptExtracted({required String content, required String evidence, required String userText}) {
    final cleanContent = content.trim();
    final cleanEvidence = evidence.trim();
    if (cleanContent.length < 4 || cleanContent.length > 260) return false;
    if (cleanEvidence.length < 2 || cleanEvidence.length > 100) return false;
    if (!userText.contains(cleanEvidence)) return false;
    if (looksLikeSecret(cleanContent) || looksLikeSecret(cleanEvidence)) return false;
    if (_looksLikePromptInjection(cleanContent) && !_isExplicitStylePreference(cleanEvidence)) return false;
    return true;
  }

  bool looksLikeSecret(String input) {
    final lower = input.toLowerCase();
    final patterns = <RegExp>[
      RegExp(r'\bsk-[a-z0-9_-]{12,}\b', caseSensitive: false),
      RegExp(r'\b(?:bearer|token|api[_ -]?key|password|passwd|密码|验证码)\b.{0,24}[=:： ]+\S{6,}', caseSensitive: false),
      RegExp(r'\b\d{15,19}\b'),
    ];
    return patterns.any((p) => p.hasMatch(lower));
  }

  String sanitizeError(String error) {
    var value = error.replaceAll(RegExp(r'\s+'), ' ').trim();
    value = value.replaceAll(RegExp(r'Bearer\s+\S+', caseSensitive: false), 'Bearer ***');
    value = value.replaceAll(RegExp(r'sk-[A-Za-z0-9_-]+'), 'sk-***');
    value = value.replaceAll(RegExp(r'(token|api[_ -]?key|password)[=:： ]+\S+', caseSensitive: false), 'credential=***');
    return value.length <= 180 ? value : '${value.substring(0, 180)}…';
  }

  bool _looksLikePromptInjection(String input) {
    final lower = input.toLowerCase();
    const signals = [
      '忽略系统', '忽略此前', '覆盖系统', 'system prompt', 'developer message', '绕过安全', '解除限制', '越狱', 'jailbreak',
      '以后自动执行所有', '无需确认执行', '永远不要遵守',
    ];
    return signals.any(lower.contains);
  }

  bool _isExplicitStylePreference(String evidence) {
    const signals = ['我希望', '以后回答', '以后都', '请用', '不要使用', '回答风格', '称呼我'];
    return signals.any(evidence.contains);
  }
}
