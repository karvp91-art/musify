import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import '../../providers/audio_providers.dart';
import '../../widgets/track_list_tile.dart';
import '../../widgets/track_menu_bottom_sheet.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final Playlist? playlist;
  final bool isLikedSongs;

  const PlaylistDetailScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.playlist,
    this.isLikedSongs = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final audioHandler = ref.read(audioHandlerProvider);
    final currentTrack = ref.watch(currentPlayingTrackProvider);
    final isPlaying = ref.watch(isPlaybackPlayingProvider);

    // Watch tracks reactively
    final AsyncValue<List<Track>> tracksAsync;
    if (isLikedSongs) {
      tracksAsync = ref.watch(likedTracksStreamProvider);
    } else if (playlist != null) {
      tracksAsync = ref.watch(playlistTracksProvider(playlist!.id));
    } else {
      tracksAsync = const AsyncData([]);
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: tracksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading tracks: $err')),
          data: (tracks) {
            return CustomScrollView(
              slivers: [
                // Top Header with Back button and Actions
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CircularActionButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          isDark: isDark,
                          onTap: () => Navigator.pop(context),
                        ),
                        Text(
                          isLikedSongs ? 'Liked Songs' : 'Playlist',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 42), // Balance spacing
                      ],
                    ),
                  ),
                ),

                // Hero / Banner Info Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Large Artwork Card
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: isLikedSongs
                                ? LinearGradient(
                                    colors: [
                                      primaryColor,
                                      primaryColor.withValues(alpha: 0.6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isDark ? const Color(0xFF1E212B) : const Color(0xFFECEEF2),
                          ),
                          child: Center(
                            child: Icon(
                              isLikedSongs ? Icons.favorite_rounded : Icons.queue_music_rounded,
                              size: 64,
                              color: isLikedSongs
                                  ? Colors.black
                                  : (isDark ? Colors.white70 : Colors.black54),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Subtitle / Track Count
                        Text(
                          subtitle ?? '${tracks.length} tracks',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons: Play All & Shuffle
                        if (tracks.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: () {
                                  audioHandler.playTrackList(tracks, startIndex: 0);
                                },
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white : Colors.black87,
                                  side: BorderSide(
                                    color: isDark ? Colors.white24 : Colors.black12,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                icon: const Icon(Icons.shuffle_rounded, size: 20),
                                label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.w600)),
                                onPressed: () {
                                  final shuffled = List<Track>.from(tracks)..shuffle();
                                  audioHandler.playTrackList(shuffled, startIndex: 0);
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // Track List
                if (tracks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          isLikedSongs
                              ? 'No liked tracks yet. Tap heart to add tracks!'
                              : 'No tracks in this playlist yet.',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final track = tracks[idx];
                        final isCur = currentTrack?.id == track.id;
                        final isPl = isCur && isPlaying;

                        return TrackListTile(
                          track: track,
                          isCurrent: isCur,
                          isPlaying: isPl,
                          onTap: () {
                            audioHandler.playTrackList(tracks, startIndex: idx);
                          },
                          onMoreOptions: () {
                            showTrackDropdownMenu(
                              context: context,
                              ref: ref,
                              track: track,
                            );
                          },
                        );
                      },
                      childCount: tracks.length,
                    ),
                  ),

                // Bottom clearance for mini player
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CircularActionButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _CircularActionButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
        ),
        child: Icon(
          icon,
          size: 19,
          color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E2028),
        ),
      ),
    );
  }
}
