import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
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
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlight
                  ? [TavoPalette.blue.withValues(alpha: .18), TavoPalette.violet.withValues(alpha: .10), const Color(0xB30C1730)]
                  : [Colors.white.withValues(alpha: .075), const Color(0xAA0B1630)],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: highlight ? TavoPalette.blue.withValues(alpha: .45) : TavoPalette.line),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 34, offset: Offset(0, 18))],
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(radius), child: card));
  }
}
