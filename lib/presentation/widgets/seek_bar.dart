import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final primaryColor = theme.colorScheme.primary;
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: theme.sliderTheme.copyWith(
            trackHeight: isDragging ? 5.0 : 3.5,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: isDragging ? 8 : 5,
              elevation: isDragging ? 4 : 1,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: primaryColor,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: primaryColor,
            overlayColor: primaryColor.withValues(alpha: 0.18),
          ),
          child: Slider(
            min: 0.0,
            max: totalDurationMs > 0 ? totalDurationMs : 1.0,
            value: sliderValue,
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
                  color: isDragging
                      ? primaryColor
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              Text(
                _formatRemaining(displayPosition, widget.duration),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
