import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/domain/models/lyrics.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/seek_bar.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  final VoidCallback onMinimize;

  const NowPlayingScreen({
    super.key,
    required this.onMinimize,
  });

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  bool _showQueue = false;
  bool _showFullLyrics = false;
  late final AnimationController _recordSpinController;

  @override
  void initState() {
    super.initState();
    // Vinyl record 360-degree rotation animation: 30 seconds per clockwise revolution
    _recordSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isPlaying = ref.read(isPlaybackPlayingProvider);
        if (isPlaying && !_recordSpinController.isAnimating) {
          _recordSpinController.repeat();
        }
      }
    });
  }

  @override
  void dispose() {
    _recordSpinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(currentPlayingTrackProvider);
    final isPlaying = ref.watch(isPlaybackPlayingProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    // React to playback state changes: spin clockwise while playing, pause rotation when paused
    ref.listen<bool>(isPlaybackPlayingProvider, (previous, next) {
      if (next) {
        if (!_recordSpinController.isAnimating) {
          _recordSpinController.repeat();
        }
      } else {
        if (_recordSpinController.isAnimating) {
          _recordSpinController.stop();
        }
      }
    });

    if (track == null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: Center(child: Text('No track playing', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)))),
      );
    }

    return PopScope(
      canPop: !_showQueue && !_showFullLyrics,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showQueue) {
          setState(() => _showQueue = false);
        } else if (_showFullLyrics) {
          setState(() => _showFullLyrics = false);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: Stack(
          children: [
            // Blurred Album Artwork Background with smooth bottom fade (matching reference UI)
            Positioned.fill(
              child: _AmbientArtworkBackground(
                artworkUrl: track.artworkUrl,
              ),
            ),

            // Main Screen Content with smooth animated transitions
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
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
                            child: _buildFullLyricsView(track, isPlaying, audioHandler, theme, primaryColor),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('main_player_view'),
                            child: _buildMainPlayerView(track, isPlaying, audioHandler, theme, primaryColor),
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
    bool isPlaying,
    dynamic audioHandler,
    ThemeData theme,
    Color primaryColor,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        // Swiping down on main player minimizes smoothly (Apple Music / Spotify UX)
        if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
          HapticFeedback.lightImpact();
          widget.onMinimize();
        }
      },
      child: Column(
        children: [
          // 1. Top Bar: (←)  Now Playing  (♡)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Circular Minimize Button (Frosted Glass)
              _GlassCircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_showQueue) {
                    setState(() => _showQueue = false);
                  } else if (_showFullLyrics) {
                    setState(() => _showFullLyrics = false);
                  } else {
                    widget.onMinimize();
                  }
                },
              ),

              // Center: Now Playing Title
              Text(
                'Now Playing',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),

              // Right Circular Heart Button (Borderless)
              _GlassCircleButton(
                icon: track.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: track.isLiked
                    ? const Color(0xFFFF5252)
                    : (theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.black87),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(audioRepositoryProvider).toggleLike(track);
                },
              ),
            ],
          ),
        ),

        // 2. Expandable content area with responsive sizing to avoid RenderFlex overflow
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                const lyricsHeight = 110.0;
                final bottomLift = (availableHeight * 0.055).clamp(38.0, 52.0);

                // Non-artwork reserved space:
                final reservedHeight = 250.0 + lyricsHeight + bottomLift;
                final maxArtFromH = (availableHeight - reservedHeight).clamp(140.0, 290.0);
                final maxArtFromW = screenWidth * 0.70;
                final artSize = math.min(maxArtFromH, maxArtFromW);

                return Column(
                  children: [
                    const Spacer(flex: 1),

                    // 3. Large Circular Album Artwork spinning clockwise like a vinyl record
                    GestureDetector(
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
                      child: Container(
                        width: artSize,
                        height: artSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.25),
                              blurRadius: 48,
                              spreadRadius: 6,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.60),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: RepaintBoundary(
                          child: RotationTransition(
                            turns: _recordSpinController,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                TrackArtwork(
                                  artworkUrl: track.artworkUrl,
                                  seedKey: track.id.isNotEmpty ? track.id : track.title,
                                  size: artSize,
                                  isCircle: true,
                                  ambientGlow: false,
                                ),
                                // Outer vinyl groove rim
                                Container(
                                  width: artSize,
                                  height: artSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                // Inner vinyl groove ring
                                Container(
                                  width: artSize * 0.70,
                                  height: artSize * 0.70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                // Center spindle hole punch
                                Container(
                                  width: artSize * 0.16,
                                  height: artSize * 0.16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? Colors.black : Colors.white,
                                    border: Border.all(
                                      color: primaryColor.withValues(alpha: 0.7),
                                      width: 2.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: artSize * 0.045,
                                      height: artSize * 0.045,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? Colors.black : const Color(0xFF20222B),
                                      ),
                                    ),
                                  ),
                                ),
                                // Spinning indicator marker for non-image songs
                                if (track.artworkUrl == null || track.artworkUrl!.trim().isEmpty)
                                  Align(
                                    alignment: const Alignment(0.55, -0.55),
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                                        border: Border.all(
                                          color: isDark ? Colors.black : Colors.white,
                                          width: 2.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isDark ? AppColors.neonLime : AppColors.limeAccentDark).withValues(alpha: 0.5),
                                            blurRadius: 6,
                                            spreadRadius: 1,
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
                    ),

                    const SizedBox(height: 16),

                    // 4. Track Title & Artist (Clean Modern Typography)
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 23,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Spacer above lyrics (centers lyrics between song name and seek bar)
                    const Spacer(flex: 1),

                    // 5. Live Sliding Lyrics (centered in the middle, tap to expand full lyrics)
                    _SlidingLyricsWidget(
                      audioHandler: audioHandler,
                      primaryColor: primaryColor,
                      onExpand: () {
                        HapticFeedback.lightImpact();
                        setState(() => _showFullLyrics = true);
                      },
                    ),

                    // Spacer below lyrics (equal to spacer above for true vertical centering)
                    const Spacer(flex: 1),

                    // 6. Isolated High-Performance Seek Bar Consumer
                    const _IsolatedPlayerSeekBar(),

                    const SizedBox(height: 18),

                    // 7. Playback Controls Row matching reference UI
                    _buildPlaybackControls(isPlaying, audioHandler, primaryColor),

                    // Generous bottom clearance from screen edge
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

  Widget _buildPlaybackControls(bool isPlaying, dynamic audioHandler, Color primaryColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveControlColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.45);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Three-Way Playback Mode Toggle: Shuffle ➔ Repeat All ➔ Repeat One
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
              modeIcon = Icons.repeat_rounded;
              modeLabel = 'Repeat Off';
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
                  width: 48,
                  height: 48,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        modeIcon,
                        key: ValueKey(modeLabel),
                        size: 22,
                        color: isActive ? primaryColor : inactiveControlColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Skip Previous in Borderless Circle
        _GlassCircleButton(
          icon: Icons.skip_previous_rounded,
          size: 52,
          iconSize: 26,
          onTap: () {
            HapticFeedback.lightImpact();
            audioHandler.skipToPrevious();
          },
        ),

        // Play / Pause in Large Neon Lime Circle with elevated glow
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (isPlaying) {
              audioHandler.pause();
            } else {
              audioHandler.play();
            }
          },
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.neonLime,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? primaryColor.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.12),
                  blurRadius: isDark ? 28 : 18,
                  spreadRadius: isDark ? 2 : 0,
                  offset: const Offset(0, 4),
                ),
                if (isDark)
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 50,
                    spreadRadius: 8,
                  ),
                if (!isDark)
                  BoxShadow(
                    color: AppColors.neonLime.withValues(alpha: 0.40),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 38,
              color: Colors.black,
            ),
          ),
        ),

        // Skip Next in Borderless Circle
        _GlassCircleButton(
          icon: Icons.skip_next_rounded,
          size: 52,
          iconSize: 26,
          onTap: () {
            HapticFeedback.lightImpact();
            audioHandler.skipToNext();
          },
        ),

        // Queue Toggle
        Tooltip(
          message: 'Playing Queue',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _showQueue = !_showQueue;
              });
            },
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Icon(
                  _showQueue ? Icons.queue_music_rounded : Icons.queue_music_outlined,
                  size: 22,
                  color: _showQueue ? primaryColor : inactiveControlColor,
                ),
              ),
            ),
          ),
        ),
      ],
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
                  setState(() => _showQueue = false);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Playing Queue (${queue.length})',
                    style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          audioHandler.clearQueue();
                        },
                        child: const Text('Clear'),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _showQueue = false;
                          });
                        },
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: Center(
                            child: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface),
                          ),
                        ),
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
                      color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    title: Text(
                      track.title,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                        color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      track.artistName,
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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
                              child: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ),
                        ),
                        Icon(Icons.drag_handle_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
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
    bool isPlaying,
    dynamic audioHandler,
    ThemeData theme,
    Color primaryColor,
  ) {
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // 1. Top Bar: (↓ Collapse)   Lyrics (Title • Artist)   (♡ Like)
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
              HapticFeedback.lightImpact();
              setState(() => _showFullLyrics = false);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassCircleButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  iconSize: 26,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _showFullLyrics = false);
                  },
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lyrics',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.title} • ${track.artistName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                _GlassCircleButton(
                  icon: track.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  iconColor: track.isLiked
                      ? const Color(0xFFFF5252)
                      : (isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(audioRepositoryProvider).toggleLike(track);
                  },
                ),
              ],
            ),
          ),
        ),

        // 2. Full Synced Lyrics Body
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
                          size: 52,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No lyrics available',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lyrics could not be found for "${track.title}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
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
            loading: () => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading full lyrics...',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Could not load lyrics',
                style: TextStyle(color: theme.colorScheme.error.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ),

        // 3. Compact Persistent Player Controls at bottom
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                (isDark ? Colors.black : Colors.white).withValues(alpha: 0.95),
                (isDark ? Colors.black : Colors.white).withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _IsolatedPlayerSeekBar(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audioHandler.skipToPrevious();
                    },
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(Icons.skip_previous_rounded, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (isPlaying) {
                        audioHandler.pause();
                      } else {
                        audioHandler.play();
                      }
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.neonLime,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? primaryColor.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            spreadRadius: isDark ? 2 : 0,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audioHandler.skipToNext();
                    },
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(Icons.skip_next_rounded, size: 28),
                      ),
                    ),
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

