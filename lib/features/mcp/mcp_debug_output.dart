import 'dart:convert';
import 'package:tavolink/features/mcp/mcp_models.dart';

/// Only redacted, bounded strings are displayed in the developer console.
class McpDebugOutput {
  McpDebugOutput(McpServerConfig config)
    : _secrets =
          _credentialValues(
              config,
            ).where((value) => value.isNotEmpty).toSet().toList()
            ..sort((a, b) => b.length.compareTo(a.length));

  McpDebugOutput.withoutCredentials() : _secrets = const [];

  final List<String> _secrets;
  static const maxLength = 20000;

  static Iterable<String> _credentialValues(McpServerConfig config) sync* {
    if (config.bearerToken?.isNotEmpty == true) yield config.bearerToken!;
    for (final header in config.headers.entries) {
      if (!_sensitiveName(header.key) &&
          !header.value.trimLeft().toLowerCase().startsWith('bearer '))
        continue;
      yield header.value;
      final withoutBearer = header.value.trim().replaceFirst(
        RegExp(r'^Bearer\s+', caseSensitive: false),
        '',
      );
      if (withoutBearer != header.value.trim()) yield withoutBearer;
    }
    for (final item in config.url.queryParameters.entries) {
      if (_sensitiveName(item.key)) yield item.value;
    }
  }

  String render(Object? value) {
    final raw = value is String
        ? value
        : const JsonEncoder.withIndent('  ').convert(_redactFields(value));
    var safe = raw;
    for (final secret in _secrets) {
      safe = safe.replaceAll(secret, '[已隐藏]');
      final encoded = jsonEncode(secret);
      safe = safe.replaceAll(encoded.substring(1, encoded.length - 1), '[已隐藏]');
    }
    safe = safe.replaceAll(
      RegExp(r'Bearer\s+[^\s"<>]+', caseSensitive: false),
      'Bearer [已隐藏]',
    );
    return safe.length <= maxLength
        ? safe
        : '${safe.substring(0, maxLength)}\n…结果过长，已截断';
  }

  Object? _redactFields(Object? value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          _sensitiveKey(key.toString()) ? '[已隐藏]' : _redactFields(item),
        ),
      );
    }
    if (value is List) return value.map(_redactFields).toList();
    return value;
  }

  static bool _sensitiveName(String key) => RegExp(
    r'token|authorization|password|secret|api[_-]?key|cookie',
    caseSensitive: false,
  ).hasMatch(key);

  bool _sensitiveKey(String key) => _sensitiveName(key);
}
