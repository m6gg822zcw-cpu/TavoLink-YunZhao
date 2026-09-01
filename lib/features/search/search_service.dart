import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:tavolink/features/search/search_models.dart';

abstract interface class SearchService {
  Future<List<SearchResultItem>> search(String query, {int limit = 5});
  void close();
}

SearchService createSearchService(SearchConfig config, {Dio? dio}) {
  return switch (config.backend) {
    SearchBackend.duckDuckGo => DuckDuckGoSearchService(dio: dio),
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

class DuckDuckGoSearchService implements SearchService {
  DuckDuckGoSearchService({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  @override
  void close() => _dio.close(force: true);

  @override
  Future<List<SearchResultItem>> search(String query, {int limit = 5}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) throw StateError('搜索关键词为空');
    final response = await _dio.getUri<String>(
      Uri.https('html.duckduckgo.com', '/html/', {'q': normalized}),
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'Accept': 'text/html,application/xhtml+xml',
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148',
        },
        sendTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final results = parseDuckDuckGoHtml(response.data ?? '', limit: limit);
    if (results.isEmpty) {
      throw StateError('免密搜索暂未返回结果，请稍后重试或切换 SearXNG');
    }
    return results;
  }
}

List<SearchResultItem> parseDuckDuckGoHtml(String html, {int limit = 5}) {
  if (html.isEmpty || limit <= 0) return const [];
  final linkPattern = RegExp(
    r'''<a(?=[^>]*class=["'][^"']*result__a[^"']*["'])(?=[^>]*href=["']([^"']+)["'])[^>]*>(.*?)</a>''',
    caseSensitive: false,
    dotAll: true,
  );
  final snippetPattern = RegExp(
    r'''<(?:a|div)(?=[^>]*class=["'][^"']*result__snippet[^"']*["'])[^>]*>(.*?)</(?:a|div)>''',
    caseSensitive: false,
    dotAll: true,
  );
  final links = linkPattern.allMatches(html).toList();
  final snippets = snippetPattern.allMatches(html).toList();
  final results = <SearchResultItem>[];
  for (var index = 0; index < links.length && results.length < limit; index++) {
    final match = links[index];
    final url = _resolveDuckDuckGoUrl(_decodeHtml(match.group(1) ?? ''));
    final title = _plainText(match.group(2) ?? '');
    if (title.isEmpty || !url.hasScheme || !url.hasAuthority) continue;
    final snippet = index < snippets.length
        ? _plainText(snippets[index].group(1) ?? '')
        : '';
    results.add(SearchResultItem(title: title, url: url, snippet: snippet));
  }
  return results;
}

Uri _resolveDuckDuckGoUrl(String raw) {
  final normalized = raw.startsWith('//') ? 'https:$raw' : raw;
  final parsed = Uri.tryParse(normalized) ?? Uri();
  final redirected = parsed.queryParameters['uddg'];
  return redirected == null ? parsed : (Uri.tryParse(redirected) ?? parsed);
}

String _plainText(String value) => _decodeHtml(
  value.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
);

String _decodeHtml(String value) {
  var decoded = value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
  decoded = decoded.replaceAllMapped(RegExp(r'&#(x?[0-9a-fA-F]+);'), (match) {
    final raw = match.group(1) ?? '';
    final radix = raw.startsWith('x') ? 16 : 10;
    final digits = raw.startsWith('x') ? raw.substring(1) : raw;
    final code = int.tryParse(digits, radix: radix);
    return code == null || code > 0x10ffff
        ? match.group(0)!
        : String.fromCharCode(code);
  });
  return decoded;
}

class TavilySearchService implements SearchService {
  TavilySearchService({required this.apiKey, Dio? dio}) : _dio = dio ?? Dio();
  final String apiKey;
  final Dio _dio;

  @override
  void close() => _dio.close(force: true);

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
  void close() => _dio.close(force: true);

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
  void close() => _dio.close(force: true);

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
  void close() => _dio.close(force: true);

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
