import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:musify/core/theme/app_colors.dart';

/// A modern, silky-smooth 3-dot pulse wave indicator for buttons, modals, and compact loading states.
class PulseDotsIndicator extends StatefulWidget {
  final double size;
  final double spacing;
  final Color? color;

  const PulseDotsIndicator({
    super.key,
    this.size = 8.0,
    this.spacing = 5.0,
    this.color,
  });

  @override
  State<PulseDotsIndicator> createState() => _PulseDotsIndicatorState();
}

class _PulseDotsIndicatorState extends State<PulseDotsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dotColor = widget.color ??
        (isDark ? AppColors.neonLime : AppColors.limeAccentDark);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            // Phase-shift each dot for a harmonious undulating wave
            final delay = index * 0.22;
            final progress = (_controller.value - delay) % 1.0;
            final wave = math.sin(progress * math.pi * 2);
            
            final scale = 0.75 + (wave * 0.25);
            final opacity = (0.55 + (wave * 0.45)).clamp(0.40, 1.0);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Rhythmic dancing audio-bar wave indicator designed specifically for loading lyrics and audio states.
class LyricsLoadingWave extends StatefulWidget {
  final Color? primaryColor;
  final double height;

  const LyricsLoadingWave({
    super.key,
    this.primaryColor,
    this.height = 36.0,
  });

  @override
  State<LyricsLoadingWave> createState() => _LyricsLoadingWaveState();
}

class _LyricsLoadingWaveState extends State<LyricsLoadingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.primaryColor ??
        (isDark ? AppColors.neonLime : AppColors.limeAccentDark);

    return SizedBox(
      height: widget.height,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(4, (index) {
                // Different harmonic phase offsets for realistic equalizer motion
                final phaseOffsets = [0.0, 0.35, 0.7, 0.2];
                final progress = (_controller.value + phaseOffsets[index]) % 1.0;
                final wave = (math.sin(progress * math.pi * 2) + 1.0) / 2.0;

                final barHeight = (8.0 + (wave * 18.0)).roundToDouble();
                final opacity = (0.65 + (wave * 0.35)).clamp(0.50, 1.0);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  width: 4.0,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

/// Shimmering squircle placeholder for images and album artwork with a soft breathing icon.
class ArtworkShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const ArtworkShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<ArtworkShimmerPlaceholder> createState() =>
      _ArtworkShimmerPlaceholderState();
}

class _ArtworkShimmerPlaceholderState extends State<ArtworkShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E202A) : const Color(0xFFE5E7EB);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.12);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _pulseAnimation.value),
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.borderRadius)
                : null,
          ),
          child: Center(
            child: Icon(
              Icons.music_note_rounded,
              size: (math.min(widget.width, widget.height) * 0.36).clamp(14.0, 48.0),
              color: iconColor,
            ),
          ),
        );
      },
    );
  }
}
