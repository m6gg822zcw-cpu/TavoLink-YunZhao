import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tavolink/core/storage/secure_store.dart';
import 'package:tavolink/features/providers/provider_models.dart';

class ApiProviderRepository {
  const ApiProviderRepository({SecureStore secureStore = const SecureStore()})
    : _secureStore = secureStore;
  final SecureStore _secureStore;

  static const _nameKey = 'api.name';
  static const _baseUrlKey = 'api.baseUrl';
  static const _modelKey = 'api.model';
  static const _headersKey = 'api.headers';
  static const _secretKey = 'api.secret';

  Future<ApiProviderConfig?> load() async {
    final prefs = SharedPreferencesAsync();
    final rawUrl = await prefs.getString(_baseUrlKey);
    final model = await prefs.getString(_modelKey);
    if (rawUrl == null ||
        rawUrl.trim().isEmpty ||
        model == null ||
        model.trim().isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    final rawHeaders = await prefs.getString(_headersKey);
    final headers = rawHeaders == null || rawHeaders.isEmpty
        ? <String, String>{}
        : (jsonDecode(rawHeaders) as Map).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
    return ApiProviderConfig(
      name: await prefs.getString(_nameKey) ?? 'OpenAI Compatible',
      baseUrl: uri,
      model: model,
      apiKey: await _secureStore.read(_secretKey),
      extraHeaders: headers,
    );
  }

  Future<void> save(ApiProviderConfig config) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_nameKey, config.name);
    await prefs.setString(_baseUrlKey, config.baseUrl.toString());
    await prefs.setString(_modelKey, config.model);
    await prefs.setString(_headersKey, jsonEncode(config.extraHeaders));
    if (config.apiKey?.trim().isNotEmpty == true) {
      await _secureStore.write(_secretKey, config.apiKey!.trim());
    }
  }
}
