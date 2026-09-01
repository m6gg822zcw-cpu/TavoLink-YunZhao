import 'package:flutter/material.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.highlight = false,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: highlight
                ? const [
                    Color(0xE42B416A),
                    Color(0xE51B2350),
                    Color(0xF00A1630),
                  ]
                : const [Color(0xE2344566), Color(0xF00A1530)],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: highlight
                ? TavoPalette.blue.withValues(alpha: .45)
                : TavoPalette.blue.withValues(alpha: .22),
            width: highlight ? 1.15 : .85,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}
