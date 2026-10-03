---
name: mini-player-glass-ui
description: "Architects and transforms Flutter UI components into floating liquid glass media player platters, featuring crystal-clear low-blur shader optics, spinning vinyl records with turntable grooves, phase-shifted 3-bar dancing equalizers, continuous train marquee text, gesture-driven dismiss actions (skip/like), and isolated reactive rebuild architecture modeled after MiniPlayer."
---

# MiniPlayer Glass UI — Component Architecture & Replication Guide

This skill provides the architectural specifications, mathematical formulas, optical shader recipes, physics curves, and drop-in code templates to construct or transform any Flutter component into a **MiniPlayer-grade floating Liquid Glass platter**.

---

## 1. Core Optical DNA of MiniPlayer

MiniPlayer achieves its lustrous, ultra-sharp refractive appearance by adhering to the following rules:

### A. Low-Blur Refractive Shader Formula
Rather than a cloudy, milky frosted look, MiniPlayer uses an ultra-low blur of `3.0`. This allows background content (album art, text, list items) to refract cleanly through the glass surface with chromatic dispersion along curved borders.

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

LiquidGlassSettings resolveMiniPlayerGlassSettings({required bool isDark}) {
  return isDark
      ? const LiquidGlassSettings(
          thickness: 30.0,             // Deep optical depth
          blur: 3.0,                  // Ultra-low blur preserves background sharpness
          chromaticAberration: 0.30,  // Spectral prism edges
          lightIntensity: 0.65,       // Crisp rim highlights
          ambientStrength: 1.0,
          refractiveIndex: 1.59,      // Polycarbonate optical refraction
          saturation: 0.70,
          lightAngle: 0.75 * math.pi, // 135° Apple standard upper-left key light
          glassColor: Color(0x2EFFFFFF),
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
          glassColor: Color(0x24FFFFFF), // Luminous sheer white tint
          specularSharpness: GlassSpecularSharpness.medium,
        );
}
```

### B. No Hard Stroke Outlines
**Rule:** NEVER place a hard `Border.all(...)` on the outer container of the glass platter.
Hard strokes cut off the mathematical specular rim calculated by `LiquidGlassSettings`. Instead, wrap the `GlassContainer` with an ambient diffuse drop shadow:

```dart
Container(
  constraints: const BoxConstraints(minHeight: 78),
  margin: const EdgeInsets.symmetric(horizontal: 10),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(28),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  ),
  child: GlassContainer(
    useOwnLayer: true,
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    shape: const LiquidRoundedSuperellipse(borderRadius: 28),
    settings: resolveMiniPlayerGlassSettings(isDark: isDark),
    child: ...,
  ),
)
```

### C. Eliminating Muddiness: Sheer White "Lens" Tint vs. Flat Grey Fills
When embedding nested input bars, triggers, badges, or chips inside a glass platter:
1. **Never use flat black/grey fills:** Painting `Colors.black.withValues(alpha: 0.05)` over low-blur glass multiplies a dull grey film over the shader's specular rim and refractive calculations, making the platter look dirty or washed out.
2. **Use sheer white "lens" tint gradients:** For pill triggers, search bars, and logo badges, apply a sheer white vertical gradient:
```dart
gradient: LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: isDark
      ? [
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.06),
        ]
      : [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.30),
        ],
),
```
This brightens the inner surface and preserves optical refraction without adding grey murkiness.
3. **Circular Action Orbs:** Standardize on MiniPlayer's skip button alpha values:
```dart
color: isDark
    ? Colors.white.withValues(alpha: 0.12)
    : Colors.black.withValues(alpha: 0.06),
```
4. **Never nest glass on glass:** A `GlassContainer` should never sit inside another `GlassContainer` or `BackdropFilter` layer, as the parent blur layer flattens the inner glass's specular highlights and chromatic dispersion.
5. **Background Refraction Contrast:** Glass over a pure white (`#FFFFFF`) screen has nothing to refract. Slightly tinting the scaffold (e.g. `Color(0xFFF8F9FA)`) or ensuring content scrolls underneath allows the Impeller shader to bend background elements naturally.

---

## 2. Interactive Control Hierarchy

