import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/track.dart';
import '../providers/audio_providers.dart';

void showTrackOptionsBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Track track,
}) {
  HapticFeedback.selectionClick();
  final theme = Theme.of(context);
  final audioHandler = ref.read(audioHandlerProvider);
  final repo = ref.read(audioRepositoryProvider);

  showModalBottomSheet(
    context: context,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Track Header summary in sheet
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: theme.colorScheme.surface,
                    child: track.artworkUrl != null
                        ? Image.network(
                            track.artworkUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.music_note_rounded),
                          )
                        : const Icon(Icons.music_note_rounded),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Menu Actions
          ListTile(
            leading: const Icon(Icons.playlist_play_rounded),
            title: const Text('Play Next'),
            onTap: () {
              audioHandler.insertNextInQueue(track);
              Navigator.pop(sheetCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Playing next in queue')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: const Text('Add to Queue'),
            onTap: () {
              audioHandler.addToQueue(track);
              Navigator.pop(sheetCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to queue')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('Add to Playlist'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _showAddToPlaylistDialog(context, ref, track);
            },
          ),
          ListTile(
            leading: Icon(
              track.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: track.isLiked ? theme.colorScheme.primary : null,
            ),
            title: Text(track.isLiked ? 'Remove from Liked Songs' : 'Save to Liked Songs'),
            onTap: () {
              repo.toggleLike(track);
              Navigator.pop(sheetCtx);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref, Track track) async {
  final repo = ref.read(audioRepositoryProvider);
  final playlists = await repo.getPlaylists();

  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Add to Playlist',
              style: Theme.of(ctx).textTheme.headlineSmall,
            ),
          ),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No playlists created yet. Create one in Library.')),
            )
          else
            ...playlists.map((pl) => ListTile(
                  leading: const Icon(Icons.playlist_play_rounded),
                  title: Text(pl.name),
                  onTap: () async {
                    await repo.addTrackToPlaylist(pl.id, track);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added to "${pl.name}"')),
                      );
                    }
                  },
                )),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
