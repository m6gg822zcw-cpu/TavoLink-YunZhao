import 'package:flutter_test/flutter_test.dart';
import 'package:tavolink/features/mcp/mcp_debug_output.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';

void main() {
  final output = McpDebugOutput(McpServerConfig(
    name: 'Fixture',
    url: Uri.parse('https://example.test/mcp?access_token=query-fixture'),
    bearerToken: 'stored-fixture',
    headers: const {'X-Api-Key': 'header-fixture'},
  ));

  test('redacts credentials from nested results and reflected errors', () {
    final rendered = output.render({
      'token': 'unknown-fixture',
      'nested': [{'api_key': 'another-fixture'}],
      'message': 'stored-fixture header-fixture query-fixture',
      'safe': 'normal result',
    });
    for (final secret in [
      'stored-fixture', 'header-fixture', 'query-fixture',
      'unknown-fixture', 'another-fixture',
    ]) {
      expect(rendered, isNot(contains(secret)));
    }
    expect(rendered, contains('normal result'));
  });

  test('redacts Bearer strings and bounds displayed output', () {
    expect(output.render('Authorization: Bearer unknown-fixture'),
      isNot(contains('unknown-fixture')));
    final rendered = output.render(
      List.filled(McpDebugOutput.maxLength + 100, 'x').join(),
    );
    expect(rendered, contains('已截断'));
    expect(rendered.length, lessThan(McpDebugOutput.maxLength + 50));
  });
}
