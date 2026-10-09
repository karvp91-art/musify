import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';

/// Ultra-refined Apple Dynamic Island floating status platter for track downloads.
/// Features liquid-glass optics, spring physics, real-time progress interpolation,
/// animated status morphing, and tactile gesture interactions (swipe up / tap to dismiss).
class DownloadDynamicIsland extends ConsumerStatefulWidget {
  const DownloadDynamicIsland({super.key});

  @override
  ConsumerState<DownloadDynamicIsland> createState() => _DownloadDynamicIslandState();
}

class _DownloadDynamicIslandState extends ConsumerState<DownloadDynamicIsland>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            offset: isVisible ? Offset.zero : const Offset(0, -1.35),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              scale: isVisible ? 1.0 : 0.85,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                opacity: isVisible ? 1.0 : 0.0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      // Swipe up to dismiss completed dynamic island
                      if (details.primaryVelocity != null && details.primaryVelocity! < -80) {
                        HapticFeedback.lightImpact();
                        downloadManager.dismissCompletedTrack();
                      }
                    },
                    onTap: () {
                      if (isCompleted) {
                        HapticFeedback.lightImpact();
                        downloadManager.dismissCompletedTrack();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(maxWidth: 396, minHeight: 58),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(29),
                        boxShadow: [
                          // Deep ambient occlusion shadow
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                            blurRadius: 26,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                          // Dynamic lime aura when completed
                          if (isCompleted)
                            BoxShadow(
                              color: (isDark ? AppColors.neonLime : AppColors.limeAccentDark)
                                  .withValues(alpha: isDark ? 0.22 : 0.14),
                              blurRadius: 20,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(29),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(29),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDark
                                    ? [
                                        const Color(0xF21B1D25),
                                        const Color(0xF50D0E13),
                                      ]
                                    : [
                                        const Color(0xFAFFFFFF),
                                        const Color(0xF7F3F5F9),
                                      ],
                              ),
                              border: Border.all(
                                color: isCompleted
                                    ? (isDark
                                        ? AppColors.neonLime.withValues(alpha: 0.45)
                                        : AppColors.limeAccentDark.withValues(alpha: 0.35))
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.08)),
                                width: 1.0,
                              ),
                            ),
                            child: track != null
                                ? Row(
                                    children: [
                                      // 1. Artwork Thumbnail with Elevation & Corner Status Indicator
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.25),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: TrackArtwork(
                                              artworkUrl: track.artworkUrl,
                                              seedKey: track.id.isNotEmpty ? track.id : track.title,
                                              size: 42,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          if (isCompleted)
                                            Positioned(
                                              right: -2,
                                              bottom: -2,
                                              child: Container(
                                                width: 15,
                                                height: 15,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF1B1D25) : Colors.white,
                                                    width: 1.8,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.check_rounded,
                                                  size: 9,
                                                  color: isDark ? Colors.black : Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      const SizedBox(width: 12),

                                      // 2. Track Title, Live Status Subtitle & Fluid Progress Bar
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
                                              style: AppTypography.style(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.2,
                                                color: isDark ? Colors.white : const Color(0xFF121316),
                                              ),
                                            ),
                                            const SizedBox(height: 2),

                                            // Status Subtitle with Animated Transitions
                                            AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 260),
                                              switchInCurve: Curves.easeOutCubic,
                                              switchOutCurve: Curves.easeInCubic,
                                              transitionBuilder: (child, animation) => FadeTransition(
                                                opacity: animation,
                                                child: SlideTransition(
                                                  position: Tween<Offset>(
                                                    begin: const Offset(0.0, 0.2),
                                                    end: Offset.zero,
                                                  ).animate(animation),
                                                  child: child,
                                                ),
                                              ),
                                              child: Row(
                                                key: ValueKey<bool>(isCompleted),
                                                children: [
                                                  if (!isCompleted)
                                                    _AnimatedDownloadPulse(
                                                      controller: _pulseController,
                                                      isDark: isDark,
                                                    ),
                                                  Expanded(
                                                    child: Text(
                                                      isCompleted
                                                          ? 'Downloaded • Ready offline'
                                                          : 'Downloading • ${(progress * 100).toInt()}%',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: AppTypography.style(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: isCompleted
                                                            ? (isDark
                                                                ? AppColors.neonLime
                                                                : AppColors.limeAccentDark)
                                                            : (isDark
                                                                ? Colors.white70
                                                                : const Color(0xFF5A6070)),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 5),

                                            // Smooth Interpolated Progress Bar
                                            _DynamicProgressBar(
                                              progress: isCompleted ? 1.0 : progress,
                                              isCompleted: isCompleted,
                                              isDark: isDark,
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // 3. Right Action Button (Tactile Spring Pill)
                                      _IslandActionButton(
                                        isCompleted: isCompleted,
                                        isDark: isDark,
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
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
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

/// Animated pulsing dot indicating active network downloading activity
class _AnimatedDownloadPulse extends StatelessWidget {
  final AnimationController controller;
  final bool isDark;

  const _AnimatedDownloadPulse({
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isDark ? AppColors.neonLime : AppColors.limeAccentDark;

    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.55 + (controller.value * 0.45)),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35 * controller.value),
                  blurRadius: 4 * controller.value,
                  spreadRadius: 1 * controller.value,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Dynamic interpolated progress bar with smooth easing and specular glow head
class _DynamicProgressBar extends StatelessWidget {
  final double progress;
  final bool isCompleted;
  final bool isDark;

  const _DynamicProgressBar({
    required this.progress,
    required this.isCompleted,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final activeGradient = LinearGradient(
      colors: isDark
          ? [
              AppColors.neonLimeDim,
              AppColors.neonLime,
            ]
          : [
              const Color(0xFF84CC16),
              AppColors.limeAccentDark,
            ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Inactive background track
            Container(
              height: 4.0,
              width: barWidth,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE2E6EE),
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Smooth animated active progress bar with easeOutCubic curve
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: clampedProgress),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                final currentWidth = (barWidth * value).clamp(0.0, barWidth);
                return Container(
                  height: 4.0,
                  width: currentWidth,
                  decoration: BoxDecoration(
                    gradient: activeGradient,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: isCompleted || value > 0.05
                        ? [
                            BoxShadow(
                              color: (isDark ? AppColors.neonLime : const Color(0xFF84CC16))
                                  .withValues(alpha: isDark ? 0.40 : 0.22),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Interactive right action button with tactile spring scale feedback
class _IslandActionButton extends StatefulWidget {
  final bool isCompleted;
  final bool isDark;
  final VoidCallback onTap;

  const _IslandActionButton({
    required this.isCompleted,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_IslandActionButton> createState() => _IslandActionButtonState();
}

class _IslandActionButtonState extends State<_IslandActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isDark ? AppColors.neonLime : AppColors.limeAccentDark;
    final defaultBg = widget.isDark ? const Color(0xFF222533) : const Color(0xFFECEEF2);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isCompleted
                ? accentColor.withValues(alpha: widget.isDark ? 0.22 : 0.15)
                : defaultBg,
            border: widget.isCompleted
                ? Border.all(
                    color: accentColor.withValues(alpha: widget.isDark ? 0.55 : 0.40),
                    width: 1.2,
                  )
                : Border.all(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1.0,
                  ),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Icon(
              widget.isCompleted ? Icons.check_rounded : Icons.close_rounded,
              key: ValueKey(widget.isCompleted),
              size: widget.isCompleted ? 18 : 16,
              color: widget.isCompleted
                  ? accentColor
                  : (widget.isDark ? Colors.white70 : const Color(0xFF424754)),
            ),
          ),
        ),
      ),
    );
  }
}
