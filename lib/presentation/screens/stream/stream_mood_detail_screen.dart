import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/offline_state_view.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';

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

class StreamMoodDetailScreen extends ConsumerStatefulWidget {
  final MoodCategory mood;

  const StreamMoodDetailScreen({
    super.key,
    required this.mood,
  });

  @override
  ConsumerState<StreamMoodDetailScreen> createState() => _StreamMoodDetailScreenState();
}

class _StreamMoodDetailScreenState extends ConsumerState<StreamMoodDetailScreen> {
  void _playTrack(List<Track> songs, int index) {
    if (songs.isEmpty) return;
    HapticFeedback.selectionClick();
    final handler = ref.read(audioHandlerProvider);
    handler.playTrackList(songs, startIndex: index);
  }

  void _playAll(List<Track> songs, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    HapticFeedback.selectionClick();
    final handler = ref.read(audioHandlerProvider);
    if (shuffle) {
      final shuffled = List<Track>.from(songs)..shuffle();
      handler.playTrackList(shuffled, startIndex: 0);
    } else {
      handler.playTrackList(songs, startIndex: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mood = widget.mood;
    final tracksAsync = ref.watch(streamMoodTracksProvider(mood.query));
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaying = ref.watch(isPlaybackPlayingProvider);
    final songs = tracksAsync.value ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                // Top Custom Navigation Bar
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
                          mood.title,
                          style: AppTypography.headlineSmall.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                ),

                // Vibrant Gradient Header Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: mood.gradientColors.map((c) => Color(c)).toList(),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(mood.gradientColors.first).withValues(alpha: 0.40),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mood.title,
                            style: AppTypography.headlineLarge.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mood.subtitle,
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _playAll(songs, shuffle: false),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.20),
                                        blurRadius: 10,
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
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _playAll(songs, shuffle: true),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.shuffle_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Shuffle',
                                        style: AppTypography.bodyMedium.copyWith(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
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
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 12),
                ),

                // Tracks List
                tracksAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(color: AppColors.neonLime),
                      ),
                    ),
                  ),
                  error: (err, stack) => SliverToBoxAdapter(
                    child: OfflineStateView(
                      title: 'Failed to Load Tracks',
                      message: 'Connect to the internet to stream this mood playlist.',
                      onRetry: () => ref.refresh(streamMoodTracksProvider(mood.query)),
                    ),
                  ),
                  data: (tracks) {
                    if (tracks.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              'No tracks found for this mood',
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
                            final track = tracks[index];
                            final isCurrentTrack = currentPlayingTrackId == track.id;

                            return TrackListTile(
                              track: track,
                              isCurrent: isCurrentTrack,
                              isPlaying: isCurrentTrack && isPlaying,
                              onTap: () => _playTrack(tracks, index),
                              onMoreOptions: () {
                                showAddToPlaylistModal(context, ref, track: track);
                              },
                            );
                          },
                          childCount: tracks.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Floating Mini Player
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingMiniPlayer(),
            ),
          ],
        ),
      ),
    );
  }
}
