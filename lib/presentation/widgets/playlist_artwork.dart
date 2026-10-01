import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'track_artwork.dart';

/// A production-grade playlist cover artwork widget that displays:
/// 1. Custom cover URL (if specified)
/// 2. Dynamic 2x2 mosaic grid if 4+ tracks have artwork (Apple Music / Spotify style)
/// 3. Single hero artwork if 1-3 tracks have artwork
/// 4. Theme-harmonized gradient container with playlist icon if empty
/// 5. Special gradient + heart for Liked Songs
class PlaylistArtwork extends ConsumerWidget {
  final String? playlistId;
  final String? coverUrl;
  final List<Track>? preloadedTracks;
  final double size;
  final BorderRadius? borderRadius;
  final bool isLikedSongs;
  final bool hasShadow;

  const PlaylistArtwork({
    super.key,
    this.playlistId,
    this.coverUrl,
    this.preloadedTracks,
    required this.size,
    this.borderRadius,
    this.isLikedSongs = false,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(16);

    // 1. Liked Songs Preset
    if (isLikedSongs) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          gradient: LinearGradient(
            colors: isDark
                ? [
                    AppColors.neonLime.withValues(alpha: 0.95),
                    const Color(0xFF1E3526),
                  ]
                : [
                    AppColors.limeAccentDark,
                    const Color(0xFF7FA832),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: hasShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            Icons.favorite_rounded,
            size: size * 0.44,
            color: isDark ? Colors.black : Colors.white,
          ),
        ),
      );
    }

    // 2. Explicit custom cover URL
    if (coverUrl != null && coverUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: effectiveRadius,
        child: _buildSingleImage(coverUrl!, size, isDark, playlistId),
      );
    }

    // 3. Extract tracks from props or watch playlistTracksProvider
    List<Track> tracks = preloadedTracks ?? const [];
    if (preloadedTracks == null && playlistId != null && playlistId!.isNotEmpty) {
      final tracksAsync = ref.watch(playlistTracksProvider(playlistId!));
      tracks = tracksAsync.value ?? const [];
    }

    // Collect unique artwork URLs
    final artworkUrls = <String>[];
    for (final t in tracks) {
      if (t.artworkUrl != null && t.artworkUrl!.trim().isNotEmpty) {
        if (!artworkUrls.contains(t.artworkUrl!.trim())) {
          artworkUrls.add(t.artworkUrl!.trim());
        }
      }
      if (artworkUrls.length >= 4) break;
    }

    Widget content;

    // 4. 2x2 Mosaic Grid (Spotify / Apple Music style)
    if (artworkUrls.length >= 4) {
      final subSize = size / 2;
      content = SizedBox(
        width: size,
        height: size,
        child: Column(
          children: [
            Row(
              children: [
                _buildMosaicTile(artworkUrls[0], subSize, isDark, 'tile_0'),
                _buildMosaicTile(artworkUrls[1], subSize, isDark, 'tile_1'),
              ],
            ),
            Row(
              children: [
                _buildMosaicTile(artworkUrls[2], subSize, isDark, 'tile_2'),
                _buildMosaicTile(artworkUrls[3], subSize, isDark, 'tile_3'),
              ],
            ),
          ],
        ),
      );
    } else if (artworkUrls.isNotEmpty) {
      // 5. Single artwork
      content = _buildSingleImage(artworkUrls.first, size, isDark, playlistId);
    } else {
      // 6. Curated Fallback
      final gradientColors = TrackArtwork.getGradientForSeed(playlistId ?? 'playlist', isDark: isDark);
      final iconColor = isDark
          ? AppColors.neonLime.withValues(alpha: 0.85)
          : AppColors.limeAccentDark.withValues(alpha: 0.85);

      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.queue_music_rounded,
            size: size * 0.44,
            color: iconColor,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: content,
      ),
    );
  }

  Widget _buildMosaicTile(String url, double subSize, bool isDark, String seed) {
    return SizedBox(
      width: subSize,
      height: subSize,
      child: _buildSingleImage(url, subSize, isDark, seed),
    );
  }

  Widget _buildSingleImage(String url, double imgSize, bool isDark, String? seed) {
    final fallbackGradient = TrackArtwork.getGradientForSeed(seed ?? url, isDark: isDark);
    final fallbackWidget = Container(
      width: imgSize,
      height: imgSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fallbackGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.album_rounded,
        size: imgSize * 0.4,
        color: isDark ? AppColors.neonLime.withValues(alpha: 0.7) : AppColors.limeAccentDark,
      ),
    );

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: imgSize,
        height: imgSize,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: imgSize,
          height: imgSize,
          color: isDark ? const Color(0xFF1B1D25) : const Color(0xFFE5E7EB),
        ),
        errorWidget: (context, _, error) => fallbackWidget,
      );
    } else {
      return Image.file(
        File(url),
        width: imgSize,
        height: imgSize,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallbackWidget,
      );
    }
  }
}
