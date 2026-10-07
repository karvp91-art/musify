import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static final TextStyle headlineLarge = GoogleFonts.plusJakartaSans(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      );

  static final TextStyle headlineSmall = GoogleFonts.plusJakartaSans(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      );

  static final TextStyle bodyLarge = GoogleFonts.plusJakartaSans(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  static final TextStyle bodyMedium = GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        height: 20 / 14.5,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.15,
      );

  static final TextStyle bodySmall = GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        height: 18 / 13.5,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
      );

  static final TextStyle caption = GoogleFonts.plusJakartaSans(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      );

  static final TextStyle button = GoogleFonts.plusJakartaSans(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      );

  /// Factory helper for creating custom Plus Jakarta Sans styles matching the app typography system
  static TextStyle style({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        decoration: decoration,
      );
}
