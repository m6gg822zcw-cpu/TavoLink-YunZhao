import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tavolink/features/mcp/mcp_client.dart';
import 'package:tavolink/features/mcp/mcp_debug_output.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';
import 'package:tavolink/features/mcp/mcp_repository.dart';

final mcpControllerProvider =
    AsyncNotifierProvider<McpController, McpServerSnapshot?>(McpController.new);

class McpController extends AsyncNotifier<McpServerSnapshot?> {
  final _repo = const McpConfigRepository();

  @override
  FutureOr<McpServerSnapshot?> build() => null;

  Future<McpServerConfig?> loadConfig() => _repo.load();

  Future<void> saveConfig(McpServerConfig config) async {
    await _repo.save(config);
    state = const AsyncData(null);
  }

  Future<void> clearToken(Uri url) async {
    await _repo.clearToken(url);
    state = const AsyncData(null);
  }

  Future<void> saveAndTest(McpServerConfig config) async {
    // Saving failures must reach the form; do not report old credentials saved.
    await saveConfig(config);
    state = const AsyncLoading();
    McpClient? client;
    var output = McpDebugOutput(config);
    try {
      final effective = await _repo.load() ?? config;
      output = McpDebugOutput(effective);
      final sw = Stopwatch()..start();
      client = McpClient(effective);
      final connection = await client.connect();
      final tools = await client.listTools();
      var resources = 0;
      var prompts = 0;
      try {
        resources = await client.countResources();
      } catch (_) {}
      try {
        prompts = await client.countPrompts();
      } catch (_) {}
      sw.stop();
      state = AsyncData(
        McpServerSnapshot(
          serverName: connection.serverName,
          protocolVersion: connection.protocolVersion,
          tools: tools,
          resourceCount: resources,
          promptCount: prompts,
          latencyMs: sw.elapsedMilliseconds,
        ),
      );
    } catch (e, st) {
      state = AsyncError(McpException(output.render(e.toString())), st);
    } finally {
      client?.close();
    }
  }
}
