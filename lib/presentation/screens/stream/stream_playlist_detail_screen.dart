import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import 'package:musify/presentation/widgets/download_dynamic_island.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/offline_state_view.dart';
import 'package:musify/presentation/widgets/shimmer_skeleton.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';
import 'package:musify/presentation/screens/player/now_playing_screen.dart';

/// Borderless circular action button matching StudioEqualizerScreen header style
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

class StreamPlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;
  final String? initialTitle;
  final String? initialSubtitle;
  final String? initialArtworkUrl;

  const StreamPlaylistDetailScreen({
    super.key,
    required this.playlistId,
    this.initialTitle,
    this.initialSubtitle,
    this.initialArtworkUrl,
  });

  @override
  ConsumerState<StreamPlaylistDetailScreen> createState() => _StreamPlaylistDetailScreenState();
}

class _StreamPlaylistDetailScreenState extends ConsumerState<StreamPlaylistDetailScreen> {
  void _playTrack(List<Track> songs, int index) {
    if (songs.isEmpty) return;
    HapticFeedback.selectionClick();
    final handler = ref.read(audioHandlerProvider);
    final track = songs[index];
    handler.playTrackList(songs, startIndex: index);
    openNowPlayingScreen(context, targetTrack: track);
  }

  void _playAll(List<Track> songs, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    HapticFeedback.selectionClick();
    final handler = ref.read(audioHandlerProvider);
    if (shuffle) {
      final shuffled = List<Track>.from(songs)..shuffle();
      handler.playTrackList(shuffled, startIndex: 0);
      openNowPlayingScreen(context, targetTrack: shuffled.first);
    } else {
      handler.playTrackList(songs, startIndex: 0);
      openNowPlayingScreen(context, targetTrack: songs.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final playlistAsync = ref.watch(streamPlaylistDetailsProvider(widget.playlistId));
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaying = ref.watch(isPlaybackPlayingProvider);

    final title = playlistAsync.value?.title ?? widget.initialTitle ?? 'Playlist';
    final subtitle = playlistAsync.value?.subtitle ?? widget.initialSubtitle;
    final description = playlistAsync.value?.description;
    final artworkUrl = playlistAsync.value?.imageUrl ?? widget.initialArtworkUrl;
    final followerCount = playlistAsync.value?.followerCount;
    final songs = playlistAsync.value?.songs ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                // Top Custom App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CircleHeaderButton(
                          icon: Icons.chevron_left_rounded,
                          iconSize: 28,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          'Playlist',
                          style: AppTypography.headlineSmall.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 44), // Balances layout
                      ],
                    ),
                  ),
                ),

                // Playlist Header / Artwork Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      children: [
                        // High-res Artwork Container
                        Center(
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: TrackArtwork(
                                artworkUrl: artworkUrl,
                                size: 200,
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Title
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppTypography.headlineSmall.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Metadata (Followers / Songs count)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (followerCount != null) ...[
                              Text(
                                followerCount,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                ),
                              ),
                              const Text(' • '),
                            ],
                            Text(
                              '${songs.length} Tracks',
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Action Buttons: Play All & Shuffle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Play All Capsule Button
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _playAll(songs, shuffle: false),
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                decoration: BoxDecoration(
                                  color: AppColors.neonLime,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.neonLime.withValues(alpha: isDark ? 0.35 : 0.45),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.black,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Play All',
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Shuffle Button
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _playAll(songs, shuffle: true),
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shuffle_rounded,
                                      color: theme.colorScheme.onSurface,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Shuffle',
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 12),
                ),

                // Track List or Loading State
                playlistAsync.when(
                  loading: () => TrackListSkeleton.sliver(itemCount: 8),
                  error: (err, stack) => SliverToBoxAdapter(
                    child: OfflineStateView(
                      title: 'Failed to Load Playlist',
                      message: 'Connect to the internet to load and stream this playlist.',
                      onRetry: () => ref.refresh(streamPlaylistDetailsProvider(widget.playlistId)),
                    ),
                  ),
                  data: (data) {
                    if (data == null || data.songs.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              'No tracks found in this playlist',
                              style: AppTypography.bodyMedium.copyWith(
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.only(bottom: 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final track = data.songs[index];
                            final isCurrentTrack = currentPlayingTrackId == track.id;

                            return TrackListTile(
                              track: track,
                              isCurrent: isCurrentTrack,
                              isPlaying: isCurrentTrack && isPlaying,
                              onTap: () => _playTrack(data.songs, index),
                              onMoreOptions: () {
                                showAddToPlaylistModal(context, ref, track: track);
                              },
                            );
                          },
                          childCount: data.songs.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Floating Mini Player Overlay
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingMiniPlayer(),
            ),

            // Floating Dynamic Island Download Status Capsule
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: const DownloadDynamicIsland(),
            ),
          ],
        ),
      ),
    );
  }
}
