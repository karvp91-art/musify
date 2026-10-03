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
  final bool isYouTubeSection;

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
    this.isYouTubeSection = false,
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

    // Reactively watch if this track is liked — O(1) Set lookup via derived provider
    final isLiked = ref.watch(
      likedTrackIdsProvider.select((ids) => ids.contains(track.id)),
    );

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

    final isYt = isYouTubeSection || track.source == AudioSourceType.youtube;

    final tileContent = InkWell(
      onTap: () {
        if (isSelectionMode) {
          onTap();
          return;
        }
        if (isYt && !track.isDownloaded) {
          final downloadManager = ref.read(downloadManagerProvider);
          if (!downloadManager.isDownloaded(track.id)) {
            HapticFeedback.lightImpact();
            AppSnackBar.show(
              context,
              message: 'YouTube is for download only. Downloading to Music folder...',
            );
            downloadManager.downloadTrack(track);
            return;
          }
        }
        if (isCurrent) {
          handlePlayPauseAction();
        } else {
          onTap();
        }
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
      highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? (isDark
                  ? const Color(0xFF84CC16).withValues(alpha: 0.12)
                  : const Color(0xFFF2F8EA))
              : theme.scaffoldBackgroundColor,
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
                      ] else if (track.source == AudioSourceType.youtube) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'YT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFF3333),
                                ),
                              ),
                              if (track.isDownloaded) ...[
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.check_rounded,
                                  size: 10,
                                  color: Color(0xFF22C55E),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          isYt && !track.isDownloaded
                              ? 'By ${track.artistName} • Download only (no streaming)'
                              : 'By ${track.artistName}${durationStr.isNotEmpty ? ' • $durationStr' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isYt && !track.isDownloaded
                                ? (isDark ? const Color(0xFFFF6666) : const Color(0xFFCC0000))
                                : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            fontSize: 12.5,
                            fontWeight: isYt && !track.isDownloaded ? FontWeight.w600 : FontWeight.w500,
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

              if (track.source != AudioSourceType.local || isYouTubeSection)
                Consumer(
                  builder: (context, ref, _) {
                    final downloadManager = ref.watch(downloadManagerProvider);
                    return ListenableBuilder(
                      listenable: downloadManager,
                      builder: (context, _) {
                        final state = downloadManager.getState(track.id);
                        final isDownloaded = state.isDownloaded || track.isDownloaded;
                        final isDownloading = state.isDownloading;

                        // When in YouTube section (or undownloaded YouTube track):
                        // Only show Download button — no streaming play button!
                        if (isYt && !isDownloaded) {
                          if (isDownloading) {
                            return GestureDetector(
                              onTap: () {
                                downloadManager.cancelDownload(track.id);
                                AppSnackBar.show(
                                  context,
                                  message: 'Cancelled download for "${track.title}"',
                                );
                              },
                              child: Tooltip(
                                message: 'Cancel download (${(state.progress * 100).toInt()}%)',
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
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
                          }

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              AppSnackBar.show(
                                context,
                                message: 'YouTube is for download only. Downloading to Music folder...',
                              );
                              downloadManager.downloadTrack(track);
                            },
                            child: Tooltip(
                              message: 'Download to permanent Music folder',
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0xFFFF0000).withValues(alpha: 0.18)
                                      : const Color(0xFFFFEEEE),
                                ),
                                child: const Icon(
                                  Icons.download_rounded,
                                  size: 20,
                                  color: Color(0xFFFF3333),
                                ),
                              ),
                            ),
                          );
                        }

                        // Standard Track (or already-downloaded YouTube track):
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isDownloaded && !isYt) ...[
                              if (isDownloading) ...[
                                GestureDetector(
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
                                ),
                              ] else ...[
                                IconButton(
                                  icon: Icon(
                                    Icons.download_rounded,
                                    size: 20,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                  ),
                                  tooltip: 'Download song',
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    downloadManager.downloadTrack(track);
                                  },
                                ),
                              ],
                              const SizedBox(width: 4),
                            ],

                            // Trailing Play / Pause Button
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
                                      ? const Color(0xFF111827)
                                      : (isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028)),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                )
              else
                // Pure Local track: direct play button
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
                          ? const Color(0xFF111827)
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
                  isLiked: isLiked,
                  onLikeToggle: onLikeToggle,
                  onRemoveFromPlaylist: onRemoveFromPlaylist,
                ),
            ],
          ],
        ),
      ),
    );

    if (isSelectionMode) {
      return tileContent;
    }

    final isRemovingFromPlaylist = onRemoveFromPlaylist != null;

    return Dismissible(
      key: ValueKey('swipe_${key != null ? key.toString() : track.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.26,
        DismissDirection.endToStart: 0.26,
      },
      movementDuration: const Duration(milliseconds: 200),
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          HapticFeedback.selectionClick();
        }
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Immediately enqueues Play Next with haptic feedback
          HapticFeedback.mediumImpact();
          ref.read(audioHandlerProvider).insertNextInQueue(track);
          AppSnackBar.show(
            context,
            message: 'Playing "${track.title}" next',
            type: AppSnackBarType.info,
            icon: Icons.playlist_play_rounded,
          );
          return false;
        } else if (direction == DismissDirection.endToStart) {
          // Swipe Left: Quick toggle Like / Favorite or Remove
          HapticFeedback.mediumImpact();
          if (isRemovingFromPlaylist) {
            onRemoveFromPlaylist!();
          } else {
            final wasLiked = isLiked;
            if (onLikeToggle != null) {
              onLikeToggle!();
            } else {
              ref.read(audioRepositoryProvider).toggleLike(track);
            }
            ref.invalidate(likedTracksStreamProvider);
            AppSnackBar.show(
              context,
              message: wasLiked
                  ? 'Removed "${track.title}" from Liked'
                  : 'Added "${track.title}" to Liked',
              type: AppSnackBarType.info,
              icon: wasLiked ? Icons.favorite_border_rounded : Icons.favorite_rounded,
            );
          }
          return false;
        }
        return false;
      },
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        iconBackgroundColor: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
        iconColor: isDark ? const Color(0xFF111827) : Colors.white,
        icon: Icons.playlist_play_rounded,
        title: 'Play Next',
        textColor: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
      ),
      secondaryBackground: isRemovingFromPlaylist
          ? _buildSwipeBackground(
              alignment: Alignment.centerRight,
              iconBackgroundColor: Colors.redAccent,
              iconColor: Colors.white,
              icon: Icons.playlist_remove_rounded,
              title: 'Remove',
              textColor: Colors.redAccent,
            )
          : isLiked
              ? _buildSwipeBackground(
                  alignment: Alignment.centerRight,
                  iconBackgroundColor: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                  iconColor: isDark ? const Color(0xFFFF6B81) : const Color(0xFFD32F2F),
                  icon: Icons.favorite_border_rounded,
                  title: 'Unlike',
                  textColor: isDark ? const Color(0xFFFF6B81) : const Color(0xFFD32F2F),
                )
              : _buildSwipeBackground(
                  alignment: Alignment.centerRight,
                  iconBackgroundColor: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                  iconColor: isDark ? const Color(0xFF111827) : Colors.white,
                  icon: Icons.favorite_rounded,
                  title: 'Like',
                  textColor: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                ),
      child: tileContent,
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color iconBackgroundColor,
    required Color iconColor,
    required IconData icon,
    required String title,
    required Color textColor,
  }) {
    final isEnd = alignment == Alignment.centerRight;
    return Container(
      height: 76,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEnd) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          if (!isEnd) ...[
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackTilePopupMenu extends ConsumerWidget {
  final Track track;
  final bool isDark;
  final bool isLiked;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onRemoveFromPlaylist;

  const _TrackTilePopupMenu({
    required this.track,
    required this.isDark,
    required this.isLiked,
    this.onLikeToggle,
    this.onRemoveFromPlaylist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // No ListenableBuilder — download state is read lazily only when the
    // popup opens (itemBuilder) or an action fires (onSelected).
    // This eliminates 15+ unnecessary PopupMenuButton rebuilds per
    // download-progress tick during scroll.
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
          // Read download manager lazily — only on action, not during scroll
          final downloadManager = ref.read(downloadManagerProvider);
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
          } else if (value == 'cancel_download') {
            downloadManager.cancelDownload(track.id);
          } else if (value == 'delete_device') {
            showConfirmDeleteTrackDialog(context, ref, track);
          } else if (value == 'like') {
            final wasLiked = isLiked;
            if (onLikeToggle != null) {
              onLikeToggle!();
            } else {
              ref.read(audioRepositoryProvider).toggleLike(track);
            }
            ref.invalidate(likedTracksStreamProvider);
            AppSnackBar.show(
              context,
              message: wasLiked
                  ? 'Removed "${track.title}" from Liked'
                  : 'Added "${track.title}" to Liked',
              type: AppSnackBarType.info,
              icon: wasLiked ? Icons.favorite_border_rounded : Icons.favorite_rounded,
            );
          }
        },
        itemBuilder: (ctx) {
          // Read download state lazily — only when popup opens, not during scroll
          final downloadManager = ref.read(downloadManagerProvider);
          final isDownloaded = downloadManager.isDownloaded(track.id) || track.isDownloaded;
          final isDownloading = downloadManager.isDownloading(track.id);

          return [
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
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 20,
                    color: isLiked ? (isDark ? AppColors.neonLime : AppColors.limeAccentDark) : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isLiked ? 'Remove from Liked' : 'Save to Liked',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isLiked ? (isDark ? AppColors.neonLime : AppColors.limeAccentDark) : null,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
  }
}
