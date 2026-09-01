import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tavolink/core/theme/tavo_theme.dart';

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                TavoPalette.ink,
                Color(0xFF081536),
                TavoPalette.midnight,
                Color(0xFF090A22),
              ],
              stops: [0, .38, .74, 1],
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _StarPainter())),
        ),
        Positioned(
          top: -130,
          right: -90,
          child: _Glow(
            size: 340,
            color: TavoPalette.violet.withValues(alpha: .22),
          ),
        ),
        Positioned(
          top: 210,
          left: -180,
          child: _Glow(
            size: 390,
            color: TavoPalette.blue.withValues(alpha: .16),
          ),
        ),
        Positioned(
          bottom: -180,
          right: -30,
          child: _Glow(
            size: 400,
            color: TavoPalette.sakura.withValues(alpha: .08),
          ),
        ),
        const Positioned(right: -38, top: 80, child: _FoxFire()),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 78, sigmaY: 78),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _FoxFire extends StatelessWidget {
  const _FoxFire();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -.18,
      child: Icon(
        Icons.local_fire_department_rounded,
        size: 150,
        color: TavoPalette.violet.withValues(alpha: .055),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    for (var i = 0; i < 58; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = random.nextDouble() * 1.25 + .25;
      final alpha = random.nextDouble() * .35 + .12;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
