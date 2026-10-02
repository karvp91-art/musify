import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:musify/core/theme/app_colors.dart';

class CustomSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const CustomSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<CustomSeekBar> createState() => _CustomSeekBarState();
}

class _CustomSeekBarState extends State<CustomSeekBar> {
  double? _dragValue;

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatRemaining(Duration position, Duration total) {
    final remaining = total - position;
    if (remaining.isNegative || remaining == Duration.zero) return '0:00';
    return '-${_formatTime(remaining)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.neonLime : AppColors.neonLime;
    final totalDurationMs = widget.duration.inMilliseconds.toDouble();
    final currentPosMs = widget.position.inMilliseconds.toDouble().clamp(
          0.0,
          totalDurationMs > 0 ? totalDurationMs : 1.0,
        );

    final sliderValue = (_dragValue ?? currentPosMs).clamp(
      0.0,
      totalDurationMs > 0 ? totalDurationMs : 1.0,
    );

    final isDragging = _dragValue != null;
    final displayPosition = isDragging
        ? Duration(milliseconds: _dragValue!.round())
        : widget.position;

    final inactiveTrack = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.08);

    final timeColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: GlassSlider(
            value: sliderValue,
            min: 0.0,
            max: totalDurationMs > 0 ? totalDurationMs : 1.0,
            activeColor: activeColor,
            thumbColor: activeColor,
            inactiveColor: inactiveTrack,
            glowColor: activeColor.withValues(alpha: isDark ? 0.60 : 0.40),
            glowRadius: 2.5,
            useOwnLayer: true,
            onChangeStart: (val) {
              HapticFeedback.selectionClick();
            },
            onChanged: totalDurationMs > 0
                ? (val) {
                    setState(() {
                      _dragValue = val;
                    });
                  }
                : null,
            onChangeEnd: totalDurationMs > 0
                ? (val) {
                    HapticFeedback.lightImpact();
                    widget.onSeek(Duration(milliseconds: val.round()));
                    setState(() {
                      _dragValue = null;
                    });
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(displayPosition),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isDragging ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12,
                  color: isDragging ? activeColor : timeColor,
                ),
              ),
              Text(
                _formatRemaining(displayPosition, widget.duration),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: timeColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
