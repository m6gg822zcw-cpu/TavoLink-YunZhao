import 'package:flutter/material.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, this.active = true, this.icon, super.key});
  final String label;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = active ? TavoPalette.jade : TavoPalette.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: color.withValues(alpha: .10),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? (active ? Icons.check_circle_rounded : Icons.circle_outlined), color: color, size: 13),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