/// Live 3-line sliding lyrics widget embedded directly beneath the song title & artist.
/// Visual styling matching reference UI:
/// - Top line: previous line, smaller font, faded (slides up and away when finished).
/// - Center line: active playing line, larger font (16.5px), bold (w800), bright white.
/// - Bottom line: upcoming line, smaller font, faded.
/// - Buttery smooth sliding animation with easeInOutCubic (380ms).
/// - Tapping expands to full lyrics view (like Spotify / YT Music).
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

  static const double _lineExtent = 34.0;
  static const double _viewHeight = 102.0;

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
      // Butter-smooth sliding animation with easeOutCubic
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.32),
              ),
            ),
          );
        }

        final position = ref.watch(
          playerStateStreamProvider.select((s) => s.value?.position ?? Duration.zero),
        );
        final duration = ref.watch(
          playerStateStreamProvider.select((s) => s.value?.duration ?? Duration.zero),
        );

        final int activeIndex;
        if (lyrics.isSynced) {
          activeIndex = lyrics.findCurrentLineIndex(position);
        } else {
          if (duration.inMilliseconds > 0 && lyrics.lines.isNotEmpty) {
            final progress = position.inMilliseconds / duration.inMilliseconds;
            activeIndex = (progress * lyrics.lines.length).floor().clamp(0, lyrics.lines.length - 1);
          } else {
            activeIndex = 0;
          }
        }

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
            // Swiping up seamlessly expands into full lyrics
            if (details.primaryVelocity != null && details.primaryVelocity! < -150) {
              HapticFeedback.lightImpact();
              widget.onExpand();
            }
          },
          child: SizedBox(
            height: _viewHeight,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.20, 0.80, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
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
                    child: AnimatedScale(
                      scale: isActive ? 1.06 : 0.94,
                      duration: const Duration(milliseconds: 340),
                      curve: Curves.easeOutCubic,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 340),
                        curve: Curves.easeOutCubic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                          color: isActive
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.38)),
                          letterSpacing: isActive ? -0.2 : -0.1,
                          height: 1.35,
                        ),
                        child: Text(
                          line.text,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      loading: () => Center(
        child: SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: widget.primaryColor.withValues(alpha: 0.6),
          ),
        ),
      ),
      error: (_, _) => Center(
        child: Text(
          'Lyrics unavailable',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.32),
          ),
        ),
      ),
    );
  }
}

