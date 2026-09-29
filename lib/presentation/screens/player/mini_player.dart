import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';

class MiniPlayer extends ConsumerWidget {
  final VoidCallback onExpand;

  const MiniPlayer({
    super.key,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Highly-optimized: Only watch current track and play state!
    // Never watch playerStateStreamProvider here, so position ticks do NOT rebuild this tree.
    final track = ref.watch(currentPlayingTrackProvider);
    final isPlaying = ref.watch(isPlaybackPlayingProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (track == null) return const SizedBox.shrink();

    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey('mini_player_${track.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          HapticFeedback.lightImpact();
          await audioHandler.skipToNext();
        } else if (direction == DismissDirection.startToEnd) {
          HapticFeedback.mediumImpact();
          final repo = ref.read(audioRepositoryProvider);
          await repo.toggleLike(track);
        }
        return false;
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onExpand();
        },
        child: Container(
          height: 68,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161822) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // Isolated Progress Bar - ONLY this 2.5px widget rebuilds on position updates!
                const _MiniPlayerProgressBar(),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        // Rounded Square Artwork (48px with 14px radius matching reference)
                        TrackArtwork(
                          artworkUrl: track.artworkUrl,
                          size: 48,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        const SizedBox(width: 14),

                        // Track Info
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  letterSpacing: -0.2,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
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
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: Text(
                                      track.artistName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.6)
                                            : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Play / Pause Button in Neon Lime Circle (42x42)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (isPlaying) {
                              audioHandler.pause();
                            } else {
                              audioHandler.play();
                            }
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 24,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Borderless Skip Next Button (38x38)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            audioHandler.skipToNext();
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                            ),
                            child: Icon(
                              Icons.skip_next_rounded,
                              size: 20,
                              color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Isolated widget that selectively rebuilds the 2.5px progress indicator
/// on playback position updates without triggering rebuilds of the entire MiniPlayer.
class _MiniPlayerProgressBar extends ConsumerWidget {
  const _MiniPlayerProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerStateStreamProvider.select((s) => s.value?.progress ?? 0.0));
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return LinearProgressIndicator(
      value: progress,
      minHeight: 2.5,
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
    );
  }
}
