import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';

class ConfigTabs extends StatelessWidget {
  const ConfigTabs({required this.searchSelected, super.key});

  final bool searchSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TavoPalette.midnight.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TavoPalette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: 'API 配置',
              icon: Icons.key_rounded,
              selected: !searchSelected,
              onTap: () => context.go('/providers'),
            ),
          ),
          Expanded(
            child: _Tab(
              label: '搜索设置',
              icon: Icons.travel_explore_rounded,
              selected: searchSelected,
              onTap: () => context.go('/search'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TavoPalette.text : TavoPalette.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      TavoPalette.blue.withValues(alpha: .34),
                      TavoPalette.violet.withValues(alpha: .24),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: TavoPalette.blue.withValues(alpha: .35))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
