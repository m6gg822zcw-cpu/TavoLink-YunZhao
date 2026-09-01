import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';

class McpException implements Exception {
  const McpException(this.message, [this.data]);
  final String message;
  final Object? data;
  @override
  String toString() => 'MCP：$message';
}

class McpConnectResult {
  const McpConnectResult({
    required this.protocolVersion,
    required this.serverName,
  });
  final String protocolVersion;
  final String serverName;
}

/// Tavo-first MCP HTTP client.
/// Compatibility order in auto mode:
/// 1. MCP 2026-07-28 stateless request
/// 2. direct HTTP JSON-RPC (used by some Tavo MCP deployments)
/// 3. MCP 2025-11-25 initialize/session flow
class McpClient {
  McpClient(this.config, {Dio? dio}) : _dio = dio ?? Dio();

  static const currentProtocol = '2026-07-28';
  static const latestLegacyProtocol = '2025-11-25';

  final McpServerConfig config;
  final Dio _dio;
  final _uuid = const Uuid();
  String? _sessionId;
  String? _protocolVersion;
  _WireMode _mode = _WireMode.stateless;
  int _nextId = 1;
  List<McpTool>? _toolCache;

  void close() => _dio.close(force: true);

  Future<McpConnectResult> connect() async {
    if (config.transport == McpTransport.directJsonRpc) return _connectDirect();
    if (config.transport == McpTransport.streamableHttp) {
      return _connectStreamable();
    }

    try {
      return await _connectStateless();
    } catch (_) {
      _reset();
    }
    try {
      return await _connectDirect();
    } catch (_) {
      _reset();
    }
    return _connectLegacy();
  }

  Future<McpConnectResult> _connectStreamable() async {
    try {
      return await _connectStateless();
    } catch (_) {
      _reset();
      return _connectLegacy();
    }
  }

  Future<McpConnectResult> _connectStateless() async {
    _mode = _WireMode.stateless;
    _protocolVersion = currentProtocol;
    final result = await _request('tools/list', const {});
    _toolCache = _parseTools(result);
    return McpConnectResult(
      protocolVersion: currentProtocol,
      serverName: config.name,
    );
  }

  Future<McpConnectResult> _connectDirect() async {
    _mode = _WireMode.direct;
    _protocolVersion = 'direct-jsonrpc';
    final result = await _request('tools/list', const {});
    _toolCache = _parseTools(result);
    return McpConnectResult(
      protocolVersion: 'direct-jsonrpc',
      serverName: config.name,
    );
  }

  Future<McpConnectResult> _connectLegacy() async {
    _mode = _WireMode.legacy;
    final info = await _request('initialize', {
      'protocolVersion': latestLegacyProtocol,
      'capabilities': const {},
      'clientInfo': {
        'name': 'TavoLink',
        'version': '1.0.0',
        'instanceId': _uuid.v4(),
      },
    }, initializing: true);
    _protocolVersion =
        info['protocolVersion']?.toString() ?? latestLegacyProtocol;
    await _notify('notifications/initialized', const {});
    final serverInfo = (info['serverInfo'] as Map?)?.cast<String, dynamic>();
    return McpConnectResult(
      protocolVersion: _protocolVersion!,
      serverName: serverInfo?['name']?.toString() ?? config.name,
    );
  }

  void _reset() {
    _sessionId = null;
    _protocolVersion = null;
    _toolCache = null;
  }

