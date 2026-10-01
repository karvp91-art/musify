import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:musify/core/theme/app_colors.dart';

class TrackArtwork extends StatelessWidget {
  final String? artworkUrl;
  final String? seedKey;
  final double size;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isCircle;
  final bool ambientGlow;
  final IconData fallbackIcon;

  // Curated theme-harmonized gradient palettes for Dark Mode
  // Deep obsidian, slate, forest, jade, olive, and chartreuse noir tones
  static const List<List<Color>> darkGradientPalettes = [
    // 1. Deep Forest Charcoal
    [Color(0xFF132019), Color(0xFF1E3226)],
    // 2. Dark Slate & Gunmetal
    [Color(0xFF181B22), Color(0xFF262C38)],
    // 3. Olive Bronze & Chartreuse Noir
    [Color(0xFF1C2213), Color(0xFF2F3A1D)],
    // 4. Muted Jade Slate
    [Color(0xFF13211F), Color(0xFF1F3532)],
    // 5. Deep Moss & Pine
    [Color(0xFF162319), Color(0xFF243B2A)],
    // 6. Charcoal Graphite with Lime Undertone
    [Color(0xFF1A1D1A), Color(0xFF283026)],
    // 7. Dark Teal Slate
    [Color(0xFF122123), Color(0xFF1C3438)],
    // 8. Dark Khaki Slate
    [Color(0xFF202217), Color(0xFF333822)],
  ];

  // Curated theme-harmonized gradient palettes for Light Mode
  // Soft, refined, airy tones in sage, light olive, chartreuse mist, pale jade, and clean slate
  static const List<List<Color>> lightGradientPalettes = [
    // 1. Soft Sage Grey
    [Color(0xFFE4EDE5), Color(0xFFD3E2D6)],
    // 2. Light Slate Card
    [Color(0xFFECEEF2), Color(0xFFDFE3EB)],
    // 3. Soft Chartreuse Mist
    [Color(0xFFEDF3DF), Color(0xFFE0ECCC)],
    // 4. Soft Olive Mist
    [Color(0xFFE9EEDF), Color(0xFFDCE4CF)],
    // 5. Pale Jade Grey
    [Color(0xFFE1EAE4), Color(0xFFCFDDD4)],
    // 6. Muted Lime Frost
    [Color(0xFFEEF5E1), Color(0xFFE1EDCF)],
    // 7. Clean Stone Slate
    [Color(0xFFEAEBED), Color(0xFFDCE0E6)],
    // 8. Soft Moss Cream
    [Color(0xFFE7ECE2), Color(0xFFD8E1D2)],
  ];

  static List<Color> getGradientForSeed(String? seed, {bool isDark = false}) {
    final palettes = isDark ? darkGradientPalettes : lightGradientPalettes;
    if (seed == null || seed.isEmpty) {
      return palettes[0];
    }
    int hash = 0;
    for (int i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return palettes[hash % palettes.length];
  }

  const TrackArtwork({
    super.key,
    required this.artworkUrl,
    this.seedKey,
    required this.size,
    this.height,
    this.borderRadius,
    this.isCircle = false,
    this.ambientGlow = false,
    this.fallbackIcon = Icons.album_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final w = size;
    final h = height ?? size;
    final effectiveRadius = isCircle
        ? BorderRadius.circular(w / 2)
        : (borderRadius ?? BorderRadius.circular(16));

    // Calculate optimal decoded bitmap cache dimension to eliminate memory bloat and scroll jank
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final targetCacheWidth = (w * pixelRatio).round().clamp(80, 1080);
    final targetCacheHeight = (h * pixelRatio).round().clamp(80, 1080);

    final effectiveSeed = seedKey ?? artworkUrl;
    final gradientColors = getGradientForSeed(effectiveSeed, isDark: isDark);
    final iconColor = isDark
        ? AppColors.neonLime.withValues(alpha: 0.82)
        : AppColors.limeAccentDark.withValues(alpha: 0.78);

    final Widget fallbackWidget = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: w * 0.44,
          color: iconColor,
        ),
      ),
    );

    Widget imageContent;

    if (artworkUrl == null || artworkUrl!.trim().isEmpty) {
      imageContent = fallbackWidget;
    } else if (artworkUrl!.startsWith('http://') || artworkUrl!.startsWith('https://')) {
      imageContent = CachedNetworkImage(
        imageUrl: artworkUrl!,
        width: w,
        height: h,
        memCacheWidth: targetCacheWidth,
        memCacheHeight: targetCacheHeight,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: w,
          height: h,
          color: const Color(0xFF1E202A),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => fallbackWidget,
      );
    } else {
      // Local file path: Image.file handles async decoding and fallback via errorBuilder
      imageContent = Image.file(
        File(artworkUrl!),
        width: w,
        height: h,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallbackWidget,
      );
    }

    final decoratedWidget = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: ambientGlow
            ? [
                // Outer colored glow
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.18),
                  blurRadius: 48,
                  spreadRadius: 6,
                ),
                // Deep drop shadow for depth
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
                // Subtle inner-ish rim glow
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.06),
                  blurRadius: 2,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: imageContent,
      ),
    );

    // Only wrap in RepaintBoundary for heavy glow shadows (like NowPlayingScreen)
    // to avoid excessive layer creation in list views
    return ambientGlow ? RepaintBoundary(child: decoratedWidget) : decoratedWidget;
  }
}
