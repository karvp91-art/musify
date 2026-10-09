import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/presentation/widgets/loading_indicators.dart';

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

  /// Detects whether an image URL is a JioSaavn default/placeholder graphic
  static bool isPlaceholderUrl(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final lower = url.toLowerCase();
    return lower.contains('default-film') ||
        lower.contains('default-music') ||
        lower.contains('artist-default') ||
        lower.contains('album-default') ||
        lower.contains('playlist-default') ||
        lower.contains('show-default') ||
        lower.contains('episode-default') ||
        lower.contains('default-artist') ||
        lower.contains('default-album') ||
        lower.contains('default_artist') ||
        lower.contains('default_album') ||
        lower.contains('/_i/3.0/') ||
        lower.contains('/_i/') ||
        lower.contains('artists/default') ||
        lower.contains('albums/default') ||
        lower.contains('c.saavncdn.com/_artists/');
  }

  final int? cacheDimension;

  /// Standardized decode dimension for hero/now-playing artwork (480x480)
  /// Provides retina sharpness on all screen densities while consuming 1/4 the memory of 1080px.
  static const int heroArtworkDimension = 480;

  /// Pre-caches the player artwork into memory ahead of time so opening NowPlayingScreen has 0ms latency
  static Future<void> precacheArtwork(BuildContext context, String? artworkUrl) async {
    if (artworkUrl == null || artworkUrl.trim().isEmpty || isPlaceholderUrl(artworkUrl)) return;
    try {
      final ImageProvider provider;
      if (artworkUrl.startsWith('http://') || artworkUrl.startsWith('https://')) {
        provider = CachedNetworkImageProvider(
          artworkUrl,
          maxWidth: heroArtworkDimension,
          maxHeight: heroArtworkDimension,
        );
      } else {
        provider = ResizeImage(
          FileImage(File(artworkUrl)),
          width: heroArtworkDimension,
          height: heroArtworkDimension,
        );
      }
      await precacheImage(provider, context).catchError((_) {});
    } catch (_) {}
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
    this.fallbackIcon = Icons.music_note_rounded,
    this.cacheDimension,
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
    final int targetCacheWidth = cacheDimension ?? (w * pixelRatio).round().clamp(80, 1080);
    final int targetCacheHeight = cacheDimension ?? (h * pixelRatio).round().clamp(80, 1080);

    final effectiveSeed = seedKey ?? artworkUrl;
    final gradientColors = getGradientForSeed(effectiveSeed, isDark: isDark);
    final iconColor = isDark
        ? AppColors.neonLime.withValues(alpha: 0.82)
        : AppColors.limeAccentDark.withValues(alpha: 0.78);

    final effectiveIcon = fallbackIcon;

    final Widget fallbackWidget = _ProceduralCoverArtwork(
      width: w,
      height: h,
      borderRadius: effectiveRadius,
      gradientColors: gradientColors,
      icon: effectiveIcon == Icons.album_rounded ? Icons.music_note_rounded : effectiveIcon,
      iconColor: iconColor,
      isDark: isDark,
      isCircle: isCircle,
    );

    Widget imageContent;

    final isPlaceholder = isPlaceholderUrl(artworkUrl);
    if (isPlaceholder) {
      imageContent = fallbackWidget;
    } else if (artworkUrl!.startsWith('http://') || artworkUrl!.startsWith('https://')) {
      imageContent = CachedNetworkImage(
        imageUrl: artworkUrl!,
        width: w,
        height: h,
        memCacheWidth: targetCacheWidth,
        memCacheHeight: targetCacheHeight,
        fit: BoxFit.cover,
        placeholder: (context, url) => ArtworkShimmerPlaceholder(
          width: w,
          height: h,
          borderRadius: effectiveRadius.topLeft.x,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
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

/// A high-aesthetic procedural vinyl & sleeve graphic rendered for songs lacking cover artwork.
/// Features theme-harmonized gradient foundation, etched micro-concentric vinyl grooves,
/// a centered lacquer disc hub, and subtle diagonal holographic rim sheen.
class _ProceduralCoverArtwork extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final List<Color> gradientColors;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final bool isCircle;

  const _ProceduralCoverArtwork({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.gradientColors,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.isCircle,
  });

  @override
  Widget build(BuildContext context) {
    final minDim = math.min(width, height);
    final centerLabelRadius = minDim * 0.44;

    final Widget vinylStack = Stack(
      alignment: Alignment.center,
      children: [
        // 1. Concentric Micro Vinyl Grooves
        Positioned.fill(
          child: CustomPaint(
            painter: _VinylGroovesPainter(
              grooveColor: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
        ),

        // 2. Vinyl Center Record Label Hub
        Container(
          width: centerLabelRadius,
          height: centerLabelRadius,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? const Color(0xFF10121A)
                : const Color(0xFFFAFBFD),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? AppColors.neonLime.withValues(alpha: 0.28)
                  : AppColors.limeAccentDark.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: centerLabelRadius * 0.52,
            color: iconColor,
          ),
        ),

        // 3. Subtle Holographic Specular Sheen (diagonal light reflection)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-1.0, -1.0),
                  end: const Alignment(1.0, 1.0),
                  stops: const [0.0, 0.45, 0.55, 1.0],
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.08 : 0.16),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: isDark ? 0.10 : 0.03),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: isCircle ? null : borderRadius,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.0,
        ),
      ),
      child: isCircle
          ? ClipOval(child: vinylStack)
          : ClipRRect(borderRadius: borderRadius, child: vinylStack),
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  final Color grooveColor;

  _VinylGroovesPainter({required this.grooveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = math.min(size.width, size.height);
    final maxRadius = minDim * 0.48;
    final minRadius = minDim * 0.24;

    final paint = Paint()
      ..color = grooveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const steps = 4;
    final stepSize = (maxRadius - minRadius) / steps;
    for (int i = 1; i <= steps; i++) {
      canvas.drawCircle(center, minRadius + i * stepSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter oldDelegate) =>
      oldDelegate.grooveColor != grooveColor;
}