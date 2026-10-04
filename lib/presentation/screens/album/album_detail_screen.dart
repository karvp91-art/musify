import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/artist/artist_detail_screen.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';

class AlbumDetailScreen extends ConsumerStatefulWidget {
  final String albumId;
  final String? initialTitle;
  final String? initialArtist;
  final String? initialArtworkUrl;

  const AlbumDetailScreen({
    super.key,
    required this.albumId,
    this.initialTitle,
    this.initialArtist,
    this.initialArtworkUrl,
  });

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaybackPlaying = ref.watch(isPlaybackPlayingProvider);

    final albumAsync = ref.watch(saavnAlbumDetailsProvider(widget.albumId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            size: 24,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.initialTitle ?? 'Album',
          style: AppTypography.style(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: albumAsync.when(
        data: (album) {
          final title = album?.title ?? widget.initialTitle ?? 'Album';
          final artist = album?.primaryArtists ?? widget.initialArtist ?? 'Artist';
          final artwork = album?.imageUrl ?? widget.initialArtworkUrl;
          final playCountText = album?.playCount ?? 'Album';
          final songs = album?.songs ?? [];

          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              const SizedBox(height: 12),

              // Hero Album Cover Art
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: TrackArtwork(
                      artworkUrl: artwork,
                      size: 200,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Album Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),

              // Primary Artists Subtitle (Tap to view artist)
              GestureDetector(
                onTap: () {
                  if (album != null && album.songs.isNotEmpty) {
                    final first = album.songs.first;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ArtistDetailScreen(
                          artistId: first.artistName,
                          initialName: artist,
                          initialImageUrl: artwork,
                        ),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    artist,
                    textAlign: TextAlign.center,
                    style: AppTypography.style(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Metadata Chips Row (Song Count, Plays / Album Tag)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded, size: 15, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${songs.length} ${songs.length == 1 ? "song" : "songs"}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (playCountText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outline_rounded, size: 15, color: isDark ? Colors.white70 : Colors.black87),
                          const SizedBox(width: 6),
                          Text(
                            playCountText,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Controls Row: Play All & Download All (Matching PlaylistDetailScreen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Primary Play All Button (Neon Lime)
                    Expanded(
                      child: SizedBox(
                        height: 48,
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
                          onPressed: songs.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  audioHandler.playTrackList(songs, startIndex: 0);
                                },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Download Album Action Button
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.file_download_outlined,
                          size: 22,
                          color: isDark ? Colors.white : const Color(0xFF1E2028),
                        ),
                        onPressed: songs.isEmpty
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                final downloadManager = ref.read(downloadManagerProvider);
                                for (final track in songs) {
                                  downloadManager.downloadTrack(track);
                                }
                                AppSnackBar.show(
                                  context,
                                  message: 'Downloading album (${songs.length} songs)...',
                                  icon: Icons.download_rounded,
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Album Tracklist ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Tracks',
                  style: AppTypography.style(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),

              if (songs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No tracks available',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              else
                ...songs.map((track) {
                  final isCurrent = currentPlayingTrackId == track.id;
                  final isTilePlaying = isCurrent && isPlaybackPlaying;

                  return TrackListTile(
                    key: ValueKey('album_song_${track.id}'),
                    track: track,
                    isCurrent: isCurrent,
                    isPlaying: isTilePlaying,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      audioHandler.playTrackList(songs, startIndex: songs.indexOf(track));
                    },
                    onLikeToggle: () {
                      ref.read(audioRepositoryProvider).toggleLike(track);
                    },
                  );
                }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
                'Failed to load album details',
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(saavnAlbumDetailsProvider(widget.albumId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
