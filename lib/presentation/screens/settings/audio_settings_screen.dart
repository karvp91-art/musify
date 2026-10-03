import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/settings/studio_equalizer_screen.dart';
import 'package:musify/presentation/widgets/theme_selection_bottom_sheet.dart';

/// Opens the Audio & Playback Settings screen.
Future<void> openAudioSettingsScreen(BuildContext context) {
  HapticFeedback.selectionClick();
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => const AudioSettingsScreen(),
    ),
  );
}

/// Borderless circular action button matching HomeScreen top header
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor =
        isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);
    final crossfade = ref.watch(crossfadeProvider);
    final crossfadeNotifier = ref.read(crossfadeProvider.notifier);
    final isGapless = ref.watch(gaplessPlaybackProvider);
    final gaplessNotifier = ref.read(gaplessPlaybackProvider.notifier);
    final currentQuality = ref.watch(audioQualityProvider);
    final qualityNotifier = ref.read(audioQualityProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = theme.scaffoldBackgroundColor;
    final cardBg = isDark ? const Color(0xFF14161F) : const Color(0xFFF5F6F9);
    final textMuted = isDark ? Colors.white54 : Colors.black45;
    final accentTextColor = isDark ? AppColors.neonLime : AppColors.limeAccentDark;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Header with borderless buttons matching HomeScreen
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _GlassCircleButton(
                    icon: Icons.chevron_left_rounded,
                    iconSize: 22,
                    onTap: () => Navigator.of(context).pop(),
                  ),

                  const SizedBox(width: 14),

                  // Title & Subtitle with AppTypography
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio & Playback',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Equalizer, gapless playback & audio quality',
                          style: AppTypography.caption.copyWith(
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right: Theme switcher button matching HomeScreen
                  _GlassCircleButton(
                    icon: ref.watch(themePreferenceProvider).icon,
                    iconSize: 20,
                    onTap: () => showThemeSelectionModal(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Scrollable Settings Content (Borderless & Minimal)
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                children: [
                  // 1. Studio Equalizer Hero Workstation Card
                  _SectionHeader(title: 'STUDIO DSP EQUALIZER', textMuted: textMuted),
                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: () {
                      openStudioEqualizerScreen(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: eqState.isEnabled
                                      ? accentTextColor.withValues(alpha: isDark ? 0.15 : 0.12)
                                      : (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2)),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: eqState.isEnabled ? accentTextColor : textMuted,
                                  size: 24,
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
                                          style: AppTypography.bodyLarge.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: eqState.isEnabled
                                                ? accentTextColor.withValues(alpha: isDark ? 0.2 : 0.12)
                                                : (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            eqState.isEnabled ? eqState.preset : 'OFF',
                                            style: AppTypography.style(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: eqState.isEnabled ? accentTextColor : textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      eqState.isEnabled
                                          ? '5-band parametric curve & bass boost active'
                                          : 'Hardware DSP Bypassed • Tap to configure',
                                      style: AppTypography.caption.copyWith(
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: eqState.isEnabled,
                                activeTrackColor: AppColors.neonLime.withValues(alpha: 0.4),
                                activeThumbColor: AppColors.neonLime,
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  eqNotifier.setEnabled(val);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Mini dynamic frequency curve preview (Borderless)
                          Container(
                            height: 75,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0C0E15) : const Color(0xFFECEEF2),
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

                          const SizedBox(height: 14),

                          // Open Equalizer Action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Open Equalizer Workstation',
                                style: AppTypography.style(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: accentTextColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: accentTextColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Playback Transitions Section
                  _SectionHeader(title: 'PLAYBACK TRANSITIONS', textMuted: textMuted),
                  const SizedBox(height: 10),

                  // Gapless Playback Card (Borderless)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isGapless
                                ? accentTextColor.withValues(alpha: isDark ? 0.15 : 0.12)
                                : (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.all_inclusive_rounded,
                            color: isGapless ? accentTextColor : textMuted,
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
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Pre-buffers incoming songs for zero-latency handoff without silent pauses. Crucial for live concert recordings, concept albums, and continuous DJ sets.',
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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

                  const SizedBox(height: 14),

                  // Crossfade Duration Slider Card (Borderless)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: crossfade > 0
                                    ? accentTextColor.withValues(alpha: isDark ? 0.15 : 0.12)
                                    : (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.swap_horiz_rounded,
                                color: crossfade > 0 ? accentTextColor : textMuted,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Track Crossfade',
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    crossfade > 0
                                        ? 'Smoothly fades track A into track B'
                                        : '0s (Off • Gapless transitions active)',
                                    style: AppTypography.caption.copyWith(
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: crossfade > 0
                                    ? accentTextColor.withValues(alpha: isDark ? 0.18 : 0.12)
                                    : (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                crossfade > 0 ? '${crossfade}s' : '0s (Off)',
                                style: AppTypography.style(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: crossfade > 0
                                      ? accentTextColor
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Liquid Glass Slider
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
                              Text('0s (Off)', style: AppTypography.caption.copyWith(fontSize: 11, color: textMuted)),
                              Text('5s (Continuous DJ)', style: AppTypography.caption.copyWith(fontSize: 11, color: textMuted)),
                              Text('10s (Maximum)', style: AppTypography.caption.copyWith(fontSize: 11, color: textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Audio Streaming Quality (Borderless Cards)
                  _SectionHeader(title: 'AUDIO STREAMING QUALITY', textMuted: textMuted),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Default Streaming Bitrate',
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Direct CDN stream decryption and playback bitrate',
                          style: AppTypography.caption.copyWith(
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),

                        ...[
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
                        ].map((tier) {
                          final isSelected = currentQuality == tier.$1;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              qualityNotifier.setQuality(tier.$1);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.neonLime.withValues(alpha: 0.12)
                                    : (isDark ? const Color(0xFF1B1D27) : const Color(0xFFECEEF2)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    size: 20,
                                    color: isSelected ? accentTextColor : textMuted,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tier.$2,
                                          style: AppTypography.style(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected
                                                ? accentTextColor
                                                : (isDark ? Colors.white : Colors.black87),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tier.$3,
                                          style: AppTypography.caption.copyWith(
                                            color: textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? accentTextColor.withValues(alpha: isDark ? 0.22 : 0.12)
                                          : (isDark ? const Color(0xFF20222B) : const Color(0xFFDFE2E8)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tier.$4,
                                      style: AppTypography.style(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? accentTextColor : textMuted,
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

                  const SizedBox(height: 24),

                  // 4. Appearance & Theme Link Card (Borderless)
                  _SectionHeader(title: 'LOOK & FEEL', textMuted: textMuted),
                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: () {
                      showThemeSelectionModal(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF222C1D) : const Color(0xFFDFEDE0),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.palette_outlined,
                              color: accentTextColor,
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
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dark mode, AMOLED black, and auto time schedule',
                                  style: AppTypography.caption.copyWith(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color textMuted;

  const _SectionHeader({required this.title, required this.textMuted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: AppTypography.style(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: textMuted,
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

    if (gains.length < 5) return;

    final xCoords = [
      size.width * 0.10,
      size.width * 0.30,
      size.width * 0.50,
      size.width * 0.70,
      size.width * 0.90,
    ];

    final points = <Offset>[];
    for (int i = 0; i < 5; i++) {
      final gain = gains[i].clamp(-12.0, 12.0);
      final normalized = (gain / 12.0);
      final y = centerY - (normalized * (size.height * 0.38));
      points.add(Offset(xCoords[i], y));
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
      ..color = isEnabled ? AppColors.neonLime : (isDark ? Colors.white30 : Colors.black26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    for (final pt in points) {
      final pinPaint = Paint()
        ..color = isEnabled ? AppColors.neonLime : (isDark ? Colors.white60 : Colors.black38)
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
