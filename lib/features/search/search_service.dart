import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:tavolink/features/search/search_models.dart';

abstract interface class SearchService {
  Future<List<SearchResultItem>> search(String query, {int limit = 5});
}

SearchService createSearchService(SearchConfig config, {Dio? dio}) {
  return switch (config.backend) {
    SearchBackend.tavily => TavilySearchService(
      apiKey: config.apiKey ?? '',
      dio: dio,
    ),
    SearchBackend.brave => BraveSearchService(
      apiKey: config.apiKey ?? '',
      dio: dio,
    ),
    SearchBackend.searxng => SearxngSearchService(
      baseUrl: config.baseUrl ?? Uri.parse('https://searx.be/'),
      dio: dio,
    ),
    SearchBackend.custom => CustomSearchService(
      baseUrl: config.baseUrl ?? Uri(),
      apiKey: config.apiKey,
      dio: dio,
    ),
  };
}

class TavilySearchService implements SearchService {
  TavilySearchService({required this.apiKey, Dio? dio}) : _dio = dio ?? Dio();
  final String apiKey;
  final Dio _dio;

  @override
  Future<List<SearchResultItem>> search(String query, {int limit = 5}) async {
    if (apiKey.isEmpty) throw StateError('Tavily API Key 未配置');
    final response = await _dio.post(
      'https://api.tavily.com/search',
      data: {
        'api_key': apiKey,
        'query': query,
        'max_results': limit,
        'search_depth': 'basic',
      },
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (data is! Map) return const [];
    final results = (data['results'] as List?) ?? const [];
    return results.whereType<Map>().map(_fromTavily).take(limit).toList();
  }

  SearchResultItem _fromTavily(Map item) => SearchResultItem(
    title: item['title']?.toString() ?? '',
    url: Uri.tryParse(item['url']?.toString() ?? '') ?? Uri(),
    snippet: item['content']?.toString() ?? '',
  );
}

class BraveSearchService implements SearchService {
  BraveSearchService({required this.apiKey, Dio? dio}) : _dio = dio ?? Dio();
  final String apiKey;
  final Dio _dio;

  @override
  Future<List<SearchResultItem>> search(String query, {int limit = 5}) async {
    if (apiKey.isEmpty) throw StateError('Brave API Key 未配置');
    final response = await _dio.get(
      'https://api.search.brave.com/res/v1/web/search',
      queryParameters: {'q': query, 'count': limit},
      options: Options(
        headers: {'Accept': 'application/json', 'X-Subscription-Token': apiKey},
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    final web = data is Map ? data['web'] : null;
    final results = web is Map
        ? (web['results'] as List? ?? const [])
        : const [];
    return results
        .whereType<Map>()
        .map(
          (item) => SearchResultItem(
            title: item['title']?.toString() ?? '',
            url: Uri.tryParse(item['url']?.toString() ?? '') ?? Uri(),
            snippet: item['description']?.toString() ?? '',
          ),
        )
        .take(limit)
        .toList();
  }
}

class SearxngSearchService implements SearchService {
  SearxngSearchService({required this.baseUrl, Dio? dio}) : _dio = dio ?? Dio();
  final Uri baseUrl;
  final Dio _dio;

  @override
  Future<List<SearchResultItem>> search(String query, {int limit = 5}) async {
    var base = baseUrl.toString();
    if (!base.endsWith('/')) base = '$base/';
    final response = await _dio.getUri(
      Uri.parse(base)
          .resolve('search')
          .replace(queryParameters: {'q': query, 'format': 'json'}),
      options: Options(
        headers: {'Accept': 'application/json'},
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    final results = data is Map
        ? (data['results'] as List? ?? const [])
        : const [];
    return results
        .whereType<Map>()
        .map(
          (item) => SearchResultItem(
            title: item['title']?.toString() ?? '',
            url: Uri.tryParse(item['url']?.toString() ?? '') ?? Uri(),
            snippet: item['content']?.toString() ?? '',
          ),
        )
        .take(limit)
        .toList();
  }
}

class CustomSearchService implements SearchService {
  CustomSearchService({required this.baseUrl, this.apiKey, Dio? dio})
    : _dio = dio ?? Dio();
  final Uri baseUrl;
  final String? apiKey;
  final Dio _dio;

  @override
  Future<List<SearchResultItem>> search(String query, {int limit = 5}) async {
    if (!baseUrl.hasScheme || !baseUrl.hasAuthority) {
      throw StateError('自定义搜索 URL 未配置');
    }
    final response = await _dio.getUri(
      baseUrl.replace(
        queryParameters: {
          ...baseUrl.queryParameters,
          'q': query,
          'limit': '$limit',
        },
      ),
      options: Options(
        headers: {
          if (apiKey?.isNotEmpty == true) 'Authorization': 'Bearer $apiKey',
        },
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    final raw = data is Map
        ? (data['results'] as List? ?? data['items'] as List? ?? const [])
        : (data is List ? data : const []);
    return raw
        .whereType<Map>()
        .map(
          (item) => SearchResultItem(
            title: item['title']?.toString() ?? item['name']?.toString() ?? '',
            url:
                Uri.tryParse(
                  item['url']?.toString() ?? item['link']?.toString() ?? '',
                ) ??
                Uri(),
            snippet:
                item['snippet']?.toString() ??
                item['content']?.toString() ??
                item['description']?.toString() ??
                '',
          ),
        )
        .take(limit)
        .toList();
  }
}
