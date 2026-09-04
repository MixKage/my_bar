import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_motion.dart';

class PortionSelector extends StatelessWidget {
  const PortionSelector({
    required this.servings,
    required this.onChanged,
    this.compact = false,
    this.powerSavingMode = false,
    super.key,
  });

  final int servings;
  final ValueChanged<int> onChanged;
  final bool compact;
  final bool powerSavingMode;

  @override
  Widget build(BuildContext context) {
    final normalizedServings = servings.clamp(1, 50);
    return Semantics(
      label: context.tr(
        'Количество порций: $normalizedServings',
        'Servings: $normalizedServings',
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF11162A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x555F74BD)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              visualDensity: compact ? VisualDensity.compact : null,
              tooltip: context.tr('Уменьшить', 'Decrease'),
              onPressed: normalizedServings > 1
                  ? () {
                      HapticFeedback.selectionClick();
                      onChanged(normalizedServings - 1);
                    }
                  : null,
              icon: const Icon(Icons.remove_rounded, size: 19),
            ),
            AnimatedSwitcher(
              duration: AppMotion.duration(
                context,
                AppMotion.quick,
                powerSavingMode: powerSavingMode,
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Text(
                context.tr(
                  '$normalizedServings порц.',
                  '$normalizedServings serv.',
                ),
                key: ValueKey<int>(normalizedServings),
                style: const TextStyle(
                  color: Color(0xFFE5EAFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              visualDensity: compact ? VisualDensity.compact : null,
              tooltip: context.tr('Увеличить', 'Increase'),
              onPressed: normalizedServings < 50
                  ? () {
                      HapticFeedback.selectionClick();
                      onChanged(normalizedServings + 1);
                    }
                  : null,
              icon: const Icon(Icons.add_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}
