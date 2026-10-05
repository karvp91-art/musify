import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';

/// Opens the Studio Equalizer full screen.
Future<void> openStudioEqualizerScreen(BuildContext context) {
  HapticFeedback.selectionClick();
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => const StudioEqualizerScreen(),
    ),
  );
}

/// Circular header button matching the top app bar actions
class _CircleHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  const _CircleHeaderButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor =
        isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: defaultIconColor,
        ),
      ),
    );
  }
}

class StudioEqualizerScreen extends ConsumerWidget {
  const StudioEqualizerScreen({super.key});

  void _showMoreMenu(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eqNotifier = ref.read(equalizerProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: Text(
                    'Reset Equalizer to Flat',
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop();
                    eqNotifier.resetToFlat();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.power_settings_new_rounded),
                  title: Text(
                    'Toggle Equalizer',
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop();
                    final current = ref.read(equalizerProvider).isEnabled;
                    eqNotifier.setEnabled(!current);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllPresetsModal(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eqState = ref.read(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All Presets',
                    style: AppTypography.headlineSmall.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: _allPresets.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final preset = _allPresets[index];
                        final isSelected = eqState.preset == preset.name;

                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          tileColor: isSelected
                              ? AppColors.neonLime.withValues(alpha: isDark ? 0.22 : 0.15)
                              : Colors.transparent,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isSelected
                                  ? AppColors.neonLime
                                  : (isDark ? const Color(0xFF181A22) : Colors.white),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              preset.icon,
                              size: 20,
                              color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          title: Text(
                            preset.label,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? AppColors.neonLime : const Color(0xFF367010))
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.neonLime)
                              : null,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            eqNotifier.setPreset(preset.name);
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);
    final activeGreenColor = isDark ? AppColors.neonLime : const Color(0xFF3E8016);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _CircleHeaderButton(
                    icon: Icons.chevron_left_rounded,
                    iconSize: 26,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Equalizer',
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  _CircleHeaderButton(
                    icon: Icons.more_vert_rounded,
                    iconSize: 22,
                    onTap: () => _showMoreMenu(context, ref),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // 1. Equalizer Header & Controls (Open Canvas - directly on background)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Equalizer',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Customize your sound frequencies',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Switch(
                          value: eqState.isEnabled,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.neonLime,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: isDark
                              ? const Color(0xFF2C2F3D)
                              : const Color(0xFFD6D9E0),
                          trackOutlineColor:
                              WidgetStateProperty.all(Colors.transparent),
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            eqNotifier.setEnabled(val);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 7 Vertical Band Sliders sitting directly on open canvas
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        final freq = index < EqualizerPresets.bandFrequencies.length
                            ? EqualizerPresets.bandFrequencies[index]
                            : 'Band ${index + 1}';
                        final gain = index < eqState.bandGains.length
                            ? eqState.bandGains[index]
                            : 0.0;

                        return _VerticalBandSlider(
                          label: freq,
                          gain: gain,
                          isEnabled: eqState.isEnabled,
                          isDark: isDark,
                          onChanged: (newGain) {
                            eqNotifier.setBandGain(index, newGain);
                          },
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Presets Section
                  Row(
                    children: [
                      Text(
                        'Presets',
                        style: AppTypography.headlineSmall.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showAllPresetsModal(context, ref),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'See all',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: activeGreenColor,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: activeGreenColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Horizontal Presets Row
                  SizedBox(
                    height: 94,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      itemCount: _horizontalPresets.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final preset = _horizontalPresets[index];
                        final isSelected = eqState.preset == preset.name;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            eqNotifier.setPreset(preset.name);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.neonLime
                                      : (isDark
                                          ? const Color(0xFF20222B)
                                          : const Color(0xFFF3F4F6)),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  preset.icon,
                                  size: 26,
                                  color: isSelected
                                      ? Colors.black
                                      : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF1E2028)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                preset.label,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 3. Audio Effect Section Header (Open Canvas)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio Enhancements',
                          style: AppTypography.headlineSmall.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fine-tune bass, spatial depth & loudness output',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Audio Effect Tiles with GlassSlider
                  _AudioEffectCard(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Bass Boost',
                    subtitle: 'Enhance low frequencies',
                    isEnabled: eqState.isEnabled,
                    isActive: eqState.bassBoost > 0.01,
                    sliderValue: eqState.bassBoost,
                    isDark: isDark,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      eqNotifier.setBassBoost(val ? 0.6 : 0.0);
                    },
                    onSliderChanged: (val) {
                      eqNotifier.setBassBoost(val);
                    },
                  ),
                  const SizedBox(height: 10),

                  _AudioEffectCard(
                    icon: Icons.surround_sound_rounded,
                    title: 'Virtualizer',
                    subtitle: 'Create a wider sound stage',
                    isEnabled: eqState.isEnabled,
                    isActive: eqState.virtualizer > 0.01,
                    sliderValue: eqState.virtualizer,
                    isDark: isDark,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      eqNotifier.setVirtualizer(val ? 0.6 : 0.0);
                    },
                    onSliderChanged: (val) {
                      eqNotifier.setVirtualizer(val);
                    },
                  ),
                  const SizedBox(height: 10),

                  _AudioEffectCard(
                    icon: Icons.flare_rounded,
                    title: 'Loudness',
                    subtitle: 'Boost overall volume',
                    isEnabled: eqState.isEnabled,
                    isActive: eqState.loudness > 0.01,
                    sliderValue: eqState.loudness,
                    isDark: isDark,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      eqNotifier.setLoudness(val ? 0.6 : 0.0);
                    },
                    onSliderChanged: (val) {
                      eqNotifier.setLoudness(val);
                    },
                  ),

                  // Bottom padding for mini-player
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),

        // Universal Floating Mini Player
        const FloatingMiniPlayer(),
      ],
    ),
  ),
);
  }
}

