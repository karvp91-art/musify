import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import '../../providers/audio_providers.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
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
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  bool _isReordering = false;
  bool _showAllTracks = false;
  List<Track>? _reorderList;

  void _showEditPlaylistDialog(Playlist playlist) {
    final nameController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E212B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Edit Playlist Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Playlist name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await ref.read(audioRepositoryProvider).updatePlaylist(
                  playlist.id,
                  name: name,
                  description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                );
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(Playlist playlist) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Delete Playlist?',
      description:
          'Are you sure you want to delete "${playlist.name}"? This action cannot be undone and your songs will remain in local music.',
      itemTitle: playlist.name,
      itemSubtitle: 'Playlist',
      itemLeading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF222533)
              : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.queue_music_rounded,
          size: 22,
          color: Color(0xFFFF4D6D),
        ),
      ),
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      await ref.read(audioRepositoryProvider).deletePlaylist(playlist.id);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showTrackMenu(Track track, List<Track> allTracks, int index) async {
    HapticFeedback.selectionClick();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final audioHandler = ref.read(audioHandlerProvider);
    final repo = ref.read(audioRepositoryProvider);

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 240,
        MediaQuery.of(context).size.height * 0.35,
        16,
        0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: isDark ? const Color(0xFF1E212B) : Colors.white,
      elevation: 10,
      items: [
        const PopupMenuItem(
          value: 'next',
          child: Row(
            children: [
              Icon(Icons.playlist_play_rounded, size: 20),
              SizedBox(width: 12),
              Text('Play Next', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'queue',
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded, size: 20),
              SizedBox(width: 12),
              Text('Add to Queue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (widget.playlist != null) ...[
          const PopupMenuItem(
            value: 'remove_playlist',
            child: Row(
              children: [
                Icon(Icons.remove_circle_outline_rounded, size: 20, color: Colors.redAccent),
                SizedBox(width: 12),
                Text('Remove from Playlist', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.redAccent)),
              ],
            ),
          ),
        ],
        const PopupMenuItem(
          value: 'other_playlist',
          child: Row(
            children: [
              Icon(Icons.playlist_add_rounded, size: 20),
              SizedBox(width: 12),
              Text('Add to other Playlist', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'like',
          child: Row(
            children: [
              Icon(
                track.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 20,
                color: track.isLiked ? primaryColor : null,
              ),
              const SizedBox(width: 12),
              Text(
                track.isLiked ? 'Remove from Liked' : 'Save to Liked',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: track.isLiked ? primaryColor : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected == 'next') {
      audioHandler.insertNextInQueue(track);
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Playing next in queue',
          type: AppSnackBarType.info,
          icon: Icons.playlist_play_rounded,
        );
      }
    } else if (selected == 'queue') {
      audioHandler.addToQueue(track);
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Added to queue',
          type: AppSnackBarType.info,
          icon: Icons.queue_music_rounded,
        );
      }
    } else if (selected == 'remove_playlist' && widget.playlist != null) {
      await repo.removeTrackFromPlaylist(widget.playlist!.id, track.id);
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Removed "${track.title}" from playlist',
          type: AppSnackBarType.info,
          icon: Icons.playlist_remove_rounded,
          actionLabel: 'Undo',
          onAction: () async {
            await repo.addTrackToPlaylist(widget.playlist!.id, track);
          },
          duration: const Duration(seconds: 4),
        );
      }
    } else if (selected == 'other_playlist') {
      if (mounted) {
        showAddToPlaylistDropdownDialog(context, ref, track);
      }
    } else if (selected == 'like') {
      await repo.toggleLike(track);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final audioHandler = ref.read(audioHandlerProvider);

    // Watch playlist object reactively to capture title/description updates
    Playlist? currentPlaylist = widget.playlist;
    if (widget.playlist != null) {
      final playlists = ref.watch(playlistsStreamProvider).value;
      if (playlists != null) {
        for (final p in playlists) {
          if (p.id == widget.playlist!.id) {
            currentPlaylist = p;
            break;
          }
        }
      }
    }

    final effectiveTitle = currentPlaylist?.name ?? widget.title;

    // Watch tracks reactively
    final AsyncValue<List<Track>> tracksAsync;
    if (widget.isLikedSongs) {
      tracksAsync = ref.watch(likedTracksStreamProvider);
    } else if (widget.playlist != null) {
      tracksAsync = ref.watch(playlistTracksProvider(widget.playlist!.id));
    } else {
      tracksAsync = const AsyncData([]);
    }

    final currentPlayingTrack = ref.watch(currentPlayingTrackProvider);
    final isPlaying = ref.watch(isPlaybackPlayingProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0F14) : Colors.white,
      body: SafeArea(
        bottom: false,
        child: tracksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading tracks: $err')),
          data: (tracks) {
            // Keep local reorder list in sync when not currently reordering
            if (!_isReordering) {
              _reorderList = List.from(tracks);
            }

            final displayTracks = _isReordering ? (_reorderList ?? tracks) : tracks;

            // Determine which track is displayed in the hero section
            final currentIdx = tracks.indexWhere((t) => t.id == currentPlayingTrack?.id);
            final Track? heroTrack;
            final int heroIndex;
            final bool isCurrentTrackActive;

            if (currentIdx != -1) {
              heroTrack = currentPlayingTrack;
              heroIndex = currentIdx;
              isCurrentTrackActive = true;
            } else if (tracks.isNotEmpty) {
              heroTrack = tracks.first;
              heroIndex = 0;
              isCurrentTrackActive = false;
            } else {
              heroTrack = null;
              heroIndex = -1;
              isCurrentTrackActive = false;
            }

            // Determine upcoming tracks for "Up Next" section
            final List<Track> upNextTracks;
            if (_showAllTracks || heroIndex == -1 || tracks.length <= 1) {
              upNextTracks = displayTracks;
            } else {
              // Tracks following the current hero track
              final nextSlice = displayTracks.sublist(heroIndex + 1);
              upNextTracks = nextSlice.isNotEmpty ? nextSlice : displayTracks;
            }

            final screenWidth = MediaQuery.of(context).size.width;
            final artSize = (screenWidth * 0.70).clamp(230.0, 310.0);

            // Compute vibrant ambient glow for hero artwork
            final seedKey = heroTrack?.id.isNotEmpty == true ? heroTrack!.id : (heroTrack?.title ?? effectiveTitle);
            final gradientColors = TrackArtwork.getGradientForSeed(seedKey, isDark: isDark);
            final glowColor = gradientColors.isNotEmpty ? gradientColors.first : primaryColor;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  // 1. Top Bar: Back | Now Playing + From Title | Heart + 3-Dots
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Back button in circular container
                        _CircularActionButton(
                          icon: Icons.chevron_left_rounded,
                          size: 42,
                          iconSize: 26,
                          isDark: isDark,
                          onTap: () => Navigator.pop(context),
                        ),

                        // Center: Now Playing + From Subtitle
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Now Playing',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF111318),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'From $effectiveTitle',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white54 : const Color(0xFF767B8B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right: Heart + More 3-Dots buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Heart Favorite Button
                            _CircularActionButton(
                              icon: (heroTrack?.isLiked == true)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              iconColor: (heroTrack?.isLiked == true)
                                  ? const Color(0xFFFF4D6D)
                                  : (isDark ? Colors.white : const Color(0xFF14161C)),
                              size: 42,
                              iconSize: 20,
                              isDark: isDark,
                              onTap: () {
                                if (heroTrack != null) {
                                  HapticFeedback.selectionClick();
                                  ref.read(audioRepositoryProvider).toggleLike(heroTrack);
                                }
                              },
                            ),
                            const SizedBox(width: 10),

                            // More 3-Dots Button
                            PopupMenuButton<String>(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              color: isDark ? const Color(0xFF1E212B) : Colors.white,
                              elevation: 10,
                              icon: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF20222B) : const Color(0xFFF1F3F6),
                                ),
                                child: Icon(
                                  Icons.more_vert_rounded,
                                  size: 20,
                                  color: isDark ? Colors.white : const Color(0xFF14161C),
                                ),
                              ),
                              onSelected: (val) {
                                HapticFeedback.selectionClick();
                                if (val == 'edit' && currentPlaylist != null) {
                                  _showEditPlaylistDialog(currentPlaylist);
                                } else if (val == 'reorder') {
                                  setState(() {
                                    _isReordering = true;
                                    _reorderList = List.from(tracks);
                                  });
                                } else if (val == 'delete' && currentPlaylist != null) {
                                  _confirmDeletePlaylist(currentPlaylist);
                                } else if (val == 'show_all') {
                                  setState(() {
                                    _showAllTracks = !_showAllTracks;
                                  });
                                }
                              },
                              itemBuilder: (context) => [
                                if (currentPlaylist != null) ...[
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 20),
                                        SizedBox(width: 12),
                                        Text('Edit Details', style: TextStyle(fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ],
                                if (tracks.length > 1) ...[
                                  PopupMenuItem(
                                    value: 'reorder',
                                    child: Row(
                                      children: [
                                        Icon(_isReordering ? Icons.check_rounded : Icons.reorder_rounded, size: 20),
                                        const SizedBox(width: 12),
                                        Text(_isReordering ? 'Finish Reordering' : 'Reorder Tracks', style: const TextStyle(fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'show_all',
                                    child: Row(
                                      children: [
                                        Icon(_showAllTracks ? Icons.playlist_play_rounded : Icons.queue_music_rounded, size: 20),
                                        const SizedBox(width: 12),
                                        Text(_showAllTracks ? 'Show Up Next Only' : 'Show All Tracks', style: const TextStyle(fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ],
                                if (currentPlaylist != null) ...[
                                  const PopupMenuDivider(height: 1),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                        SizedBox(width: 12),
                                        Text('Delete Playlist', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Featured Album Artwork with Smooth Radial Glow
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! < -250) {
                            HapticFeedback.lightImpact();
                            audioHandler.skipToNext();
                          } else if (details.primaryVelocity! > 250) {
                            HapticFeedback.lightImpact();
                            audioHandler.skipToPrevious();
                          }
                        }
                      },
                      child: Container(
                        width: artSize,
                        height: artSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            // Soft ambient colored halo matching reference artwork
                            BoxShadow(
                              color: glowColor.withValues(alpha: isDark ? 0.35 : 0.28),
                              blurRadius: 40,
                              spreadRadius: 3,
                              offset: const Offset(0, 10),
                            ),
                            // Grounding drop shadow
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: TrackArtwork(
                            artworkUrl: heroTrack?.artworkUrl,
                            seedKey: seedKey,
                            size: artSize,
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 3. Track Title & Artist (Clean Centered Typography)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Text(
                          heroTrack?.title ?? effectiveTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF111318),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          heroTrack?.artistName ?? '${tracks.length} tracks',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : const Color(0xFF767B8B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. Custom Neon Lime Seek Bar (1:10 —————●——— 3:35)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _PlaylistPlayerSeekBar(
                      isCurrentTrackActive: isCurrentTrackActive,
                      fallbackDuration: Duration(milliseconds: heroTrack?.durationMs ?? 0),
                      onSeek: (pos) => audioHandler.seek(pos),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. Playback Controls Row: Shuffle | Prev | Play/Pause (Lime Glow) | Next | Repeat
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Shuffle Button
                        Consumer(
                          builder: (context, ref, _) {
                            final isShuffle = ref.watch(
                              playerStateStreamProvider.select((s) => s.value?.isShuffleEnabled ?? false),
                            );
                            return IconButton(
                              icon: Icon(
                                Icons.shuffle_rounded,
                                size: 24,
                                color: isShuffle
                                    ? AppColors.neonLime
                                    : (isDark ? Colors.white54 : const Color(0xFF8E92A2)),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                audioHandler.toggleShuffle();
                              },
                            );
                          },
                        ),

                        // Skip Previous Button in Circle
                        _CircularActionButton(
                          icon: Icons.skip_previous_rounded,
                          size: 54,
                          iconSize: 28,
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            audioHandler.skipToPrevious();
                          },
                        ),

                        // Large Neon Lime Play/Pause Button with Glowing Halo
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            if (isCurrentTrackActive) {
                              if (isPlaying) {
                                audioHandler.pause();
                              } else {
                                audioHandler.play();
                              }
                            } else if (tracks.isNotEmpty) {
                              audioHandler.playTrackList(tracks, startIndex: heroIndex >= 0 ? heroIndex : 0);
                            }
                          },
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.neonLime,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.neonLime.withValues(alpha: 0.55),
                                  blurRadius: 22,
                                  spreadRadius: 3,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                (isPlaying && isCurrentTrackActive)
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 36,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),

                        // Skip Next Button in Circle
                        _CircularActionButton(
                          icon: Icons.skip_next_rounded,
                          size: 54,
                          iconSize: 28,
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            audioHandler.skipToNext();
                          },
                        ),

                        // Repeat Button
                        Consumer(
                          builder: (context, ref, _) {
                            final repeatMode = ref.watch(
                              playerStateStreamProvider.select((s) => s.value?.repeatMode ?? AppRepeatMode.off),
                            );
                            final isActive = repeatMode != AppRepeatMode.off;
                            final icon = repeatMode == AppRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded;

                            return IconButton(
                              icon: Icon(
                                icon,
                                size: 24,
                                color: isActive
                                    ? AppColors.neonLime
                                    : (isDark ? Colors.white54 : const Color(0xFF8E92A2)),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                audioHandler.cycleRepeatMode();
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 6. "Up Next" Card Section with Rounded Top Corners & List
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151722) : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border.all(
                        color: isDark ? const Color(0xFF222533) : const Color(0xFFECEEF2),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Drag Handle Pill
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2E3E) : const Color(0xFFD5D8DF),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Header Row: "Up Next" and "See All >"
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isReordering ? 'Reorder Tracks' : 'Up Next',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF111318),
                                ),
                              ),
                              if (_isReordering)
                                TextButton(
                                  onPressed: () async {
                                    HapticFeedback.mediumImpact();
                                    if (_reorderList != null && currentPlaylist != null) {
                                      final newOrder = _reorderList!.map((t) => t.id).toList();
                                      await ref.read(audioRepositoryProvider).reorderPlaylistTracks(currentPlaylist.id, newOrder);
                                    }
                                    setState(() => _isReordering = false);
                                  },
                                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                                )
                              else if (tracks.length > 1)
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _showAllTracks = !_showAllTracks;
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        _showAllTracks ? 'Show Less' : 'See All',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white60 : const Color(0xFF717584),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        _showAllTracks ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
                                        size: 18,
                                        color: isDark ? Colors.white60 : const Color(0xFF717584),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Tracks List
                        if (tracks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    widget.isLikedSongs ? Icons.favorite_border_rounded : Icons.queue_music_rounded,
                                    size: 44,
                                    color: isDark ? Colors.white24 : Colors.black26,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.isLikedSongs ? 'No liked tracks yet' : 'This playlist is empty',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.isLikedSongs
                                        ? 'Tap the heart icon on any song to save it here.'
                                        : 'Tap the 3 dots on any song to add it here.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_isReordering && currentPlaylist != null)
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayTracks.length,
                            // ignore: deprecated_member_use
                            onReorder: (oldIndex, newIndex) async {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final item = _reorderList!.removeAt(oldIndex);
                                _reorderList!.insert(newIndex, item);
                              });
                              final newOrder = _reorderList!.map((t) => t.id).toList();
                              await ref.read(audioRepositoryProvider).reorderPlaylistTracks(currentPlaylist!.id, newOrder);
                            },
                            itemBuilder: (context, idx) {
                              final track = displayTracks[idx];
                              return ListTile(
                                key: ValueKey(track.id),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                                leading: TrackArtwork(
                                  artworkUrl: track.artworkUrl,
                                  size: 46,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                                subtitle: Text(
                                  track.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                                trailing: ReorderableDragStartListener(
                                  index: idx,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: upNextTracks.length,
                            padding: const EdgeInsets.only(top: 4, bottom: 20),
                            itemBuilder: (context, idx) {
                              final track = upNextTracks[idx];
                              final isCurrent = currentPlayingTrack?.id == track.id;
                              final isCurrentPlaying = isCurrent && isPlaying;
                              final originalIndex = tracks.indexOf(track);

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    final playIdx = originalIndex >= 0 ? originalIndex : idx;
                                    audioHandler.playTrackList(tracks, startIndex: playIdx);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                    child: Row(
                                      children: [
                                        // Track Thumbnail
                                        TrackArtwork(
                                          artworkUrl: track.artworkUrl,
                                          seedKey: track.id.isNotEmpty ? track.id : track.title,
                                          size: 48,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        const SizedBox(width: 14),

                                        // Title and Artist
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                track.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: isCurrent
                                                      ? (isDark ? AppColors.neonLime : AppColors.limeAccentDark)
                                                      : (isDark ? Colors.white : const Color(0xFF111318)),
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                track.artistName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? Colors.white54 : const Color(0xFF767B8B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Circular Play Button (Reference UI)
                                        GestureDetector(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            if (isCurrent) {
                                              if (isPlaying) {
                                                audioHandler.pause();
                                              } else {
                                                audioHandler.play();
                                              }
                                            } else {
                                              final playIdx = originalIndex >= 0 ? originalIndex : idx;
                                              audioHandler.playTrackList(tracks, startIndex: playIdx);
                                            }
                                          },
                                          child: Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isDark ? const Color(0xFF222533) : const Color(0xFFF1F3F6),
                                            ),
                                            child: Icon(
                                              isCurrentPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              size: 20,
                                              color: isDark ? Colors.white : const Color(0xFF14161C),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 4),

                                        // 3-Dots More Options Menu
                                        IconButton(
                                          icon: Icon(
                                            Icons.more_vert_rounded,
                                            size: 20,
                                            color: isDark ? Colors.white54 : const Color(0xFF8E92A2),
                                          ),
                                          onPressed: () {
                                            final menuIdx = originalIndex >= 0 ? originalIndex : idx;
                                            _showTrackMenu(track, tracks, menuIdx);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        // Extra bottom clearance for mini player
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CircularActionButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final bool isDark;
  final VoidCallback onTap;

  const _CircularActionButton({
    required this.icon,
    this.iconColor,
    this.size = 42,
    this.iconSize = 20,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFF1F3F6),
        ),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor ?? (isDark ? Colors.white : const Color(0xFF14161C)),
          ),
        ),
      ),
    );
  }
}

class _PlaylistPlayerSeekBar extends ConsumerStatefulWidget {
  final bool isCurrentTrackActive;
  final Duration fallbackDuration;
  final ValueChanged<Duration> onSeek;

  const _PlaylistPlayerSeekBar({
    required this.isCurrentTrackActive,
    required this.fallbackDuration,
    required this.onSeek,
  });

  @override
  ConsumerState<_PlaylistPlayerSeekBar> createState() => _PlaylistPlayerSeekBarState();
}

class _PlaylistPlayerSeekBarState extends ConsumerState<_PlaylistPlayerSeekBar> {
  double? _dragValue;

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Duration currentPos;
    final Duration totalDur;

    if (widget.isCurrentTrackActive) {
      currentPos = ref.watch(playerStateStreamProvider.select((s) => s.value?.position ?? Duration.zero));
      totalDur = ref.watch(playerStateStreamProvider.select((s) => s.value?.duration ?? widget.fallbackDuration));
    } else {
      currentPos = Duration.zero;
      totalDur = widget.fallbackDuration;
    }

    final totalDurationMs = totalDur.inMilliseconds.toDouble();
    final currentPosMs = currentPos.inMilliseconds.toDouble().clamp(
          0.0,
          totalDurationMs > 0 ? totalDurationMs : 1.0,
        );

    final sliderValue = (_dragValue ?? currentPosMs).clamp(
      0.0,
      totalDurationMs > 0 ? totalDurationMs : 1.0,
    );

    final isDragging = _dragValue != null;
    final displayPosition = isDragging
        ? Duration(milliseconds: _dragValue!.round())
        : currentPos;

    final inactiveTrack = isDark
        ? const Color(0xFF262835)
        : const Color(0xFFE8EAF0);
    const timeColor = Color(0xFF858997);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: theme.sliderTheme.copyWith(
            trackHeight: 4.0,
            trackShape: const RectangularSliderTrackShape(),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 6.5,
              elevation: 2,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.neonLime,
            inactiveTrackColor: inactiveTrack,
            thumbColor: AppColors.neonLime,
            overlayColor: AppColors.neonLime.withValues(alpha: 0.22),
          ),
          child: Slider(
            min: 0.0,
            max: totalDurationMs > 0 ? totalDurationMs : 1.0,
            value: sliderValue,
            onChangeStart: (val) {
              HapticFeedback.selectionClick();
            },
            onChanged: totalDurationMs > 0
                ? (val) {
                    setState(() {
                      _dragValue = val;
                    });
                  }
                : null,
            onChangeEnd: totalDurationMs > 0
                ? (val) {
                    HapticFeedback.lightImpact();
                    widget.onSeek(Duration(milliseconds: val.round()));
                    setState(() {
                      _dragValue = null;
                    });
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(displayPosition),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: timeColor,
                ),
              ),
              Text(
                _formatTime(totalDur),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: timeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
