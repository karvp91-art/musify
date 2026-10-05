import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/album/album_detail_screen.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';

/// Borderless circular action button matching AudioSettingsScreen header style
class _CircleHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  const _CircleHeaderButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor =
        isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: defaultIconColor,
        ),
      ),
    );
  }
}

class ArtistDetailScreen extends ConsumerStatefulWidget {
  final String artistId;
  final String? initialName;
  final String? initialImageUrl;

  const ArtistDetailScreen({
    super.key,
    required this.artistId,
    this.initialName,
    this.initialImageUrl,
  });

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  bool _showAllSongs = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaybackPlaying = ref.watch(isPlaybackPlayingProvider);

    final artistAsync = ref.watch(saavnArtistDetailsProvider(widget.artistId));

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header matching AudioSettingsScreen aesthetic
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _CircleHeaderButton(
                        icon: Icons.chevron_left_rounded,
                        iconSize: 26,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 14),

                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.initialName ?? 'Artist',
                              style: AppTypography.headlineSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Artist Profile',
                              style: AppTypography.caption.copyWith(
                                color: textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Right: Shuffle Top Songs
                      artistAsync.maybeWhen(
                        data: (artist) {
                          final topSongs = artist?.topSongs ?? [];
                          if (topSongs.isEmpty) return const SizedBox.shrink();
                          return _CircleHeaderButton(
                            icon: Icons.shuffle_rounded,
                            iconSize: 20,
                            onTap: () {
                              final shuffled = List<Track>.from(topSongs)..shuffle();
                              audioHandler.playTrackList(shuffled, startIndex: 0);
                            },
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Main Content
                Expanded(
                  child: artistAsync.when(
                    data: (artist) {
                      final name = artist?.name ?? widget.initialName ?? 'Artist';
                      final artwork = artist?.imageUrl ?? widget.initialImageUrl;
                      final fanCountText = artist?.fanCount ?? 'Artist';
                      final isVerified = artist?.isVerified ?? true;
                      final topSongs = artist?.topSongs ?? [];
                      final topAlbums = artist?.topAlbums ?? [];

                      final displayedSongs = _showAllSongs ? topSongs : topSongs.take(5).toList();

                      return ListView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 140),
                        children: [
                          const SizedBox(height: 8),

                          // Circular Artist Hero Photo with shadow
                          Center(
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: TrackArtwork(
                                  artworkUrl: artwork,
                                  size: 160,
                                  isCircle: true,
                                  fallbackIcon: Icons.person_rounded,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Artist Name with Verified Checkmark Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.style(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 20,
                                  color: Colors.blueAccent,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Metadata chip: Fan Count
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 15,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    fanCountText,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : const Color(0xFF1E2028),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Play All Button (Neon Lime)
                          Center(
                            child: SizedBox(
                              height: 48,
                              width: 170,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.neonLime,
                                  foregroundColor: const Color(0xFF111827),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 24,
                                  color: Color(0xFF111827),
                                ),
                                label: const Text(
                                  'Play All',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                onPressed: topSongs.isEmpty
                                    ? null
                                    : () {
                                        HapticFeedback.mediumImpact();
                                        audioHandler.playTrackList(topSongs, startIndex: 0);
                                      },
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // --- Top Songs Header ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              'Top Songs',
                              style: AppTypography.style(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),

                          if (topSongs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No songs available',
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            )
                          else ...[
                            ...displayedSongs.map((track) {
                              final isCurrent = currentPlayingTrackId == track.id;
                              final isTilePlaying = isCurrent && isPlaybackPlaying;

                              return TrackListTile(
                                key: ValueKey('artist_song_${track.id}'),
                                track: track,
                                isCurrent: isCurrent,
                                isPlaying: isTilePlaying,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  audioHandler.playTrackList(topSongs, startIndex: topSongs.indexOf(track));
                                },
                                onLikeToggle: () {
                                  ref.read(audioRepositoryProvider).toggleLike(track);
                                },
                              );
                            }),

                            // "Show More / Show Less" toggle button
                            if (topSongs.length > 5)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _showAllSongs = !_showAllSongs);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _showAllSongs ? 'Show Less' : 'Show All ${topSongs.length} Songs',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],

                          // --- Top Albums Header ---
                          if (topAlbums.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                'Top Albums',
                                style: AppTypography.style(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            ...topAlbums.map((album) {
                              return InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AlbumDetailScreen(
                                        albumId: album.id,
                                        initialTitle: album.title,
                                        initialArtist: album.music,
                                        initialArtworkUrl: album.imageUrl,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                                child: Container(
                                  height: 76,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: theme.scaffoldBackgroundColor,
                                  ),
                                  child: Row(
                                    children: [
                                      TrackArtwork(
                                        artworkUrl: album.imageUrl,
                                        size: 54,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              album.title,
                                              style: AppTypography.style(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white : const Color(0xFF1E2028),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              album.description.isNotEmpty
                                                  ? album.description
                                                  : (album.music != null && album.music!.isNotEmpty
                                                      ? '${album.music!} • Album'
                                                      : 'Album'),
                                              style: AppTypography.caption.copyWith(
                                                fontSize: 12.5,
                                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 22,
                                        color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.neonLime),
                    ),
                    error: (err, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load artist details',
                            style: AppTypography.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(saavnArtistDetailsProvider(widget.artistId)),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Universal Floating Mini Player
            const FloatingMiniPlayer(),
          ],
        ),
      ),
    );
  }
}