Inside the `GlassContainer`, layout elements in a single horizontal `Row`:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ [Spinning Vinyl]  [ Marquee Title Text                   ]  (Play)  (Skip) │
│   48x48 record    [ ılı Equalizer + Artist               ]  42x42   38x38  │
│                   [ ━━━━━━━ Progress Bar & Timestamps ━━ ]  Lime    Circle │
└─────────────────────────────────────────────────────────────────────────────┘
```

### A. Spinning Turntable Vinyl Record (`48x48`)
Wrapped in a `RepaintBoundary` to prevent canvas repainting of the rest of the UI while the record spins:

```dart
Widget buildVinylArtwork({
  required AnimationController vinylController,
  required String? artworkUrl,
  required String seedKey,
  required bool isDark,
  required Color accentColor,
  double size = 48.0,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.20),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: RepaintBoundary(
      child: RotationTransition(
        turns: vinylController, // 14-second repeating linear controller
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Base Album Artwork / Seeded Gradient
            TrackArtwork(
              artworkUrl: artworkUrl,
              seedKey: seedKey,
              size: size,
              isCircle: true,
              ambientGlow: false,
            ),
            // 2. Outer Vinyl Groove Rim
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                  width: 1.0,
                ),
              ),
            ),
            // 3. Inner Vinyl Groove Ring (70% proportion)
            Container(
              width: size * 0.70,
              height: size * 0.70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                  width: 0.8,
                ),
              ),
            ),
            // 4. Center Spindle Hole Punch (16% proportion, 4.5% center hole)
            Container(
              width: size * 0.16,
              height: size * 0.16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.black : Colors.white,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.7),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Container(
                  width: size * 0.045,
                  height: size * 0.045,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.black : const Color(0xFF20222B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

---

### B. Dancing 3-Bar Sinusoidal Equalizer
Uses phase-shifted trigonometric sine functions across a 1.0-second repeating animation loop:

```dart
class MiniEqualizerBars extends StatelessWidget {
  final Animation<double> animation;
  final bool isPlaying;
  final Color color;

  const MiniEqualizerBars({
    super.key,
    required this.animation,
    required this.isPlaying,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPlaying) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBar(4.0),
          const SizedBox(width: 2.0),
          _buildBar(4.0),
          const SizedBox(width: 2.0),
          _buildBar(4.0),
        ],
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final h1 = 3.5 + 7.5 * ((math.sin(t * 2 * math.pi) + 1) / 2);
        final h2 = 4.0 + 8.5 * ((math.sin((t + 0.35) * 2 * math.pi) + 1) / 2);
        final h3 = 3.0 + 6.5 * ((math.sin((t + 0.70) * 2 * math.pi) + 1) / 2);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(h1),
            const SizedBox(width: 2.0),
            _buildBar(h2),
            const SizedBox(width: 2.0),
            _buildBar(h3),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.2,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
```

---

### C. Continuous Train Marquee Title Text
Measures the intrinsic text width using `TextPainter`. If the text fits, it renders statically. If it exceeds available width, it scrolls continuously at a comfortable `28 px/s` velocity:

```dart
class TrainMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool isPlaying;

  const TrainMarqueeText({
    super.key,
    required this.text,
    required this.style,
    required this.isPlaying,
  });

  @override
  State<TrainMarqueeText> createState() => _TrainMarqueeTextState();
}

class _TrainMarqueeTextState extends State<TrainMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0.0;
  double _textHeight = 18.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  }

  void _calculateDimensions([TextScaler textScaler = TextScaler.noScaling]) {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    _textWidth = textPainter.width;
    _textHeight = textPainter.height > 0 ? textPainter.height : 16.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _calculateDimensions(MediaQuery.textScalerOf(context));

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        if (_textWidth <= availableWidth) {
          if (_controller.isAnimating) _controller.stop();
          return Text(widget.text, style: widget.style, maxLines: 1, overflow: TextOverflow.ellipsis);
        }

        final gap = math.max(32.0, availableWidth - 0.25 * _textWidth);
        final cycleDistance = _textWidth + gap;
        final durationMs = ((cycleDistance / 28.0) * 1000).round().clamp(2000, 30000);
        _controller.duration = Duration(milliseconds: durationMs);

        if (widget.isPlaying && !_controller.isAnimating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.isPlaying && !_controller.isAnimating) {
              _controller.repeat();
            }
          });
        } else if (!widget.isPlaying && _controller.isAnimating) {
          _controller.stop();
        }

        return SizedBox(
          height: _textHeight,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset = _controller.value * cycleDistance;
                return OverflowBox(
                  minWidth: 0.0,
                  maxWidth: double.infinity,
                  minHeight: _textHeight,
                  maxHeight: _textHeight,
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(-offset, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                        SizedBox(width: gap),
                        Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                        SizedBox(width: gap),
                        Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
```

---

### D. Isolated Progress Line & Micro-Timestamps
**Rule:** Build the progress line in an isolated widget that listens to stream position updates independently. This prevents position ticks (every 200–500ms) from rebuilding the outer glass shader, vinyl, or buttons.

```dart
class MiniPlayerProgressSection extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Color accentColor;
  final Color textColor;
  final Color inactiveColor;

  const MiniPlayerProgressSection({
    super.key,
    required this.position,
    required this.duration,
    required this.accentColor,
    required this.textColor,
    required this.inactiveColor,
  });

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final double progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            return Stack(
              children: [
                // Inactive Track
                Container(
                  height: 2.5,
                  width: barWidth,
                  decoration: BoxDecoration(
                    color: inactiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Active Glowing Track
                Container(
                  height: 2.5,
                  width: (barWidth * progress).clamp(0.0, barWidth),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_format(position), style: TextStyle(fontSize: 9.5, height: 1.1, fontWeight: FontWeight.w600, color: textColor, decoration: TextDecoration.none)),
            Text(_format(duration), style: TextStyle(fontSize: 9.5, height: 1.1, fontWeight: FontWeight.w600, color: textColor, decoration: TextDecoration.none)),
          ],
        ),
      ],
    );
  }
}
```

---

### E. High-Contrast Action Orbs

```dart
// 1. Play / Pause Hero Button (42x42 Vibrant Neon Lime circle with glow shadow)
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: onPlayPause,
  child: Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.neonLime,
      boxShadow: [
        BoxShadow(
          color: AppColors.neonLime.withValues(alpha: isDark ? 0.35 : 0.45),
          blurRadius: 10,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 24,
      color: Colors.black,
    ),
  ),
),

// 2. Skip Button (38x38 Tinted frosted circular orb)
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: onSkip,
  child: Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.06),
    ),
    child: Icon(
      Icons.skip_next_rounded,
      size: 20,
      color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
    ),
  ),
),
```

---

## 3. Gestures & Navigation Engine

Wrap the player in a `Dismissible` with horizontal haptics and an upward vertical drag listener:

```dart
Dismissible(
  key: ValueKey('mini_player_${track.id}'),
  direction: DismissDirection.horizontal,
  confirmDismiss: (direction) async {
    if (direction == DismissDirection.endToStart) {
      // Right-to-Left: Skip to next track
      HapticFeedback.lightImpact();
      await audioHandler.skipToNext();
    } else if (direction == DismissDirection.startToEnd) {
      // Left-to-Right: Toggle like/favorite
      HapticFeedback.mediumImpact();
      await repository.toggleLike(track);
    }
    return false; // Always springs back smoothly
  },
  child: GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onExpand(); // Slides open full now playing screen
    },
    onVerticalDragEnd: (details) {
      // Upward flick expands player
      if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
        HapticFeedback.selectionClick();
        onExpand();
      }
    },
    child: ...,
  ),
)
```

---

## 4. Universal Defensive Layout Rules

### 1. Typography Protection with `Material(type: MaterialType.transparency)`
Whenever rendering floating glass overlays, platters, or HUDs, **always** wrap the container in `Material(type: MaterialType.transparency, child: ...)` and set `decoration: TextDecoration.none` on all text styles.

#### Why `MaterialType.transparency` is Essential:
1. **Prevents the "Yellow Double Underlines" Bug:**
   In Flutter, when text is rendered outside a standard `Scaffold` body (such as inside a floating `Stack`, `Overlay`, or custom shader layer), Flutter lacks an ambient `DefaultTextStyle`. It falls back to its raw debug style: **red text with double yellow underlines**. Wrapping the platter in `Material` provides the necessary text theme context.
2. **Protects the Liquid Glass Shader from Being Obscured:**
   A standard `Material()` widget defaults to `MaterialType.canvas`, which paints a solid opaque surface color (white or dark grey). This destroys the refraction and blur of `GlassContainer`. `MaterialType.transparency` paints **0% background fill** (completely transparent), allowing the refractive shader to render cleanly.
3. **Hosts Material Ink Splashes & Ripples:**
   Interactive children using `InkWell`, `IconButton`, or `InkResponse` require an ancestor `Material` to host their ripple animation canvas. `MaterialType.transparency` provides that canvas without adding background color.

#### Material Type Comparison:
| Material Type | Background Painted? | Elevation Shadow? | Use Case |
| :--- | :--- | :--- | :--- |
| `MaterialType.canvas` *(default)* | Yes (Theme background) | Yes (if elevation > 0) | Full page screens, standard cards |
| `MaterialType.card` | Yes (Theme card color) | Yes | Traditional solid cards |
| **`MaterialType.transparency`** | **No (0% opacity)** | **No** | **Glass UI, floating HUDs, custom shaders, transparent overlays** |

---

### 2. Text Scaling Clamping
Always wrap with `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.15, child: ...)` to prevent large accessibility font settings from pushing action buttons off-screen or causing `RenderFlex` overflows.

```dart
return MediaQuery.withClampedTextScaling(
  maxScaleFactor: 1.15,
  child: Dismissible(
    ...
  ),
);
```

---

### 3. Contrast & Typography Standards
- **In Light Mode:** Titles use `const Color(0xFF111827)`, subtitles `const Color(0xFF111827).withValues(alpha: 0.65)`, icon controls `Colors.black87`.
- **In Dark Mode:** Titles use `Colors.white`, subtitles `Colors.white.withValues(alpha: 0.70)`, icon controls `Colors.white.withValues(alpha: 0.85)`.
- **Line Heights:** Always enforce `height: 1.15` - `1.2` on title and artist text to prevent vertical expansion and bounds overflow.

