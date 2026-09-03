import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';

class PortionSelector extends StatelessWidget {
  const PortionSelector({
    required this.servings,
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  final int servings;
  final ValueChanged<int> onChanged;
  final bool compact;

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
                  ? () => onChanged(normalizedServings - 1)
                  : null,
              icon: const Icon(Icons.remove_rounded, size: 19),
            ),
            Text(
              context.tr(
                '$normalizedServings порц.',
                '$normalizedServings serv.',
              ),
              style: const TextStyle(
                color: Color(0xFFE5EAFF),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            IconButton(
              visualDensity: compact ? VisualDensity.compact : null,
              tooltip: context.tr('Увеличить', 'Increase'),
              onPressed: normalizedServings < 50
                  ? () => onChanged(normalizedServings + 1)
                  : null,
              icon: const Icon(Icons.add_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}
