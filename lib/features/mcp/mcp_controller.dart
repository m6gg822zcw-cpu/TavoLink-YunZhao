import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tavolink/features/mcp/mcp_client.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';
import 'package:tavolink/features/mcp/mcp_repository.dart';

final mcpControllerProvider = AsyncNotifierProvider<McpController, McpServerSnapshot?>(McpController.new);

class McpController extends AsyncNotifier<McpServerSnapshot?> {
  final _repo = const McpConfigRepository();

  @override
  FutureOr<McpServerSnapshot?> build() => null;

  Future<McpServerConfig?> loadConfig() => _repo.load();

  Future<void> saveAndTest(McpServerConfig config) async {
    state = const AsyncLoading();
    try {
      await _repo.save(config);
      final effective = await _repo.load() ?? config;
      final sw = Stopwatch()..start();
      final client = McpClient(effective);
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
      state = AsyncData(McpServerSnapshot(
        serverName: connection.serverName,
        protocolVersion: connection.protocolVersion,
        tools: tools,
        resourceCount: resources,
        promptCount: prompts,
        latencyMs: sw.elapsedMilliseconds,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
