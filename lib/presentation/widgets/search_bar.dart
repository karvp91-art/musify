import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Universal optical glass settings for Liquid Glass platters (MiniPlayer, AppShell dock, SearchBar, etc.)
LiquidGlassSettings resolveGlassSettings({required bool isDark}) {
  return isDark
      ? const LiquidGlassSettings(
          thickness: 30.0,
          blur: 3.0,                  // Ultra-low blur preserves sharp background refraction
          chromaticAberration: 0.30,  // Spectral prism edges
          lightIntensity: 0.65,       // Specular rim reflection
          ambientStrength: 1.0,
          refractiveIndex: 1.59,      // Polycarbonate optical refraction
          saturation: 0.70,
          lightAngle: 0.75 * math.pi, // 135° Apple standard upper-left key light
          glassColor: Color(0x2EFFFFFF),
          specularSharpness: GlassSpecularSharpness.sharp,
        )
      : const LiquidGlassSettings(
          thickness: 28.0,
          blur: 3.0,
          chromaticAberration: 0.25,
          lightIntensity: 0.60,
          ambientStrength: 1.0,
          refractiveIndex: 1.55,
          saturation: 0.85,
          lightAngle: 0.75 * math.pi,
          glassColor: Color(0x24FFFFFF), // Luminous sheer white tint
          specularSharpness: GlassSpecularSharpness.medium,
        );
}

/// Backwards compatibility alias for search bar consumers
LiquidGlassSettings resolveSearchBarGlassSettings({required bool isDark}) =>
    resolveGlassSettings(isDark: isDark);

/// Compact search trigger. No flat grey fill: uses a sheer white "lens" tint
/// so the glass underneath stays clear and the rim highlight is preserved.
class GlassSearchTrigger extends StatelessWidget {
  final VoidCallback onTap;
  final String hintText;
  final double height;

  const GlassSearchTrigger({
    super.key,
    required this.onTap,
    this.hintText = 'Search library...',
    this.height = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          // Sheer white wash instead of black: brightens, never muddies.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.06),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.30),
                  ],
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 19,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : const Color(0xFF111827).withValues(alpha: 0.75),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hintText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.70)
                      : const Color(0xFF111827).withValues(alpha: 0.62),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The active search field content featuring high-contrast frosted action orbs,
/// animated clear button, and text scale clamping.
class GlassSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final String hintText;
  final bool autofocus;

  const GlassSearchField({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onClear,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Search songs, artists, albums...',
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        // 1. Back Navigation Orb (MiniPlayer Action Orb Standard: 38x38)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onBack();
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.90)
                  : const Color(0xFF1E2028),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // 2. High-Contrast Text Input
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF111827),
              decoration: TextDecoration.none,
            ),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: isDark
                    ? Colors.white38
                    : const Color(0xFF555B6E).withValues(alpha: 0.6),
                decoration: TextDecoration.none,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),

        // 3. Animated Clear Button Orb
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                onClear();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A standalone or embeddable floating liquid glass search bar platter.
/// Adheres strictly to the mini-player-glass-ui architectural pattern:
/// - Wrapped in Material(type: MaterialType.transparency) to prevent yellow underline bugs
/// - Clamped text scaling (maxScaleFactor: 1.15) to guarantee zero RenderFlex overflow
/// - Ambient diffuse shadow with zero hard border outlines
/// - Low-blur refractive Impeller liquid glass optics
class GlassSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onBack;
  final String hintText;
  final bool isExpanded;
  final VoidCallback? onExpand;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final double borderRadius;

  const GlassSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onBack,
    this.hintText = 'Search library...',
    this.isExpanded = false,
    this.onExpand,
    this.leading,
    this.trailing,
    this.height = 64.0,          // was 56, gives the glass more depth to refract
    this.borderRadius = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: GlassContainer(
            useOwnLayer: true,
            quality: GlassQuality.premium,
            clipBehavior: Clip.antiAlias,
            // Same padding as MiniPlayer
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
            settings: resolveSearchBarGlassSettings(isDark: isDark),
            child: isExpanded
                ? GlassSearchField(
                    controller: controller,
                    focusNode: focusNode,
                    hintText: hintText,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    onBack: () => onBack?.call(),
                    onClear: () {
                      controller.clear();
                      onClear?.call();
                    },
                  )
                : Row(
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: 8)],
                      Expanded(
                        child: GlassSearchTrigger(
                          hintText: hintText,
                          onTap: () => onExpand?.call(),
                        ),
                      ),
                      if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