/// Full synchronized lyrics scroll view matching Spotify / YT Music.
/// Highlights active line with large bold typography and auto-scrolls smoothly.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final position = ref.watch(playerStateStreamProvider.select((s) => s.value?.position ?? Duration.zero));
    final duration = ref.watch(playerStateStreamProvider.select((s) => s.value?.duration ?? Duration.zero));

    final int activeIndex;
    if (widget.lyrics.isSynced) {
      activeIndex = widget.lyrics.findCurrentLineIndex(position);
    } else {
      if (duration.inMilliseconds > 0 && widget.lyrics.lines.isNotEmpty) {
        final progress = position.inMilliseconds / duration.inMilliseconds;
        activeIndex = (progress * widget.lyrics.lines.length).floor().clamp(0, widget.lyrics.lines.length - 1);
      } else {
        activeIndex = 0;
      }
    }

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
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.06, 0.92, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(17, 28, 17, 60),
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
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(vertical: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isActive
                          ? widget.primaryColor.withValues(alpha: isDark ? 0.16 : 0.12)
                          : Colors.transparent,
                    ),
                    child: Text(
                      line.text,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: isActive ? 21.0 : 17.0,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        color: isActive
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.38)
                                : Colors.black.withValues(alpha: 0.40)),
                        height: 1.45,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                );
              },
            ),
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
                  color: isDark ? const Color(0xFF222533) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.primaryColor.withValues(alpha: 0.4),
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
                    Icon(Icons.sync_rounded, size: 14, color: widget.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Jump to current',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.primaryColor,
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

/// Borderless circular button
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 20,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF20222B) : const Color(0xFFF2F4F8);
    final defaultIcon = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: defaultBg,
          border: isDark ? null : Border.all(color: const Color(0xFFE2E5EC), width: 1.0),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor ?? defaultIcon,
        ),
      ),
    );
  }
}

