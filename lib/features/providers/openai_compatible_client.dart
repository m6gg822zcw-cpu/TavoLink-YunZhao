import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:tavolink/features/providers/provider_models.dart';

class OpenAiCompatibleClient {
  OpenAiCompatibleClient(this.config, {Dio? dio}) : _dio = dio ?? Dio();
  final ApiProviderConfig config;
  final Dio _dio;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (config.apiKey?.isNotEmpty == true)
      'Authorization': 'Bearer ${config.apiKey}',
    ...config.extraHeaders,
  };

  Uri _endpoint(String path) {
    var base = config.baseUrl.toString();
    if (!base.endsWith('/')) base = '$base/';
    return Uri.parse(base).resolve(path);
  }

  Future<List<String>> listModels() async {
    final response = await _dio.getUri(
      _endpoint('models'),
      options: Options(
        headers: _headers,
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (data is! Map) throw const FormatException('模型列表响应格式错误');
    final models = (data['data'] as List?) ?? const [];
    return models
        .whereType<Map>()
        .map((m) => m['id']?.toString())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<ChatCompletionResult> createCompletion({
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools = const [],
  }) async {
    final payload = <String, dynamic>{
      'model': config.model,
      'messages': messages,
      'stream': false,
      if (tools.isNotEmpty) 'tools': tools,
      if (tools.isNotEmpty) 'tool_choice': 'auto',
    };
    final response = await _dio.postUri(
      _endpoint('chat/completions'),
      data: payload,
      options: Options(
        headers: _headers,
        sendTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (data is! Map) throw const FormatException('对话响应格式错误');
    final choices = (data['choices'] as List?) ?? const [];
    if (choices.isEmpty || choices.first is! Map) {
      throw const FormatException('模型没有返回 choices');
    }
    final choice = choices.first as Map;
    final raw = choice['message'];
    if (raw is! Map) throw const FormatException('模型没有返回 message');
    final message = raw.cast<String, dynamic>();
    final toolCalls = <ToolCallRequest>[];
    final rawCalls = message['tool_calls'];
    if (rawCalls is List) {
      for (final item in rawCalls.whereType<Map>()) {
        final function = item['function'];
        if (function is! Map) continue;
        final id = item['id']?.toString() ?? '';
        final name = function['name']?.toString() ?? '';
        if (id.isEmpty || name.isEmpty) continue;
        Map<String, dynamic> args = const {};
        final rawArgs = function['arguments'];
        try {
          if (rawArgs is String && rawArgs.trim().isNotEmpty) {
            final decoded = jsonDecode(rawArgs);
            if (decoded is Map) args = decoded.cast<String, dynamic>();
          } else if (rawArgs is Map) {
            args = rawArgs.cast<String, dynamic>();
          }
        } catch (_) {
          args = {'_raw': rawArgs?.toString() ?? ''};
        }
        toolCalls.add(ToolCallRequest(id: id, name: name, arguments: args));
      }
    }
    return ChatCompletionResult(
      content: message['content']?.toString() ?? '',
      rawAssistantMessage: message,
      toolCalls: toolCalls,
    );
  }
}
