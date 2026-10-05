import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/services/audio_player_handler.dart';

/// Minimal, compact, animation-rich floating MiniPlayer capsule with
/// an enlarged protruding vinyl disc and refined high-contrast buttons.
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
  late final AnimationController _playPressScaleController;
  late final AnimationController _skipPressScaleController;

  MiniPlayerPalette? _cachedPalette;

  @override
  void initState() {
    super.initState();
    // Smooth 14-second rotation per revolution for physical turntable vinyl
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );

    // 1.0-second repeating loop for sinusoidal dancing equalizer
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Micro-scale spring bounce controller on Play button press
    _playPressScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );

    // Micro-scale spring bounce controller on Skip button press
    _skipPressScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isPlaying = ref.read(isPlaybackPlayingProvider);
        _syncAnimations(isPlaying);
        final current = ref.read(currentPlayingTrackProvider) ?? widget.fallbackTrack;
        if (current?.artworkUrl != null) {
          TrackArtwork.precacheArtwork(context, current!.artworkUrl);
        }
      }
    });
  }

  @override
  void dispose() {
    _vinylController.dispose();
    _equalizerController.dispose();
    _playPressScaleController.dispose();
    _skipPressScaleController.dispose();
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

    // Listen to playback state changes to sync vinyl & equalizer animations
    ref.listen<bool>(isPlaybackPlayingProvider, (_, playing) {
      _syncAnimations(playing);
    });

    // Pre-cache high-res player artwork (480px) for instant NowPlaying expansion
    ref.listen<Track?>(currentPlayingTrackProvider, (prev, next) {
      if (next?.artworkUrl != null && next!.artworkUrl!.trim().isNotEmpty) {
        TrackArtwork.precacheArtwork(context, next.artworkUrl);
      }
    });

    // Dynamic Artwork Palette extraction via Riverpod & PaletteService
    final paletteAsync = ref.watch(
      trackPaletteProvider((track: track, isDark: isDark)),
    );

    final palette = paletteAsync.value ??
        PaletteService.instance.getCachedPalette(track, isDark: isDark) ??
        _cachedPalette ??
        MiniPlayerPalette.fallback(
          isDark: isDark,
          seed: track.id.isNotEmpty ? track.id : track.title,
        );

    _cachedPalette = palette;

    const double containerHeight = 48.0;
    const double vinylSize = 58.0;
    const double totalHeight = 60.0;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Dismissible(
        key: ValueKey('mini_player_${track.id}_${widget.uniqueTag}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Swipe Left to Skip
            HapticFeedback.lightImpact();
            await audioHandler.skipToNext();
          } else if (direction == DismissDirection.startToEnd) {
            // Swipe Right to Like
            HapticFeedback.mediumImpact();
            final repo = ref.read(audioRepositoryProvider);
            await repo.toggleLike(track);
          }
          return false; // Always bounce back
        },
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onExpand();
          },
          onVerticalDragEnd: (details) {
            // Upward flick gesture expands smoothly to NowPlayingScreen
            if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
              HapticFeedback.selectionClick();
              widget.onExpand();
            }
          },
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              height: totalHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // 1. Main Capsule Body Container (Height 48px, rounded pill)
                  Positioned(
                    left: 14.0,
                    right: 14.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      height: containerHeight,
                      padding: const EdgeInsets.only(left: 56.0, right: 14.0),
                      decoration: BoxDecoration(
                        color: palette.backgroundColor,
                        borderRadius: BorderRadius.circular(24.0),
                        boxShadow: [
                          BoxShadow(
                            color: palette.shadowColor,
                            blurRadius: 16,
                            spreadRadius: 0,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Track Title & Artist Subtitle with Live Marquee & Equalizer
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Marquee Title Text
                                _TrainMarqueeText(
                                  text: track.title,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    height: 1.15,
                                    letterSpacing: -0.2,
                                    color: palette.titleColor,
                                    decoration: TextDecoration.none,
                                  ),
                                  isPlaying: isPlaying,
                                ),
                                const SizedBox(height: 1.5),

                                // 3-Bar Sinusoidal Dancing Equalizer + Artist Name
                                Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 5),
                                      child: _MiniEqualizerBars(
                                        animation: _equalizerController,
                                        isPlaying: isPlaying,
                                        color: palette.titleColor.withValues(alpha: 0.90),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        track.artistName.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 10.5,
                                          height: 1.15,
                                          fontWeight: FontWeight.w600,
                                          color: palette.artistColor,
                                          letterSpacing: 0.3,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          // 2. Circular Outlined Play / Pause Button
                          _buildPlayPauseButton(isPlaying, audioHandler, palette),

                          const SizedBox(width: 8),

                          // 3. Compact Skip Next Action Button
                          _buildSkipButton(audioHandler, palette),
                        ],
                      ),
                    ),
                  ),

                  // 2. Enlarged Protruding Spinning Vinyl Record (Overlapping the capsule)
                  Positioned(
                    left: 8.0,
                    top: (totalHeight - vinylSize) / 2,
                    child: _buildVinylArtwork(track, isDark, palette, size: vinylSize),
                  ),

                  // 3. Ultra-Thin Micro Progress Indicator at bottom of capsule
                  Positioned(
                    left: 70.0,
                    right: 36.0,
                    bottom: (totalHeight - containerHeight) / 2 + 0.5,
                    child: _MiniPlayerMicroProgress(
                      activeColor: palette.progressBarColor,
                      inactiveColor: palette.progressInactiveColor,
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

  /// Circular outlined Play/Pause hero button matching the reference UI
  Widget _buildPlayPauseButton(
    bool isPlaying,
    MusifyAudioHandler audioHandler,
    MiniPlayerPalette palette,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _playPressScaleController.reverse(),
      onTapUp: (_) => _playPressScaleController.forward(),
      onTapCancel: () => _playPressScaleController.forward(),
      onTap: () {
        HapticFeedback.selectionClick();
        if (isPlaying) {
          audioHandler.pause();
        } else {
          audioHandler.play();
        }
      },
      child: AnimatedBuilder(
        animation: _playPressScaleController,
        builder: (context, child) => Transform.scale(
          scale: _playPressScaleController.value,
          child: child,
        ),
        child: Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.buttonFill,
            border: Border.all(
              color: palette.buttonOutline,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(isPlaying),
                size: 21,
                color: palette.iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compact Skip Next icon button with interactive spring tap feedback
  Widget _buildSkipButton(
    MusifyAudioHandler audioHandler,
    MiniPlayerPalette palette,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _skipPressScaleController.reverse(),
      onTapUp: (_) => _skipPressScaleController.forward(),
      onTapCancel: () => _skipPressScaleController.forward(),
      onTap: () {
        HapticFeedback.lightImpact();
        audioHandler.skipToNext();
      },
      child: AnimatedBuilder(
        animation: _skipPressScaleController,
        builder: (context, child) => Transform.scale(
          scale: _skipPressScaleController.value,
          child: child,
        ),
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          child: Center(
            child: Icon(
              Icons.skip_next_rounded,
              size: 23,
              color: palette.iconColor.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
    );
  }

  /// Spinning turntable vinyl record with authentic grooves and center artwork
  Widget _buildVinylArtwork(
    Track track,
    bool isDark,
    MiniPlayerPalette palette, {
    required double size,
  }) {
    // Increased proportion from 0.62 to 0.78 to significantly reduce the dark outer vinyl ring thickness
    final artworkSize = size * 0.78;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF14161C), // Deep physical vinyl record base
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.30),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(1, 3),
          ),
        ],
      ),
      child: RepaintBoundary(
        child: RotationTransition(
          turns: _vinylController,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Concentric Micro Vinyl Grooves on outer vinyl ring
              Positioned.fill(
                child: CustomPaint(
                  painter: _MiniVinylGroovesPainter(
                    artworkRadius: artworkSize / 2,
                  ),
                ),
              ),

              // 2. Base Album Artwork in center circle
              ClipOval(
                child: TrackArtwork(
                  artworkUrl: track.artworkUrl,
                  seedKey: track.id.isNotEmpty ? track.id : track.title,
                  size: artworkSize,
                  isCircle: true,
                  ambientGlow: false,
                  fallbackIcon: Icons.music_note_rounded,
                ),
              ),

              // 3. Inner Vinyl Groove Ring dividing record and label (refined thin hairline)
              Container(
                width: artworkSize,
                height: artworkSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.25),
                    width: 0.35,
                  ),
                ),
              ),

              // 4. Center Spindle Hole Punch (refined proportion with thinner dark ring)
              Container(
                width: size * 0.12,
                height: size * 0.12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 0.45,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: size * 0.035,
                    height: size * 0.035,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),

              // 5. Diagonal Subtle Vinyl Holographic Specular Sheen
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipOval(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: const Alignment(-1.0, -1.0),
                          end: const Alignment(1.0, 1.0),
                          stops: const [0.0, 0.45, 0.55, 1.0],
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
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

/// Custom painter for fine turntable vinyl micro-groove rings
class _MiniVinylGroovesPainter extends CustomPainter {
  final double? artworkRadius;

  _MiniVinylGroovesPainter({this.artworkRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 1.2;
    final effectiveArtRadius = artworkRadius ?? (size.width * 0.39);
    final minRadius = effectiveArtRadius + 0.6;

    if (maxRadius <= minRadius) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.25;

    const steps = 2;
    final step = (maxRadius - minRadius) / (steps + 1);
    for (int i = 1; i <= steps; i++) {
      canvas.drawCircle(center, minRadius + i * step, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniVinylGroovesPainter oldDelegate) =>
      oldDelegate.artworkRadius != artworkRadius;
}

/// Ultra-thin 1.5px micro-progress bar rendered at the bottom of the capsule
class _MiniPlayerMicroProgress extends ConsumerWidget {
  final Color activeColor;
  final Color inactiveColor;

  const _MiniPlayerMicroProgress({
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateStreamProvider).value;
    final position = playerState?.position ?? Duration.zero;
    final duration = playerState?.duration ?? Duration.zero;

    final double progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: Container(
        height: 1.5,
        color: inactiveColor,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(
            color: activeColor,
          ),
        ),
      ),
    );
  }
}

/// 3 dancing equalizer bars indicating active music playback
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
          _buildBar(3.5),
          const SizedBox(width: 1.5),
          _buildBar(3.5),
          const SizedBox(width: 1.5),
          _buildBar(3.5),
        ],
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final h1 = 3.0 + 6.0 * ((math.sin(t * 2 * math.pi) + 1) / 2);
        final h2 = 3.5 + 7.5 * ((math.sin((t + 0.35) * 2 * math.pi) + 1) / 2);
        final h3 = 2.5 + 5.5 * ((math.sin((t + 0.70) * 2 * math.pi) + 1) / 2);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(h1),
            const SizedBox(width: 1.5),
            _buildBar(h2),
            const SizedBox(width: 1.5),
            _buildBar(h3),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 1.8,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.0),
      ),
    );
  }
}

/// Seamless continuous train marquee text animation for overflowing song titles
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
