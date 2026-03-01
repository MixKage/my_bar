import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class StretchedDotsLoader extends StatelessWidget {
  const StretchedDotsLoader({
    required this.size,
    required this.color,
    super.key,
    this.backgroundColor = Colors.transparent,
  });

  final double size;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: LoadingAnimationWidget.stretchedDots(color: color, size: size),
      ),
    );
  }
}
