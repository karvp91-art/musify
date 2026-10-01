import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// A reusable glass capsule container built using [liquid_glass_widgets].
///
/// Features authentic liquid glass optical properties:
/// - Real-time background blur and refraction
/// - Specular highlight rim and chromatic aberration
/// - AMOLED-compliant dark mode styling
/// - Smooth superellipse / pill stadium geometry
class CapsuleContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final LiquidGlassSettings? settings;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const CapsuleContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.margin,
    this.padding,
    this.borderRadius = 30.0,
    this.settings,
    this.border,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveSettings = settings ??
        (isDark
            ? const LiquidGlassSettings(
                glassColor: Color(0x1F20222B),
                saturation: 1.4,
                blur: 16.0,
                blurWeight: 1.5,
                frost: 10.0,
                frostOpacity: 0.75,
                thickness: 24.0,
                refractiveIndex: 1.22,
                rimLight: 1.1,
                rimShade: 0.35,
                specularSharpness: GlassSpecularSharpness.sharp,
                shadowElevation: 2.0,
              )
            : const LiquidGlassSettings(
                glassColor: Color(0x66FFFFFF),
                saturation: 1.8,
                blur: 14.0,
                blurWeight: 1.0,
                frost: 8.0,
                frostOpacity: 0.65,
                thickness: 22.0,
                refractiveIndex: 1.20,
                rimLight: 1.0,
                rimShade: 0.25,
                specularSharpness: GlassSpecularSharpness.medium,
                shadowElevation: 2.0,
              ));

    Widget content = GlassContainer(
      useOwnLayer: true,
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      settings: effectiveSettings,
      child: child,
    );

    if (boxShadow != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: boxShadow,
        ),
        child: content,
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
