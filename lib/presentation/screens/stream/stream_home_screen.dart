import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/player/now_playing_screen.dart';
import 'package:musify/presentation/screens/search/search_screen.dart';
import 'package:musify/presentation/screens/settings/studio_equalizer_screen.dart';
import 'package:musify/presentation/screens/stream/all_artists_screen.dart';
import 'package:musify/presentation/screens/stream/all_movie_soundtracks_screen.dart';
import 'package:musify/presentation/screens/stream/widgets/stream_cards.dart';
import 'package:musify/presentation/screens/stream/widgets/stream_section_header.dart';
import 'package:musify/presentation/screens/stream/widgets/stream_shimmer_skeleton.dart';
import 'package:musify/presentation/widgets/offline_state_view.dart';
import 'package:musify/presentation/widgets/theme_selection_bottom_sheet.dart';

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

/// Borderless circular button used for header actions and controls.
class _GlassCircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double? iconSize;
  final Color? iconColor;
  final Color? background;
  final double size;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.iconSize,
    this.iconColor,
    this.background,
    this.size = 46,
  });

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.background ??
        (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2));
    final fg =
        isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onLongPress: widget.onLongPress != null
          ? () {
              HapticFeedback.heavyImpact();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: widget.iconSize ?? (widget.size * 0.48),
            color: widget.iconColor ?? fg,
          ),
        ),
      ),
    );
  }
}

class StreamHomeScreen extends ConsumerStatefulWidget {
  const StreamHomeScreen({super.key});

  @override
  ConsumerState<StreamHomeScreen> createState() => _StreamHomeScreenState();
}