/// A single vertical band slider with top decibel readout, vertical GlassSlider track, and bottom frequency label
class _VerticalBandSlider extends StatelessWidget {
  final String label;
  final double gain;
  final bool isEnabled;
  final bool isDark;
  final ValueChanged<double> onChanged;

  const _VerticalBandSlider({
    required this.label,
    required this.gain,
    required this.isEnabled,
    required this.isDark,
    required this.onChanged,
  });

  String _formatGain(double val) {
    final rounded = val.round();
    if (rounded > 0) return '+$rounded';
    return '$rounded';
  }

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);
    final valueTextColor = isEnabled
        ? (isDark ? Colors.white : const Color(0xFF181A22))
        : (isDark ? Colors.white30 : Colors.black26);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top decibel readout (+4, +2, 0, -1, etc.)
        SizedBox(
          height: 20,
          child: Text(
            _formatGain(gain),
            style: AppTypography.style(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: valueTextColor,
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Vertical GlassSlider inside RotatedBox (quarterTurns: 3 so min is at bottom and max is at top)
        SizedBox(
          height: 175,
          width: 36,
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                width: 170,
                child: GlassSlider(
                  value: gain.clamp(-10.0, 10.0),
                  min: -10.0,
                  max: 10.0,
                  divisions: 20,
                  activeColor: isEnabled
                      ? AppColors.neonLime
                      : (isDark ? Colors.white38 : Colors.black38),
                  thumbColor: isEnabled
                      ? AppColors.neonLime
                      : (isDark ? Colors.white54 : Colors.black45),
                  inactiveColor: isDark
                      ? const Color(0xFF282B38)
                      : const Color(0xFFE5E7EB),
                  glowColor: isEnabled
                      ? AppColors.neonLime.withValues(alpha: 0.45)
                      : Colors.transparent,
                  glowRadius: 2.0,
                  trackHeight: 4.0,
                  thumbRadius: 10.0,
                  useOwnLayer: true,
                  onChangeStart: (_) => HapticFeedback.selectionClick(),
                  onChanged: isEnabled
                      ? (val) {
                          onChanged(val.roundToDouble());
                        }
                      : null,
                  onChangeEnd: (_) => HapticFeedback.lightImpact(),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Bottom frequency label (60Hz, 150Hz, etc.)
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isEnabled ? textMuted : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ],
    );
  }
}

/// A card for Audio Enhancements (Bass Boost, Virtualizer, Loudness) with optional GlassSlider fine-tuning
class _AudioEffectCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEnabled;
  final bool isActive;
  final bool isDark;
  final ValueChanged<bool> onChanged;
  final double? sliderValue;
  final ValueChanged<double>? onSliderChanged;

  const _AudioEffectCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
    required this.isActive,
    required this.isDark,
    required this.onChanged,
    this.sliderValue,
    this.onSliderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);

    final iconBg = isDark
        ? AppColors.neonLime.withValues(alpha: 0.18)
        : const Color(0xFFEFFCC8);
    final iconColor = isDark ? AppColors.neonLime : const Color(0xFF3E8016);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Squircle icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor,
                ),
              ),

              const SizedBox(width: 14),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Switch toggle
              Switch(
                value: isActive,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.neonLime,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: isDark
                    ? const Color(0xFF2C2F3D)
                    : const Color(0xFFD6D9E0),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                onChanged: isEnabled ? onChanged : null,
              ),
            ],
          ),

          // Liquid Glass Slider for fine-tuning when effect is active
          if (isActive && sliderValue != null && onSliderChanged != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GlassSlider(
                    value: sliderValue!.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    activeColor: AppColors.neonLime,
                    thumbColor: AppColors.neonLime,
                    inactiveColor: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : const Color(0xFFE2E4E9),
                    glowColor: AppColors.neonLime.withValues(alpha: 0.4),
                    glowRadius: 2.0,
                    trackHeight: 4.0,
                    thumbRadius: 9.0,
                    useOwnLayer: true,
                    onChangeStart: (_) => HapticFeedback.selectionClick(),
                    onChanged: onSliderChanged,
                    onChangeEnd: (_) => HapticFeedback.lightImpact(),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(sliderValue! * 100).round()}%',
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetItemData {
  final String name;
  final String label;
  final IconData icon;

  const _PresetItemData(this.name, this.label, this.icon);
}

final _horizontalPresets = [
  const _PresetItemData('Custom', 'Custom', Icons.tune_rounded),
  const _PresetItemData('Normal', 'Normal', Icons.equalizer_rounded),
  const _PresetItemData('Bass Boost', 'Bass Boost', Icons.volume_up_rounded),
  const _PresetItemData('Vocal', 'Vocal', Icons.person_outline_rounded),
  const _PresetItemData('Rock', 'Rock', Icons.electric_bolt_rounded),
  const _PresetItemData('Pop', 'Pop', Icons.music_note_rounded),
];

final _allPresets = [
  const _PresetItemData('Custom', 'Custom', Icons.tune_rounded),
  const _PresetItemData('Normal', 'Normal (Flat)', Icons.equalizer_rounded),
  const _PresetItemData('Bass Boost', 'Bass Boost', Icons.volume_up_rounded),
  const _PresetItemData('Vocal', 'Vocal', Icons.person_outline_rounded),
  const _PresetItemData('Rock', 'Rock', Icons.electric_bolt_rounded),
  const _PresetItemData('Pop', 'Pop', Icons.music_note_rounded),
  const _PresetItemData('Electronic', 'Electronic', Icons.album_outlined),
  const _PresetItemData('Hip-Hop', 'Hip-Hop', Icons.headphones_outlined),
  const _PresetItemData('Jazz', 'Jazz', Icons.nightlife_outlined),
  const _PresetItemData('Classical', 'Classical', Icons.piano_outlined),
  const _PresetItemData('Acoustic', 'Acoustic', Icons.queue_music_outlined),
];