  Future<List<McpTool>> listTools() async {
    final cached = _toolCache;
    if (cached != null) {
      _toolCache = null;
      return cached;
    }
    return _parseTools(await _request('tools/list', const {}));
  }

  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> arguments,
  ) {
    return _request('tools/call', {
      'name': name,
      'arguments': arguments,
    }, nameHeader: name);
  }

  Future<int> countResources() async {
    final result = await _request('resources/list', const {});
    return ((result['resources'] as List?) ?? const []).length;
  }

  Future<int> countPrompts() async {
    final result = await _request('prompts/list', const {});
    return ((result['prompts'] as List?) ?? const []).length;
  }

  List<McpTool> _parseTools(Map<String, dynamic> result) {
    final raw = (result['tools'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => McpTool.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Map<String, String> _headers({
    required String method,
    String? nameHeader,
    bool initializing = false,
  }) {
    final out = <String, String>{
      'Accept': 'application/json, text/event-stream',
      'Content-Type': 'application/json',
      ...config.headers,
    };
    final token = config.bearerToken;
    if (token != null && token.trim().isNotEmpty) {
      out['Authorization'] = 'Bearer ${token.trim()}';
    }
    if (_mode == _WireMode.legacy && _sessionId != null) {
      out['Mcp-Session-Id'] = _sessionId!;
    }
    if (_mode == _WireMode.stateless) {
      out['MCP-Protocol-Version'] = currentProtocol;
      out['Mcp-Method'] = method;
      if (nameHeader != null) out['Mcp-Name'] = _encodeHeaderValue(nameHeader);
    } else if (_mode == _WireMode.legacy &&
        !initializing &&
        _protocolVersion != null) {
      out['MCP-Protocol-Version'] = _protocolVersion!;
    }
    return out;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> params, {
    String? nameHeader,
    bool initializing = false,
  }) async {
    final id = _nextId++;
    final requestParams = <String, dynamic>{...params};
    if (_mode == _WireMode.stateless) {
      requestParams['_meta'] = {
        'io.modelcontextprotocol/protocolVersion': currentProtocol,
        'io.modelcontextprotocol/clientInfo': {
          'name': 'TavoLink',
          'version': '1.0.0',
        },
        'io.modelcontextprotocol/clientCapabilities': const {},
      };
    }
    final response = await _dio.postUri(
      config.url,
      data: {
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': requestParams,
      },
      options: Options(
        headers: _headers(
          method: method,
          nameHeader: nameHeader,
          initializing: initializing,
        ),
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 35),
        sendTimeout: const Duration(seconds: 20),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    final session = response.headers.value('mcp-session-id');
    if (session != null && session.isNotEmpty) _sessionId = session;
    final data = _normalizeResponse(response.data, id);
    if (data['error'] != null) {
      final error = (data['error'] as Map?)?.cast<String, dynamic>();
      throw McpException(
        error?['message']?.toString() ?? '未知 MCP 错误',
        error?['data'],
      );
    }
    return (data['result'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
  }

  Future<void> _notify(String method, Map<String, dynamic> params) async {
    await _dio.postUri(
      config.url,
      data: {'jsonrpc': '2.0', 'method': method, 'params': params},
      options: Options(
        headers: _headers(method: method),
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
  }

  Map<String, dynamic> _normalizeResponse(dynamic data, int expectedId) {
    final text = data?.toString().trim() ?? '';
    if (text.isEmpty) throw const McpException('服务器返回空响应');
    if (text.length > 4 * 1024 * 1024) {
      throw const McpException('服务器响应超过 4 MiB 安全上限');
    }
    if (!text.startsWith('data:') && !text.contains('\ndata:')) {
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      throw const McpException('JSON-RPC 响应不是对象');
    }
    Map<String, dynamic>? matched;
    for (final line in const LineSplitter().convert(text)) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          final map = decoded.cast<String, dynamic>();
          if (map['id'] == expectedId) matched = map;
        }
      } catch (_) {}
    }
    if (matched != null) return matched;
    throw const McpException('SSE 流结束但没有对应 JSON-RPC 响应');
  }

  String _encodeHeaderValue(String value) {
    final safeAscii =
        value.codeUnits.every((c) => c >= 0x20 && c <= 0x7e) &&
        value.trim() == value;
    return safeAscii ? value : '=?base64?${base64Encode(utf8.encode(value))}?=';
  }
}

enum _WireMode { stateless, direct, legacy }
