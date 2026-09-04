import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';

/// Shared press/focus treatment without Material ink ripples.
class BarPressable extends StatefulWidget {
  const BarPressable({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.powerSavingMode = false,
    this.selected,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final bool powerSavingMode;
  final bool? selected;

  @override
  State<BarPressable> createState() => _BarPressableState();
}

class _BarPressableState extends State<BarPressable> {
  bool _pressed = false;
  bool _focused = false;

  void _press(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: enabled ? (_) => _press(true) : null,
          onTapUp: enabled ? (_) => _press(false) : null,
          onTapCancel: () => _press(false),
          child: AnimatedScale(
            scale: _pressed && enabled ? 0.97 : 1,
            duration: AppMotion.duration(
              context,
              AppMotion.quick,
              powerSavingMode: widget.powerSavingMode,
            ),
            child: AnimatedContainer(
              duration: AppMotion.duration(
                context,
                AppMotion.quick,
                powerSavingMode: widget.powerSavingMode,
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                color: _pressed ? const Color(0x188FA3FF) : Colors.transparent,
                border: _focused
                    ? Border.all(color: const Color(0xFF8FA3FF), width: 2)
                    : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The same compact, softly glowing action style used on the About screen.
class BarActionButton extends StatelessWidget {
  const BarActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.powerSavingMode = false,
    this.foregroundColor = Colors.white,
    this.backgroundColor = const Color(0xFF5C63FF),
    this.borderColor,
    this.glowColor = const Color(0x335C63FF),
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool powerSavingMode;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color? borderColor;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return BarPressable(
      onTap: onPressed,
      powerSavingMode: powerSavingMode,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!),
            boxShadow: powerSavingMode || glowColor == null
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: glowColor!,
                      blurRadius: 12,
                      spreadRadius: 0.6,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: foregroundColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BarHeaderButton extends StatelessWidget {
  const BarHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.powerSavingMode = false,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool powerSavingMode;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: BarPressable(
        onTap: onPressed,
        powerSavingMode: powerSavingMode,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF303047),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 24, color: const Color(0xFFD2DEFF)),
          ),
        ),
      ),
    );
  }
}
