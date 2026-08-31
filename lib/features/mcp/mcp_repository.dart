import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tavolink/core/storage/secure_store.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';

class McpConfigRepository {
  const McpConfigRepository({SecureStore secureStore = const SecureStore()})
    : _secureStore = secureStore;
  final SecureStore _secureStore;

  static const _urlKey = 'mcp.url';
  static const _nameKey = 'mcp.name';
  static const _headersKey = 'mcp.headers';
  static const _transportKey = 'mcp.transport';
  static const _tokenKey = 'mcp.token';

  Future<McpServerConfig?> load() async {
    final prefs = SharedPreferencesAsync();
    final url = await prefs.getString(_urlKey);
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    final name = await prefs.getString(_nameKey) ?? 'Tavo MCP';
    final rawHeaders = await prefs.getString(_headersKey);
    final token = await _secureStore.read(_tokenKey);
    final rawTransport = await prefs.getString(_transportKey);
    final transport =
        McpTransport.values.where((e) => e.name == rawTransport).firstOrNull ??
        McpTransport.auto;
    final headers = rawHeaders == null
        ? <String, String>{}
        : (jsonDecode(rawHeaders) as Map).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          );
    return McpServerConfig(
      name: name,
      url: uri,
      bearerToken: token,
      headers: headers,
      transport: transport,
    );
  }

  Future<void> save(McpServerConfig config) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_urlKey, config.url.toString());
    await prefs.setString(_nameKey, config.name);
    await prefs.setString(_headersKey, jsonEncode(config.headers));
    await prefs.setString(_transportKey, config.transport.name);
    if (config.bearerToken?.trim().isNotEmpty == true) {
      await _secureStore.write(_tokenKey, config.bearerToken!.trim());
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
