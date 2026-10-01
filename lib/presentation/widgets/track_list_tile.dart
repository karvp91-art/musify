import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import '../../core/theme/app_colors.dart';
import '../providers/audio_providers.dart';
import 'track_artwork.dart';
import 'track_menu_bottom_sheet.dart';

class TrackListTile extends ConsumerWidget {
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onPlayPause;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onMoreOptions;
  final VoidCallback? onRemoveFromPlaylist;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;

  const TrackListTile({
    super.key,
    required this.track,
    this.isCurrent = false,
    this.isPlaying = false,
    required this.onTap,
    this.onPlayPause,
    this.onLikeToggle,
    this.onMoreOptions,
    this.onRemoveFromPlaylist,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
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

    void handlePlayPauseAction() {
      HapticFeedback.selectionClick();
      if (isSelectionMode) {
        onTap();
        return;
      }
      if (onPlayPause != null) {
        onPlayPause!();
        return;
      }
      if (isCurrent) {
        final audioHandler = ref.read(audioHandlerProvider);
        if (isPlaying) {
          audioHandler.pause();
        } else {
          audioHandler.play();
        }
      } else {
        onTap();
      }
    }

    return InkWell(
      onTap: () {
        if (isSelectionMode) {
          onTap();
        } else if (isCurrent) {
          handlePlayPauseAction();
        } else {
          onTap();
        }
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
      highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? (isDark
                  ? const Color(0xFF84CC16).withValues(alpha: 0.12)
                  : const Color(0xFFF2F8EA))
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Checkbox for Selection Mode
            if (isSelectionMode) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (isDark ? AppColors.neonLime : const Color(0xFF70A314))
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? AppColors.neonLime : const Color(0xFF70A314))
                        : (isDark ? Colors.white.withValues(alpha: 0.38) : const Color(0xFF9E9E9E)),
                    width: 1.6,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: isDark ? Colors.black : Colors.white,
                      )
                    : null,
              ),
            ],

            // Rounded Square Artwork (matching reference — 14px radius)
            TrackArtwork(
              artworkUrl: track.artworkUrl,
              seedKey: track.id.isNotEmpty ? track.id : track.title,
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

            if (!isSelectionMode) ...[
              const SizedBox(width: 6),

              // Inline Download Indicator / Button
              Consumer(
                builder: (context, ref, _) {
                  final downloadManager = ref.watch(downloadManagerProvider);
                  return ListenableBuilder(
                    listenable: downloadManager,
                    builder: (context, _) {
                      final state = downloadManager.getState(track.id);
                      final isDownloaded = state.isDownloaded || track.isDownloaded;
                      final isDownloading = state.isDownloading;

                      if (isDownloading) {
                        return GestureDetector(
                          onTap: () => downloadManager.cancelDownload(track.id),
                          child: Tooltip(
                            message: 'Cancel download',
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    value: state.progress > 0 ? state.progress : null,
                                    strokeWidth: 2.4,
                                    color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      } else if (!isDownloaded && track.source != AudioSourceType.local) {
                        return IconButton(
                          icon: Icon(
                            Icons.download_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                          tooltip: 'Download song',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            downloadManager.downloadTrack(track);
                            AppSnackBar.show(
                              context,
                              message: 'Downloading "${track.title}"...',
                              type: AppSnackBarType.info,
                              icon: Icons.download_rounded,
                              duration: const Duration(seconds: 2),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),

              const SizedBox(width: 4),

              // Trailing: Borderless Circular Play / Pause Action Button
              GestureDetector(
                onTap: handlePlayPauseAction,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? (isDark ? AppColors.neonLime : AppColors.neonLime)
                        : (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2)),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: (isDark ? AppColors.neonLime : Colors.black).withValues(alpha: 0.20),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                    color: isCurrent
                        ? (isDark ? const Color(0xFF111827) : const Color(0xFF111827))
                        : (isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028)),
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
                  onRemoveFromPlaylist: onRemoveFromPlaylist,
                ),
            ],
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
  final VoidCallback? onRemoveFromPlaylist;

  const _TrackTilePopupMenu({
    required this.track,
    required this.isDark,
    this.onLikeToggle,
    this.onRemoveFromPlaylist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final downloadManager = ref.watch(downloadManagerProvider);

    return ListenableBuilder(
      listenable: downloadManager,
      builder: (context, _) {
        final isDownloaded = downloadManager.isDownloaded(track.id) || track.isDownloaded;
        final isDownloading = downloadManager.isDownloading(track.id);

        return Theme(
          data: theme.copyWith(
            popupMenuTheme: PopupMenuThemeData(
              color: isDark ? Colors.black : Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
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
                AppSnackBar.show(
                  context,
                  message: 'Playing next in queue',
                  type: AppSnackBarType.info,
                  icon: Icons.playlist_play_rounded,
                );
              } else if (value == 'queue') {
                ref.read(audioHandlerProvider).addToQueue(track);
                AppSnackBar.show(
                  context,
                  message: 'Added to queue',
                  type: AppSnackBarType.info,
                  icon: Icons.queue_music_rounded,
                );
              } else if (value == 'playlist') {
                showAddToPlaylistDropdownDialog(context, ref, track);
              } else if (value == 'remove_playlist') {
                onRemoveFromPlaylist?.call();
              } else if (value == 'download') {
                downloadManager.downloadTrack(track);
                AppSnackBar.show(
                  context,
                  message: 'Downloading "${track.title}"...',
                  type: AppSnackBarType.info,
                  icon: Icons.download_rounded,
                );
              } else if (value == 'cancel_download') {
                downloadManager.cancelDownload(track.id);
              } else if (value == 'delete_device') {
                showConfirmDeleteTrackDialog(context, ref, track);
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
              if (onRemoveFromPlaylist != null) ...[
                const PopupMenuItem(
                  value: 'remove_playlist',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline_rounded, size: 20, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Text('Remove from Playlist',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500, color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
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
              if (!isDownloaded && !isDownloading) ...[
                PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
                      const SizedBox(width: 12),
                      const Text('Download Song', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ] else if (isDownloading) ...[
                PopupMenuItem(
                  value: 'cancel_download',
                  child: Row(
                    children: [
                      Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
                      const SizedBox(width: 12),
                      const Text('Cancel Download', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ] else if (isDownloaded || track.source == AudioSourceType.local) ...[
                const PopupMenuItem(
                  value: 'delete_device',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Text('Delete from Device', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
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
      },
    );
  }
}
