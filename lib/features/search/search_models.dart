enum SearchBackend { tavily, brave, searxng, custom }

extension SearchBackendLabel on SearchBackend {
  String get label => switch (this) {
        SearchBackend.tavily => 'Tavily',
        SearchBackend.brave => 'Brave Search',
        SearchBackend.searxng => 'SearXNG',
        SearchBackend.custom => '自定义',
      };
}

class SearchConfig {
  const SearchConfig({
    required this.backend,
    this.apiKey,
    this.baseUrl,
    this.enabled = true,
    this.autoSearch = true,
  });

  final SearchBackend backend;
  final String? apiKey;
  final Uri? baseUrl;
  final bool enabled;
  final bool autoSearch;
}

class SearchResultItem {
  const SearchResultItem({required this.title, required this.url, required this.snippet});
  final String title;
  final Uri url;
  final String snippet;

  Map<String, dynamic> toJson() => {'title': title, 'url': url.toString(), 'snippet': snippet};
}
