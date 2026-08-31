enum McpTransport { auto, streamableHttp, directJsonRpc }

extension McpTransportLabel on McpTransport {
  String get label => switch (this) {
    McpTransport.auto => '自动兼容',
    McpTransport.streamableHttp => 'Streamable HTTP',
    McpTransport.directJsonRpc => 'HTTP JSON-RPC',
  };
}

class McpServerConfig {
  const McpServerConfig({
    required this.name,
    required this.url,
    this.transport = McpTransport.auto,
    this.bearerToken,
    this.headers = const {},
  });

  final String name;
  final Uri url;
  final McpTransport transport;
  final String? bearerToken;
  final Map<String, String> headers;
}

class McpServerSnapshot {
  const McpServerSnapshot({
    required this.serverName,
    required this.protocolVersion,
    required this.tools,
    required this.resourceCount,
    required this.promptCount,
    required this.latencyMs,
  });

  final String serverName;
  final String protocolVersion;
  final List<McpTool> tools;
  final int resourceCount;
  final int promptCount;
  final int latencyMs;
  int get toolCount => tools.length;
}

class McpTool {
  const McpTool({
    required this.name,
    this.description,
    this.inputSchema = const {},
  });
  final String name;
  final String? description;
  final Map<String, dynamic> inputSchema;

  factory McpTool.fromJson(Map<String, dynamic> json) => McpTool(
    name: json['name']?.toString() ?? 'unknown',
    description: json['description']?.toString(),
    inputSchema:
        (json['inputSchema'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}
