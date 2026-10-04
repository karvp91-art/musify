import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/lyrics.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/seek_bar.dart';
import 'package:musify/presentation/widgets/track_menu_bottom_sheet.dart';
import 'package:musify/presentation/screens/settings/studio_equalizer_screen.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  final VoidCallback onMinimize;

  const NowPlayingScreen({
    super.key,
    required this.onMinimize,
  });

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _showQueue = false;
  bool _showFullLyrics = false;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(currentPlayingTrackProvider);
    final isPlaying = ref.watch(isPlaybackPlayingProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    if (track == null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: Center(
          child: Text(
            'No track playing',
            style: AppTypography.style(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : AppColors.onSurfaceMutedLight,
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
          setState(() => _showQueue = false);
        } else if (_showFullLyrics) {
          setState(() => _showFullLyrics = false);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: Stack(
          children: [
            // Full-bleed portrait hero artwork fading smoothly into theme background
            Positioned.fill(
              child: _HeroArtworkBackground(
                artworkUrl: track.artworkUrl,
              ),
            ),

            // Main Screen Content with smooth animated transitions
            Positioned.fill(
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
      child: SafeArea(
        child: Column(
          children: [
            // 1. Top Bar: Minimal Collapse Chevron
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onMinimize();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.70),
                        border: isDark
                            ? null
                            : Border.all(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isDark ? Colors.white : AppColors.onSurfaceLight,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),

            // Flexible space pushing everything down so the artwork is fully visible above!
            const Spacer(),

            // Cohesive bottom content block: Title, Artist, Heart, Lyrics, Controls, Seekbar, Aux
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title & Artist on Left, Heart button on Right (sitting right on fading edge of artwork)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.onSurfaceLight,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.65)
                                    : AppColors.onSurfaceMutedLight,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Heart / Favorite button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(audioRepositoryProvider).toggleLike(track);
                        },
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Icon(
                              track.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 26,
                              color: track.isLiked
                                  ? const Color(0xFFFF4868)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.75)
                                      : AppColors.onSurfaceMutedLight),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Live Synced Lyric Single-Line Preview (sitting right above controls)
                  _SyncedLyricLinePreview(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showFullLyrics = true);
                    },
                  ),

                  const SizedBox(height: 22),

                  // 5-Control Playback Row (Shuffle/Repeat | Prev | Hero Play/Pause | Next | Queue)
                  RepaintBoundary(
                    child: _buildPlaybackControls(isPlaying, audioHandler, primaryColor),
                  ),

                  const SizedBox(height: 16),

                  // Isolated High-Performance Seek Bar (retaining GlassSlider!)
                  const RepaintBoundary(
                    child: _IsolatedPlayerSeekBar(),
                  ),

                  const SizedBox(height: 10),

                  // Bottom Auxiliary 4-Icon Utility Row
                  _buildBottomAuxiliaryRow(track),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(bool isPlaying, dynamic audioHandler, Color primaryColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const activeAccent = AppColors.neonLime;
    final inactiveControlColor = isDark
        ? Colors.white.withValues(alpha: 0.50)
        : AppColors.onSurfaceMutedLight;
    final primaryIconColor = isDark
        ? Colors.white
        : AppColors.onSurfaceLight;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Mode toggle: Shuffle ➔ Repeat All ➔ Repeat One
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
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      modeIcon,
                      size: 22,
                      color: isActive ? activeAccent : inactiveControlColor,
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Skip Previous
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            audioHandler.skipToPrevious();
          },
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                Icons.skip_previous_rounded,
                size: 34,
                color: primaryIconColor,
              ),
            ),
          ),
        ),

        // Hero Circular Play / Pause Button (Signature Neon Lime)
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
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: AppColors.neonLime,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonLime.withValues(alpha: isDark ? 0.38 : 0.28),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 36,
                color: const Color(0xFF111827),
              ),
            ),
          ),
        ),

        // Skip Next
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            audioHandler.skipToNext();
          },
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                Icons.skip_next_rounded,
                size: 34,
                color: primaryIconColor,
              ),
            ),
          ),
        ),

        // Queue Toggle Button
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
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  _showQueue ? Icons.queue_music_rounded : Icons.queue_music_outlined,
                  size: 24,
                  color: _showQueue ? activeAccent : inactiveControlColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAuxiliaryRow(Track track) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const activeAccent = AppColors.neonLime;
    final defaultAuxColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.onSurfaceMutedLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Devices / Output
          Tooltip(
            message: 'Audio Output',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                AppSnackBar.show(
                  context,
                  message: 'Playing on this device',
                  type: AppSnackBarType.info,
                );
              },
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: Icon(
                    Icons.sensors_rounded,
                    size: 22,
                    color: defaultAuxColor,
                  ),
                ),
              ),
            ),
          ),

          // 2. Studio Equalizer DSP
          Tooltip(
            message: 'Studio Equalizer',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                openStudioEqualizerScreen(context);
              },
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final isEqEnabled = ref.watch(equalizerProvider).isEnabled;
                      return Icon(
                        Icons.graphic_eq_rounded,
                        size: 22,
                        color: isEqEnabled ? activeAccent : defaultAuxColor,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // 3. Download Track
          Consumer(
            builder: (context, ref, _) {
              final downloadManager = ref.watch(downloadManagerProvider);
              final state = downloadManager.getState(track.id);
              final isDownloaded = state.isDownloaded || track.isDownloaded;
              final isDownloading = state.isDownloading;

              final IconData dlIcon;
              final Color dlColor;
              final String dlTooltip;

              if (isDownloading) {
                dlIcon = Icons.downloading_rounded;
                dlColor = activeAccent;
                dlTooltip = 'Downloading...';
              } else if (isDownloaded) {
                dlIcon = Icons.download_done_rounded;
                dlColor = activeAccent;
                dlTooltip = 'Downloaded';
              } else {
                dlIcon = Icons.file_download_outlined;
                dlColor = defaultAuxColor;
                dlTooltip = 'Download';
              }

              return Tooltip(
                message: dlTooltip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (isDownloaded) {
                      AppSnackBar.show(
                        context,
                        message: 'Track already downloaded',
                        type: AppSnackBarType.info,
                      );
                    } else if (isDownloading) {
                      downloadManager.cancelDownload(track.id);
                      AppSnackBar.show(
                        context,
                        message: 'Cancelled download for "${track.title}"',
                        type: AppSnackBarType.info,
                      );
                    } else {
                      downloadManager.downloadTrack(track);
                      AppSnackBar.show(
                        context,
                        message: 'Downloading "${track.title}"...',
                        type: AppSnackBarType.info,
                      );
                    }
                  },
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: Icon(dlIcon, size: 22, color: dlColor),
                    ),
                  ),
                ),
              );
            },
          ),

          // 4. More Options Menu
          Builder(
            builder: (btnCtx) {
              return Tooltip(
                message: 'More options',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    showTrackDropdownMenu(
                      context: context,
                      ref: ref,
                      track: track,
                      buttonContext: btnCtx,
                    );
                  },
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 22,
                        color: defaultAuxColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQueueView(
    dynamic audioHandler,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: isDark ? const Color(0xE80A0B0E) : const Color(0xF2FFFFFF),
          child: SafeArea(
            child: Consumer(
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Playing Queue (${queue.length})',
                              style: AppTypography.style(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.3,
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
                                const SizedBox(width: 4),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _showQueue = false;
                                    });
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                                    ),
                                    child: Center(
                                      child: Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.onSurface),
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
                              color: isCurrent ? AppColors.neonLime : theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            ),
          ),
        ),
      ),
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: isDark ? const Color(0xE80A0B0E) : const Color(0xF2FFFFFF),
          child: SafeArea(
            child: Column(
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
                                style: AppTypography.style(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${track.title} • ${track.artistName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.style(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
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
                                    fontWeight: FontWeight.w400,
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
                            style: AppTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Text(
                        'Could not load lyrics',
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.error.withValues(alpha: 0.7),
                        ),
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
                              child: const Icon(
                                Icons.pause_rounded,
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Sleek single-line synced lyric preview embedded beneath song title & artist.
/// Matches the reference UI ("I found a love for me").
/// Tapping opens the full lyrics screen.
class _SyncedLyricLinePreview extends ConsumerWidget {
  final VoidCallback onTap;

  const _SyncedLyricLinePreview({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);

    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : AppColors.onSurfaceLight.withValues(alpha: 0.78);
    final placeholderColor = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : AppColors.onSurfaceMutedLight;

    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics == null || lyrics.isEmpty) {
          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  size: 15,
                  color: placeholderColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Lyrics unavailable',
                  style: AppTypography.style(
                    fontSize: 14,
                    color: placeholderColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
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

        final lineText = (activeIndex >= 0 && activeIndex < lyrics.lines.length)
            ? lyrics.lines[activeIndex].text
            : (lyrics.lines.isNotEmpty ? lyrics.lines[0].text : '');

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
            child: Row(
              key: ValueKey(lineText),
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    lineText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 14.5,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: placeholderColor,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => SizedBox(
        height: 18,
        child: Text(
          'Loading lyrics...',
          style: AppTypography.style(
            fontSize: 13,
            color: placeholderColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
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
                      style: AppTypography.style(
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
  final double iconSize;
  final Color? iconColor;

  static const double size = 44;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
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

/// Full-bleed portrait hero artwork background matching the reference UI screenshot.
/// Hardware-accelerated LinearGradient eliminates all GPU blur shader passes,
/// delivering fluid 60/120 FPS performance with zero dropped frames.
///
/// Features:
/// - Light theme: smoothly fades into pure white
/// - Dark theme: smoothly fades into pure black
/// - Extended height (76% of screen) so Title, Artist, and Lyrics overlay the artwork before fading
class _HeroArtworkBackground extends StatelessWidget {
  final String? artworkUrl;

  const _HeroArtworkBackground({required this.artworkUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.black : Colors.white;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // Cover 76% of screen height so artwork extends behind lower title & lyrics before fading
    final heroHeight = screenHeight * 0.76;

    Widget buildImage() {
      if (artworkUrl == null || artworkUrl!.trim().isEmpty) {
        return Container(
          color: isDark ? const Color(0xFF14161F) : const Color(0xFFE8ECF2),
          child: Center(
            child: Icon(
              Icons.music_note_rounded,
              size: 80,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.15),
            ),
          ),
        );
      } else if (artworkUrl!.startsWith('http://') || artworkUrl!.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: artworkUrl!,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          width: screenWidth,
          height: heroHeight,
          memCacheWidth: 720,
          memCacheHeight: 960,
          filterQuality: FilterQuality.medium,
          placeholder: (context, url) => Container(
            color: isDark ? const Color(0xFF14161F) : const Color(0xFFE8ECF2),
          ),
          errorWidget: (context, url, error) => Container(
            color: isDark ? const Color(0xFF14161F) : const Color(0xFFE8ECF2),
            child: Center(
              child: Icon(
                Icons.music_note_rounded,
                size: 80,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.15),
              ),
            ),
          ),
        );
      } else {
        final file = File(artworkUrl!);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            width: screenWidth,
            height: heroHeight,
            cacheWidth: 720,
            cacheHeight: 960,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => Container(
              color: isDark ? const Color(0xFF14161F) : const Color(0xFFE8ECF2),
              child: Center(
                child: Icon(
                  Icons.music_note_rounded,
                  size: 80,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.15),
                ),
              ),
            ),
          );
        } else {
          return Container(
            color: isDark ? const Color(0xFF14161F) : const Color(0xFFE8ECF2),
            child: Center(
              child: Icon(
                Icons.music_note_rounded,
                size: 80,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.15),
              ),
            ),
          );
        }
      }
    }

    return RepaintBoundary(
      child: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Stack(
          children: [
            // Solid theme background base (Black in Dark Mode, White in Light Mode)
            Positioned.fill(
              child: ColoredBox(color: baseColor),
            ),

            // Top portrait hero artwork
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: heroHeight,
              child: buildImage(),
            ),

            // Smooth linear gradient fading artwork into theme base color
            // Softly darkens/lightens behind title and lyrics (at 44%-64%)
            // and transitions into solid baseColor near the controls (at 84%-100%)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: heroHeight + 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: isDark
                        ? const [0.0, 0.35, 0.56, 0.74, 0.90, 1.0]
                        : const [0.0, 0.32, 0.54, 0.72, 0.88, 1.0],
                    colors: isDark
                        ? [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.20),
                            Colors.black.withValues(alpha: 0.62),
                            Colors.black.withValues(alpha: 0.94),
                            Colors.black,
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.68),
                            Colors.white.withValues(alpha: 0.95),
                            Colors.white,
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


