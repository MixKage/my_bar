import 'dart:ui';

import 'package:animated_border_widgets/animated_border_widgets.dart';
import 'package:flutter/material.dart';

class NeonBottomNavigation extends StatelessWidget {
  const NeonBottomNavigation({
    required this.currentIndex,
    required this.onChanged,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedGradientBorder(
            borderRadius: BorderRadius.circular(24),
            borderWidth: 1.5,
            innerColor: const Color(0xCC111425),
            colors: const <Color>[
              Color(0xFFAE7BFF),
              Color(0xFF63CBFF),
              Color(0xFFAE7BFF),
            ],
            glowEffect: true,
            glow: const AnimatedGradientBorderGlow(opacity: 0.45),
            child: SizedBox(
              height: 74,
              child: Row(
                children: <Widget>[
                  _NavItem(
                    selected: currentIndex == 0,
                    icon: Icons.liquor_rounded,
                    title: 'Ингридиенты',
                    onTap: () => onChanged(0),
                  ),
                  _NavItem(
                    selected: currentIndex == 1,
                    icon: Icons.local_bar_rounded,
                    title: 'Барная карта',
                    onTap: () => onChanged(1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? const Color(0x2D95A6FF) : Colors.transparent,
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x55598DFF),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: const Color(0x3395A6FF),
            highlightColor: const Color(0x1F95A6FF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  color: selected ? Colors.white : const Color(0xFF98A6D2),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF98A6D2),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
