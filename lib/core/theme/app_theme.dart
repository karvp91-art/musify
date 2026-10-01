import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static final ThemeData lightTheme = _buildLightTheme();
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.limeAccentDark,
      secondary: AppColors.limeAccentDark,
      primaryContainer: AppColors.neonLime,
      onPrimaryContainer: Colors.black,
      surface: AppColors.surfaceLight,
      surfaceContainerHighest: AppColors.surfacePillLight,
      error: AppColors.errorLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.onSurfaceLight,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.onSurfaceLight),
        titleTextStyle: TextStyle(
          color: AppColors.onSurfaceLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.limeAccentDark,
        inactiveTrackColor: AppColors.dividerLight,
        thumbColor: AppColors.limeAccentDark,
        overlayColor: AppColors.limeAccentDarkGlow,
        trackHeight: 3.5,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: Colors.black,
        unselectedItemColor: AppColors.onSurfaceMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfacePillLight,
        selectedColor: AppColors.neonLime,
        disabledColor: Colors.grey.shade200,
        labelStyle: const TextStyle(
          color: Color(0xFF1E2028),
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const StadiumBorder(side: BorderSide.none),
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
      ),
      textTheme: _buildTextTheme(
        primaryColor: AppColors.onSurfaceLight,
        mutedColor: AppColors.onSurfaceMutedLight,
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.neonLime,
      secondary: AppColors.neonLime,
      surface: AppColors.surfaceDark,
      surfaceContainerHighest: AppColors.surfacePillDark,
      error: AppColors.errorDark,
      onPrimary: Color(0xFF0E0F14),
      onSecondary: Color(0xFF0E0F14),
      onSurface: AppColors.onSurfaceDark,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.black,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.onSurfaceDark),
        titleTextStyle: TextStyle(
          color: AppColors.onSurfaceDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.neonLime,
        inactiveTrackColor: Color(0xFF262935),
        thumbColor: AppColors.neonLime,
        overlayColor: AppColors.neonLimeGlow,
        trackHeight: 3.5,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.neonLime,
        unselectedItemColor: AppColors.onSurfaceMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfacePillDark,
        selectedColor: AppColors.neonLime,
        disabledColor: Colors.grey.shade800,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const StadiumBorder(side: BorderSide.none),
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
      ),
      textTheme: _buildTextTheme(
        primaryColor: AppColors.onSurfaceDark,
        mutedColor: AppColors.onSurfaceMutedDark,
      ),
    );
  }

  static TextTheme _buildTextTheme({
    required Color primaryColor,
    required Color mutedColor,
  }) {
    return TextTheme(
      headlineLarge: AppTypography.headlineLarge.copyWith(color: primaryColor, fontWeight: FontWeight.bold),
      headlineSmall: AppTypography.headlineSmall.copyWith(color: primaryColor, fontWeight: FontWeight.bold),
      titleLarge: AppTypography.headlineSmall.copyWith(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: AppTypography.bodyLarge.copyWith(color: primaryColor, fontWeight: FontWeight.w600),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: primaryColor),
      bodySmall: AppTypography.bodySmall.copyWith(color: mutedColor),
      labelSmall: AppTypography.caption.copyWith(color: mutedColor),
      labelLarge: AppTypography.button.copyWith(color: primaryColor),
    );
  }
}
