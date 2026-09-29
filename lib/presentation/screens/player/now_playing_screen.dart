import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/lyrics.dart';
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
  bool _showLyrics = false;
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
        backgroundColor: isDark ? const Color(0xFF0A0B0E) : Colors.white,
        body: Center(child: Text('No track playing', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)))),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0B0E) : Colors.white,
      body: Stack(
        children: [
          // Blurred Album Artwork Background with smooth bottom fade (matching reference UI)
          Positioned.fill(
            child: _AmbientArtworkBackground(
              artworkUrl: track.artworkUrl,
            ),
          ),

          // Main Screen Content
          SafeArea(
            child: _showLyrics
                ? _buildLyricsView(track, isPlaying, audioHandler, theme, primaryColor)
                : (_showQueue
                    ? _buildQueueView(audioHandler, theme)
                    : _buildMainPlayerView(track, isPlaying, audioHandler, theme, primaryColor)),
          ),
        ],
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

    return Column(
      children: [
        // 1. Top Bar: (←)  Now Playing  (♡)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Circular Minimize Button (Frosted Glass)
              _GlassCircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_showLyrics) {
                    setState(() => _showLyrics = false);
                  } else if (_showQueue) {
                    setState(() => _showQueue = false);
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                final showLyrics = availableHeight > 540;
                final lyricsHeight = showLyrics ? 40.0 : 0.0;
                final bottomLift = (availableHeight * 0.04).clamp(14.0, 30.0);

                // Reserve fixed vertical space for controls, title, seekbar, margins
                final reservedHeight = 50.0 + lyricsHeight + 42.0 + 72.0 + bottomLift + 36.0;
                final maxArtFromH = (availableHeight - reservedHeight).clamp(130.0, 260.0);
                final maxArtFromW = screenWidth * 0.65;
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
                              color: primaryColor.withValues(alpha: 0.22),
                              blurRadius: 48,
                              spreadRadius: 6,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.08),
                              blurRadius: 2,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: RepaintBoundary(
                          child: RotationTransition(
                            turns: _recordSpinController,
                            child: TrackArtwork(
                              artworkUrl: track.artworkUrl,
                              size: artSize,
                              isCircle: true,
                              ambientGlow: false,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // 4. Track Title & Artist (Clean Modern Typography)
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    if (showLyrics) ...[
                      const SizedBox(height: 10),
                      // 5. Live Lyrics Preview Pill (tapping opens full lyrics screen)
                      _MiniLyricsPreview(
                        onTap: () {
                          setState(() {
                            _showLyrics = true;
                            _showQueue = false;
                          });
                        },
                        primaryColor: primaryColor,
                      ),
                    ],

                    const Spacer(flex: 1),

                    // 6. Isolated High-Performance Seek Bar Consumer
                    const _IsolatedPlayerSeekBar(),

                    const SizedBox(height: 8),

                    // 7. Playback Controls Row matching reference UI
                    _buildPlaybackControls(isPlaying, audioHandler, primaryColor),

                    // Elevated bottom clearance comfortably above device navigation bar
                    SizedBox(height: bottomLift),
                  ],
                );
              },
            ),
          ),
        ),
      ],
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
        // Shuffle Toggle Consumer
        Consumer(
          builder: (context, ref, _) {
            final isShuffle = ref.watch(playerStateStreamProvider.select((s) => s.value?.isShuffleEnabled ?? false));
            return IconButton(
              icon: Icon(
                Icons.shuffle_rounded,
                size: 22,
                color: isShuffle ? primaryColor : inactiveControlColor,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                audioHandler.toggleShuffle();
              },
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
              color: primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.5),
                  blurRadius: 28,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 50,
                  spreadRadius: 8,
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

        // Lyrics Toggle
        IconButton(
          tooltip: 'Lyrics',
          icon: Icon(
            _showLyrics ? Icons.lyrics_rounded : Icons.lyrics_outlined,
            size: 22,
            color: _showLyrics ? primaryColor : inactiveControlColor,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              _showLyrics = !_showLyrics;
              if (_showLyrics) _showQueue = false;
            });
          },
        ),

        // Queue Toggle
        IconButton(
          tooltip: 'Playing Queue',
          icon: Icon(
            _showQueue ? Icons.queue_music_rounded : Icons.queue_music_outlined,
            size: 22,
            color: _showQueue ? primaryColor : inactiveControlColor,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              _showQueue = !_showQueue;
              if (_showQueue) _showLyrics = false;
            });
          },
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface),
                        onPressed: () {
                          setState(() {
                            _showQueue = false;
                          });
                        },
                      ),
                    ],
                  ),
                ],
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
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            audioHandler.removeQueueItemAt(index);
                          },
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

  Widget _buildLyricsView(
    Track track,
    bool isPlaying,
    dynamic audioHandler,
    ThemeData theme,
    Color primaryColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);

    return Column(
      children: [
        // 1. Top Bar: (←)  Lyrics (badge)  (♡)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GlassCircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _showLyrics = false);
                },
              ),
              lyricsAsync.when(
                data: (l) => Row(
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
                    if (l != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l.source,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                loading: () => Text(
                  'Lyrics',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                error: (_, _) => Text(
                  'Lyrics',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
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

        // 2. Compact Playing Bar at top of lyrics view
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161822) : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: TrackArtwork(
                    artworkUrl: track.artworkUrl,
                    size: 42,
                    ambientGlow: false,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  size: 36,
                  color: primaryColor,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (isPlaying) {
                    audioHandler.pause();
                  } else {
                    audioHandler.play();
                  }
                },
              ),
            ],
          ),
        ),

        // 3. Compact seek bar
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: _IsolatedPlayerSeekBar(),
        ),

        // 4. Main Lyrics Body
        Expanded(
          child: lyricsAsync.when(
            data: (lyrics) {
              if (lyrics == null || lyrics.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lyrics_outlined,
                          size: 54,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No lyrics found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lyrics could not be found for "${track.title}" on JioSaavn or online catalog.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.invalidate(currentTrackLyricsProvider);
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry Search'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (lyrics.isSynced) {
                return _SyncedLyricsView(
                  lyrics: lyrics,
                  audioHandler: audioHandler,
                  primaryColor: primaryColor,
                );
              } else {
                return _PlainLyricsView(
                  lyrics: lyrics,
                  primaryColor: primaryColor,
                );
              }
            },
            loading: () => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Fetching lyrics from JioSaavn...',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 42,
                      color: theme.colorScheme.error.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 12),
                    Text('Failed to load lyrics: $err'),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(currentTrackLyricsProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncedLyricsView extends ConsumerStatefulWidget {
  final Lyrics lyrics;
  final dynamic audioHandler;
  final Color primaryColor;

  const _SyncedLyricsView({
    required this.lyrics,
    required this.audioHandler,
    required this.primaryColor,
  });

  @override
  ConsumerState<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<_SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (_userIsScrolling) return;
    final key = _lineKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.4,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final position = ref.watch(playerStateStreamProvider.select((s) => s.value?.position ?? Duration.zero));
    final activeIndex = widget.lyrics.findCurrentLineIndex(position);

    if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(activeIndex);
      });
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction != ScrollDirection.idle) {
          _userIsScrolling = true;
        } else {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _userIsScrolling = false;
          });
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        itemCount: widget.lyrics.lines.length,
        itemBuilder: (context, index) {
          final line = widget.lyrics.lines[index];
          final isActive = index == activeIndex;
          _lineKeys[index] ??= GlobalKey();

          return GestureDetector(
            key: _lineKeys[index],
            onTap: () {
              HapticFeedback.lightImpact();
              widget.audioHandler.seek(line.timestamp);
              _userIsScrolling = false;
              _scrollToIndex(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isActive
                    ? widget.primaryColor.withValues(alpha: isDark ? 0.18 : 0.12)
                    : Colors.transparent,
              ),
              child: Text(
                line.text,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: isActive ? 20.0 : 16.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? (isDark ? Colors.white : Colors.black)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  height: 1.45,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlainLyricsView extends StatelessWidget {
  final Lyrics lyrics;
  final Color primaryColor;

  const _PlainLyricsView({
    required this.lyrics,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final line = lyrics.lines[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            line.text,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E2028),
              height: 1.6,
              letterSpacing: -0.2,
            ),
          ),
        );
      },
    );
  }
}

