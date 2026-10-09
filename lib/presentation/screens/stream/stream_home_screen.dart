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
import 'package:musify/presentation/screens/stream/widgets/stream_cards.dart';
import 'package:musify/presentation/screens/stream/widgets/stream_section_header.dart';
import 'package:musify/presentation/screens/stream/widgets/stream_shimmer_skeleton.dart';
import 'package:musify/presentation/widgets/offline_state_view.dart';
import 'package:musify/presentation/widgets/theme_selection_bottom_sheet.dart';

/// Borderless circular action button matching StudioEqualizerScreen header style
class _CircleHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double iconSize;
  final Color? iconColor;

  const _CircleHeaderButton({
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.iconSize = 22,
    this.iconColor,
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
      onLongPress: onLongPress != null
          ? () {
              HapticFeedback.heavyImpact();
              onLongPress!();
            }
          : null,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor ?? defaultIconColor,
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
    final homepageDataAsync = ref.watch(streamHomepageDataProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
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
              // 1. Sticky Pinned App Bar with Dynamic Greeting & Neon Accents
              SliverAppBar(
                pinned: true,
                floating: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 70,
                titleSpacing: 20,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _getGreeting(),
                            style: AppTypography.headlineLarge.copyWith(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              color: isDark ? AppColors.neonLime : AppColors.neonLimeDim,
                            ),
                          ),
                          TextSpan(
                            text: '.',
                            style: AppTypography.headlineLarge.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: isDark ? AppColors.neonLime : const Color(0xFF000000),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Discover music & soundtracks',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.55)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Search Action Button
                  _CircleHeaderButton(
                    icon: Icons.search_rounded,
                    iconSize: 21,
                    onTap: () => _openSearchScreen(context),
                  ),
                  const SizedBox(width: 8),
                  // Theme Toggle Button (Tap: switch Light/Dark, Long Press: open Theme Picker)
                  _CircleHeaderButton(
                    icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    iconSize: 20,
                    iconColor: isDark ? AppColors.neonLime : AppColors.neonLimeDim,
                    onTap: () {
                      ref.read(themeModeProvider.notifier).toggleTheme();
                    },
                    onLongPress: () {
                      showThemeSelectionModal(context);
                    },
                  ),
                  const SizedBox(width: 8),
                  // Studio Equalizer Action Button
                  _CircleHeaderButton(
                    icon: Icons.tune_rounded,
                    iconSize: 21,
                    onTap: () => _openEqualizerScreen(context),
                  ),
                  const SizedBox(width: 16),
                ],
              ),

              // 2. Sections or Loading State
              homepageDataAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: StreamShimmerSkeleton(),
                ),
                error: (error, stack) => SliverToBoxAdapter(
                  child: OfflineStateView(
                    title: 'Offline Mode',
                    message:
                        'Connect to the internet to explore stream charts, new releases, and trending hits.',
                    onRetry: _handleRefresh,
                  ),
                ),
                data: (data) => SliverMainAxisGroup(
                  slivers: [
                    // Section 1: Recently Played (Horizontal Carousel)
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: _RecentlyPlayedSection(
                          fallbackTracks: data.recentlyPlayed,
                          onPlayTrack: _playTrack,
                        ),
                      ),
                    ),

                    // Section 2: Popular Artists (Horizontal Carousel of Avatars)
                    if (data.popularArtists.isNotEmpty)
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: _PopularArtistsSection(
                            artists: data.popularArtists,
                          ),
                        ),
                      ),

                    // Section 3: Movie Soundtracks (Horizontal Carousel of Movie Albums)
                    if (data.movieAlbums.isNotEmpty)
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: _MovieSoundtracksSection(
                            albums: data.movieAlbums,
                          ),
                        ),
                      ),

                    // Section 4: Top Charts (Horizontal Carousel of Chart Cubes)
                    if (data.topCharts.isNotEmpty)
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: _TopChartsSection(
                            charts: data.topCharts,
                          ),
                        ),
                      ),

                    // Section 5: Editorial Picks / Made For You (Playlists Carousel)
                    if (data.editorialPlaylists.isNotEmpty)
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: _EditorialPlaylistsSection(
                            playlists: data.editorialPlaylists,
                          ),
                        ),
                      ),

                    // Bottom Spacing for Floating Dock + Mini Player
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolated Section Components for Frame Rate and Paint Optimization
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
          title: 'Recently Played',
          subtitle: 'Jump back into your history',
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
        const SizedBox(height: 16),
        const StreamSectionHeader(
          title: 'Popular Artists',
          subtitle: 'Top trending singers & producers',
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
        const SizedBox(height: 16),
        const StreamSectionHeader(
          title: 'Movie Soundtracks',
          subtitle: 'Original film albums & blockbuster hits',
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
        const SizedBox(height: 16),
        const StreamSectionHeader(
          title: 'Top Charts',
          subtitle: 'Ranked playlists updated daily',
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
        const SizedBox(height: 16),
        const StreamSectionHeader(
          title: 'Editorial Picks',
          subtitle: 'Handpicked mixes & collections',
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
