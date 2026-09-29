import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';
import 'package:musify/presentation/widgets/track_menu_bottom_sheet.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  void _showNewPlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final repo = ref.read(audioRepositoryProvider);
                await repo.createPlaylist(name);
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openPlaylistTracks(BuildContext context, WidgetRef ref, Playlist playlist) async {
    final repo = ref.read(audioRepositoryProvider);
    final audioHandler = ref.read(audioHandlerProvider);
    final tracks = await repo.getPlaylistTracks(playlist.id);

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      playlist.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (tracks.isNotEmpty)
                      FilledButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                        onPressed: () {
                          audioHandler.playTrackList(tracks, startIndex: 0);
                          Navigator.pop(sheetCtx);
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: tracks.isEmpty
                  ? const Center(child: Text('No tracks in this playlist yet'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: tracks.length,
                      itemBuilder: (ctx, idx) => TrackListTile(
                        track: tracks[idx],
                        onTap: () {
                          audioHandler.playTrackList(tracks, startIndex: idx);
                          Navigator.pop(sheetCtx);
                        },
                        onMoreOptions: () {
                          showTrackOptionsBottomSheet(
                            context: context,
                            ref: ref,
                            track: tracks[idx],
                          );
                        },
                      ),
                    ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _openLikedSongs(BuildContext context, WidgetRef ref, List<Track> likedTracks) {
    final audioHandler = ref.read(audioHandlerProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Liked Songs (${likedTracks.length})',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (likedTracks.isNotEmpty)
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play All'),
                      onPressed: () {
                        audioHandler.playTrackList(likedTracks, startIndex: 0);
                        Navigator.pop(sheetCtx);
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: likedTracks.isEmpty
                  ? const Center(child: Text('No liked songs yet'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: likedTracks.length,
                      itemBuilder: (ctx, idx) => TrackListTile(
                        track: likedTracks[idx],
                        onTap: () {
                          audioHandler.playTrackList(likedTracks, startIndex: idx);
                          Navigator.pop(sheetCtx);
                        },
                        onLikeToggle: () {
                          ref.read(audioRepositoryProvider).toggleLike(likedTracks[idx]);
                        },
                        onMoreOptions: () {
                          showTrackOptionsBottomSheet(
                            context: context,
                            ref: ref,
                            track: likedTracks[idx],
                          );
                        },
                      ),
                    ),
            ),
          ],
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
        title: const Text('Your Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Playlist',
            onPressed: () => _showNewPlaylistDialog(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          // Liked Songs Item
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 26),
            ),
            title: const Text('Liked Songs', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$likedCount songs'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              final list = likedTracksAsync.value ?? [];
              _openLikedSongs(context, ref, list);
            },
          ),

          // Local Files Item
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.colorScheme.surface,
              ),
              child: Icon(Icons.folder_rounded, color: theme.colorScheme.primary, size: 26),
            ),
            title: const Text('Local Files', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$localCount audio files on device'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              ref.read(currentTabIndexProvider.notifier).setIndex(0); // Navigate to Home
            },
          ),

          const Divider(height: 24),

          // Playlists Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Playlists', style: theme.textTheme.headlineSmall),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create'),
                  onPressed: () => _showNewPlaylistDialog(context, ref),
                ),
              ],
            ),
          ),

          // User Playlists
          playlistsAsync.when(
            data: (List<Playlist> playlists) {
              if (playlists.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No playlists created yet. Tap "Create" to make one.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Column(
                children: playlists.map((playlist) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: theme.colorScheme.surface,
                      ),
                      child: const Icon(Icons.playlist_play_rounded, size: 28),
                    ),
                    title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(playlist.description ?? 'Playlist'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          ref.read(audioRepositoryProvider).deletePlaylist(playlist.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Playlist'),
                        ),
                      ],
                    ),
                    onTap: () => _openPlaylistTracks(context, ref, playlist),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}
