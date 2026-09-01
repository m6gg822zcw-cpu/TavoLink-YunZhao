import 'package:flutter_test/flutter_test.dart';
import 'package:tavolink/features/search/search_service.dart';

void main() {
  test('parses DuckDuckGo HTML results and unwraps redirect URLs', () {
    const html = '''
      <div class="result results_links results_links_deep web-result">
        <a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fdocs">
          Example &amp; Documentation
        </a>
        <a class="result__snippet">A &lt;useful&gt; search result.</a>
      </div>
    ''';

    final results = parseDuckDuckGoHtml(html);

    expect(results, hasLength(1));
    expect(results.single.title, 'Example & Documentation');
    expect(results.single.url, Uri.parse('https://example.com/docs'));
    expect(results.single.snippet, 'A <useful> search result.');
  });

  test('honors result limit and ignores invalid links', () {
    const html = '''
      <a class="result__a" href="not-a-url">Invalid</a>
      <a class="result__a" href="https://one.example">One</a>
      <a class="result__a" href="https://two.example">Two</a>
    ''';

    final results = parseDuckDuckGoHtml(html, limit: 1);

    expect(results, hasLength(1));
    expect(results.single.title, 'One');
  });
}
