import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavolink/features/mcp/mcp_client.dart';
import 'package:tavolink/features/mcp/mcp_developer_page.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';
import 'package:tavolink/features/mcp/mcp_repository.dart';

class _Repository extends McpConfigRepository {
  @override
  Future<McpServerConfig?> load() async => McpServerConfig(
    name: 'Fixture',
    url: Uri.parse('https://example.test/mcp'),
    bearerToken: 'saved-fixture',
  );
}

class _Client extends McpClient {
  _Client(super.config);
  int calls = 0;
  bool closed = false;

  @override
  Future<McpConnectResult> connect() async => const McpConnectResult(
    protocolVersion: 'fixture', serverName: 'Fixture',
  );

  @override
  Future<List<McpTool>> listTools() async => const [McpTool(
    name: 'fixture.echo',
    inputSchema: {
      'type': 'object',
      'required': ['text'],
      'properties': {
        'text': {'type': 'string'},
      },
    },
  )];

  @override
  Future<Map<String, dynamic>> callTool(String name, Map<String, dynamic> arguments) async {
    calls++;
    return {'content': 'echo saved-fixture', 'isError': false};
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  testWidgets('loads saved token, requires confirmation and clears client on exit', (tester) async {
    late _Client client;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: McpDeveloperPage(
      repository: _Repository(),
      clientFactory: (config) => client = _Client(config),
    ))));
    await tester.tap(find.text('连接 / 刷新工具'));
    await tester.pumpAndSettle();
    expect(client.config.bearerToken, 'saved-fixture');
    expect(client.calls, 0);

    await tester.ensureVisible(find.text('生成参数模板'));
    await tester.tap(find.text('生成参数模板'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, contains('"text"'));

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '{"text":"hello"}');
    await tester.ensureVisible(find.text('调用工具'));
    await tester.tap(find.text('调用工具'));
    await tester.pumpAndSettle();
    expect(find.text('确认调用 MCP 工具'), findsOneWidget);
    expect(client.calls, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(client.calls, 0);

    await tester.tap(find.text('调用工具'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认执行'));
    await tester.pumpAndSettle();
    expect(client.calls, 1);
    expect(find.textContaining('saved-fixture'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(client.closed, isTrue);
  });

  testWidgets('rejects non-object JSON without sending a tool call', (tester) async {
    late _Client client;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: McpDeveloperPage(
      repository: _Repository(),
      clientFactory: (config) => client = _Client(config),
    ))));
    await tester.tap(find.text('连接 / 刷新工具'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '[]');
    await tester.ensureVisible(find.text('调用工具'));
    await tester.tap(find.text('调用工具'));
    await tester.pumpAndSettle();
    expect(client.calls, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
