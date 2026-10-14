import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// iOS-style "large title" header that shrinks into a compact pinned bar.
///
/// Layout (top to bottom):
///   [status bar inset]
///   [top row]   -> animates from expandedTopHeight to collapsedTopHeight
///   [search]    -> optional, height is driven from outside (animated)
///   [bottom]    -> optional, fixed height (e.g. filter chips), always pinned
///
/// `topRowBuilder` receives `t` (0 = fully expanded, 1 = fully collapsed) so the
/// caller can morph title size, subtitle opacity, button sizes, etc.
///
/// While expanded the header is transparent (the page's colour wash shows
/// through). As it collapses, it fades into an opaque `collapsedColor` with a
/// hairline divider, so list items scroll cleanly underneath it.
class CollapsingLargeTitleDelegate extends SliverPersistentHeaderDelegate {
  CollapsingLargeTitleDelegate({
    required this.topInset,
    required this.expandedTopHeight,
    required this.collapsedTopHeight,
    required this.topRowBuilder,
    required this.collapsedColor,
    this.topColor,
    this.dividerColor = Colors.transparent,
    this.searchBar,
    this.searchHeight = 0,
    this.searchFullHeight = 60,
    this.bottom,
    this.bottomHeight = 0,
  });

  final double topInset;
  final double expandedTopHeight;
  final double collapsedTopHeight;
  final Widget Function(BuildContext context, double t) topRowBuilder;
  final Color collapsedColor;
  final Color? topColor;
  final Color dividerColor;

  /// Current (animated) height of the search slot. 0 = hidden.
  final Widget? searchBar;
  final double searchHeight;
  final double searchFullHeight;

  final Widget? bottom;
  final double bottomHeight;

  double get collapseDistance => expandedTopHeight - collapsedTopHeight;

  @override
  double get minExtent => topInset + collapsedTopHeight + searchHeight + bottomHeight;

  @override
  double get maxExtent => topInset + expandedTopHeight + searchHeight + bottomHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = collapseDistance <= 0 ? 0.0 : (shrinkOffset / collapseDistance).clamp(0.0, 1.0);
    final topH = lerpDouble(expandedTopHeight, collapsedTopHeight, t)!;
    // Fades in the backing gradient wash cleanly as the header completes its collapse,
    // seamlessly masking scrolling items without any color jarring or flash.
    final bgAlpha = Curves.easeInQuad.transform(t);
    final effectiveTopColor = topColor ?? collapsedColor;

    return Stack(
      children: [
        // Seamless color wash background: identical tint and gradient flow to the page's ambient wash.
        // Zero color change during scroll, perfectly bends into the color wash when collapsed.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  effectiveTopColor.withValues(alpha: bgAlpha),
                  collapsedColor.withValues(alpha: bgAlpha),
                ],
              ),
              border: (dividerColor != Colors.transparent && dividerColor.a > 0)
                  ? Border(
                      bottom: BorderSide(
                        color: dividerColor.withValues(alpha: t),
                        width: 0.5,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        // Content (clipped so rounding errors can never overflow)
        Positioned.fill(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: topInset),
                  SizedBox(height: topH, child: topRowBuilder(context, t)),
                  if (searchBar != null && searchHeight > 0.5)
                    SizedBox(
                      height: searchHeight,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: searchFullHeight,
                          maxHeight: searchFullHeight,
                          child: Opacity(
                            opacity: (searchHeight / searchFullHeight).clamp(0.0, 1.0),
                            child: searchBar,
                          ),
                        ),
                      ),
                    ),
                  if (bottom != null) SizedBox(height: bottomHeight, child: bottom),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Cheap to rebuild; the parent builds a new delegate whenever state changes.
  @override
  bool shouldRebuild(covariant CollapsingLargeTitleDelegate old) => true;
}
