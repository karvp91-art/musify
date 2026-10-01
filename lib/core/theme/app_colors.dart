import 'package:flutter/material.dart';

class AppColors {
  // Ultra-modern Neon Lime / Chartreuse Strategy (matching reference UI)
  static const Color neonLime = Color(0xFFD2F843);
  static const Color neonLimeDim = Color(0xFFB5DB2A);
  static const Color neonLimeGlow = Color(0x33D2F843);

  // High-contrast vibrant chartreuse for Light Theme (WCAG AA compliant 4.9:1 on white)
  static const Color limeAccentDark = Color(0xFF527E03);
  static const Color limeAccentDarkGlow = Color(0x33527E03);

  static const Color accentLight = Color(0xFF527E03);
  static const Color accentDark = Color(0xFFD2F843);

  // Surfaces & Backgrounds
  static const Color backgroundLight = Colors.white;
  static const Color backgroundDark = Color(0xFF0E0F14);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF16171E);

  static const Color surfaceCardLight = Color(0xFFECEEF2);
  static const Color surfaceCardDark = Color(0xFF1D1F27);

  static const Color surfacePillLight = Color(0xFFECEEF2);
  static const Color surfacePillDark = Color(0xFF20222B);

  static const Color circleButtonLight = Color(0xFFECEEF2);
  static const Color circleButtonDark = Color(0xFF20222B);

  // Text & Content
  static const Color onSurfaceLight = Color(0xFF121316);
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color onSurfaceMutedLight = Color(0xFF717584);
  static const Color onSurfaceMutedDark = Color(0xFF8E92A2);

  // Dividers & Borders
  static const Color dividerLight = Color(0xFFE4E7EE);
  static const Color dividerDark = Color(0xFF1F222C);

  // Semantics
  static const Color errorLight = Color(0xFFE74C3C);
  static const Color errorDark = Color(0xFFFF5252);
  static const Color successLight = Color(0xFF27AE60);
  static const Color successDark = Color(0xFFD2F843);
}
