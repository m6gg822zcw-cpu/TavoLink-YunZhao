import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tavolink/core/storage/secure_store.dart';
import 'package:tavolink/core/network/url_policy.dart';
import 'package:tavolink/features/mcp/mcp_credentials.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';

class McpConfigRepository {
  const McpConfigRepository({SecureStore secureStore = const SecureStore()})
    : _secureStore = secureStore;
  final SecureStore _secureStore;

  McpCredentials get _credentials => McpCredentials(store: _secureStore);

  static const _urlKey = 'mcp.url';
  static const _nameKey = 'mcp.name';
  static const _headersKey = 'mcp.headers';
  static const _transportKey = 'mcp.transport';

  Future<McpServerConfig?> load() async {
    final prefs = SharedPreferencesAsync();
    final url = await prefs.getString(_urlKey);
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !isAllowedEndpoint(uri) ||
        hasSensitiveQueryParameter(uri) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final name = await prefs.getString(_nameKey) ?? 'Tavo MCP';
    final rawHeaders = await prefs.getString(_headersKey);
    await _credentials.migrateLegacyToken(uri);
    final token = await _credentials.tokenFor(uri);
    final rawTransport = await prefs.getString(_transportKey);
    final transport =
        McpTransport.values.where((e) => e.name == rawTransport).firstOrNull ??
        McpTransport.auto;
    var headers = await _credentials.headersFor(uri);
    if (headers == null) {
      try {
        headers = rawHeaders == null
            ? <String, String>{}
            : (jsonDecode(rawHeaders) as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              );
        await _credentials.saveHeaders(uri, headers);
      } catch (_) {
        // A malformed legacy value is discarded instead of blocking recovery.
        headers = <String, String>{};
        await _credentials.saveHeaders(uri, headers);
      }
    }
    // Custom headers may also contain credentials: never retain plaintext.
    if (rawHeaders != null) await prefs.remove(_headersKey);
    return McpServerConfig(
      name: name,
      url: uri,
      bearerToken: token,
      headers: headers,
      transport: transport,
    );
  }

  Future<void> save(McpServerConfig config) async {
    if (!isAllowedEndpoint(config.url) ||
        hasSensitiveQueryParameter(config.url) ||
        config.url.fragment.isNotEmpty) {
      throw const FormatException('MCP 地址无效；Token 必须使用安全 Token 字段');
    }
    final normalizedToken = McpCredentials.normalizeToken(
      config.bearerToken ?? '',
    );
    // Migrate existing credentials before updating the saved endpoint.
    final previous = await load();
    if (previous == null) {
      // Keychain can outlive a reinstall while preferences do not. An orphan
      // legacy token has no verifiable endpoint and must not attach to a new one.
      await _secureStore.delete('mcp.token');
    }
    final prefs = SharedPreferencesAsync();
    await _credentials.saveToken(config.url, normalizedToken);
    await _credentials.saveHeaders(config.url, config.headers);
    await prefs.setString(_urlKey, config.url.toString());
    await prefs.setString(_nameKey, config.name);
    await prefs.setString(_transportKey, config.transport.name);
  }

  Future<void> clearToken(Uri url) async {
    await load();
    await _credentials.deleteToken(url);
    // Also remove a custom Authorization header so clear really disables auth.
    final headers = await _credentials.headersFor(url);
    if (headers != null) {
      headers.removeWhere((key, _) => key.toLowerCase() == 'authorization');
      await _credentials.saveHeaders(url, headers);
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
