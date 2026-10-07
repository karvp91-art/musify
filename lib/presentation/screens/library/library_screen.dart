import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';
import 'package:musify/presentation/widgets/create_playlist_modal.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/playlist_artwork.dart';
import '../playlist/playlist_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  void _showNewPlaylistDialog(BuildContext context, WidgetRef ref) {
    showCreatePlaylistModal(
      context,
      ref,
      onCreated: (newPl) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(
              title: newPl.name,
              subtitle: newPl.description,
              playlist: newPl,
            ),
          ),
        );
      },
    );
  }

  void _openPlaylistTracks(BuildContext context, WidgetRef ref, Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          title: playlist.name,
          subtitle: playlist.description,
          playlist: playlist,
        ),
      ),
    );
  }

  void _openLikedSongs(BuildContext context, WidgetRef ref, List<Track> likedTracks) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlaylistDetailScreen(
          title: 'Liked Songs',
          isLikedSongs: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final likedTracksAsync = ref.watch(likedTracksStreamProvider);
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final localTracksAsync = ref.watch(localTracksProvider);

    final likedCount = likedTracksAsync.value?.length ?? 0;
    final localCount = localTracksAsync.value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 26),
            tooltip: 'New Playlist',
            onPressed: () => _showNewPlaylistDialog(context, ref),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          // Liked Songs Item with dynamic mosaic/preset
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: const PlaylistArtwork(
              size: 54,
              isLikedSongs: true,
              borderRadius: BorderRadius.all(Radius.circular(14)),
              hasShadow: false,
            ),
            title: const Text('Liked Songs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            subtitle: Text(
              '$likedCount ${likedCount == 1 ? 'song' : 'songs'}',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 22),
            onTap: () {
              final list = likedTracksAsync.value ?? [];
              _openLikedSongs(context, ref, list);
            },
          ),

          // Local Files Item
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              child: Icon(Icons.folder_rounded, color: theme.colorScheme.primary, size: 28),
            ),
            title: const Text('Local Files', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            subtitle: Text(
              '$localCount audio files on device',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 22),
            onTap: () {
              ref.read(currentTabIndexProvider.notifier).setIndex(1); // Navigate to My music
            },
          ),

          const Divider(height: 28, indent: 14, endIndent: 14),

          // Playlists Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Playlists',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => _showNewPlaylistDialog(context, ref),
                ),
              ],
            ),
          ),

          // User Playlists with dynamic mosaic artwork
          playlistsAsync.when(
            data: (List<Playlist> playlists) {
              if (playlists.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 36),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          size: 48,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No playlists created yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "Create" to start building your mix.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: playlists.map((playlist) {
                  return _PlaylistListTile(
                    playlist: playlist,
                    onTap: () => _openPlaylistTracks(context, ref, playlist),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),

      // Universal Floating Mini Player
      const FloatingMiniPlayer(),
    ],
  ),
);
  }
}

class _PlaylistListTile extends ConsumerWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlaylistListTile({required this.playlist, required this.onTap});

  void _showEditPlaylistDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description ?? '');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        title: const Text('Edit Playlist', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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

  void _confirmDeletePlaylist(BuildContext context, WidgetRef ref) async {
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
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tracksAsync = ref.watch(playlistTracksProvider(playlist.id));
    final tracks = tracksAsync.value ?? const [];
    final audioHandler = ref.read(audioHandlerProvider);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: PlaylistArtwork(
        playlistId: playlist.id,
        size: 54,
        borderRadius: BorderRadius.circular(14),
        hasShadow: false,
      ),
      title: Text(
        playlist.name,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}${playlist.description != null && playlist.description!.isNotEmpty ? ' • ${playlist.description}' : ''}',
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
        icon: Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        ),
        onSelected: (value) async {
          HapticFeedback.selectionClick();
          if (value == 'play') {
            if (tracks.isNotEmpty) {
              audioHandler.playTrackList(tracks, startIndex: 0);
            } else {
              AppSnackBar.show(
                context,
                message: 'Playlist has no songs to play',
                type: AppSnackBarType.info,
              );
            }
          } else if (value == 'edit') {
            _showEditPlaylistDialog(context, ref);
          } else if (value == 'delete') {
            _confirmDeletePlaylist(context, ref);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'play',
            child: Row(
              children: [
                Icon(Icons.play_arrow_rounded, size: 20),
                SizedBox(width: 10),
                Text('Play', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 19),
                SizedBox(width: 10),
                Text('Edit Details', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Delete Playlist', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
