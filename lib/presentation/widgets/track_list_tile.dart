import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
  final bool enableSwipePlayNext;

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
    this.enableSwipePlayNext = true,
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

    final isYt = isYouTubeSection;

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
            downloadManager.downloadTrack(track);
            return;
          }
        }
        onTap();
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
      highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
      child: Container(
        height: isYt ? 88 : 76,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: isYt ? 8 : 8),
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

            // Artwork: 16:9 Cinema Card for YouTube, 1:1 Square for Standard tracks
            if (isYt) ...[
              SizedBox(
                width: 96,
                height: 54,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: TrackArtwork(
                        artworkUrl: track.artworkUrl,
                        seedKey: track.id.isNotEmpty ? track.id : track.title,
                        size: 96,
                        height: 54,
                        borderRadius: BorderRadius.circular(12),
                        fallbackIcon: Icons.smart_display_rounded,
                      ),
                    ),
                    // Top-Left: Glowing Red ▶ YT mini badge
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCC0000).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF0000).withValues(alpha: 0.40),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 8, color: Colors.white),
                            const SizedBox(width: 1.5),
                            Text(
                              'YT',
                              style: AppTypography.style(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom-Right: Semi-transparent duration pill
                    if (durationStr.isNotEmpty)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.80),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            durationStr,
                            style: AppTypography.style(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              TrackArtwork(
                artworkUrl: track.artworkUrl,
                seedKey: track.id.isNotEmpty ? track.id : track.title,
                size: 56,
                borderRadius: BorderRadius.circular(14),
                fallbackIcon: track.isAudioClip
                    ? (track.title.toLowerCase().contains('ringtone') ||
                            (track.filePath?.toLowerCase().contains('ringtone') ?? false)
                        ? Icons.ring_volume_rounded
                        : Icons.graphic_eq_rounded)
                    : Icons.music_note_rounded,
              ),
            ],
            const SizedBox(width: 13),

            // Metadata Area
            Expanded(
              child: isYt
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            color: isCurrent ? primaryColor : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            height: 1.25,
                            letterSpacing: -0.15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                track.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 12,
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            color: isCurrent ? primaryColor : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (track.isAudioClip) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.neonLime.withValues(alpha: 0.15)
                                      : const Color(0xFF70A314).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (track.title.toLowerCase().contains('ringtone') ||
                                          (track.filePath?.toLowerCase().contains('ringtone') ?? false))
                                      ? 'RINGTONE'
                                      : 'AUDIO',
                                  style: AppTypography.style(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.neonLime : const Color(0xFF70A314),
                                  ),
                                ),
                              ),
                            ] else if (track.source == AudioSourceType.saavn) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '320K',
                                  style: AppTypography.style(
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
                                style: AppTypography.caption.copyWith(
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

                        // When in YouTube section (or YouTube track):
                        if (isYt) {
                          if (isDownloading) {
                            return GestureDetector(
                              onTap: () {
                                downloadManager.cancelDownload(track.id);
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

                          if (isDownloaded) {
                            return Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                                    : const Color(0xFFDCFCE7),
                                border: Border.all(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Color(0xFF22C55E),
                              ),
                            );
                          }

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
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
                                      ? const Color(0xFFFF0000).withValues(alpha: 0.16)
                                      : const Color(0xFFFFEEEE),
                                  border: Border.all(
                                    color: const Color(0xFFFF0000).withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                                      blurRadius: 6,
                                    ),
                                  ],
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

                        // Standard Track:
                        if (!isDownloaded) {
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
                          } else {
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
                              },
                            );
                          }
                        }

                        return const SizedBox.shrink();
                      },
                    );
                  },
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

    if (isSelectionMode || !enableSwipePlayNext) {
      return tileContent;
    }

    return _SwipeableTrackTile(
      isDark: isDark,
      trackId: track.id,
      onPlayNext: () {
        HapticFeedback.mediumImpact();
        ref.read(audioHandlerProvider).insertNextInQueue(track);
        AppSnackBar.show(
          context,
          message: 'Playing "${track.title}" next',
          type: AppSnackBarType.info,
          icon: Icons.playlist_play_rounded,
        );
      },
      child: tileContent,
    );
  }
}

/// Smooth swipe-to-play-next wrapper using Flutter Dismissible configured for start-to-end swipe only.
/// Returning false from confirmDismiss ensures the tile automatically springs back into place after queueing.
class _SwipeableTrackTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onPlayNext;
  final bool isDark;
  final String trackId;

  const _SwipeableTrackTile({
    required this.child,
    required this.onPlayNext,
    required this.isDark,
    required this.trackId,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('swipe_play_next_$trackId'),
      direction: DismissDirection.startToEnd,
      movementDuration: const Duration(milliseconds: 220),
      resizeDuration: null,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onPlayNext();
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2616) : const Color(0xFFE8F8DC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.playlist_play_rounded,
                size: 22,
                color: isDark ? const Color(0xFF111827) : Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Play Next',
              style: AppTypography.style(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
      child: child,
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
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
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
          } else if (value == 'copy_yt_link') {
            final ytId = track.sourceId.isNotEmpty ? track.sourceId : track.id.replaceFirst('youtube:', '');
            Clipboard.setData(ClipboardData(text: 'https://youtube.com/watch?v=$ytId'));
            AppSnackBar.show(
              context,
              message: 'YouTube link copied to clipboard',
              type: AppSnackBarType.success,
              icon: Icons.link_rounded,
            );
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
          final isYtTrack = track.source == AudioSourceType.youtube;
          final menuItemStyle = AppTypography.bodyMedium.copyWith(fontSize: 14, fontWeight: FontWeight.w500);

          return [
            PopupMenuItem(
              value: 'next',
              child: Row(
                children: [
                  Icon(Icons.playlist_play_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
                  const SizedBox(width: 12),
                  Text('Play Next', style: menuItemStyle),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'queue',
              child: Row(
                children: [
                  Icon(Icons.queue_music_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
                  const SizedBox(width: 12),
                  Text('Add to Queue', style: menuItemStyle),
                ],
              ),
            ),
            if (isYtTrack) ...[
              PopupMenuItem(
                value: 'copy_yt_link',
                child: Row(
                  children: [
                    Icon(Icons.link_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
                    const SizedBox(width: 12),
                    Text('Copy YouTube Link', style: menuItemStyle),
                  ],
                ),
              ),
            ],
            if (onRemoveFromPlaylist != null) ...[
              PopupMenuItem(
                value: 'remove_playlist',
                child: Row(
                  children: [
                    const Icon(Icons.remove_circle_outline_rounded, size: 20, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Text(
                      'Remove from Playlist',
                      style: menuItemStyle.copyWith(color: Colors.redAccent),
                    ),
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
                  Text('Add to Playlist', style: menuItemStyle),
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
                    Text('Download Song', style: menuItemStyle),
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
                    Text('Cancel Download', style: menuItemStyle),
                  ],
                ),
              ),
            ] else if (isDownloaded || track.source == AudioSourceType.local) ...[
              PopupMenuItem(
                value: 'delete_device',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Text(
                      'Delete from Device',
                      style: menuItemStyle.copyWith(color: Colors.redAccent),
                    ),
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
                    style: menuItemStyle.copyWith(
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
