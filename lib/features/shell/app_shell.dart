import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';
import 'package:tavolink/core/widgets/aurora_background.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});
  final Widget child;

  static const paths = ['/', '/chat', '/mcp', '/providers', '/search'];

  void _go(BuildContext context, int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    context.go(paths[index]);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    var index = location.startsWith('/mcp/') ? 2 : paths.indexOf(location);
    if (index < 0) index = 0;

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(bottom: false, child: child),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(10, 0, 10, 9),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TavoPalette.midnight.withValues(alpha: .97),
                  const Color(0xFF091530).withValues(alpha: .97),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: TavoPalette.line),
              boxShadow: [
                BoxShadow(
                  color: TavoPalette.violet.withValues(alpha: .12),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: NavigationBar(
              height: 66,
              backgroundColor: Colors.transparent,
              indicatorColor: TavoPalette.violet.withValues(alpha: .18),
              selectedIndex: index,
              onDestinationSelected: (i) => _go(context, i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_rounded),
                  selectedIcon: Icon(
                    Icons.home_rounded,
                    color: TavoPalette.gold,
                  ),
                  label: '首页',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(
                    Icons.chat_bubble_rounded,
                    color: TavoPalette.cyan,
                  ),
                  label: '对话',
                ),
                NavigationDestination(
                  icon: Icon(Icons.hub_outlined),
                  selectedIcon: Icon(
                    Icons.hub_rounded,
                    color: TavoPalette.cyan,
                  ),
                  label: 'MCP',
                ),
                NavigationDestination(
                  icon: Icon(Icons.key_outlined),
                  selectedIcon: Icon(
                    Icons.key_rounded,
                    color: TavoPalette.violet,
                  ),
                  label: 'API',
                ),
                NavigationDestination(
                  icon: Icon(Icons.travel_explore_outlined),
                  selectedIcon: Icon(
                    Icons.travel_explore_rounded,
                    color: TavoPalette.sakura,
                  ),
                  label: '搜索',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
