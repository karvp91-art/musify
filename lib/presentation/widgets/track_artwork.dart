import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TrackArtwork extends StatelessWidget {
  final String? artworkUrl;
  final double size;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isCircle;
  final bool ambientGlow;
  final IconData fallbackIcon;

  const TrackArtwork({
    super.key,
    required this.artworkUrl,
    required this.size,
    this.height,
    this.borderRadius,
    this.isCircle = false,
    this.ambientGlow = false,
    this.fallbackIcon = Icons.album_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final w = size;
    final h = height ?? size;
    final effectiveRadius = isCircle
        ? BorderRadius.circular(w / 2)
        : (borderRadius ?? BorderRadius.circular(16));

    // Calculate optimal decoded bitmap cache dimension to eliminate memory bloat and scroll jank
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final targetCacheWidth = (w * pixelRatio).round().clamp(80, 1080);
    final targetCacheHeight = (h * pixelRatio).round().clamp(80, 1080);

    final Widget fallbackWidget = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF262936),
            Color(0xFF161820),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: w * 0.45,
          color: primaryColor.withValues(alpha: 0.6),
        ),
      ),
    );

    Widget imageContent;

    if (artworkUrl == null || artworkUrl!.trim().isEmpty) {
      imageContent = fallbackWidget;
    } else if (artworkUrl!.startsWith('http://') || artworkUrl!.startsWith('https://')) {
      imageContent = CachedNetworkImage(
        imageUrl: artworkUrl!,
        width: w,
        height: h,
        memCacheWidth: targetCacheWidth,
        memCacheHeight: targetCacheHeight,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: w,
          height: h,
          color: const Color(0xFF1E202A),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => fallbackWidget,
      );
    } else {
      // Local file path: Image.file handles async decoding and fallback via errorBuilder
      imageContent = Image.file(
        File(artworkUrl!),
        width: w,
        height: h,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallbackWidget,
      );
    }

    final decoratedWidget = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: ambientGlow
            ? [
                // Outer colored glow
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.18),
                  blurRadius: 48,
                  spreadRadius: 6,
                ),
                // Deep drop shadow for depth
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
                // Subtle inner-ish rim glow
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.06),
                  blurRadius: 2,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: imageContent,
      ),
    );

    // Only wrap in RepaintBoundary for heavy glow shadows (like NowPlayingScreen)
    // to avoid excessive layer creation in list views
    return ambientGlow ? RepaintBoundary(child: decoratedWidget) : decoratedWidget;
  }
}
