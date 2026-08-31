import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavolink/features/providers/openai_compatible_client.dart';
import 'package:tavolink/features/providers/provider_models.dart';

void main() {
  test('OpenAI-compatible client lists models and parses tool calls', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/v1/models') {
        request.response.write(
          jsonEncode({
            'data': [
              {'id': 'mock-model'},
            ],
          }),
        );
      } else if (request.uri.path == '/v1/chat/completions') {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        expect(body['model'], 'mock-model');
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': null,
                  'tool_calls': [
                    {
                      'id': 'call_1',
                      'type': 'function',
                      'function': {
                        'name': 'web_search',
                        'arguments': '{"query":"Tavo"}',
                      },
                    },
                  ],
                },
              },
            ],
          }),
        );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });

    final client = OpenAiCompatibleClient(
      ApiProviderConfig(
        name: 'mock',
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}/v1/'),
        model: 'mock-model',
        apiKey: 'test-key',
      ),
    );
    expect(await client.listModels(), ['mock-model']);
    final completion = await client.createCompletion(
      messages: const [
        {'role': 'user', 'content': 'hi'},
      ],
      tools: const [
        {
          'type': 'function',
          'function': {
            'name': 'web_search',
            'parameters': {'type': 'object'},
          },
        },
      ],
    );
    expect(completion.toolCalls.single.name, 'web_search');
    expect(completion.toolCalls.single.arguments['query'], 'Tavo');
  });
}
