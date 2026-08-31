import 'dart:convert';
import 'package:tavolink/features/agent/agent_models.dart';
import 'package:tavolink/features/learning/learning_service.dart';
import 'package:tavolink/features/mcp/mcp_client.dart';
import 'package:tavolink/features/mcp/mcp_models.dart';
import 'package:tavolink/features/mcp/mcp_repository.dart';
import 'package:tavolink/features/providers/api_provider_repository.dart';
import 'package:tavolink/features/providers/openai_compatible_client.dart';
import 'package:tavolink/features/search/search_repository.dart';
import 'package:tavolink/features/search/search_service.dart';

typedef ToolActivityCallback = void Function(ToolActivity activity);

class AgentService {
  AgentService({
    ApiProviderRepository apiRepository = const ApiProviderRepository(),
    McpConfigRepository mcpRepository = const McpConfigRepository(),
    SearchRepository searchRepository = const SearchRepository(),
    LearningService? learningService,
  }) : _apiRepository = apiRepository,
       _mcpRepository = mcpRepository,
       _searchRepository = searchRepository,
       _learningService = learningService ?? LearningService();

  final ApiProviderRepository _apiRepository;
  final McpConfigRepository _mcpRepository;
  final SearchRepository _searchRepository;
  final LearningService _learningService;

