import 'dart:ui';

import 'package:animated_border_widgets/animated_border_widgets.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';

const double kNeonBottomNavigationHeight = 74;
const double kNeonBottomNavigationHorizontalPadding = 16;
const double kNeonBottomNavigationBottomMargin = 22;
const double kNeonSideNavigationWidth = 106;
const double kNeonSideNavigationPanelHeight = 204;

class NeonBottomNavigation extends StatelessWidget {
  const NeonBottomNavigation({
    required this.currentIndex,
    required this.onChanged,
    this.powerSavingMode = false,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final bool powerSavingMode;

  @override
  Widget build(BuildContext context) {
    final borderChild = AnimatedGradientBorder(
      enabled: !powerSavingMode,
      borderRadius: BorderRadius.circular(24),
      borderWidth: 1.5,
      innerColor: const Color(0xCC111425),
      colors: const <Color>[
        Color(0xFFAE7BFF),
        Color(0xFF63CBFF),
        Color(0xFFAE7BFF),
      ],
      glowEffect: !powerSavingMode,
      glow: const AnimatedGradientBorderGlow(opacity: 0.45),
      child: SizedBox(
        height: kNeonBottomNavigationHeight,
        child: Row(
          children: <Widget>[
            _NavItem(
              selected: currentIndex == 0,
              icon: Icons.liquor_rounded,
              title: context.tr('Ингридиенты', 'Ingredients'),
              onTap: () => onChanged(0),
            ),
            _NavItem(
              selected: currentIndex == 1,
              icon: Icons.local_bar_rounded,
              title: context.tr('Барная карта', 'Bar Menu'),
              onTap: () => onChanged(1),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        kNeonBottomNavigationHorizontalPadding,
        0,
        kNeonBottomNavigationHorizontalPadding,
        kNeonBottomNavigationBottomMargin,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: powerSavingMode
            ? borderChild
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: borderChild,
              ),
      ),
    );
  }
}

class NeonSideNavigation extends StatelessWidget {
  const NeonSideNavigation({
    required this.currentIndex,
    required this.onChanged,
    this.powerSavingMode = false,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final bool powerSavingMode;

  @override
  Widget build(BuildContext context) {
    final borderChild = AnimatedGradientBorder(
      enabled: !powerSavingMode,
      borderRadius: BorderRadius.circular(24),
      borderWidth: 1.5,
      innerColor: const Color(0xCC111425),
      colors: const <Color>[
        Color(0xFFAE7BFF),
        Color(0xFF63CBFF),
        Color(0xFFAE7BFF),
      ],
      glowEffect: !powerSavingMode,
      glow: const AnimatedGradientBorderGlow(opacity: 0.45),
      child: SizedBox(
        width: kNeonSideNavigationWidth,
        height: kNeonSideNavigationPanelHeight,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _NavItem(
                selected: currentIndex == 0,
                icon: Icons.liquor_rounded,
                title: context.tr('Ингридиенты', 'Ingredients'),
                onTap: () => onChanged(0),
                axis: Axis.vertical,
              ),
            ),
            Expanded(
              child: _NavItem(
                selected: currentIndex == 1,
                icon: Icons.local_bar_rounded,
                title: context.tr('Барная карта', 'Bar Menu'),
                onTap: () => onChanged(1),
                axis: Axis.vertical,
              ),
            ),
          ],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: powerSavingMode
          ? borderChild
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: borderChild,
            ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.axis = Axis.horizontal,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Axis axis;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final targetForegroundColor = widget.selected
        ? Colors.white
        : const Color(0xFF98A6D2);
    final pressedOverlayBase = widget.selected
        ? const Color(0x3A95A6FF)
        : const Color(0x1F95A6FF);
    final selectedBackgroundColor = widget.selected
        ? const Color(0x2D95A6FF)
        : Colors.transparent;
    final selectedShadowColor = widget.selected
        ? const Color(0x55598DFF)
        : Colors.transparent;

    final isVertical = widget.axis == Axis.vertical;
    final itemChild = Semantics(
      button: true,
      selected: widget.selected,
      label: widget.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          scale: _pressed ? 0.97 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            margin: isVertical
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
                : const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selectedBackgroundColor,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: selectedShadowColor,
                  blurRadius: widget.selected ? 16 : 12,
                  spreadRadius: widget.selected ? 1 : 0,
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: _pressed ? pressedOverlayBase : Colors.transparent,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TweenAnimationBuilder<Color?>(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    tween: ColorTween(end: targetForegroundColor),
                    builder: (context, color, _) {
                      return Icon(
                        widget.icon,
                        color: color ?? targetForegroundColor,
                      );
                    },
                  ),
                  const SizedBox(height: 3),
                  TweenAnimationBuilder<Color?>(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    tween: ColorTween(end: targetForegroundColor),
                    builder: (context, color, _) {
                      return Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        maxLines: isVertical ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color ?? targetForegroundColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (isVertical) {
      return itemChild;
    }

    return Expanded(child: itemChild);
  }
}
