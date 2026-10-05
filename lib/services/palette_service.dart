import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';

/// Data class holding extracted and calculated color tokens for MiniPlayer and NowPlaying surfaces.
class MiniPlayerPalette {
  final Color backgroundColor;
  final Color titleColor;
  final Color artistColor;
  final Color iconColor;
  final Color buttonOutline;
  final Color buttonFill;
  final Color progressBarColor;
  final Color progressInactiveColor;
  final Color shadowColor;
  final bool isLight;

  const MiniPlayerPalette({
    required this.backgroundColor,
    required this.titleColor,
    required this.artistColor,
    required this.iconColor,
    required this.buttonOutline,
    required this.buttonFill,
    required this.progressBarColor,
    required this.progressInactiveColor,
    required this.shadowColor,
    required this.isLight,
  });

  /// Default fallback palette when no artwork exists: Neon Lime capsule matching user specification.
  factory MiniPlayerPalette.fallback({required bool isDark, String? seed}) {
    const bgColor = AppColors.neonLime;
    return MiniPlayerPalette(
      backgroundColor: bgColor,
      titleColor: const Color(0xFF111827),
      artistColor: const Color(0xFF111827).withValues(alpha: 0.78),
      iconColor: const Color(0xFF111827),
      buttonOutline: const Color(0xFF111827).withValues(alpha: 0.70),
      buttonFill: const Color(0xFF111827).withValues(alpha: 0.12),
      progressBarColor: const Color(0xFF111827),
      progressInactiveColor: const Color(0xFF111827).withValues(alpha: 0.20),
      shadowColor: bgColor.withValues(alpha: isDark ? 0.40 : 0.28),
      isLight: true,
    );
  }
}

/// Service that generates and caches color palettes extracted from track artwork
/// using `palette_generator`.
class PaletteService {
  PaletteService._();
  static final PaletteService instance = PaletteService._();

  // In-memory cache for fast 0ms color lookups
  final Map<String, MiniPlayerPalette> _cache = {};

  /// Retrieves or extracts a palette for the given track.
  Future<MiniPlayerPalette> getPaletteForTrack(
    Track track, {
    required bool isDark,
  }) async {
    final cacheKey = '${track.id}_${track.artworkUrl ?? ""}_${isDark ? "dark" : "light"}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final artworkUrl = track.artworkUrl;
    if (artworkUrl == null || artworkUrl.trim().isEmpty || TrackArtwork.isPlaceholderUrl(artworkUrl)) {
      final fallback = MiniPlayerPalette.fallback(isDark: isDark, seed: track.id.isNotEmpty ? track.id : track.title);
      _cache[cacheKey] = fallback;
      return fallback;
    }

    try {
      ImageProvider imageProvider;
      if (artworkUrl.startsWith('http://') || artworkUrl.startsWith('https://')) {
        imageProvider = CachedNetworkImageProvider(artworkUrl);
      } else {
        imageProvider = FileImage(File(artworkUrl));
      }

      final generator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(48, 48), // Downscaled bitmap for sub-15ms extraction
        maximumColorCount: 16,
      ).timeout(const Duration(milliseconds: 1800));

      final resolvedColor = _selectBestColor(generator, isDark: isDark, seed: track.title);
      final palette = _buildPalette(resolvedColor, isDark: isDark);
      _cache[cacheKey] = palette;
      return palette;
    } catch (_) {
      // Fallback gracefully on timeout / network error
      final fallback = MiniPlayerPalette.fallback(isDark: isDark, seed: track.id.isNotEmpty ? track.id : track.title);
      _cache[cacheKey] = fallback;
      return fallback;
    }
  }

  /// Synchronously returns cached palette if available, otherwise null.
  MiniPlayerPalette? getCachedPalette(Track track, {required bool isDark}) {
    final cacheKey = '${track.id}_${track.artworkUrl ?? ""}_${isDark ? "dark" : "light"}';
    return _cache[cacheKey];
  }

  Color _selectBestColor(PaletteGenerator generator, {required bool isDark, required String seed}) {
    // Collect potential candidates in priority order
    final candidates = <Color?>[
      generator.vibrantColor?.color,
      generator.dominantColor?.color,
      generator.lightVibrantColor?.color,
      generator.darkVibrantColor?.color,
      generator.mutedColor?.color,
      generator.lightMutedColor?.color,
      generator.darkMutedColor?.color,
      ...generator.colors,
    ].whereType<Color>().toList();

    if (candidates.isEmpty) {
      final gradient = TrackArtwork.getGradientForSeed(seed, isDark: isDark);
      return gradient.first;
    }

    // Find the most vibrant / saturated color with good visual richness
    Color? bestColor;
    double bestScore = -1.0;

    for (final color in candidates) {
      final hsl = HSLColor.fromColor(color);
      final saturation = hsl.saturation;
      final lightness = hsl.lightness;

      // Score based on saturation and balanced lightness (ideal lightness 0.35 - 0.60)
      double score = saturation * 2.0;
      if (lightness >= 0.25 && lightness <= 0.65) {
        score += 1.5;
      } else if (lightness < 0.15 || lightness > 0.85) {
        score -= 1.5; // Avoid near-black or blown-out white
      }

      if (score > bestScore) {
        bestScore = score;
        bestColor = color;
      }
    }

    final chosen = bestColor ?? candidates.first;
    final hsl = HSLColor.fromColor(chosen);

    // Polish color into a rich, warm, vibrant tone (like the golden mustard in TAIDADA)
    if (isDark) {
      return hsl
          .withSaturation((hsl.saturation * 1.15).clamp(0.40, 0.95))
          .withLightness(hsl.lightness.clamp(0.30, 0.55))
          .toColor();
    } else {
      return hsl
          .withSaturation((hsl.saturation * 1.10).clamp(0.35, 0.90))
          .withLightness(hsl.lightness.clamp(0.38, 0.65))
          .toColor();
    }
  }

  MiniPlayerPalette _buildPalette(Color bgColor, {required bool isDark}) {
    final luminance = bgColor.computeLuminance();
    final isLight = luminance > 0.55;

    final titleColor = isLight ? const Color(0xFF111827) : Colors.white;
    final artistColor = isLight
        ? const Color(0xFF111827).withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.82);
    final iconColor = isLight ? const Color(0xFF111827) : Colors.white;
    final buttonOutline = isLight
        ? const Color(0xFF111827).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.85);
    final buttonFill = isLight
        ? const Color(0xFF111827).withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.18);
    final progressBarColor = isLight ? const Color(0xFF111827) : Colors.white;
    final progressInactiveColor = isLight
        ? const Color(0xFF111827).withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.22);
    final shadowColor = bgColor.withValues(alpha: isDark ? 0.40 : 0.28);

    return MiniPlayerPalette(
      backgroundColor: bgColor,
      titleColor: titleColor,
      artistColor: artistColor,
      iconColor: iconColor,
      buttonOutline: buttonOutline,
      buttonFill: buttonFill,
      progressBarColor: progressBarColor,
      progressInactiveColor: progressInactiveColor,
      shadowColor: shadowColor,
      isLight: isLight,
    );
  }
}
