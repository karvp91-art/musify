import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

/// A modern, state-of-the-art Floating Glass Island Capsule (Dynamic Dock)
/// built using [liquid_glass_widgets].
///
/// Replaces the legacy full-width bottom navigation bar with a floating,
/// interactive glass stadium capsule featuring:
/// - Real-time optical liquid glass refraction, specular rim, and blur
/// - Fluid spring-animated active indicator pill with neon-lime accent
/// - Real-time playback dynamics (subtle equalizer pulse when music is playing)
/// - Pure AMOLED black backdrop contrast
/// - Instant haptic selection feedback
class FloatingGlassDock extends ConsumerStatefulWidget {
  final int activeIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingGlassDock({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
  });

  @override
  ConsumerState<FloatingGlassDock> createState() => _FloatingGlassDockState();
}

class _FloatingGlassDockState extends ConsumerState<FloatingGlassDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPlaying = ref.watch(isPlaybackPlayingProvider);

    // Liquid Glass settings calibrated for the floating dock
    final glassSettings = isDark
        ? const LiquidGlassSettings(
            glassColor: Color(0x181F222B),
            saturation: 1.5,
            blur: 16.0,
            blurWeight: 1.6,
            frost: 12.0,
            frostOpacity: 0.8,
            thickness: 28.0,
            refractiveIndex: 1.24,
            rimLight: 1.25,
            rimShade: 0.4,
            specularSharpness: GlassSpecularSharpness.sharp,
            shadowElevation: 3.0,
          )
        : const LiquidGlassSettings(
            glassColor: Color(0x75FFFFFF),
            saturation: 1.8,
            blur: 14.0,
            blurWeight: 1.2,
            frost: 8.0,
            frostOpacity: 0.65,
            thickness: 24.0,
            refractiveIndex: 1.20,
            rimLight: 1.0,
            rimShade: 0.25,
            specularSharpness: GlassSpecularSharpness.medium,
            shadowElevation: 3.0,
          );

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                if (isDark)
                  BoxShadow(
                    color: const Color(0xFF262A36).withValues(alpha: 0.35),
                    blurRadius: 1,
                    spreadRadius: 1,
                    offset: Offset.zero,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: GlassContainer(
                useOwnLayer: true,
                padding: const EdgeInsets.all(5),
                shape: const LiquidRoundedSuperellipse(borderRadius: 30),
                settings: glassSettings,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 2) / 2;
                    final isTab0 = widget.activeIndex == 0;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Fluid Sliding Active Indicator Pill
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: const Cubic(0.2, 0.9, 0.22, 1.0),
                          left: isTab0 ? 0 : itemWidth,
                          width: itemWidth,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.neonLime,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.neonLime.withValues(alpha: 0.38),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Interactive Tab Items Row
                        Row(
                          children: [
                            // Tab 0: "My music"
                            Expanded(
                              child: _DockItem(
                                label: 'My music',
                                activeIcon: Icons.headphones_rounded,
                                inactiveIcon: Icons.headphones_outlined,
                                isSelected: isTab0,
                                isPlaying: isPlaying,
                                pulseAnimation: _pulseController,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  widget.onTabSelected(0);
                                },
                              ),
                            ),

                            // Tab 1: "Stream"
                            Expanded(
                              child: _DockItem(
                                label: 'Stream',
                                activeIcon: Icons.play_circle_fill_rounded,
                                inactiveIcon: Icons.play_circle_outline_rounded,
                                isSelected: !isTab0,
                                isPlaying: false,
                                pulseAnimation: _pulseController,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  widget.onTabSelected(1);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final bool isPlaying;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  const _DockItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.isPlaying,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedTextColor = const Color(0xFF111827);
    final unselectedTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : const Color(0xFF555B6E);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with active transition
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              size: 20,
              color: isSelected ? selectedTextColor : unselectedTextColor,
            ),
            const SizedBox(width: 8),

            // Text Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? selectedTextColor : unselectedTextColor,
                letterSpacing: -0.2,
              ),
              child: Text(label),
            ),

            // Dynamic Equalizer Pulse Dot when music is playing on My Music tab
            if (isPlaying && label == 'My music') ...[
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFF111827)
                          : (isDark ? AppColors.neonLime : AppColors.limeAccentDark),
                      boxShadow: [
                        BoxShadow(
                          color: (isSelected ? const Color(0xFF111827) : AppColors.neonLime)
                              .withValues(alpha: 0.3 + (pulseAnimation.value * 0.4)),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
