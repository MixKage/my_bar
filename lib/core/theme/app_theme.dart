import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF070911),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      chipTheme: base.chipTheme.copyWith(
        checkmarkColor: Colors.white,
        selectedColor: const Color(0x554F63CC),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
      ),
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
        displaySmall: GoogleFonts.orbitron(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        titleLarge: GoogleFonts.orbitron(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        triggerMode: TooltipTriggerMode.longPress,
        waitDuration: const Duration(milliseconds: 420),
        showDuration: const Duration(milliseconds: 2200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: GoogleFonts.manrope(
          color: const Color(0xFFE9EEFF),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        decoration: BoxDecoration(
          color: const Color(0xEE11152A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x88798CFF), width: 1.1),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66A16BFF),
              blurRadius: 16,
              spreadRadius: 0.8,
            ),
            BoxShadow(
              color: Color(0x553FCBFF),
              blurRadius: 14,
              spreadRadius: 0.6,
            ),
          ],
        ),
      ),
    );
  }
}
