import 'package:flutter/material.dart';
import 'package:musify/domain/models/track.dart';
import 'track_artwork.dart';

class TrackListTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
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

            if (onMoreOptions != null) ...[
              const SizedBox(width: 2),
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                onPressed: onMoreOptions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
