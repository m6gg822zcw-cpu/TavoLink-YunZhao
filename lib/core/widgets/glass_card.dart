import 'dart:ui';
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlight
                  ? [
                      TavoPalette.blue.withValues(alpha: .20),
                      TavoPalette.violet.withValues(alpha: .12),
                      const Color(0xC20A1630),
                    ]
                  : [
                      Colors.white.withValues(alpha: .085),
                      const Color(0xC20A1530),
                    ],
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
                color: Color(0x33000000),
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
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
