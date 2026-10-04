import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
class MiniPlayer extends ConsumerStatefulWidget {
  final VoidCallback onExpand;
  final Track? fallbackTrack;
  final String uniqueTag;

  const MiniPlayer({
    super.key,
    required this.onExpand,
    this.fallbackTrack,
    this.uniqueTag = 'default',
  });

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with TickerProviderStateMixin {
  late final AnimationController _vinylController;
  late final AnimationController _equalizerController;

  @override
  void initState() {
    super.initState();
    // 14 seconds per clockwise revolution for smooth vinyl record rotation
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );

    // 1.0 second loop for rhythmic equalizer dancing
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isPlaying = ref.read(isPlaybackPlayingProvider);
        _syncAnimations(isPlaying);
      }
    });
  }

  @override
  void dispose() {
    _vinylController.dispose();
    _equalizerController.dispose();
    super.dispose();
  }

  void _syncAnimations(bool isPlaying) {
    if (isPlaying) {
      if (!_vinylController.isAnimating) {
        _vinylController.repeat();
      }
      if (!_equalizerController.isAnimating) {
        _equalizerController.repeat();
      }
    } else {
      if (_vinylController.isAnimating) {
        _vinylController.stop();
      }
      if (_equalizerController.isAnimating) {
        _equalizerController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(currentPlayingTrackProvider) ?? widget.fallbackTrack;
    final isPlaying = ref.watch(isPlaybackPlayingProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (track == null) return const SizedBox.shrink();

    const titleColor = Colors.black;
    final artistColor = Colors.black.withValues(alpha: 0.85);
    const accentColor = Colors.black;

    // Reactively sync animation state with playback state
    ref.listen<bool>(isPlaybackPlayingProvider, (_, playing) {
      _syncAnimations(playing);
    });

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Dismissible(
        key: ValueKey('mini_player_${track.id}_${widget.uniqueTag}'),
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
            widget.onExpand();
          },
          onVerticalDragEnd: (details) {
            // Swiping UP on mini player expands smoothly into full player (Spotify/Apple Music style)
            if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
              HapticFeedback.selectionClick();
              widget.onExpand();
            }
          },
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              constraints: const BoxConstraints(minHeight: 78),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.neonLime,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonLime.withValues(alpha: isDark ? 0.35 : 0.45),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Spinning Circular Vinyl Artwork matching NowPlaying turntable
                    _buildVinylArtwork(track, isDark),

                    const SizedBox(width: 12),

                    // 2. Track Title, Equalizer + Artist, Progress Bar & Timestamps
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          _TrainMarqueeText(
                            text: track.title,
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              height: 1.15,
                              letterSpacing: -0.3,
                              color: titleColor,
                              decoration: TextDecoration.none,
                            ),
                            isPlaying: isPlaying,
                          ),
                          const SizedBox(height: 2),

                          // Live 3-Bar Equalizer + Artist Name
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: _MiniEqualizerBars(
                                  animation: _equalizerController,
                                  isPlaying: isPlaying,
                                  color: accentColor,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  track.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 11.5,
                                    height: 1.15,
                                    fontWeight: FontWeight.w600,
                                    color: artistColor,
                                    letterSpacing: -0.1,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.5),

                          // Progress bar & Elapsed/Duration timestamps
                          _MiniPlayerProgressSection(
                            accentColor: accentColor,
                            textColor: artistColor,
                            inactiveColor: Colors.black.withValues(alpha: 0.18),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // 3. Play / Pause Button (42x42 vibrant neon circle with black icon)
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
                          color: Colors.black,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // 4. Skip Next Button (38x38 tinted translucent circle with icon)
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
                          color: Colors.black.withValues(alpha: 0.10),
                        ),
                        child: const Icon(
                          Icons.skip_next_rounded,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildVinylArtwork(Track track, bool isDark) {
    final themePrimary = isDark ? AppColors.neonLime : AppColors.limeAccentDark;
    const double size = 48.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: RepaintBoundary(
        child: RotationTransition(
          turns: _vinylController,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Base Album Artwork / Theme-harmonized seeded gradient with olive record label icon
              TrackArtwork(
                artworkUrl: track.artworkUrl,
                seedKey: track.id.isNotEmpty ? track.id : track.title,
                size: size,
                isCircle: true,
                ambientGlow: false,
                fallbackIcon: Icons.music_note_rounded,
              ),

              // 2. Outer vinyl groove rim
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                    width: 1.0,
                  ),
                ),
              ),

              // 3. Inner vinyl groove ring (70% proportion)
              Container(
                width: size * 0.70,
                height: size * 0.70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                    width: 0.8,
                  ),
                ),
              ),

              // 4. Center spindle hole punch (16% proportion with inner 4.5% hole)
              Container(
                width: size * 0.16,
                height: size * 0.16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: size * 0.045,
                    height: size * 0.045,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),

              // 5. Orbiting spinning indicator dot marker for non-image songs
              if (track.artworkUrl == null || track.artworkUrl!.trim().isEmpty)
                Align(
                  alignment: const Alignment(0.55, -0.55),
                  child: Container(
                    width: 4.5,
                    height: 4.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: themePrimary,
                      border: Border.all(
                        color: isDark ? Colors.black : Colors.white,
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: themePrimary.withValues(alpha: 0.5),
                          blurRadius: 2.5,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders 3 dancing equalizer bars indicating active music playback.
class _MiniEqualizerBars extends StatelessWidget {
  final Animation<double> animation;
  final bool isPlaying;
  final Color color;

  const _MiniEqualizerBars({
    required this.animation,
    required this.isPlaying,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPlaying) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBar(4.0),
          const SizedBox(width: 2.0),
          _buildBar(4.0),
          const SizedBox(width: 2.0),
          _buildBar(4.0),
        ],
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final h1 = 3.5 + 7.5 * ((math.sin(t * 2 * math.pi) + 1) / 2);
        final h2 = 4.0 + 8.5 * ((math.sin((t + 0.35) * 2 * math.pi) + 1) / 2);
        final h3 = 3.0 + 6.5 * ((math.sin((t + 0.70) * 2 * math.pi) + 1) / 2);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(h1),
            const SizedBox(width: 2.0),
            _buildBar(h2),
            const SizedBox(width: 2.0),
            _buildBar(h3),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.2,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// Isolated widget that selectively rebuilds the progress line and timestamps
/// on playback position updates without triggering rebuilds of the entire MiniPlayer.
class _MiniPlayerProgressSection extends ConsumerWidget {
  final Color accentColor;
  final Color textColor;
  final Color inactiveColor;

  const _MiniPlayerProgressSection({
    required this.accentColor,
    required this.textColor,
    required this.inactiveColor,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateStreamProvider).value;
    final position = playerState?.position ?? Duration.zero;
    final duration = playerState?.duration ?? Duration.zero;

    final double progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Horizontal progress line
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            return Stack(
              children: [
                // Inactive Track
                Container(
                  height: 2.5,
                  width: barWidth,
                  decoration: BoxDecoration(
                    color: inactiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Active Track
                Container(
                  height: 2.5,
                  width: (barWidth * progress).clamp(0.0, barWidth),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 2),
        // Timestamps
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(position),
              style: AppTypography.caption.copyWith(
                fontSize: 9.5,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: -0.1,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              _formatDuration(duration),
              style: AppTypography.caption.copyWith(
                fontSize: 9.5,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: -0.1,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Seamless continuous train marquee text animation that moves right-to-left.
class _TrainMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool isPlaying;

  const _TrainMarqueeText({
    required this.text,
    required this.style,
    required this.isPlaying,
  });

  @override
  State<_TrainMarqueeText> createState() => _TrainMarqueeTextState();
}

class _TrainMarqueeTextState extends State<_TrainMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0.0;
  double _textHeight = 18.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _calculateDimensions();
  }

  @override
  void didUpdateWidget(covariant _TrainMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _calculateDimensions();
    }
    if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  void _calculateDimensions([TextScaler textScaler = TextScaler.noScaling]) {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();

    _textWidth = textPainter.width;
    _textHeight = textPainter.height > 0 ? textPainter.height : 16.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    _calculateDimensions(textScaler);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        if (_textWidth <= 0 || availableWidth <= 0) {
          return Text(widget.text, style: widget.style, maxLines: 1);
        }

        if (_textWidth <= availableWidth) {
          if (_controller.isAnimating) {
            _controller.stop();
          }
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final gap = math.max(32.0, availableWidth - 0.25 * _textWidth);
        final cycleDistance = _textWidth + gap;
        final durationMs = ((cycleDistance / 28.0) * 1000).round().clamp(2000, 30000);
        final newDuration = Duration(milliseconds: durationMs);

        if (_controller.duration != newDuration) {
          _controller.duration = newDuration;
        }

        if (widget.isPlaying && !_controller.isAnimating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.isPlaying && !_controller.isAnimating) {
              _controller.repeat();
            }
          });
        } else if (!widget.isPlaying && _controller.isAnimating) {
          _controller.stop();
        }

        return SizedBox(
          height: _textHeight,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset = _controller.value * cycleDistance;

                return OverflowBox(
                  minWidth: 0.0,
                  maxWidth: double.infinity,
                  minHeight: _textHeight,
                  maxHeight: _textHeight,
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(-offset, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                        SizedBox(width: gap),
                        Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                        SizedBox(width: gap),
                        Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
