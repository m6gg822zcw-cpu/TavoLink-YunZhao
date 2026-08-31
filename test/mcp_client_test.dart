import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavolink/features/mcp/mcp_client.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';

void main() {
  test('MCP 2026 stateless connect lists and calls tools', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      final method = body['method'];
      expect(request.headers.value('mcp-protocol-version'), '2026-07-28');
      request.response.headers.contentType = ContentType.json;
      if (method == 'tools/list') {
        request.response.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': body['id'],
            'result': {
              'tools': [
                {
                  'name': 'tavo.echo',
                  'description': 'Echo',
                  'inputSchema': {'type': 'object'},
                },
              ],
            },
          }),
        );
      } else if (method == 'tools/call') {
        request.response.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': body['id'],
            'result': {'content': 'ok'},
          }),
        );
      }
      await request.response.close();
    });

    final client = McpClient(
      McpServerConfig(
        name: 'Mock Tavo',
        url: Uri.parse('http://127.0.0.1:${server.port}/mcp'),
      ),
    );
    final connection = await client.connect();
    expect(connection.protocolVersion, '2026-07-28');
    final tools = await client.listTools();
    expect(tools.single.name, 'tavo.echo');
    final result = await client.callTool('tavo.echo', {'text': 'hi'});
    expect(result['content'], 'ok');
  });

  test('auto mode falls back to direct JSON-RPC', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      if (request.headers.value('mcp-protocol-version') == '2026-07-28') {
        request.response.statusCode = 400;
        request.response.write('unsupported');
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': body['id'],
            'result': {'tools': []},
          }),
        );
      }
      await request.response.close();
    });

    final client = McpClient(
      McpServerConfig(
        name: 'Tavo Direct',
        url: Uri.parse('http://127.0.0.1:${server.port}/mcp'),
      ),
    );
    final connection = await client.connect();
    expect(connection.protocolVersion, 'direct-jsonrpc');
  });
}
