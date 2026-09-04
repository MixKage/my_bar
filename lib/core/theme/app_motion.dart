import 'package:flutter/material.dart';

/// Shared motion rules for transitions that communicate a state change.
///
/// Motion is disabled when the app is saving power or when the operating
/// system asks applications to reduce animations.
abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasized = Duration(milliseconds: 360);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedCurve = Curves.easeOutBack;

  static bool isEnabled(BuildContext context, {bool powerSavingMode = false}) {
    return !powerSavingMode && !MediaQuery.disableAnimationsOf(context);
  }

  static Duration duration(
    BuildContext context,
    Duration preferred, {
    bool powerSavingMode = false,
  }) {
    return isEnabled(context, powerSavingMode: powerSavingMode)
        ? preferred
        : Duration.zero;
  }
}