class _StreamHomeScreenState extends ConsumerState<StreamHomeScreen>
    with AutomaticKeepAliveClientMixin {
  Color? _lastWashAccent;

  @override
  bool get wantKeepAlive => true;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }

  void _playTrack(List<Track> trackList, int initialIndex) {
    if (trackList.isEmpty) return;
    HapticFeedback.selectionClick();
    final handler = ref.read(audioHandlerProvider);
    final currentPlayingTrackId = ref.read(currentPlayingTrackIdProvider);
    final isPlaying = ref.read(isPlaybackPlayingProvider);
    final targetTrack = trackList[initialIndex];

    if (currentPlayingTrackId == targetTrack.id) {
      if (isPlaying) {
        handler.pause();
      } else {
        handler.play();
        openNowPlayingScreen(context, targetTrack: targetTrack);
      }
    } else {
      handler.playTrackList(trackList, startIndex: initialIndex);
      openNowPlayingScreen(context, targetTrack: targetTrack);
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(streamContentRepositoryProvider);
    await repo.getHomepageData(forceRefresh: true);
    ref.invalidate(streamHomepageDataProvider);
  }

  void _openSearchScreen(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const SearchScreen(),
      ),
    );
  }

  void _openEqualizerScreen(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const StudioEqualizerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.black : Colors.white;
    final onSurface = theme.colorScheme.onSurface;
    final homepageDataAsync = ref.watch(streamHomepageDataProvider);

    // Wash color: artwork of the song playing now, else the most recent one.
    final playingTrack = ref.watch(currentPlayingTrackProvider);
    final recentFirst = ref.watch(recentlyPlayedTracksStreamProvider).value?.firstOrNull ??
        homepageDataAsync.value?.recentlyPlayed.firstOrNull;
    final washTrack = playingTrack ?? recentFirst;

    Color? washAccent;
    if (washTrack != null) {
      final paletteAsync = ref.watch(
        trackPaletteProvider((track: washTrack, isDark: isDark)),
      );
      final palette = paletteAsync.value ??
          PaletteService.instance.getCachedPalette(washTrack, isDark: isDark);
      if (palette != null) {
        _lastWashAccent = palette.backgroundColor;
      }
      washAccent = _lastWashAccent;
    } else {
      _lastWashAccent = null;
    }
    final hasPalette = washAccent != null;
    final washColor = washAccent ?? AppColors.neonLime;
    // Same strength and falloff as PlaylistDetailScreen and HomeScreen
    final washStrength = hasPalette ? (isDark ? 0.75 : 0.55) : (isDark ? 0.10 : 0.16);
    final topColor = _mix(baseColor, washColor, washStrength);

    return Scaffold(
      backgroundColor: baseColor,
      body: Stack(
        children: [
          // Color wash that dissolves into the page background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 520,
            child: IgnorePointer(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: topColor),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOutCubic,
                builder: (context, animatedTop, _) {
                  final top = animatedTop ?? topColor;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 1.0],
                        colors: [top, _mix(top, baseColor, 0.6), baseColor],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Clean header matching HomeScreen layout
                _buildTopHeader(context, isDark, onSurface),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.neonLime,
                    backgroundColor: isDark ? const Color(0xFF20222B) : Colors.white,
                    displacement: 20,
                    onRefresh: _handleRefresh,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [

                  // Sections or loading state
                  homepageDataAsync.when(
                    loading: () => const SliverToBoxAdapter(
                      child: StreamShimmerSkeleton(),
                    ),
                    error: (error, stack) => SliverToBoxAdapter(
                      child: OfflineStateView(
                        title: 'You\'re offline',
                        message:
                            'Connect to the internet to explore charts, new releases and trending hits.',
                        onRetry: _handleRefresh,
                      ),
                    ),
                    data: (data) => SliverMainAxisGroup(
                      slivers: [
                        // Recently played
                        SliverToBoxAdapter(
                          child: RepaintBoundary(
                            child: _RecentlyPlayedSection(
                              fallbackTracks: data.recentlyPlayed,
                              onPlayTrack: _playTrack,
                            ),
                          ),
                        ),

                        // Popular artists
                        if (data.popularArtists.isNotEmpty)
                          SliverToBoxAdapter(
                            child: RepaintBoundary(
                              child: _PopularArtistsSection(
                                artists: data.popularArtists,
                              ),
                            ),
                          ),

                        // Movie soundtracks
                        if (data.movieAlbums.isNotEmpty)
                          SliverToBoxAdapter(
                            child: RepaintBoundary(
                              child: _MovieSoundtracksSection(
                                albums: data.movieAlbums,
                              ),
                            ),
                          ),

                        // Top charts
                        if (data.topCharts.isNotEmpty)
                          SliverToBoxAdapter(
                            child: RepaintBoundary(
                              child: _TopChartsSection(
                                charts: data.topCharts,
                              ),
                            ),
                          ),

                        // Editorial picks
                        if (data.editorialPlaylists.isNotEmpty)
                          SliverToBoxAdapter(
                            child: RepaintBoundary(
                              child: _EditorialPlaylistsSection(
                                playlists: data.editorialPlaylists,
                              ),
                            ),
                          ),

                        // Space for the floating dock + mini player
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 160),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ],
),
);
}

  Widget _buildTopHeader(BuildContext context, bool isDark, Color onSurface) {
    final circleBg =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getGreeting(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineLarge.copyWith(
                    fontSize: 28,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Discover music and soundtracks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                    color: onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          _GlassCircleButton(
            icon: Icons.search_rounded,
            size: 46,
            background: circleBg,
            onTap: () => _openSearchScreen(context),
          ),
          const SizedBox(width: 8),
          _GlassCircleButton(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 46,
            background: circleBg,
            iconColor: isDark ? AppColors.neonLime : AppColors.neonLimeDim,
            onTap: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
            onLongPress: () {
              showThemeSelectionModal(context);
            },
          ),
          const SizedBox(width: 8),
          _GlassCircleButton(
            icon: Icons.tune_rounded,
            size: 46,
            background: circleBg,
            onTap: () => _openEqualizerScreen(context),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolated section components (keep repaints and rebuilds local)
// ─────────────────────────────────────────────────────────────────────────────

class _RecentlyPlayedSection extends ConsumerWidget {
  final List<Track> fallbackTracks;
  final void Function(List<Track> trackList, int index) onPlayTrack;

  const _RecentlyPlayedSection({
    required this.fallbackTracks,
    required this.onPlayTrack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentTracks =
        ref.watch(recentlyPlayedTracksStreamProvider).value ?? fallbackTracks;
    if (recentTracks.isEmpty) return const SizedBox.shrink();

    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaying = ref.watch(isPlaybackPlayingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const StreamSectionHeader(
          title: 'Recently played',
          subtitle: 'Jump back in',
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: recentTracks.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final track = recentTracks[index];
              final isCurrent = currentPlayingTrackId == track.id;

              return StreamSongCard(
                track: track,
                isCurrent: isCurrent,
                isPlaying: isPlaying,
                onTap: () => onPlayTrack(recentTracks, index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PopularArtistsSection extends StatelessWidget {
  final List<SearchArtistItem> artists;

  const _PopularArtistsSection({required this.artists});

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        StreamSectionHeader(
          title: 'Popular artists',
          subtitle: 'Trending singers and producers',
          actionLabel: 'See all',
          onActionTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const AllArtistsScreen(),
              ),
            );
          },
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: artists.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return StreamArtistCircleCard(artist: artists[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _MovieSoundtracksSection extends StatelessWidget {
  final List<SearchAlbumItem> albums;

  const _MovieSoundtracksSection({required this.albums});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        StreamSectionHeader(
          title: 'Movie soundtracks',
          subtitle: 'Film albums and blockbuster hits',
          actionLabel: 'See all',
          onActionTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const AllMovieSoundtracksScreen(),
              ),
            );
          },
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: albums.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return StreamAlbumCard(album: albums[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _TopChartsSection extends StatelessWidget {
  final List<TopChartItem> charts;

  const _TopChartsSection({required this.charts});

  @override
  Widget build(BuildContext context) {
    if (charts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        const StreamSectionHeader(
          title: 'Top charts',
          subtitle: 'Ranked playlists, updated daily',
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: charts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return StreamChartCard(chart: charts[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _EditorialPlaylistsSection extends StatelessWidget {
  final List<SearchPlaylistItem> playlists;

  const _EditorialPlaylistsSection({required this.playlists});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        const StreamSectionHeader(
          title: 'Editorial picks',
          subtitle: 'Handpicked mixes and collections',
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: playlists.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return StreamPlaylistCard(playlist: playlists[index]);
            },
          ),
        ),
      ],
    );
  }
}