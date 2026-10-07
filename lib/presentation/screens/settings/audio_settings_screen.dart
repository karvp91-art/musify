import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/settings/backup_restore_screen.dart';
import 'package:musify/presentation/screens/settings/studio_equalizer_screen.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/theme_selection_bottom_sheet.dart';

/// Opens the Audio & Playback Settings screen with authentic iOS slide navigation.
Future<void> openAudioSettingsScreen(BuildContext context) {
  HapticFeedback.selectionClick();
  return Navigator.of(context).push<void>(
    CupertinoPageRoute(
      builder: (_) => const AudioSettingsScreen(),
    ),
  );
}

/// Borderless circular action button matching top header
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

class AudioSettingsScreen extends ConsumerWidget {
  const AudioSettingsScreen({super.key});

  static const List<(String id, String label, String description, String badge)> _qualityTiers = [
    (
      '320k',
      'Very High (320 kbps)',
      'Studio Master Fidelity • Pristine Dynamic Range',
      'STUDIO 320K',
    ),
    (
      '256k',
      'High (256 kbps)',
      'High-Definition Audio • Balanced Quality',
      'HD 256K',
    ),
    (
      '160k',
      'Standard (160 kbps)',
      'Fast Buffering • Moderate Data Usage',
      '160K',
    ),
    (
      '96k',
      'Data Saver (96 kbps)',
      'Ultra-Low Bandwidth for Mobile Networks',
      'SAVER 96K',
    ),
  ];

  void _showAudioQualityModal(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentQuality = ref.read(audioQualityProvider);
    final qualityNotifier = ref.read(audioQualityProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
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
                  'Streaming Audio Quality',
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sets the direct CDN streaming bitrate and dynamic range',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF8E92A0),
                  ),
                ),
                const SizedBox(height: 16),

                ..._qualityTiers.map((tier) {
                  final isSelected = currentQuality == tier.$1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
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
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 20,
                          color: isSelected
                              ? Colors.black
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      title: Text(
                        tier.$2,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? AppColors.neonLime : const Color(0xFF367010))
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        tier.$3,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : const Color(0xFF8E92A0),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? AppColors.neonLime.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.8))
                              : (isDark ? const Color(0xFF181A22) : const Color(0xFFDFE2E8)),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          tier.$4,
                          style: AppTypography.style(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? (isDark ? AppColors.neonLime : const Color(0xFF2C600B))
                                : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        qualityNotifier.setQuality(tier.$1);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);
    final crossfade = ref.watch(crossfadeProvider);
    final crossfadeNotifier = ref.read(crossfadeProvider.notifier);
    final isGapless = ref.watch(gaplessPlaybackProvider);
    final gaplessNotifier = ref.read(gaplessPlaybackProvider.notifier);
    final currentQuality = ref.watch(audioQualityProvider);
    final currentTheme = ref.watch(themePreferenceProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);
    final activeGreenColor = isDark ? AppColors.neonLime : const Color(0xFF3E8016);
    final iconBgColor = isDark
        ? AppColors.neonLime.withValues(alpha: 0.18)
        : const Color(0xFFEFFCC8);

