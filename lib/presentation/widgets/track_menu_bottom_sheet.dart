import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/track.dart';
import '../providers/audio_providers.dart';

/// Displays a dropdown popup menu for track actions instead of a modal bottom sheet.
void showTrackDropdownMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Track track,
  Offset? tapPosition,
  BuildContext? buttonContext,
}) async {
  HapticFeedback.selectionClick();
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final primaryColor = theme.colorScheme.primary;
  final audioHandler = ref.read(audioHandlerProvider);
  final repo = ref.read(audioRepositoryProvider);

  final screenSize = MediaQuery.of(context).size;
  double dx = screenSize.width - 24;
  double dy = screenSize.height * 0.4;

  final targetCtx = buttonContext ?? context;
  try {
    final box = targetCtx.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final pos = box.localToGlobal(Offset.zero);
      final size = box.size;
      if (size.height < screenSize.height * 0.7) {
        dx = pos.dx + size.width;
        dy = pos.dy + size.height;
      }
    }
  } catch (_) {}

  if (tapPosition != null) {
    dx = tapPosition.dx;
    dy = tapPosition.dy;
  }

  // Clamp menu positioning so it stays elegantly on-screen
  final double menuWidth = 220;
  final double left = (dx - menuWidth).clamp(12.0, screenSize.width - menuWidth - 12);
  final double top = (dy).clamp(60.0, screenSize.height - 260);

  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      left,
      top,
      screenSize.width - left - menuWidth,
      screenSize.height - top,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    color: isDark ? const Color(0xFF1E212B) : Colors.white,
    elevation: 10,
    items: [
      PopupMenuItem(
        value: 'next',
        child: Row(
          children: [
            Icon(Icons.playlist_play_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
            const SizedBox(width: 12),
            const Text('Play Next', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'queue',
        child: Row(
          children: [
            Icon(Icons.queue_music_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
            const SizedBox(width: 12),
            const Text('Add to Queue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'playlist',
        child: Row(
          children: [
            Icon(Icons.playlist_add_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
            const SizedBox(width: 12),
            const Text('Add to Playlist', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
              color: track.isLiked ? primaryColor : theme.colorScheme.onSurface.withValues(alpha: 0.75),
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playing next in queue')),
      );
    }
  } else if (selected == 'queue') {
    audioHandler.addToQueue(track);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to queue')),
      );
    }
  } else if (selected == 'playlist') {
    if (context.mounted) {
      showAddToPlaylistDropdownDialog(context, ref, track);
    }
  } else if (selected == 'like') {
    repo.toggleLike(track);
  }
}

/// Backward compatibility alias — redirects to the dropdown menu to eliminate bottom sheets
void showTrackOptionsBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Track track,
}) {
  showTrackDropdownMenu(context: context, ref: ref, track: track);
}

/// Dialog for selecting playlist (replaces bottom sheet with a clean dialog)
void showAddToPlaylistDropdownDialog(BuildContext context, WidgetRef ref, Track track) async {
  final repo = ref.read(audioRepositoryProvider);
  final playlists = await repo.getPlaylists();

  if (!context.mounted) return;
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final primaryColor = theme.colorScheme.primary;

  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E212B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Add to Playlist',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: playlists.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No playlists created yet.\nCreate one in Library tab.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (ctx, idx) {
                  final pl = playlists[idx];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.queue_music_rounded, color: primaryColor, size: 20),
                    ),
                    title: Text(
                      pl.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: pl.description != null && pl.description!.isNotEmpty
                        ? Text(pl.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    onTap: () async {
                      await repo.addTrackToPlaylist(pl.id, track);
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to "${pl.name}"')),
                        );
                      }
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}