class _IsolatedPlayerSeekBar extends ConsumerWidget {
  const _IsolatedPlayerSeekBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerStateStreamProvider.select((s) => s.value?.position ?? Duration.zero));
    final duration = ref.watch(playerStateStreamProvider.select((s) => s.value?.duration ?? Duration.zero));
    final audioHandler = ref.watch(audioHandlerProvider);

    return RepaintBoundary(
      child: CustomSeekBar(
        position: position,
        duration: duration,
        onSeek: (pos) => audioHandler.seek(pos),
      ),
    );
  }
}

/// Blurred bottom-fading artwork background (matching reference screenshot 3)
/// Renders the track's album artwork heavily blurred in the upper half of the screen
/// and smoothly fades it into solid dark #0A0B0E toward the controls.
///
/// Performance: uses a tiny 64px source image so the sigma-50 Gaussian blur
/// processes very few pixels, making it essentially free on any GPU.
/// The widget is wrapped in RepaintBoundary and only rebuilds when artworkUrl changes.
class _AmbientArtworkBackground extends StatelessWidget {
  final String? artworkUrl;

  const _AmbientArtworkBackground({
    required this.artworkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final baseColor = isDark ? Colors.black : Colors.white;

    // Use a tiny source image (64px) — blur at sigma 50 obliterates all detail anyway,
    // so rendering a large image just to blur it is wasted GPU work.
    const int tinyRes = 64;

    Widget imageWidget;
    if (artworkUrl == null || artworkUrl!.trim().isEmpty) {
      imageWidget = Container(
        color: isDark ? const Color(0xFF14161F) : theme.colorScheme.surface,
      );
    } else if (artworkUrl!.startsWith('http://') || artworkUrl!.startsWith('https://')) {
      imageWidget = CachedNetworkImage(
        imageUrl: artworkUrl!,
        fit: BoxFit.cover,
        width: screenWidth,
        height: screenHeight * 0.85,
        memCacheWidth: tinyRes,
        memCacheHeight: tinyRes,
        errorWidget: (context, url, error) => Container(color: isDark ? const Color(0xFF14161F) : theme.colorScheme.surface),
      );
    } else {
      imageWidget = Image.file(
        File(artworkUrl!),
        fit: BoxFit.cover,
        width: screenWidth,
        height: screenHeight * 0.85,
        cacheWidth: tinyRes,
        cacheHeight: tinyRes,
        errorBuilder: (context, error, stackTrace) => Container(color: isDark ? const Color(0xFF14161F) : theme.colorScheme.surface),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Stack(
          children: [
            // Solid base
            Positioned.fill(
              child: ColoredBox(color: baseColor),
            ),

            // Blurred artwork image extending down through 85% of screen
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.85,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Transform.scale(
                  scale: 1.15,
                  child: imageWidget,
                ),
              ),
            ),

            // Vertical gradient smoothly fading image out at 65% of screen into solid baseColor
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: isDark
                        ? const [0.0, 0.38, 0.55, 0.68, 0.80, 1.0]
                        : const [0.0, 0.22, 0.44, 0.62, 0.80, 1.0],
                    colors: isDark
                        ? [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.20),
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.88),
                            Colors.black,
                            Colors.black,
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.72),
                            Colors.white.withValues(alpha: 0.48),
                            Colors.white.withValues(alpha: 0.62),
                            baseColor.withValues(alpha: 0.90),
                            baseColor,
                            baseColor,
                          ],
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

