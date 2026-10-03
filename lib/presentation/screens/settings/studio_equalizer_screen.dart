import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

/// Opens the Studio Equalizer full screen.
Future<void> openStudioEqualizerScreen(BuildContext context) {
  HapticFeedback.selectionClick();
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => const StudioEqualizerScreen(),
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

class StudioEqualizerScreen extends ConsumerWidget {
  const StudioEqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);
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
                        Row(
                          children: [
                            Text(
                              'Equalizer',
                              style: AppTypography.headlineSmall.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: eqState.isEnabled
                                    ? accentTextColor.withValues(alpha: isDark ? 0.18 : 0.12)
                                    : (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PRO DSP',
                                style: AppTypography.style(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: eqState.isEnabled ? accentTextColor : textMuted,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          eqState.isEnabled
                              ? '5-band parametric curve • Active'
                              : 'Hardware DSP Bypassed',
                          style: AppTypography.caption.copyWith(
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Master DSP Power Switch
                  Switch.adaptive(
                    value: eqState.isEnabled,
                    activeTrackColor: AppColors.neonLime.withValues(alpha: 0.4),
                    activeThumbColor: AppColors.neonLime,
                    onChanged: (enabled) {
                      HapticFeedback.selectionClick();
                      eqNotifier.setEnabled(enabled);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Scrollable Content
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                children: [
                  // 1. High-Precision Frequency Response Visualizer (Borderless)
                  _FrequencyCurveCanvas(
                    isEnabled: eqState.isEnabled,
                    gains: eqState.bandGains,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 20),

                  // 2. Presets Carousel Header
                  Row(
                    children: [
                      Text(
                        'STUDIO PRESETS',
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: textMuted,
                        ),
                      ),
                      const Spacer(),
                      if (eqState.preset != 'Flat' ||
                          eqState.bandGains.any((g) => g.abs() > 0.01))
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            eqNotifier.resetToFlat();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.refresh_rounded, size: 14, color: accentTextColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Reset to Flat',
                                  style: AppTypography.style(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: accentTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Presets Horizontal Carousel (Borderless Pills)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      itemCount: EqualizerPresets.presets.keys.length,
                      separatorBuilder: (context, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final name = EqualizerPresets.presets.keys.elementAt(index);
                        final isSelected = eqState.preset == name;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            eqNotifier.setPreset(name);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.neonLime
                                  : (isDark ? const Color(0xFF1B1D26) : const Color(0xFFECEEF2)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                name,
                                style: AppTypography.style(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.black
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Frequency Band Sliders (Borderless Card & Minimalist Glass Faders)
                  Row(
                    children: [
                      Text(
                        'BAND GAINS (-12 dB to +12 dB)',
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap dB badge to reset',
                        style: AppTypography.caption.copyWith(color: textMuted),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: List.generate(5, (index) {
                        final freq = EqualizerPresets.bandFrequencies[index];
                        final label = EqualizerPresets.bandLabels[index];
                        final gain = eqState.bandGains[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _BandGainRow(
                            frequency: freq,
                            label: label,
                            gain: gain,
                            isEnabled: eqState.isEnabled,
                            isDark: isDark,
                            onGainChanged: (newGain) {
                              eqNotifier.setBandGain(index, newGain);
                            },
                            onResetBand: () {
                              HapticFeedback.selectionClick();
                              eqNotifier.setBandGain(index, 0.0);
                            },
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Studio DSP Enhancements (Borderless Card)
                  Text(
                    'ACOUSTIC ENHANCEMENTS',
                    style: AppTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: textMuted,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        _EnhancementSliderRow(
                          icon: Icons.speaker_group_rounded,
                          title: 'Sub-Bass & Punch',
                          subtitle: '${(eqState.bassBoost * 100).round()}% Loudness Boost',
                          value: eqState.bassBoost,
                          isEnabled: eqState.isEnabled,
                          isDark: isDark,
                          onChanged: (val) => eqNotifier.setBassBoost(val),
                        ),
                        const SizedBox(height: 14),
                        Divider(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                          height: 1,
                        ),
                        const SizedBox(height: 14),
                        _EnhancementSliderRow(
                          icon: Icons.surround_sound_rounded,
                          title: 'Spatial Soundstage',
                          subtitle: '${(eqState.virtualizer * 100).round()}% 3D Width',
                          value: eqState.virtualizer,
                          isEnabled: eqState.isEnabled,
                          isDark: isDark,
                          onChanged: (val) => eqNotifier.setVirtualizer(val),
                        ),
                      ],
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

/// Dynamic Spline Canvas of the 5 EQ bands (Borderless)
class _FrequencyCurveCanvas extends StatelessWidget {
  final bool isEnabled;
  final List<double> gains;
  final bool isDark;

  const _FrequencyCurveCanvas({
    required this.isEnabled,
    required this.gains,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0F16) : const Color(0xFFECEEF2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EqualizerScreenSplinePainter(
                  gains: gains,
                  isEnabled: isEnabled,
                  isDark: isDark,
                ),
              ),
            ),
            if (!isEnabled)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E212B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'HARDWARE DSP BYPASSED',
                      style: AppTypography.style(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EqualizerScreenSplinePainter extends CustomPainter {
  final List<double> gains;
  final bool isEnabled;
  final bool isDark;

  _EqualizerScreenSplinePainter({
    required this.gains,
    required this.isEnabled,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    // Draw subtle grid lines (+12 dB, +6 dB, 0 dB, -6 dB, -12 dB)
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    final centerGridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), centerGridPaint);
    canvas.drawLine(Offset(0, size.height * 0.15), Offset(size.width, size.height * 0.15), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.32), Offset(size.width, size.height * 0.32), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.68), Offset(size.width, size.height * 0.68), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.85), Offset(size.width, size.height * 0.85), gridPaint);

    if (gains.length < 5) return;

    final xCoords = [
      size.width * 0.12,
      size.width * 0.31,
      size.width * 0.50,
      size.width * 0.69,
      size.width * 0.88,
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

    // Gradient fill under the curve
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
                AppColors.neonLime.withValues(alpha: 0.32),
                AppColors.neonLime.withValues(alpha: 0.02),
              ]
            : [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.0),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Stroke curve
    final strokePaint = Paint()
      ..color = isEnabled ? AppColors.neonLime : (isDark ? Colors.white38 : Colors.black38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Glowing pins
    for (final pt in points) {
      if (isEnabled) {
        final glowPaint = Paint()
          ..color = AppColors.neonLime.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawCircle(pt, 6.0, glowPaint);
      }

      final pinPaint = Paint()
        ..color = isEnabled ? AppColors.neonLime : (isDark ? Colors.white70 : Colors.black54)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 3.6, pinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerScreenSplinePainter oldDelegate) {
    return oldDelegate.isEnabled != isEnabled ||
        oldDelegate.isDark != isDark ||
        oldDelegate.gains != gains;
  }
}

/// A single frequency band row with decibel readout and Liquid Glass Slider.
class _BandGainRow extends StatelessWidget {
  final String frequency;
  final String label;
  final double gain;
  final bool isEnabled;
  final bool isDark;
  final ValueChanged<double> onGainChanged;
  final VoidCallback onResetBand;

  const _BandGainRow({
    required this.frequency,
    required this.label,
    required this.gain,
    required this.isEnabled,
    required this.isDark,
    required this.onGainChanged,
    required this.onResetBand,
  });

  String _formatGain(double val) {
    if (val.abs() < 0.05) return '0.0 dB';
    final sign = val > 0 ? '+' : '';
    return '$sign${val.toStringAsFixed(1)} dB';
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.neonLime;
    final inactiveTrack = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    final isNonZero = gain.abs() > 0.05;

    return Row(
      children: [
        // Frequency and Subtitle with AppTypography
        SizedBox(
          width: 76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                frequency,
                style: AppTypography.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isEnabled
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),

        // Liquid Glass Slider (Rule 2: useOwnLayer on page platter)
        Expanded(
          child: GlassSlider(
            value: gain.clamp(-12.0, 12.0),
            min: -12.0,
            max: 12.0,
            activeColor: isEnabled ? activeColor : (isDark ? Colors.white38 : Colors.black38),
            thumbColor: isEnabled ? activeColor : (isDark ? Colors.white54 : Colors.black45),
            inactiveColor: inactiveTrack,
            glowColor: isEnabled
                ? activeColor.withValues(alpha: 0.45)
                : Colors.transparent,
            glowRadius: 2.5,
            useOwnLayer: true,
            onChangeStart: (_) => HapticFeedback.selectionClick(),
            onChanged: isEnabled
                ? (val) {
                    onGainChanged(val);
                  }
                : null,
          ),
        ),

        const SizedBox(width: 10),

        // Tappable Decibel Readout Badge (Borderless, tap to reset)
        GestureDetector(
          onTap: isEnabled && isNonZero ? onResetBand : null,
          child: Container(
            width: 62,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: isNonZero && isEnabled
                  ? (isDark ? activeColor.withValues(alpha: 0.18) : AppColors.limeAccentDark.withValues(alpha: 0.12))
                  : (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatGain(gain),
              textAlign: TextAlign.center,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isEnabled
                    ? (isNonZero
                        ? (isDark ? activeColor : AppColors.limeAccentDark)
                        : (isDark ? Colors.white70 : Colors.black87))
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Enhancement slider for Bass Boost and Virtualizer
class _EnhancementSliderRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final bool isEnabled;
  final bool isDark;
  final ValueChanged<double> onChanged;

  const _EnhancementSliderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isEnabled,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.neonLime;
    final accentTextColor = isDark ? AppColors.neonLime : AppColors.limeAccentDark;
    final inactiveTrack = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: isEnabled && value > 0.01
              ? accentTextColor
              : (isDark ? Colors.white38 : Colors.black38),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isEnabled
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isEnabled && value > 0.01
                      ? accentTextColor
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GlassSlider(
            value: value.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            activeColor: isEnabled ? activeColor : (isDark ? Colors.white38 : Colors.black38),
            thumbColor: isEnabled ? activeColor : (isDark ? Colors.white54 : Colors.black45),
            inactiveColor: inactiveTrack,
            glowColor: isEnabled ? activeColor.withValues(alpha: 0.45) : Colors.transparent,
            glowRadius: 2.5,
            useOwnLayer: true,
            onChangeStart: (_) => HapticFeedback.selectionClick(),
            onChanged: isEnabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
