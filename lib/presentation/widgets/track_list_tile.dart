import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/track.dart';
import '../providers/audio_providers.dart';
import 'track_artwork.dart';
import 'track_menu_bottom_sheet.dart';

class TrackListTile extends ConsumerWidget {
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onMoreOptions;

  const TrackListTile({
    super.key,
    required this.track,
    this.isCurrent = false,
    this.isPlaying = false,
    required this.onTap,
    this.onLikeToggle,
    this.onMoreOptions,
  });

  String _formatDuration(int ms) {
    if (ms <= 0) return '';
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final durationStr = _formatDuration(track.durationMs);

    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
      highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Rounded Square Artwork (matching reference — 14px radius)
            TrackArtwork(
              artworkUrl: track.artworkUrl,
              size: 56,
              borderRadius: BorderRadius.circular(14),
            ),
            const SizedBox(width: 14),

            // Title & "By Artist • Duration"
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isCurrent ? primaryColor : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (track.source == AudioSourceType.saavn) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '320K',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          'By ${track.artistName}${durationStr.isNotEmpty ? ' • $durationStr' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Trailing: Borderless Circular Play / Pause Action Button
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying
                      ? primaryColor
                      : (isCurrent
                          ? primaryColor.withValues(alpha: 0.18)
                          : (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2))),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 20,
                  color: isPlaying
                      ? Colors.black
                      : (isCurrent ? primaryColor : (isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028))),
                ),
              ),
            ),

            const SizedBox(width: 2),

            // 3-Dot Dropdown Menu Button — always positioned precisely at this song's button
            if (onMoreOptions != null)
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                onPressed: onMoreOptions,
              )
            else
              _TrackTilePopupMenu(
                track: track,
                isDark: isDark,
                onLikeToggle: onLikeToggle,
              ),
          ],
        ),
      ),
    );
  }
}

class _TrackTilePopupMenu extends ConsumerWidget {
  final Track track;
  final bool isDark;
  final VoidCallback? onLikeToggle;

  const _TrackTilePopupMenu({
    required this.track,
    required this.isDark,
    this.onLikeToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Theme(
      data: theme.copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? const Color(0xFF1E212B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 10,
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'More options',
        position: PopupMenuPosition.under,
        offset: const Offset(0, 4),
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        ),
        onSelected: (value) {
          HapticFeedback.selectionClick();
          if (value == 'next') {
            ref.read(audioHandlerProvider).insertNextInQueue(track);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Playing next in queue')),
            );
          } else if (value == 'queue') {
            ref.read(audioHandlerProvider).addToQueue(track);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added to queue')),
            );
          } else if (value == 'playlist') {
            showAddToPlaylistDropdownDialog(context, ref, track);
          } else if (value == 'like') {
            if (onLikeToggle != null) {
              onLikeToggle!();
            } else {
              ref.read(audioRepositoryProvider).toggleLike(track);
            }
          }
        },
        itemBuilder: (ctx) => [
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
      ),
    );
  }
}
