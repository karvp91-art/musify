import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/studio_equalizer_modal.dart';
import 'package:musify/presentation/widgets/theme_selection_bottom_sheet.dart';

import 'package:musify/presentation/screens/settings/audio_settings_screen.dart';

/// Opens the unified Settings & Audio Preferences screen.
Future<void> showAppSettingsModal(BuildContext context, {int initialTab = 0}) {
  return openAudioSettingsScreen(context);
}

class AppSettingsModal extends ConsumerStatefulWidget {
  final int initialTab;

  const AppSettingsModal({super.key, this.initialTab = 0});

  @override
  ConsumerState<AppSettingsModal> createState() => _AppSettingsModalState();
}

class _AppSettingsModalState extends ConsumerState<AppSettingsModal> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    final bgColor = isDark ? const Color(0xFF13141B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB);
    final textMuted = isDark ? Colors.white54 : Colors.black45;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.fromLTRB(12, 0, 12, math.max(paddingBottom, 12)),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row: Title & Tab Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SETTINGS & AUDIO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedTab == 0
                            ? 'DSP equalizer, gapless playback & quality'
                            : 'App appearance & daylight schedule',
                        style: TextStyle(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Segmented Tab Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1D27) : const Color(0xFFEFF1F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF282D3D) : const Color(0xFFE2E5EB),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      title: 'Audio & DSP',
                      icon: Icons.graphic_eq_rounded,
                      isSelected: _selectedTab == 0,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = 0);
                      },
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      title: 'Appearance',
                      icon: Icons.palette_outlined,
                      isSelected: _selectedTab == 1,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = 1);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Tab Content
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _selectedTab == 0
                  ? const _AudioSettingsView()
                  : const _AppearanceSettingsView(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2B3042) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.neonLime
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Audio & DSP Settings Tab
class _AudioSettingsView extends ConsumerWidget {
  const _AudioSettingsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);
    final crossfade = ref.watch(crossfadeProvider);
    final crossfadeNotifier = ref.read(crossfadeProvider.notifier);
    final isGapless = ref.watch(gaplessPlaybackProvider);
    final gaplessNotifier = ref.read(gaplessPlaybackProvider.notifier);
    final currentQuality = ref.watch(audioQualityProvider);
    final qualityNotifier = ref.read(audioQualityProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF181A23) : const Color(0xFFF7F8FA);
    final borderColor = isDark ? const Color(0xFF262A37) : const Color(0xFFE5E7EB);
    final textMuted = isDark ? Colors.white54 : Colors.black45;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        // 1. Studio Equalizer Card
        GestureDetector(
          onTap: () {
            showStudioEqualizerModal(context);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: eqState.isEnabled
                    ? AppColors.neonLime.withValues(alpha: 0.35)
                    : borderColor,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: eqState.isEnabled
                        ? AppColors.neonLime.withValues(alpha: 0.15)
                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: eqState.isEnabled ? AppColors.neonLime : textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Studio Equalizer',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (eqState.isEnabled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.neonLime.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                eqState.preset,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neonLime,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        eqState.isEnabled
                            ? '5-band parametric curve & bass boost active'
                            : 'Hardware DSP bypassed • Tap to configure',
                        style: TextStyle(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262A38) : const Color(0xFFE9ECF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Tune',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Gapless Playback Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isGapless
                      ? AppColors.neonLime.withValues(alpha: 0.15)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.all_inclusive_rounded,
                  color: isGapless ? AppColors.neonLime : textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gapless Playback',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pre-buffers next track for zero-gap transitions between songs',
                      style: TextStyle(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isGapless,
                activeTrackColor: AppColors.neonLime.withValues(alpha: 0.4),
                activeThumbColor: AppColors.neonLime,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  gaplessNotifier.setEnabled(val);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Track Crossfade Slider (0s to 10s)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: crossfade > 0
                          ? AppColors.neonLime.withValues(alpha: 0.15)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: crossfade > 0 ? AppColors.neonLime : textMuted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track Crossfade',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          crossfade > 0
                              ? 'Fades track A into track B smoothly'
                              : 'Off (Instant or Gapless playback)',
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: crossfade > 0
                          ? AppColors.neonLime.withValues(alpha: 0.15)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: crossfade > 0
                            ? AppColors.neonLime.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      crossfade > 0 ? '${crossfade}s' : '0s (Off)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: crossfade > 0
                            ? AppColors.neonLime
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Liquid Glass Slider for Crossfade
              GlassSlider(
                value: crossfade.toDouble().clamp(0.0, 10.0),
                min: 0.0,
                max: 10.0,
                divisions: 10,
                activeColor: AppColors.neonLime,
                thumbColor: AppColors.neonLime,
                inactiveColor: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                glowColor: crossfade > 0
                    ? AppColors.neonLime.withValues(alpha: 0.45)
                    : Colors.transparent,
                glowRadius: 2.5,
                useOwnLayer: true,
                onChangeStart: (_) => HapticFeedback.selectionClick(),
                onChanged: (val) {
                  crossfadeNotifier.setDuration(val.round());
                },
                onChangeEnd: (_) => HapticFeedback.lightImpact(),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0s (Off)', style: TextStyle(fontSize: 10, color: textMuted)),
                    Text('5s (Balanced)', style: TextStyle(fontSize: 10, color: textMuted)),
                    Text('10s (Max DJ)', style: TextStyle(fontSize: 10, color: textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. Audio Streaming Quality Selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.neonLime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.high_quality_rounded,
                      color: AppColors.neonLime,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Streaming Audio Quality',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sets direct stream bitrate and dynamic range',
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              ...[
                ('320k', 'Very High (320 kbps)', 'Studio Master Fidelity • Direct DDL'),
                ('256k', 'High (256 kbps)', 'High-Definition Audio • Balanced'),
                ('160k', 'Standard (160 kbps)', 'Fast Buffering • Moderate Data Usage'),
                ('96k', 'Data Saver (96 kbps)', 'Ultra-Low Bandwidth for Mobile Networks'),
              ].map((tier) {
                final isSelected = currentQuality == tier.$1;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    qualityNotifier.setQuality(tier.$1);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonLime.withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF202330) : const Color(0xFFEFF1F5)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.neonLime
                            : (isDark ? const Color(0xFF2D3244) : const Color(0xFFDFE2E8)),
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 18,
                          color: isSelected ? AppColors.neonLime : textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tier.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                tier.$3,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (tier.$1 == '320k')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neonLime.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'STUDIO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.neonLime,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

/// Appearance Settings Tab (delegates to ThemeSelectionBottomSheet layout)
class _AppearanceSettingsView extends StatelessWidget {
  const _AppearanceSettingsView();

  @override
  Widget build(BuildContext context) {
    return const ThemeSelectionBottomSheet();
  }
}