    // Selected quality tuple
    final selectedQualityTier = _qualityTiers.firstWhere(
      (t) => t.$1 == currentQuality,
      orElse: () => _qualityTiers[0],
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top App Bar matching Studio Equalizer
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
                            'Settings',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      _CircleHeaderButton(
                        icon: currentTheme.icon,
                        iconSize: 20,
                        onTap: () => showThemeSelectionModal(context),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content (Open Canvas, Borderless, Unclosed Approach)
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // 1. STUDIO DSP EQUALIZER (Open Canvas)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Equalizer',
                                      style: AppTypography.headlineSmall.copyWith(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: iconBgColor,
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Text(
                                        eqState.isEnabled
                                            ? eqState.preset.toUpperCase()
                                            : 'OFF',
                                        style: AppTypography.style(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: activeGreenColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  eqState.isEnabled
                                      ? '7-band parametric curve & DSP active'
                                      : 'Hardware DSP bypassed • Tap to configure',
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

                      const SizedBox(height: 14),

                      // Mini frequency curve preview sitting directly on canvas
                      GestureDetector(
                        onTap: () => openStudioEqualizerScreen(context),
                        child: Container(
                          height: 76,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF13151F)
                                : const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CustomPaint(
                              painter: _MiniCurvePainter(
                                gains: eqState.bandGains,
                                isEnabled: eqState.isEnabled,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Workstation launcher link
                      GestureDetector(
                        onTap: () => openStudioEqualizerScreen(context),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Open Equalizer Workstation',
                                style: AppTypography.style(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: activeGreenColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: activeGreenColor,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 2. PLAYBACK & TRANSITIONS (Open Canvas)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Playback Transitions',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Zero-latency gapless handoff & continuous DJ crossfades',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Gapless Playback (Open Canvas Row)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: iconBgColor,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.all_inclusive_rounded,
                                color: activeGreenColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gapless Playback',
                                    style: AppTypography.headlineSmall.copyWith(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Zero-latency handoff between consecutive tracks',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 12,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isGapless,
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
                                gaplessNotifier.setEnabled(val);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Track Crossfade (Open Canvas Row & Glass Slider)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.swap_horiz_rounded,
                                    color: activeGreenColor,
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Track Crossfade',
                                        style: AppTypography.headlineSmall.copyWith(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        crossfade > 0
                                            ? 'Smoothly fades out song into the next'
                                            : '0s (Off • Gapless transitions active)',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontSize: 12,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    crossfade > 0 ? '${crossfade}s' : '0s OFF',
                                    style: AppTypography.style(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: activeGreenColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Liquid Glass Slider directly on open canvas
                            GlassSlider(
                              value: crossfade.toDouble().clamp(0.0, 10.0),
                              min: 0.0,
                              max: 10.0,
                              divisions: 10,
                              activeColor: AppColors.neonLime,
                              thumbColor: AppColors.neonLime,
                              inactiveColor: isDark
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : const Color(0xFFE2E4E9),
                              glowColor: crossfade > 0
                                  ? AppColors.neonLime.withValues(alpha: 0.45)
                                  : Colors.transparent,
                              glowRadius: 2.5,
                              trackHeight: 4.5,
                              thumbRadius: 10.0,
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
                                  Text(
                                    '0s (Off)',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                                  Text(
                                    '5s (DJ Continuous)',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                                  Text(
                                    '10s (Maximum)',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 3. AUDIO STREAMING QUALITY (Open Canvas)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Streaming Quality',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Direct CDN stream decryption and playback bitrate',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Open Canvas Bitrate Row
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showAudioQualityModal(context, ref),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: iconBgColor,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.high_quality_rounded,
                                  color: activeGreenColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Streaming Bitrate',
                                      style: AppTypography.headlineSmall.copyWith(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedQualityTier.$3,
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 12,
                                        color: textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: iconBgColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  selectedQualityTier.$4,
                                  style: AppTypography.style(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: activeGreenColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Quick Bitrate Segmented Selector sitting directly on canvas
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: _qualityTiers.map((tier) {
                            final isSelected = currentQuality == tier.$1;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(audioQualityProvider.notifier)
                                      .setQuality(tier.$1);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? activeGreenColor
                                        : (isDark
                                            ? const Color(0xFF20222B)
                                            : const Color(0xFFECEEF2)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    tier.$1.toUpperCase(),
                                    style: AppTypography.style(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? (isDark ? Colors.black : Colors.white)
                                          : (isDark ? Colors.white70 : const Color(0xFF374151)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 4. PREFERENCES & RESILIENCE (Open Canvas)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preferences & Resilience',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Look & feel theme and library backup state',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Appearance & Theme (Open Canvas Row)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showThemeSelectionModal(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: iconBgColor,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.palette_outlined,
                                  color: activeGreenColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Appearance & Theme',
                                      style: AppTypography.headlineSmall.copyWith(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentTheme.displayName,
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 12,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Backup & Restore Library (Open Canvas Row)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => openBackupRestoreScreen(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: iconBgColor,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.settings_backup_restore_rounded,
                                  color: activeGreenColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Backup & Restore Library',
                                      style: AppTypography.headlineSmall.copyWith(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Export & restore playlists, favorites & audio settings',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 12,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Clearance for floating mini player
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

class _MiniCurvePainter extends CustomPainter {
  final List<double> gains;
  final bool isEnabled;
  final bool isDark;

  _MiniCurvePainter({
    required this.gains,
    required this.isEnabled,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    if (gains.isEmpty) return;

    final count = gains.length;
    final points = <Offset>[];
    for (int i = 0; i < count; i++) {
      final x = count == 1
          ? size.width * 0.5
          : size.width * (0.08 + (i / (count - 1)) * 0.84);
      final gain = gains[i].clamp(-12.0, 12.0);
      final normalized = (gain / 12.0);
      final y = centerY - (normalized * (size.height * 0.38));
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(0, centerY);
    path.lineTo(points[0].dx * 0.4, (centerY + points[0].dy) / 2);
    path.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final last = points.last;
    path.lineTo(size.width - (size.width - last.dx) * 0.4, (last.dy + centerY) / 2);
    path.lineTo(size.width, centerY);

    // Gradient fill
    final fillPath = Path.from(path)
      ..lineTo(size.width, centerY)
      ..lineTo(0, centerY)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isEnabled
            ? [
                AppColors.neonLime.withValues(alpha: 0.28),
                AppColors.neonLime.withValues(alpha: 0.02),
              ]
            : [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.0),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = isEnabled
          ? AppColors.neonLime
          : (isDark ? Colors.white30 : Colors.black26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    for (final pt in points) {
      final pinPaint = Paint()
        ..color = isEnabled
            ? AppColors.neonLime
            : (isDark ? Colors.white60 : Colors.black38)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 2.5, pinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniCurvePainter oldDelegate) {
    return oldDelegate.isEnabled != isEnabled ||
        oldDelegate.isDark != isDark ||
        oldDelegate.gains != gains;
  }
}
