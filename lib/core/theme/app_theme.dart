import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF070911),
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
    );
  }
}
