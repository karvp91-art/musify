---
name: glass-ui-transformer
description: "Transforms and styles any Flutter UI component to match the authentic optical characteristics, liquid refraction, specular rim lighting, jelly physics, and typography of GlassTabBar.bottom."
---

# Glass UI Transformer — Component Replication Guide

This skill provides the architectural specifications, optical shader formulas, physics curves, and drop-in code templates needed to transform **any standard Flutter UI component** into the exact aesthetic and physical characteristics of `GlassTabBar.bottom` from `liquid_glass_widgets`.

---

## 1. The Core Optical DNA of `GlassTabBar.bottom`

Every widget styled with this skill must adhere to the **`kBottomBarGlassDefaults`** optical recipe:

### Optical Shader Preset
```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

LiquidGlassSettings resolveGlassDockSettings({required bool isDark}) {
  return isDark
      ? const LiquidGlassSettings(
          thickness: 30.0,             // Deep refraction without icon distortion
          blur: 3.0,                  // Frosted back-blur
          chromaticAberration: 0.30,  // Spectral RGB edge dispersion
          lightIntensity: 0.65,       // Specular rim reflection intensity
          ambientStrength: 1.0,
          refractiveIndex: 1.59,      // Polycarbonate refractive index
          saturation: 0.70,
          lightAngle: 0.75 * math.pi, // 135° Apple standard upper-left key light
          glassColor: Color(0x2EFFFFFF), // Luminous liquid glass tint matching GlassTabBar.bottom
          specularSharpness: GlassSpecularSharpness.sharp,
        )
      : const LiquidGlassSettings(
          thickness: 28.0,
          blur: 3.0,
          chromaticAberration: 0.25,
          lightIntensity: 0.60,
          ambientStrength: 1.0,
          refractiveIndex: 1.55,
          saturation: 0.85,
          lightAngle: 0.75 * math.pi,
          glassColor: Color(0x3DFFFFFF),
          specularSharpness: GlassSpecularSharpness.medium,
        );
}
```

---

## 2. Universal Styling Rules & Antidotes

### Rule 1: Always Enforce Typography Protection
To prevent Flutter's yellow/green double underlines bug when rendering text in isolated glass layers:
1. Always wrap the glass container in `Material(type: MaterialType.transparency, child: ...)`
2. Explicitly specify `decoration: TextDecoration.none` and `fontFamily` on all text styles.

### Rule 2: Floating Stadium Geometry & Clean Ambient Shadows
Do NOT add harsh, dark bounding box shadows or spread radiuses in dark mode. `GlassTabBar.bottom` relies on optical refraction and edge specular rims, accented with a soft diffuse shadow:
```dart
BoxDecoration(
  borderRadius: BorderRadius.circular(borderRadius),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ],
)
```

### Rule 3: Jelly Spring Physics for Active Indicators
Use Apple iOS 26 fluid curve `const Cubic(0.2, 0.9, 0.22, 1.0)` with a `300ms` - `340ms` duration for moving pills, sliders, or selection states:
```dart
AnimatedPositioned(
  duration: const Duration(milliseconds: 320),
  curve: const Cubic(0.2, 0.9, 0.22, 1.0),
  // ...
)
```

---

## 3. Transformation Recipes by Component Type

### A. Transforming a Button / Toggle Bar into a Floating Glass Dock

```dart
class GlassDockPill<T> extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final ValueChanged<T> onSelected;
  final Widget Function(T item, bool isSelected) itemBuilder;
  final Color activeColor;

  const GlassDockPill({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
    required this.itemBuilder,
    this.activeColor = const Color(0xFFCCFF00), // AppColors.neonLime
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = items.indexOf(selectedItem);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: GlassContainer(
          useOwnLayer: true,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(4),
          shape: const LiquidRoundedSuperellipse(borderRadius: 28),
          settings: resolveGlassDockSettings(isDark: isDark),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;

              return Stack(
                children: [
                  // Fluid Spring Active Pill
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: const Cubic(0.2, 0.9, 0.22, 1.0),
                    left: selectedIndex * itemWidth,
                    width: itemWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.38),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Interactive Items Row
                  Row(
                    children: items.map((item) {
                      final isSelected = item == selectedItem;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelected(item);
                          },
                          child: Center(
                            child: itemBuilder(item, isSelected),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

---

### B. Transforming a Card or Banner into a Liquid Glass Platter

```dart
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Material(
      type: MaterialType.transparency,
      child: GlassContainer(
        useOwnLayer: true,
        clipBehavior: Clip.antiAlias,
        padding: padding,
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
        settings: resolveGlassDockSettings(isDark: isDark),
        child: child,
      ),
    );

    if (onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: content,
    );
  }
}
```

---

### C. Transforming Action Buttons into Liquid Glass Icons (`GlassIconButton`)

```dart
class LiquidGlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? activeGlowColor;

  const LiquidGlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 46,
    this.iconSize = 22,
    this.iconColor,
    this.activeGlowColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              if (activeGlowColor != null)
                BoxShadow(
                  color: activeGlowColor!.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GlassContainer(
            useOwnLayer: true,
            clipBehavior: Clip.antiAlias,
            shape: LiquidRoundedSuperellipse(borderRadius: size / 2),
            settings: resolveGlassDockSettings(isDark: isDark),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? defaultColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 4. Checklist for Transformed Components

When converting any UI element:
- [ ] Uses `resolveGlassDockSettings(isDark: isDark)` (thickness 30, chromatic dispersion 0.3, refractiveIndex 1.59).
- [ ] Uses `LiquidRoundedSuperellipse` for smooth curvature.
- [ ] Wrapped in `Material(type: MaterialType.transparency)` with explicit `TextDecoration.none`.
- [ ] Contains multi-layer drop shadows for depth separation from background content.
- [ ] Uses spring curve `Cubic(0.2, 0.9, 0.22, 1.0)` with haptic feedback (`HapticFeedback.selectionClick()` / `HapticFeedback.lightImpact()`).
- [ ] Content inside stays crisp and opaque (no double glass nesting).