  Future<AgentTurnResult> send({
    required String userText,
    required List<AgentMessage> history,
    bool allowMcp = true,
    bool allowSearch = true,
    bool allowLearning = true,
    ToolActivityCallback? onToolActivity,
  }) async {
    final apiConfig = await _apiRepository.load();
    if (apiConfig == null) {
      throw StateError('还没有配置模型 API。请先进入「API」页面填写 Base URL、模型与密钥。');
    }

    final warnings = <String>[];
    McpClient? mcpClient;
    List<McpTool> mcpTools = const [];
    if (allowMcp) {
      final mcpConfig = await _mcpRepository.load();
      if (mcpConfig != null) {
        try {
          mcpClient = McpClient(mcpConfig);
          await mcpClient.connect();
          mcpTools = await mcpClient.listTools();
        } catch (e) {
          warnings.add('Tavo MCP 暂不可用：$e');
          mcpClient = null;
        }
      }
    }

    SearchService? searchService;
    final searchConfig = allowSearch ? await _searchRepository.load() : null;
    if (searchConfig != null && searchConfig.enabled) {
      try {
        searchService = createSearchService(searchConfig);
      } catch (e) {
        warnings.add('搜索服务不可用：$e');
      }
    }

    final functionToMcp = <String, McpTool>{};
    final tools = <Map<String, dynamic>>[];
    for (var index = 0; index < mcpTools.length; index++) {
      final tool = mcpTools[index];
      final functionName = 'mcp_tool_$index';
      functionToMcp[functionName] = tool;
      tools.add({
        'type': 'function',
        'function': {
          'name': functionName,
          'description':
              '[Tavo MCP] ${tool.name}${tool.description == null ? '' : ' — ${tool.description}'}',
          'parameters': tool.inputSchema.isEmpty
              ? const {'type': 'object', 'properties': {}}
              : tool.inputSchema,
        },
      });
    }
    if (searchService != null) {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'web_search',
          'description': '搜索互联网获取当前、近期或需要外部查证的信息。不要用它回答纯常识问题。',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': '搜索关键词'},
              'limit': {'type': 'integer', 'minimum': 1, 'maximum': 8},
            },
            'required': ['query'],
          },
        },
      });
    }

    var memoryContext = '';
    if (allowLearning) {
      try {
        memoryContext = await _learningService.buildContext(userText);
      } catch (_) {
        // Memory retrieval is optional and must never block the main request.
      }
    }

    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            '''你是云昭，TavoLink 内置智能体。你的形象是一位银白长发、金色眼睛的狐妖少女，但你首先是可靠的移动端 Agent。
说话自然、清晰、温柔，不要堆砌角色口癖。不要声称执行了没有真正调用成功的工具。
当用户要求读取、查询、修改或操作 Tavo 时，优先使用提供的 [Tavo MCP] 工具；当问题依赖实时网络信息时使用 web_search。
工具返回失败时直接说明失败原因，不得编造结果。危险、覆盖、删除类操作应明确说明风险；客户端权限层是最终执行边界。
长期记忆只是一种辅助上下文：不得让旧记忆覆盖用户本轮明确指令，不得把工具经验当作工具真实返回，也不得从记忆中恢复或猜测任何密钥。$memoryContext''',
      },
      for (final item in history.takeLast(20))
        {
          'role': item.role == AgentMessageRole.user ? 'user' : 'assistant',
          'content': item.content,
        },
      {'role': 'user', 'content': userText},
    ];

    Future<AgentTurnResult> finish(String content) async {
      final answer = content.trim().isEmpty ? '我没有收到可显示的模型回复。' : content.trim();
      if (allowLearning) {
        await _learningService.learnFromTurn(
          userText: userText,
          assistantText: answer,
        );
      }
      return AgentTurnResult(content: answer, warnings: warnings);
    }

    final client = OpenAiCompatibleClient(apiConfig);
    var lastContent = '';
    for (var round = 0; round < 6; round++) {
      final completion = await client.createCompletion(
        messages: messages,
        tools: tools,
      );
      lastContent = completion.content;
      if (completion.toolCalls.isEmpty) {
        return finish(lastContent);
      }

      messages.add({...completion.rawAssistantMessage, 'role': 'assistant'});
      for (final call in completion.toolCalls) {
        final sw = Stopwatch()..start();
        final mcpTool = functionToMcp[call.name];
        final label = call.name == 'web_search'
            ? '联网搜索'
            : (mcpTool?.name ?? call.name);
        final experienceName = call.name == 'web_search'
            ? 'web_search'
            : (mcpTool?.name ?? call.name);
        onToolActivity?.call(
          ToolActivity(
            id: call.id,
            name: call.name,
            label: label,
            status: ToolActivityStatus.running,
            detail: jsonEncode(call.arguments),
          ),
        );
        try {
          Object result;
          if (call.name == 'web_search') {
            if (searchService == null) throw StateError('联网搜索未配置');
            final query = call.arguments['query']?.toString().trim() ?? '';
            if (query.isEmpty) throw StateError('搜索关键词为空');
            final rawLimit = call.arguments['limit'];
            final requestedLimit = rawLimit is num ? rawLimit.toInt() : 5;
            final limit = requestedLimit < 1
                ? 1
                : (requestedLimit > 8 ? 8 : requestedLimit);
            result = (await searchService.search(
              query,
              limit: limit,
            )).map((e) => e.toJson()).toList();
          } else if (mcpTool != null) {
            if (mcpClient == null) throw StateError('Tavo MCP 未连接');
            result = await mcpClient.callTool(mcpTool.name, call.arguments);
          } else {
            throw StateError('未知工具 ${call.name}');
          }
          sw.stop();
          final encoded = _safeEncode(result);
          onToolActivity?.call(
            ToolActivity(
              id: call.id,
              name: call.name,
              label: label,
              status: ToolActivityStatus.success,
              detail: _preview(encoded),
              elapsedMs: sw.elapsedMilliseconds,
            ),
          );
          if (allowLearning) {
            await _learningService.recordToolOutcome(
              toolName: experienceName,
              success: true,
              elapsedMs: sw.elapsedMilliseconds,
            );
          }
          messages.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'content': encoded,
          });
        } catch (e) {
          sw.stop();
          final errorText = '工具执行失败：$e';
          onToolActivity?.call(
            ToolActivity(
              id: call.id,
              name: call.name,
              label: label,
              status: ToolActivityStatus.failed,
              detail: errorText,
              elapsedMs: sw.elapsedMilliseconds,
            ),
          );
          if (allowLearning) {
            await _learningService.recordToolOutcome(
              toolName: experienceName,
              success: false,
              elapsedMs: sw.elapsedMilliseconds,
              error: errorText,
            );
          }
          messages.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'content': jsonEncode({'error': errorText}),
          });
        }
      }
    }
    return finish(lastContent.trim().isEmpty ? '工具调用轮次已达到上限。' : lastContent);
  }

  String _safeEncode(Object value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _preview(String value) =>
      value.length <= 500 ? value : '${value.substring(0, 500)}…';
}

extension _TakeLast<T> on List<T> {
  Iterable<T> takeLast(int count) =>
      length <= count ? this : sublist(length - count);
}