class _MiniLyricsPreview extends ConsumerWidget {
  final VoidCallback onTap;
  final Color primaryColor;

  const _MiniLyricsPreview({
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: lyricsAsync.when(
          data: (lyrics) {
            if (lyrics == null || lyrics.isEmpty) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lyrics_outlined, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                  const SizedBox(width: 8),
                  Text(
                    'Tap to view lyrics',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              );
            }

            if (lyrics.isSynced) {
              final position = ref.watch(playerStateStreamProvider.select((s) => s.value?.position ?? Duration.zero));
              final activeIdx = lyrics.findCurrentLineIndex(position);
              final activeText = (activeIdx >= 0 && activeIdx < lyrics.lines.length)
                  ? lyrics.lines[activeIdx].text
                  : lyrics.lines.first.text;

              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mic_external_on_rounded, size: 13, color: primaryColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      activeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ],
              );
            }

            final previewText = lyrics.lines.isNotEmpty ? lyrics.lines.first.text : lyrics.plainLyrics;
            return Row(
              children: [
                Icon(Icons.lyrics_rounded, size: 15, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              ],
            );
          },
          loading: () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading lyrics...',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          error: (_, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lyrics_outlined, size: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Text(
                'Lyrics unavailable',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final defaultBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final defaultIcon = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: defaultBg,
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
    final baseColor = isDark ? const Color(0xFF0A0B0E) : Colors.white;

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
        memCacheWidth: 320,
        memCacheHeight: 320,
        errorWidget: (context, url, error) => Container(color: isDark ? const Color(0xFF14161F) : theme.colorScheme.surface),
      );
    } else {
      imageWidget = Image.file(
        File(artworkUrl!),
        fit: BoxFit.cover,
        width: screenWidth,
        height: screenHeight * 0.85,
        cacheWidth: 320,
        cacheHeight: 320,
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
                    stops: const [0.0, 0.38, 0.55, 0.68, 0.80, 1.0],
                    colors: isDark
                        ? [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.20),
                            Colors.black.withValues(alpha: 0.45),
                            const Color(0xFF0A0B0E).withValues(alpha: 0.88),
                            const Color(0xFF0A0B0E),
                            const Color(0xFF0A0B0E),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.05),
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.45),
                            baseColor.withValues(alpha: 0.88),
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
