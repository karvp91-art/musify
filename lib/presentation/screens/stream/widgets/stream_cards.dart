import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/search_result_models.dart';
import 'package:musify/domain/models/stream_home_models.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/screens/album/album_detail_screen.dart';
import 'package:musify/presentation/screens/artist/artist_detail_screen.dart';
import 'package:musify/presentation/screens/stream/stream_mood_detail_screen.dart';
import 'package:musify/presentation/screens/stream/stream_playlist_detail_screen.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';

/// 1. Quick Pick Tile (2-column compact grid item)
class StreamQuickPickTile extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final VoidCallback onTap;

  const StreamQuickPickTile({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2028) : const Color(0xFFF3F4F6);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: isPlaying
              ? Border.all(color: AppColors.neonLime.withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Artwork 60x60
            SizedBox(
              width: 60,
              height: 60,
              child: TrackArtwork(
                artworkUrl: track.artworkUrl,
                size: 60,
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(width: 10),
            // Title & Artist
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isPlaying
                          ? (isDark ? AppColors.neonLime : const Color(0xFF3B7D14))
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      fontSize: 11.5,
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            // Play or Equalizer indicator
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 6),
              child: isPlaying
                  ? const Icon(
                      Icons.equalizer_rounded,
                      color: AppColors.neonLime,
                      size: 20,
                    )
                  : Icon(
                      Icons.play_circle_filled_rounded,
                      color: isDark ? Colors.white38 : Colors.black26,
                      size: 24,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. Vertical Song Card (for Trending / Top Tracks carousel)
class StreamSongCard extends StatelessWidget {
  final Track track;
  final int? rank;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  const StreamSongCard({
    super.key,
    required this.track,
    this.rank,
    this.isCurrent = false,
    this.isPlaying = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: 136,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork Container with overlay rank badge and play state
            Stack(
              children: [
                Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: TrackArtwork(
                      artworkUrl: track.artworkUrl,
                      size: 136,
                      cacheDimension: 280,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (rank != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$rank',
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: rank == 1 ? AppColors.neonLime : Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (isCurrent)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.neonLime,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isCurrent
                    ? (isDark ? AppColors.neonLime : const Color(0xFF3B7D14))
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              track.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3. Album Card (for New Releases)
class StreamAlbumCard extends StatelessWidget {
  final SearchAlbumItem album;

  const StreamAlbumCard({
    super.key,
    required this.album,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => AlbumDetailScreen(
              albumId: album.id,
              initialTitle: album.title,
              initialArtist: album.music,
              initialArtworkUrl: album.imageUrl,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: TrackArtwork(
                  artworkUrl: album.imageUrl,
                  size: 140,
                  cacheDimension: 280,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              album.music?.isNotEmpty == true ? album.music! : (album.year ?? 'Album'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. Artist Circle Card (for Popular Artists)
class StreamArtistCircleCard extends StatelessWidget {
  final SearchArtistItem artist;

  const StreamArtistCircleCard({
    super.key,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => ArtistDetailScreen(
              artistId: artist.id,
              initialName: artist.title,
              initialImageUrl: artist.imageUrl,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF2E313D) : const Color(0xFFE2E4E9),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: TrackArtwork(
                  artworkUrl: artist.imageUrl,
                  size: 92,
                  cacheDimension: 200,
                  borderRadius: BorderRadius.circular(46),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              artist.description.isNotEmpty ? artist.description : 'Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5. Top Chart Card (for Charts carousel)
class StreamChartCard extends StatelessWidget {
  final TopChartItem chart;

  const StreamChartCard({
    super.key,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => StreamPlaylistDetailScreen(
              playlistId: chart.id,
              initialTitle: chart.title,
              initialSubtitle: chart.subtitle,
              initialArtworkUrl: chart.imageUrl,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork Cube with overlay badge
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: TrackArtwork(
                      artworkUrl: chart.imageUrl,
                      size: 140,
                      cacheDimension: 280,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (chart.badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        chart.badge!,
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.neonLime : const Color(0xFFD2F843),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              chart.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              chart.subtitle ?? chart.count ?? 'Top Chart',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 6. Mood & Activity Gradient Card
class StreamMoodCard extends StatelessWidget {
  final MoodCategory mood;

  const StreamMoodCard({
    super.key,
    required this.mood,
  });

  IconData _getIconData(String iconName) {
    return switch (iconName) {
      'spa' => Icons.spa_rounded,
      'fitness_center' => Icons.fitness_center_rounded,
      'psychology' => Icons.psychology_rounded,
      'directions_car' => Icons.directions_car_rounded,
      'celebration' => Icons.celebration_rounded,
      _ => Icons.music_note_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => StreamMoodDetailScreen(mood: mood),
          ),
        );
      },
      child: Container(
        width: 154,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: mood.gradientColors.map((c) => Color(c)).toList(),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(mood.gradientColors.first).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              _getIconData(mood.iconName),
              color: Colors.white,
              size: 22,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mood.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  mood.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 7. Editorial Playlist Card (for Editorial Picks / Made for You)
class StreamPlaylistCard extends StatelessWidget {
  final SearchPlaylistItem playlist;

  const StreamPlaylistCard({
    super.key,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => StreamPlaylistDetailScreen(
              playlistId: playlist.id,
              initialTitle: playlist.title,
              initialSubtitle: playlist.description,
              initialArtworkUrl: playlist.imageUrl,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: TrackArtwork(
                  artworkUrl: playlist.imageUrl,
                  size: 140,
                  cacheDimension: 280,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              playlist.description.isNotEmpty ? playlist.description : 'Playlist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
