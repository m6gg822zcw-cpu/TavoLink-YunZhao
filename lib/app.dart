import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/features/chat/chat_page.dart';
import 'package:tavolink/features/home/home_page.dart';
import 'package:tavolink/features/learning/learning_page.dart';
import 'package:tavolink/features/mcp/mcp_page.dart';
import 'package:tavolink/features/mcp/mcp_developer_page.dart';
import 'package:tavolink/features/providers/providers_page.dart';
import 'package:tavolink/features/search/search_page.dart';
import 'package:tavolink/features/settings/settings_page.dart';
import 'package:tavolink/features/shell/app_shell.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(path: '/chat', builder: (_, _) => const ChatPage()),
        GoRoute(path: '/mcp', builder: (_, _) => const McpPage()),
        GoRoute(path: '/mcp/develop', builder: (_, _) => const McpDeveloperPage()),
        GoRoute(path: '/providers', builder: (_, _) => const ProvidersPage()),
        GoRoute(path: '/search', builder: (_, _) => const SearchPage()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        GoRoute(path: '/learning', builder: (_, _) => const LearningPage()),
      ],
    ),
  ],
);

class TavoLinkApp extends StatelessWidget {
  const TavoLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'TavoLink · 云昭',
      theme: TavoTheme.dark,
      routerConfig: _router,
    );
  }
}
