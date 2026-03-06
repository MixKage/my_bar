import 'package:flutter/material.dart';

class NeonScrollbar extends StatelessWidget {
  const NeonScrollbar({
    required this.controller,
    required this.child,
    this.visibility = 1,
    super.key,
  }) : assert(visibility >= 0 && visibility <= 1);

  final ScrollController controller;
  final Widget child;
  final double visibility;

  @override
  Widget build(BuildContext context) {
    final thumbColor = Color.lerp(
      Colors.transparent,
      const Color(0xCC8A78FF),
      visibility,
    )!;
    final trackColor = Color.lerp(
      Colors.transparent,
      const Color(0x3344537F),
      visibility,
    )!;
    final trackBorderColor = Color.lerp(
      Colors.transparent,
      const Color(0x665F74C7),
      visibility,
    )!;

    return RawScrollbar(
      controller: controller,
      notificationPredicate: (_) => true,
      thumbVisibility: visibility > 0.01,
      interactive: visibility > 0.01,
      scrollbarOrientation: ScrollbarOrientation.right,
      radius: const Radius.circular(999),
      thickness: 5.2,
      thumbColor: thumbColor,
      trackVisibility: visibility > 0.01,
      trackColor: trackColor,
      trackBorderColor: trackBorderColor,
      child: child,
    );
  }
}
