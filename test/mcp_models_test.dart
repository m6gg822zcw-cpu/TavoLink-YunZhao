import 'package:flutter_test/flutter_test.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';

void main() {
  test('McpTool parses schema and metadata', () {
    final tool = McpTool.fromJson({
      'name': 'tavo.read_character',
      'description': 'Read a character',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
        },
      },
    });
    expect(tool.name, 'tavo.read_character');
    expect(tool.description, 'Read a character');
    expect(tool.inputSchema['type'], 'object');
  });
}
