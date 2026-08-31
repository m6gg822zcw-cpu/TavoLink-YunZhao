class ApiProviderConfig {
  const ApiProviderConfig({
    required this.name,
    required this.baseUrl,
    required this.model,
    this.apiKey,
    this.extraHeaders = const {},
  });

  final String name;
  final Uri baseUrl;
  final String model;
  final String? apiKey;
  final Map<String, String> extraHeaders;

  ApiProviderConfig copyWith({
    String? name,
    Uri? baseUrl,
    String? model,
    String? apiKey,
    Map<String, String>? extraHeaders,
  }) {
    return ApiProviderConfig(
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      extraHeaders: extraHeaders ?? this.extraHeaders,
    );
  }
}

class ToolCallRequest {
  const ToolCallRequest({
    required this.id,
    required this.name,
    required this.arguments,
  });
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
}

class ChatCompletionResult {
  const ChatCompletionResult({
    required this.content,
    required this.rawAssistantMessage,
    this.toolCalls = const [],
  });
  final String content;
  final Map<String, dynamic> rawAssistantMessage;
  final List<ToolCallRequest> toolCalls;
}
