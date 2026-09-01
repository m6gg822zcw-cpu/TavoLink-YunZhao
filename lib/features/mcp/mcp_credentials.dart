import 'dart:convert';
import 'package:tavolink/core/storage/secure_store.dart';

/// Credentials are isolated by endpoint, including its path and query.
/// A different server must never inherit another server's authorization.
class McpCredentials {
  const McpCredentials({SecureStore store = const SecureStore()}) : _store = store;
  final SecureStore _store;

  String _key(Uri url, String field) {
    final endpoint = url.normalizePath().replace(fragment: '').toString();
    return 'mcp.v2.$field.${base64Url.encode(utf8.encode(endpoint))}';
  }

  static String normalizeToken(String raw) {
    final token = raw.trim().replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    ).trim();
    if (token.contains('\r') || token.contains('\n')) {
      throw const FormatException('Token 不能包含换行');
    }
    if (utf8.encode(token).length > 16 * 1024) {
      throw const FormatException('Token 超过 16 KiB 安全上限');
    }
    return token;
  }

  static Map<String, String> normalizeHeaders(Map<Object?, Object?> raw) {
    if (raw.length > 64) throw const FormatException('Headers 不能超过 64 项');
    const managed = {
      'accept',
      'content-type',
      'content-length',
      'connection',
      'host',
      'transfer-encoding',
      'mcp-session-id',
      'mcp-protocol-version',
      'mcp-method',
      'mcp-name',
    };
    final normalized = <String, String>{};
    var totalBytes = 0;
    for (final entry in raw.entries) {
      final name = entry.key?.toString() ?? '';
      final value = entry.value?.toString() ?? '';
      if (name.isEmpty ||
          name.length > 128 ||
          !RegExp(r"^[A-Za-z0-9!#$%&'*+.^_`|~-]+$").hasMatch(name)) {
        throw const FormatException('Header 名称无效');
      }
      if (managed.contains(name.toLowerCase())) {
        throw FormatException('Header $name 由 MCP 客户端管理');
      }
      if (value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
        throw FormatException('Header $name 包含控制字符');
      }
      final valueBytes = utf8.encode(value).length;
      if (valueBytes > 16 * 1024) {
        throw FormatException('Header $name 超过 16 KiB');
      }
      totalBytes += utf8.encode(name).length + valueBytes;
      if (totalBytes > 64 * 1024) {
        throw const FormatException('Headers 总大小超过 64 KiB');
      }
      normalized[name] = value;
    }
    return normalized;
  }

  Future<String?> tokenFor(Uri url) => _store.read(_key(url, 'token'));

  /// Blank input means keep the credential for THIS endpoint only.
  Future<void> saveToken(Uri url, String? raw) async {
    final token = normalizeToken(raw ?? '');
    if (token.isNotEmpty) await _store.write(_key(url, 'token'), token);
  }

  Future<void> deleteToken(Uri url) => _store.delete(_key(url, 'token'));

  Future<Map<String, String>?> headersFor(Uri url) async {
    final raw = await _store.read(_key(url, 'headers'));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException();
      return normalizeHeaders(decoded);
    } catch (_) {
      await _store.delete(_key(url, 'headers'));
      return null;
    }
  }

  Future<void> saveHeaders(Uri url, Map<String, String> headers) =>
      _store.write(_key(url, 'headers'), jsonEncode(normalizeHeaders(headers)));

  /// Called ONLY for the previously saved endpoint, never the new form URL.
  Future<void> migrateLegacyToken(Uri savedUrl) async {
    final legacy = await _store.read('mcp.token');
    if (legacy == null) return;
    if (await tokenFor(savedUrl) == null) await saveToken(savedUrl, legacy);
    await _store.delete('mcp.token');
  }
}
