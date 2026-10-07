import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/lyrics.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/seek_bar.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/track_menu_bottom_sheet.dart';
import 'package:musify/presentation/screens/settings/studio_equalizer_screen.dart';

/// Global helper to push NowPlayingScreen seamlessly from any screen
Future<void> openNowPlayingScreen(BuildContext context) {
  HapticFeedback.selectionClick();
  FocusManager.instance.primaryFocus?.unfocus();
  SystemChannels.textInput.invokeMethod('TextInput.hide');
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder(
      // Fully opaque so underlying screens (home, lists, mini player) stop painting once open
      opaque: true,
      fullscreenDialog: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return NowPlayingScreen(
          onMinimize: () => Navigator.of(context).pop(),
          expandAnimation: animation,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Cubic(0.2, 0.9, 0.22, 1.0);
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
    ),
  );
}

/// Quantizes 35s vinyl rotation to ~30 fps (1050 steps) so unchanged frames don't dirty the render tree
class _SteppedCurve extends Curve {
  const _SteppedCurve();
  @override
  double transformInternal(double t) => (t * 1050).floorToDouble() / 1050; // 35s * 30fps
}

class NowPlayingScreen extends ConsumerStatefulWidget {
  final VoidCallback onMinimize;
  final Animation<double>? expandAnimation;

  const NowPlayingScreen({
    super.key,
    required this.onMinimize,
    this.expandAnimation,
  });

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  bool _showQueue = false;
  bool _showFullLyrics = false;
  late final AnimationController _recordSpinController;
  late final Animation<double> _spinTurns;
  Animation<double>? _effectiveAnimation;

  @override
  void initState() {
    super.initState();
    // 360-degree rotation animation: 35 seconds per revolution, throttled to ~30 fps
    _recordSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    );
    _spinTurns = CurvedAnimation(
      parent: _recordSpinController,
      curve: const _SteppedCurve(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupAnimationListener();
  }

  @override
  void didUpdateWidget(covariant NowPlayingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandAnimation != oldWidget.expandAnimation) {
      _cleanupAnimationListener();
      _setupAnimationListener();
    }
  }

  void _setupAnimationListener() {
    final anim = widget.expandAnimation ?? ModalRoute.of(context)?.animation;
    if (anim == _effectiveAnimation) return;
    _cleanupAnimationListener();
    _effectiveAnimation = anim;

    if (anim != null) {
      if (anim.isCompleted) {
        final isPlaying = ref.read(isPlaybackPlayingProvider);
        _syncSpinAnimation(isPlaying: isPlaying);
      } else {
        anim.addStatusListener(_handleRouteStatus);
      }
    } else {
      final isPlaying = ref.read(isPlaybackPlayingProvider);
      _syncSpinAnimation(isPlaying: isPlaying);
    }
  }

  void _cleanupAnimationListener() {
    _effectiveAnimation?.removeStatusListener(_handleRouteStatus);
    _effectiveAnimation = null;
  }

