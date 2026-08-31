import 'package:shared_preferences/shared_preferences.dart';
import 'package:tavolink/core/storage/secure_store.dart';
import 'package:tavolink/features/search/search_models.dart';

class SearchRepository {
  const SearchRepository({SecureStore secureStore = const SecureStore()})
    : _secureStore = secureStore;
  final SecureStore _secureStore;

  static const _backend = 'search.backend';
  static const _url = 'search.url';
  static const _enabled = 'search.enabled';
  static const _auto = 'search.auto';
  static const _secret = 'search.secret';

  Future<SearchConfig?> load() async {
    final prefs = SharedPreferencesAsync();
    final rawBackend = await prefs.getString(_backend);
    if (rawBackend == null) return null;
    final backend = SearchBackend.values
        .where((e) => e.name == rawBackend)
        .firstOrNull;
    if (backend == null) return null;
    final rawUrl = await prefs.getString(_url);
    return SearchConfig(
      backend: backend,
      apiKey: await _secureStore.read(_secret),
      baseUrl: rawUrl == null || rawUrl.isEmpty ? null : Uri.tryParse(rawUrl),
      enabled: await prefs.getBool(_enabled) ?? true,
      autoSearch: await prefs.getBool(_auto) ?? true,
    );
  }

  Future<void> save(SearchConfig config) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_backend, config.backend.name);
    await prefs.setString(_url, config.baseUrl?.toString() ?? '');
    await prefs.setBool(_enabled, config.enabled);
    await prefs.setBool(_auto, config.autoSearch);
    if (config.apiKey?.trim().isNotEmpty == true) {
      await _secureStore.write(_secret, config.apiKey!.trim());
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
