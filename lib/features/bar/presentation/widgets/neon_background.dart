import 'package:flutter/material.dart';

class NeonBackground extends StatelessWidget {
  const NeonBackground({
    required this.child,
    required this.topGlow,
    required this.bottomGlow,
    super.key,
  });

  final Widget child;
  final Color topGlow;
  final Color bottomGlow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF04060E),
                Color(0xFF080B16),
                Color(0xFF0C1020),
              ],
            ),
          ),
        ),
        Positioned(top: -80, left: -10, child: _GlowBlob(color: topGlow)),
        Positioned(right: -50, bottom: 40, child: _GlowBlob(color: bottomGlow)),
        child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 100,
            spreadRadius: 14,
          ),
        ],
      ),
    );
  }
}