  void _handleRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } else if (status == AnimationStatus.completed) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (mounted) {
        final isPlaying = ref.read(isPlaybackPlayingProvider);
        _syncSpinAnimation(isPlaying: isPlaying);
      }
    } else if (status == AnimationStatus.reverse || status == AnimationStatus.dismissed) {
      // Pause rotation during collapse to keep reverse slide at 120fps
      if (mounted && _recordSpinController.isAnimating) {
        _recordSpinController.stop();
      }
    }
  }

  @override
  void dispose() {
    _cleanupAnimationListener();
    _recordSpinController.dispose();
    super.dispose();
  }

  void _syncSpinAnimation({required bool isPlaying}) {
    final isVinylVisible = !_showQueue && !_showFullLyrics;
    final isTransitionDone = _effectiveAnimation == null || _effectiveAnimation!.isCompleted;
    if (isPlaying && isVinylVisible && isTransitionDone) {
      if (!_recordSpinController.isAnimating) {
        _recordSpinController.repeat();
      }
    } else {
      if (_recordSpinController.isAnimating) {
        _recordSpinController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(currentPlayingTrackProvider);
    final audioHandler = ref.read(audioHandlerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    // React to playback state changes: spin only when playing AND vinyl is currently visible
    ref.listen<bool>(isPlaybackPlayingProvider, (previous, next) {
      _syncSpinAnimation(isPlaying: next);
    });

    if (track == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0C0D12) : const Color(0xFFF7F8FA),
        body: Center(
          child: Text(
            'No track playing',
            style: AppTypography.style(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_showQueue && !_showFullLyrics,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showQueue) {
          setState(() {
            _showQueue = false;
            _syncSpinAnimation(isPlaying: ref.read(isPlaybackPlayingProvider));
          });
        } else if (_showFullLyrics) {
          setState(() {
            _showFullLyrics = false;
            _syncSpinAnimation(isPlaying: ref.read(isPlaybackPlayingProvider));
          });
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0C0D12) : const Color(0xFFF7F8FA),
        body: Stack(
          children: [
            // Atmospheric blurred artwork background (0% CPU, tiny decode hardware upscaled)
            Positioned.fill(
              child: _AmbientArtworkBackground(
                key: ValueKey(track.artworkUrl),
                artworkUrl: track.artworkUrl,
              ),
            ),

            // Main Screen Content with open canvas layout (borderless & unclosed)
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _showQueue
                    ? KeyedSubtree(
                        key: const ValueKey('queue_view'),
                        child: _buildQueueView(audioHandler, theme),
                      )
                    : _showFullLyrics
                        ? KeyedSubtree(
                            key: const ValueKey('full_lyrics_view'),
                            child: _buildFullLyricsView(track, audioHandler, theme, primaryColor),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('main_player_view'),
                            child: _buildMainPlayerView(track, audioHandler, theme, primaryColor),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPlayerView(
    Track track,
    dynamic audioHandler,
    ThemeData theme,
    Color primaryColor,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        // Swiping down on main player minimizes smoothly
        if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
          HapticFeedback.lightImpact();
          widget.onMinimize();
        }
      },
      child: Column(
        children: [
          // 1. Top Bar matching Studio Equalizer & Audio Settings: (←)  Now Playing  (EQ, ♡, ⋮)
          RepaintBoundary(
            child: _NowPlayingTopBar(
              track: track,
              onBack: () {
                HapticFeedback.lightImpact();
                if (_showQueue) {
                  setState(() {
                    _showQueue = false;
                    _syncSpinAnimation(isPlaying: ref.read(isPlaybackPlayingProvider));
                  });
                } else if (_showFullLyrics) {
                  setState(() {
                    _showFullLyrics = false;
                    _syncSpinAnimation(isPlaying: ref.read(isPlaybackPlayingProvider));
                  });
                } else {
                  widget.onMinimize();
                }
              },
            ),
          ),

          // 2. Open Canvas Content Area (borderless, no closed cards/boxes)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  const lyricsHeight = 84.0;
                  final bottomLift = (availableHeight * 0.04).clamp(16.0, 36.0);

                  // Non-artwork reserved space:
                  final reservedHeight = 220.0 + lyricsHeight + bottomLift;
                  final maxArtFromH = (availableHeight - reservedHeight).clamp(150.0, 320.0);
                  final maxArtFromW = screenWidth * 0.70;
                  final artSize = math.min(maxArtFromH, maxArtFromW);

                  return Column(
                    children: [
                      const Spacer(flex: 1),

                      // 3. Pristine Circular Artwork Hero (borderless, GPU-cached rotation)
                      _CircularArtworkHero(
                        track: track,
                        artSize: artSize,
                        spinTurns: _spinTurns,
                        audioHandler: audioHandler,
                        primaryColor: primaryColor,
                      ),

                      const SizedBox(height: 18),

                      // 4. Track Title & Artist (Studio Clean Typography)
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.style(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.style(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.55)
                              : Colors.black.withValues(alpha: 0.50),
                          letterSpacing: -0.1,
                        ),
                      ),

                      // Compact spacing between artist name and lyrics
                      const SizedBox(height: 50),

                      // 5. Live Sliding Lyrics (open canvas, compact)
                      RepaintBoundary(
                        child: _SlidingLyricsWidget(
                          audioHandler: audioHandler,
                          primaryColor: primaryColor,
                          onExpand: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _showFullLyrics = true;
                              _syncSpinAnimation(isPlaying: ref.read(isPlaybackPlayingProvider));
                            });
                          },
                        ),
                      ),

                      // Compact spacing between lyrics and seek bar
                      const SizedBox(height: 50),

                      // 6. Isolated High-Performance Seek Bar Consumer (open canvas)
                      const RepaintBoundary(
                        child: _IsolatedPlayerSeekBar(),
                      ),

                      const SizedBox(height: 20),

                      // 7. Playback Controls Row matching Studio Equalizer approach
                      RepaintBoundary(
                        child: _PlaybackControlsRow(
                          audioHandler: audioHandler,
                          primaryColor: primaryColor,
                          isQueueOpen: _showQueue,
                          onToggleQueue: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _showQueue = !_showQueue;
                              _syncSpinAnimation(isPlaying: ref.read(isPlaybackPlayingProvider));
                            });
                          },
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Bottom clearance
                      SizedBox(height: bottomLift),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueView(
    dynamic audioHandler,
    ThemeData theme,
  ) {
    return Consumer(
      builder: (context, ref, _) {
        final queue = ref.watch(playerStateStreamProvider.select((s) => s.value?.queue ?? const []));
        final currentIndex = ref.watch(playerStateStreamProvider.select((s) => s.value?.currentIndex ?? -1));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _showQueue = false;
                    _syncSpinAnimation(isPlaying: ref.read(isPlaybackPlayingProvider));
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Playing Queue (${queue.length})',
                      style: AppTypography.style(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            audioHandler.clearQueue();
                          },
                          child: Text(
                            'Clear',
                            style: AppTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neonLime,
                            ),
                          ),
                        ),
                        _CircleHeaderButton(
                          icon: Icons.close_rounded,
                          iconSize: 20,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _showQueue = false;
                              _syncSpinAnimation(isPlaying: ref.read(isPlaybackPlayingProvider));
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: queue.length,
                onReorderItem: (oldIdx, newIdx) {
                  HapticFeedback.selectionClick();
                  audioHandler.reorderQueue(oldIdx, newIdx);
                },
                itemBuilder: (context, index) {
                  final track = queue[index];
                  final isCurrent = index == currentIndex;

                  return ListTile(
                    key: ValueKey('queue_${track.id}_$index'),
                    leading: Icon(
                      isCurrent ? Icons.volume_up_rounded : Icons.music_note_rounded,
                      color: isCurrent ? AppColors.neonLime : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    title: Text(
                      track.title,
                      style: AppTypography.style(
                        fontSize: 15,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? AppColors.neonLime : theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      track.artistName,
                      style: AppTypography.style(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            audioHandler.removeQueueItemAt(index);
                          },
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Center(
                              child: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                        Icon(Icons.drag_handle_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      ],
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      audioHandler.playTrackAtIndex(index);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFullLyricsView(
    Track track,
    dynamic audioHandler,
    ThemeData theme,
    Color primaryColor,
  ) {
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // 1. Top Bar matching Studio Equalizer & Audio Settings: (↓ Collapse)   Lyrics   (♡ Like, ⋮ Options)
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
              HapticFeedback.lightImpact();
              setState(() {
                _showFullLyrics = false;
                _syncSpinAnimation(isPlaying: ref.read(isPlaybackPlayingProvider));
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleHeaderButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  iconSize: 26,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _showFullLyrics = false;
                      _syncSpinAnimation(isPlaying: ref.read(isPlaybackPlayingProvider));
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lyrics',
                        style: AppTypography.style(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.title} • ${track.artistName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.50)
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LikeButton(track: track),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (btnCtx) => _CircleHeaderButton(
                        icon: Icons.more_vert_rounded,
                        onTap: () {
                          showTrackDropdownMenu(
                            context: context,
                            buttonContext: btnCtx,
                            ref: ref,
                            track: track,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 2. Full Synced Lyrics Body (open canvas)
        Expanded(
          child: lyricsAsync.when(
            data: (Lyrics? lyrics) {
              if (lyrics == null || lyrics.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lyrics_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No lyrics available',
                          style: AppTypography.style(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lyrics could not be found for "${track.title}"',
                          textAlign: TextAlign.center,
                          style: AppTypography.style(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.50),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return _FullLyricsScrollView(
                lyrics: lyrics,
                audioHandler: audioHandler,
                primaryColor: primaryColor,
              );
            },
            loading: () => const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonLime),
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Could not load lyrics',
                style: AppTypography.style(
                  fontSize: 13,
                  color: theme.colorScheme.error.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),

        // 3. Compact Persistent Player Controls at bottom (transparent open canvas)
        Container(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _IsolatedPlayerSeekBar(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CircleHeaderButton(
                    icon: Icons.skip_previous_rounded,
                    size: 44,
                    iconSize: 26,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audioHandler.skipToPrevious();
                    },
                  ),
                  const SizedBox(width: 16),
                  _PlayPauseButton(
                    size: 52,
                    iconSize: 30,
                    audioHandler: audioHandler,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(width: 16),
                  _CircleHeaderButton(
                    icon: Icons.skip_next_rounded,
                    size: 44,
                    iconSize: 26,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audioHandler.skipToNext();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular header button matching the design system in StudioEqualizerScreen & AudioSettingsScreen
class _CircleHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;

  const _CircleHeaderButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 22,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final defaultIconColor =
        isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: defaultBg,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor ?? defaultIconColor,
        ),
      ),
    );
  }
}

/// Top bar with back arrow, "Now Playing" title, and circular header buttons
class _NowPlayingTopBar extends ConsumerWidget {
  final Track track;
  final VoidCallback onBack;

  const _NowPlayingTopBar({
    required this.track,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Back Button (Matching Studio Equalizer _CircleHeaderButton)
          _CircleHeaderButton(
            icon: Icons.chevron_left_rounded,
            iconSize: 26,
            onTap: onBack,
          ),

          // Center: Now Playing Title (Clean typography)
          Text(
            'Now Playing',
            style: AppTypography.style(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E2028),
              letterSpacing: -0.2,
            ),
          ),

          // Right Action Buttons: Equalizer, Heart, 3-Dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Equalizer DSP Button (isolated selector)
              Consumer(
                builder: (context, ref, _) {
                  final isEqEnabled = ref.watch(equalizerProvider.select((e) => e.isEnabled));
                  return _CircleHeaderButton(
                    icon: Icons.tune_rounded,
                    iconColor: isEqEnabled ? AppColors.neonLime : null,
                    onTap: () => openStudioEqualizerScreen(context),
                  );
                },
              ),
              const SizedBox(width: 8),

            

              // 3-Dot Options Dropdown Menu Button
              Builder(
                builder: (btnCtx) => _CircleHeaderButton(
                  icon: Icons.more_vert_rounded,
                  onTap: () {
                    showTrackDropdownMenu(
                      context: context,
                      buttonContext: btnCtx,
                      ref: ref,
                      track: track,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Isolated Like / Heart Button with instant spring interaction
class _LikeButton extends ConsumerWidget {
  final Track track;

  const _LikeButton({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(
      currentPlayingTrackProvider.select((t) => t?.id == track.id ? (t?.isLiked ?? false) : track.isLiked),
    );

    return _CircleHeaderButton(
      icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      iconColor: isLiked ? const Color(0xFFFF5252) : null,
      onTap: () {
        ref.read(audioRepositoryProvider).toggleLike(track);
      },
    );
  }
}

/// Pristine Circular Album Artwork Hero matching the Studio design language (borderless & unclosed)
class _CircularArtworkHero extends StatelessWidget {
  final Track track;
  final double artSize;
  final Animation<double> spinTurns;
  final dynamic audioHandler;
  final Color primaryColor;

  const _CircularArtworkHero({
    required this.track,
    required this.artSize,
    required this.spinTurns,
    required this.audioHandler,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final heroCacheDimension = (artSize * pixelRatio).round().clamp(100, 720);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -250) {
            HapticFeedback.lightImpact();
            audioHandler.skipToNext();
          } else if (details.primaryVelocity! > 250) {
            HapticFeedback.lightImpact();
            audioHandler.skipToPrevious();
          }
        }
      },
      child: SizedBox(
        width: artSize,
        height: artSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Static Shadow Layer: Painted once and cached by GPU; never dirtied by rotation ticks!
            RepaintBoundary(
              child: Container(
                width: artSize,
                height: artSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: isDark ? 0.22 : 0.12),
                      blurRadius: 36,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Rotating Vinyl Disk: Quantized ~30fps step turns on open canvas with static outer ClipOval
            RepaintBoundary(
              child: ClipOval(
                child: RotationTransition(
                  turns: spinTurns,
                  child: TrackArtwork(
                    artworkUrl: track.artworkUrl,
                    seedKey: track.id.isNotEmpty ? track.id : track.title,
                    size: artSize,
                    isCircle: true,
                    ambientGlow: false,
                    cacheDimension: heroCacheDimension,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Playback Controls Row matching Studio Equalizer approach (borderless & open canvas)
class _PlaybackControlsRow extends StatelessWidget {
  final dynamic audioHandler;
  final Color primaryColor;
  final bool isQueueOpen;
  final VoidCallback onToggleQueue;

  const _PlaybackControlsRow({
    required this.audioHandler,
    required this.primaryColor,
    required this.isQueueOpen,
    required this.onToggleQueue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Dark high-contrast active color for Light Theme
    final activeToggleColor = isDark ? AppColors.neonLime : const Color(0xFF1E2028);
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.50)
        : const Color(0xFF9EA2B0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. Shuffle Toggle (borderless, on open canvas)
        Consumer(
          builder: (context, ref, _) {
            final isShuffle = ref.watch(playerStateStreamProvider.select((s) => s.value?.isShuffleEnabled ?? false));
            final repeatMode = ref.watch(playerStateStreamProvider.select((s) => s.value?.repeatMode ?? AppRepeatMode.off));

            final IconData modeIcon;
            final String modeLabel;
            final bool isActive;

            if (isShuffle) {
              modeIcon = Icons.shuffle_rounded;
              modeLabel = 'Shuffle';
              isActive = true;
            } else if (repeatMode == AppRepeatMode.one) {
              modeIcon = Icons.repeat_one_rounded;
              modeLabel = 'Repeat One';
              isActive = true;
            } else if (repeatMode == AppRepeatMode.all) {
              modeIcon = Icons.repeat_rounded;
              modeLabel = 'Repeat All';
              isActive = true;
            } else {
              modeIcon = Icons.shuffle_rounded;
              modeLabel = 'Shuffle Off';
              isActive = false;
            }

            return Tooltip(
              message: modeLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  audioHandler.cyclePlaybackMode();
                },
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        modeIcon,
                        key: ValueKey(modeLabel),
                        size: 22,
                        color: isActive ? activeToggleColor : inactiveColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // 2. Skip Previous in circular header button style (borderless)
        _CircleHeaderButton(
          icon: Icons.skip_previous_rounded,
          size: 52,
          iconSize: 26,
          onTap: () {
            HapticFeedback.lightImpact();
            audioHandler.skipToPrevious();
          },
        ),

        // 3. Large Solid Neon Lime Play/Pause Button
        _PlayPauseButton(
          size: 64,
          iconSize: 34,
          audioHandler: audioHandler,
          primaryColor: primaryColor,
        ),

        // 4. Skip Next in circular header button style (borderless)
        _CircleHeaderButton(
          icon: Icons.skip_next_rounded,
          size: 52,
          iconSize: 26,
          onTap: () {
            HapticFeedback.lightImpact();
            audioHandler.skipToNext();
          },
        ),

        // 5. Queue Toggle (borderless, on open canvas)
        Tooltip(
          message: 'Playing Queue',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleQueue,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  isQueueOpen ? Icons.queue_music_rounded : Icons.queue_music_outlined,
                  size: 22,
                  color: isQueueOpen ? activeToggleColor : inactiveColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Large Neon Lime Play/Pause Button matching Studio Equalizer vibrant accents
class _PlayPauseButton extends ConsumerWidget {
  final double size;
  final double iconSize;
  final dynamic audioHandler;
  final Color primaryColor;

  const _PlayPauseButton({
    required this.size,
    required this.iconSize,
    required this.audioHandler,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(isPlaybackPlayingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (isPlaying) {
          audioHandler.pause();
        } else {
          audioHandler.play();
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.neonLime,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? AppColors.neonLime.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            size: iconSize,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

/// Live 3-line sliding lyrics widget embedded directly beneath the song title & artist.
/// Sits directly on open canvas (borderless & unclosed). Zero-cost gradient overlay.
class _SlidingLyricsWidget extends ConsumerStatefulWidget {
  final dynamic audioHandler;
  final Color primaryColor;
  final VoidCallback onExpand;

  const _SlidingLyricsWidget({
    required this.audioHandler,
    required this.primaryColor,
    required this.onExpand,
  });

  @override
  ConsumerState<_SlidingLyricsWidget> createState() => _SlidingLyricsWidgetState();
}

class _SlidingLyricsWidgetState extends ConsumerState<_SlidingLyricsWidget> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  static const double _lineExtent = 28.0;
  static const double _viewHeight = 84.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveIndex(int index, {bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final targetOffset = (index * _lineExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);

    return lyricsAsync.when(
      data: (Lyrics? lyrics) {
        if (lyrics == null || lyrics.isEmpty) {
          return Center(
            child: Text(
              'Lyrics unavailable',
              style: AppTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.30),
              ),
            ),
          );
        }

        // Highly optimized selector with O(log n) binary search
        final int activeIndex = ref.watch(
          playerStateStreamProvider.select((s) {
            final pos = s.value?.position ?? Duration.zero;
            if (lyrics.isSynced) {
              return lyrics.findCurrentLineIndex(pos);
            } else {
              final dur = s.value?.duration ?? Duration.zero;
              if (dur.inMilliseconds > 0 && lyrics.lines.isNotEmpty) {
                final progress = pos.inMilliseconds / dur.inMilliseconds;
                return (progress * lyrics.lines.length).floor().clamp(0, lyrics.lines.length - 1);
              }
              return 0;
            }
          }),
        );

        if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
          final isJump = (_lastActiveIndex == -1) || ((activeIndex - _lastActiveIndex).abs() > 2);
          _lastActiveIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToActiveIndex(activeIndex, animate: !isJump);
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onExpand();
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -150) {
              HapticFeedback.lightImpact();
              widget.onExpand();
            }
          },
          child: SizedBox(
            height: _viewHeight,
            child: ListView.builder(
              controller: _scrollController,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: _lineExtent),
              itemExtent: _lineExtent,
              itemCount: lyrics.lines.length,
              itemBuilder: (context, index) {
                final line = lyrics.lines[index];
                final isActive = index == activeIndex;

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnimatedScale(
                      scale: isActive ? 1.12 : 0.94,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: Text(
                        line.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.style(
                          fontSize: 14.5,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.35)),
                          letterSpacing: -0.15,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => const Center(
        child: SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: AppColors.neonLime,
          ),
        ),
      ),
      error: (_, _) => Center(
        child: Text(
          'Lyrics unavailable',
          style: AppTypography.style(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.30),
          ),
        ),
      ),
    );
  }
}

/// Full synchronized lyrics scroll view matching Spotify / YT Music.
/// Highlights active line on open canvas without boxed card containers.
class _FullLyricsScrollView extends ConsumerStatefulWidget {
  final Lyrics lyrics;
  final dynamic audioHandler;
  final Color primaryColor;

  const _FullLyricsScrollView({
    required this.lyrics,
    required this.audioHandler,
    required this.primaryColor,
  });

  @override
  ConsumerState<_FullLyricsScrollView> createState() => _FullLyricsScrollViewState();
}

class _FullLyricsScrollViewState extends ConsumerState<_FullLyricsScrollView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollTimer;

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (_userIsScrolling) return;
    final key = _lineKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.35,
        duration: animate ? const Duration(milliseconds: 400) : Duration.zero,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Highly optimized selector with O(log n) binary search
    final int activeIndex = ref.watch(
      playerStateStreamProvider.select((s) {
        final pos = s.value?.position ?? Duration.zero;
        if (widget.lyrics.isSynced) {
          return widget.lyrics.findCurrentLineIndex(pos);
        } else {
          final dur = s.value?.duration ?? Duration.zero;
          if (dur.inMilliseconds > 0 && widget.lyrics.lines.isNotEmpty) {
            final progress = pos.inMilliseconds / dur.inMilliseconds;
            return (progress * widget.lyrics.lines.length).floor().clamp(0, widget.lyrics.lines.length - 1);
          }
          return 0;
        }
      }),
    );

    if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
      final isJump = (_lastActiveIndex == -1);
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(activeIndex, animate: !isJump);
      });
    }

    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              _userIsScrolling = true;
              _userScrollTimer?.cancel();
              setState(() {});
            } else {
              _userScrollTimer?.cancel();
              _userScrollTimer = Timer(const Duration(milliseconds: 3500), () {
                if (mounted) {
                  setState(() => _userIsScrolling = false);
                  _scrollToIndex(activeIndex);
                }
              });
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
            itemCount: widget.lyrics.lines.length,
            itemBuilder: (context, index) {
              final line = widget.lyrics.lines[index];
              final isActive = index == activeIndex;
              _lineKeys[index] ??= GlobalKey();

              return GestureDetector(
                key: _lineKeys[index],
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (line.timestamp != Duration.zero) {
                    widget.audioHandler.seek(line.timestamp);
                  }
                  _userIsScrolling = false;
                  _userScrollTimer?.cancel();
                  _scrollToIndex(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isActive
                        ? AppColors.neonLime.withValues(alpha: isDark ? 0.14 : 0.10)
                        : Colors.transparent,
                  ),
                  child: AnimatedScale(
                    scale: isActive ? 1.06 : 1.0,
                    alignment: Alignment.centerLeft,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: Text(
                      line.text,
                      textAlign: TextAlign.left,
                      style: AppTypography.style(
                        fontSize: 17.5,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        color: isActive
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.38)),
                        height: 1.4,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Floating "Jump to current" button when user has scrolled away
        if (_userIsScrolling)
          Positioned(
            bottom: 12,
            right: 20,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _userIsScrolling = false);
                _userScrollTimer?.cancel();
                _scrollToIndex(activeIndex);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E202A) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.neonLime.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_rounded, size: 14, color: AppColors.neonLime),
                    const SizedBox(width: 6),
                    Text(
                      'Jump to current',
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neonLime,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Isolated High-Performance Seek Bar Consumer (Open Canvas)
class _IsolatedPlayerSeekBar extends ConsumerWidget {
  const _IsolatedPlayerSeekBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerStateStreamProvider.select((s) => s.value?.position ?? Duration.zero));
    final duration = ref.watch(playerStateStreamProvider.select((s) => s.value?.duration ?? Duration.zero));
    final audioHandler = ref.read(audioHandlerProvider);

    return CustomSeekBar(
      position: position,
      duration: duration,
      onSeek: (pos) => audioHandler.seek(pos),
    );
  }
}

/// Atmospheric artwork background
/// Open canvas approach: decodes at tiny 48x48 size and lets the GPU upscale it with bilinear
/// interpolation directly into the base scaffold background, with zero CPU cost, zero ImageFilter blur passes,
/// and instant 120fps animations.
class _AmbientArtworkBackground extends StatelessWidget {
  final String? artworkUrl;

  const _AmbientArtworkBackground({
    super.key,
    required this.artworkUrl,
  });

  static const int _tiny = 48; // bilinear upscale = free "blur"

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF0C0D12) : const Color(0xFFF7F8FA);
    final url = artworkUrl;

    if (url == null || url.trim().isEmpty || TrackArtwork.isPlaceholderUrl(url)) {
      return ColoredBox(color: baseColor);
    }

    final Widget image = (url.startsWith('http://') || url.startsWith('https://'))
        ? CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            memCacheWidth: _tiny,
            memCacheHeight: _tiny,
            filterQuality: FilterQuality.medium,
            fadeInDuration: const Duration(milliseconds: 200),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          )
        : Image.file(
            File(url),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            cacheWidth: _tiny,
            cacheHeight: _tiny,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          );

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Solid base matching Studio Equalizer & Audio Settings scaffold background
          ColoredBox(color: baseColor),

          // 2. Tiny decode image with hardware bilinear upscale
          image,

          // 3. Vertical gradient smoothly fading image out into solid baseColor (zero hard lines)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: isDark
                      ? const [0.0, 0.35, 0.55, 0.68, 0.80, 1.0]
                      : const [0.0, 0.28, 0.50, 0.68, 0.84, 1.0],
                  colors: isDark
                      ? [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.22),
                          Colors.black.withValues(alpha: 0.48),
                          Colors.black.withValues(alpha: 0.88),
                          baseColor,
                          baseColor,
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.20),
                          Colors.white.withValues(alpha: 0.55),
                          baseColor.withValues(alpha: 0.90),
                          baseColor,
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
