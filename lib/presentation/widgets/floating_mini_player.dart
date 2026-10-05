import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/player/mini_player.dart';
import 'package:musify/presentation/screens/player/now_playing_screen.dart';

/// Universal floating mini player widget for detail and sub-screens.
/// Automatically handles keyboard avoidance (floats above keyboard without hiding).
class FloatingMiniPlayer extends ConsumerWidget {
  final double? bottomOffset;

  const FloatingMiniPlayer({
    super.key,
    this.bottomOffset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentPlayingTrackProvider);
    if (track == null) return const SizedBox.shrink();

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final defaultBottom = keyboardHeight > 0
        ? keyboardHeight + 8.0
        : (bottomOffset ?? math.max(MediaQuery.paddingOf(context).bottom + 6.0, 10.0));

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: defaultBottom,
      child: Material(
        type: MaterialType.transparency,
        child: MiniPlayer(
          onExpand: () => openNowPlayingScreen(context),
        ),
      ),
    );
  }
}
