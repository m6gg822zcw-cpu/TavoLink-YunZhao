import 'package:flutter/material.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';

class YunZhaoAvatar extends StatelessWidget {
  const YunZhaoAvatar({this.size = 42, this.showGlow = true, super.key});
  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .035),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [TavoPalette.gold, TavoPalette.sakura, TavoPalette.violet],
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: TavoPalette.violet.withValues(alpha: .34),
                  blurRadius: size * .45,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/yunzhao_hero_v2.png',
          fit: BoxFit.cover,
          alignment: const Alignment(.20, -.54),
        ),
      ),
    );
  }
}
