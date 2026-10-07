import 'package:flutter/material.dart';

/// Sleek animated Shimmer loading skeleton for Stream Home Screen.
class StreamShimmerSkeleton extends StatefulWidget {
  const StreamShimmerSkeleton({super.key});

  @override
  State<StreamShimmerSkeleton> createState() => _StreamShimmerSkeletonState();
}

class _StreamShimmerSkeletonState extends State<StreamShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double borderRadius = 14,
    required bool isDark,
  }) {
    final baseColor = isDark ? const Color(0xFF22242E) : const Color(0xFFE5E7EB);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        );
      },
    );
  }

  Widget _sectionSkeleton({required bool isDark, required double cardWidth, required double cardHeight}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(width: 140, height: 18, isDark: isDark),
              const SizedBox(height: 6),
              _shimmerBox(width: 220, height: 12, isDark: isDark),
            ],
          ),
        ),
        SizedBox(
          height: cardHeight + 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(width: cardWidth, height: cardHeight, borderRadius: 16, isDark: isDark),
                const SizedBox(height: 8),
                _shimmerBox(width: cardWidth * 0.8, height: 12, isDark: isDark),
                const SizedBox(height: 4),
                _shimmerBox(width: cardWidth * 0.5, height: 10, isDark: isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Popular Artists Skeleton
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(width: 150, height: 18, isDark: isDark),
                    const SizedBox(height: 6),
                    _shimmerBox(width: 200, height: 12, isDark: isDark),
                  ],
                ),
              ),
              SizedBox(
                height: 148,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 5,
                  separatorBuilder: (context, index) => const SizedBox(width: 16),
                  itemBuilder: (context, index) => Column(
                    children: [
                      _shimmerBox(width: 92, height: 92, borderRadius: 46, isDark: isDark),
                      const SizedBox(height: 8),
                      _shimmerBox(width: 70, height: 12, isDark: isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Movie Soundtracks Skeleton
          _sectionSkeleton(isDark: isDark, cardWidth: 140, cardHeight: 140),

          const SizedBox(height: 16),

          // 3. Top Charts Skeleton
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(width: 130, height: 18, isDark: isDark),
                    const SizedBox(height: 6),
                    _shimmerBox(width: 190, height: 12, isDark: isDark),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerBox(
                        width: 140,
                        height: 140,
                        borderRadius: 16,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _shimmerBox(width: 110, height: 12, isDark: isDark),
                      const SizedBox(height: 4),
                      _shimmerBox(width: 70, height: 10, isDark: isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 4. Editorial Picks Skeleton
          _sectionSkeleton(isDark: isDark, cardWidth: 140, cardHeight: 140),
        ],
      ),
    );
  }
}
