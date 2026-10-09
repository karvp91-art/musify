import 'package:flutter/material.dart';

/// Centralized, high-performance shimmer skeleton system designed for AMOLED dark & light themes.
/// Uses a single synchronized controller with hardware-accelerated painting.

class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 12,
    this.shape = BoxShape.rectangle,
    this.margin,
  });

  const ShimmerBox.circle({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shape = BoxShape.circle;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
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
    final baseColor = isDark ? const Color(0xFF22242E) : const Color(0xFFE5E7EB);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: widget.margin,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _animation.value),
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.borderRadius)
                : null,
          ),
        );
      },
    );
  }
}

/// Shimmer placeholder matching TrackListTile 1:1
class TrackTileSkeleton extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const TrackTileSkeleton({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          // 54x54 Album Squircle
          const ShimmerBox(
            width: 54,
            height: 54,
            borderRadius: 14,
          ),
          const SizedBox(width: 14),
          // Title & Artist Lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                ShimmerBox(
                  width: 160,
                  height: 14,
                  borderRadius: 7,
                ),
                SizedBox(height: 8),
                ShimmerBox(
                  width: 100,
                  height: 11,
                  borderRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Trailing action button
          const ShimmerBox.circle(size: 32),
        ],
      ),
    );
  }
}

/// Shimmer list of track tiles
class TrackListSkeleton extends StatelessWidget {
  final int itemCount;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  const TrackListSkeleton({
    super.key,
    this.itemCount = 8,
    this.shrinkWrap = false,
    this.physics,
    this.padding = const EdgeInsets.only(top: 6, bottom: 90),
  });

  /// Sliver version of the track list skeleton
  static Widget sliver({int itemCount = 8, EdgeInsetsGeometry padding = const EdgeInsets.only(top: 6, bottom: 90)}) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const TrackTileSkeleton(),
          childCount: itemCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const TrackTileSkeleton(),
    );
  }
}

/// Shimmer Header for Album, Playlist, and Stream Playlist detail screens
class MediaHeaderSkeleton extends StatelessWidget {
  final bool isCircular;

  const MediaHeaderSkeleton({super.key, this.isCircular = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Centered Artwork Hero
          Center(
            child: isCircular
                ? const ShimmerBox.circle(size: 160)
                : const ShimmerBox(
                    width: 200,
                    height: 200,
                    borderRadius: 24,
                  ),
          ),
          const SizedBox(height: 18),
          // Title
          const ShimmerBox(width: 200, height: 22, borderRadius: 11),
          const SizedBox(height: 8),
          // Subtitle / metadata
          const ShimmerBox(width: 130, height: 13, borderRadius: 7),
          const SizedBox(height: 20),
          // Play All & Shuffle Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              ShimmerBox(
                width: 150,
                height: 48,
                borderRadius: 24,
              ),
              SizedBox(width: 12),
              ShimmerBox.circle(size: 48),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Shimmer Skeleton for Artist Detail screen
class ArtistHeaderSkeleton extends StatelessWidget {
  const ArtistHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        children: [
          // Circular Artist Image
          const Center(
            child: ShimmerBox.circle(size: 140),
          ),
          const SizedBox(height: 16),
          // Artist Name
          const ShimmerBox(width: 180, height: 24, borderRadius: 12),
          const SizedBox(height: 8),
          // Stats
          const ShimmerBox(width: 120, height: 13, borderRadius: 6),
          const SizedBox(height: 18),
          // Play All Pill
          const Center(
            child: ShimmerBox(width: 170, height: 48, borderRadius: 24),
          ),
          const SizedBox(height: 24),
          // Top Songs Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBox(width: 110, height: 18, borderRadius: 9),
                ShimmerBox(width: 70, height: 12, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer Multi-Category Skeleton for Search Screen
class SearchMultiSkeleton extends StatelessWidget {
  const SearchMultiSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Top Hero Result Label
        const ShimmerBox(width: 100, height: 16, borderRadius: 8),
        const SizedBox(height: 10),
        // Hero Card
        const ShimmerBox(width: double.infinity, height: 140, borderRadius: 20),
        const SizedBox(height: 22),

        // Songs Section Header
        const ShimmerBox(width: 80, height: 16, borderRadius: 8),
        const SizedBox(height: 10),
        // 4 Track Tiles
        const TrackTileSkeleton(padding: EdgeInsets.symmetric(vertical: 6)),
        const TrackTileSkeleton(padding: EdgeInsets.symmetric(vertical: 6)),
        const TrackTileSkeleton(padding: EdgeInsets.symmetric(vertical: 6)),
        const TrackTileSkeleton(padding: EdgeInsets.symmetric(vertical: 6)),

        const SizedBox(height: 16),

        // Artists Section Header
        const ShimmerBox(width: 90, height: 16, borderRadius: 8),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) => Column(
              children: const [
                ShimmerBox.circle(size: 76),
                SizedBox(height: 8),
                ShimmerBox(width: 60, height: 11, borderRadius: 6),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Albums Section Header
        const ShimmerBox(width: 90, height: 16, borderRadius: 8),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 130, height: 130, borderRadius: 16),
                SizedBox(height: 8),
                ShimmerBox(width: 100, height: 11, borderRadius: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
