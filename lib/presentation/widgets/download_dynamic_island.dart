import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';

class DownloadDynamicIsland extends ConsumerWidget {
  const DownloadDynamicIsland({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadManager = ref.watch(downloadManagerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: downloadManager,
      builder: (context, _) {
        final activeTrack = downloadManager.activeDownloadingTrack;
        final completedTrack = downloadManager.lastCompletedTrack;
        final progress = downloadManager.activeProgress;

        final track = activeTrack ?? completedTrack;
        final bool isVisible = track != null;
        final bool isCompleted = completedTrack != null;

        return IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            offset: isVisible ? Offset.zero : const Offset(0, -1.4),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: isVisible ? 1.0 : 0.0,
              child: Align(
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () {
                    if (isCompleted) {
                      HapticFeedback.lightImpact();
                      downloadManager.dismissCompletedTrack();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 11),
                    padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                    constraints: const BoxConstraints(maxWidth: 390, minHeight: 56),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF262A36)
                            : const Color(0xFFEFEFEF),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                          blurRadius: 24,
                          spreadRadius: 0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: track != null
                        ? Row(
                            children: [
                              // 1. Artwork Thumbnail
                              TrackArtwork(
                                artworkUrl: track.artworkUrl,
                                seedKey: track.id.isNotEmpty ? track.id : track.title,
                                size: 42,
                                borderRadius: BorderRadius.circular(11),
                              ),

                              const SizedBox(width: 12),

                              // 2. Track Title, Status Subtitle & Horizontal Progress Line
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                        color: isDark ? Colors.white : const Color(0xFF121316),
                                      ),
                                    ),
                                    const SizedBox(height: 2),

                                    // Status & percentage: "Downloading • 62%"
                                    Text(
                                      isCompleted
                                          ? 'Downloaded • Ready offline'
                                          : 'Downloading • ${(progress * 100).toInt()}%',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: isCompleted
                                            ? (isDark ? AppColors.neonLime : AppColors.limeAccentDark)
                                            : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                                      ),
                                    ),
                                    const SizedBox(height: 5),

                                    // Horizontal Progress Bar Line
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final barWidth = constraints.maxWidth;
                                        return Stack(
                                          children: [
                                            // Inactive background track
                                            Container(
                                              height: 3.5,
                                              width: barWidth,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white.withValues(alpha: 0.12)
                                                    : const Color(0xFFE5E7EB),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            // Active vibrant lime progress bar
                                            Container(
                                              height: 3.5,
                                              width: (barWidth * (isCompleted ? 1.0 : progress)).clamp(0.0, barWidth),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors.neonLime
                                                    : const Color(0xFF84CC16),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // 3. Right Action Button (34x34 Soft Circular Button with Pause/Check Icon)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  HapticFeedback.selectionClick();
                                  if (isCompleted) {
                                    downloadManager.dismissCompletedTrack();
                                  } else if (activeTrack != null) {
                                    final confirmed = await showAppConfirmationDialog(
                                      context: context,
                                      title: 'Stop Download?',
                                      description:
                                          'Are you sure you want to cancel the download of this song? The downloaded data will be removed.',
                                      track: activeTrack,
                                      confirmText: 'Stop Download',
                                      cancelText: 'Cancel',
                                    );
                                    if (confirmed == true) {
                                      downloadManager.cancelDownload(activeTrack.id);
                                    }
                                  }
                                },
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? const Color(0xFF222533) : const Color(0xFFF1F3F6),
                                  ),
                                  child: Icon(
                                    isCompleted ? Icons.check_rounded : Icons.pause_rounded,
                                    size: 18,
                                    color: isCompleted
                                        ? (isDark ? AppColors.neonLime : AppColors.limeAccentDark)
                                        : (isDark ? Colors.white : const Color(0xFF1E2028)),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
