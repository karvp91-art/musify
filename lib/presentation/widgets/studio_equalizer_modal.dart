import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

import 'package:musify/presentation/screens/settings/studio_equalizer_screen.dart';

/// Opens the production-grade Studio Equalizer screen.
Future<void> showStudioEqualizerModal(BuildContext context) {
  return openStudioEqualizerScreen(context);
}

class StudioEqualizerModal extends ConsumerWidget {
  const StudioEqualizerModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    final bgColor = isDark ? const Color(0xFF13141B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF252936) : const Color(0xFFE5E7EB);
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
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Studio Title & Master Power Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: eqState.isEnabled
                        ? AppColors.neonLime.withValues(alpha: 0.15)
                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: eqState.isEnabled
                          ? AppColors.neonLime.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
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
                            'STUDIO EQUALIZER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: eqState.isEnabled
                                  ? AppColors.neonLime.withValues(alpha: 0.2)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PRO DSP',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: eqState.isEnabled ? AppColors.neonLime : textMuted,
                                letterSpacing: 0.5,
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
                        style: TextStyle(
                          fontSize: 12,
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
                  onChanged: (enabled) {
                    HapticFeedback.selectionClick();
                    eqNotifier.setEnabled(enabled);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Scrollable Body Content
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              children: [
                // Dynamic Frequency Response Curve Canvas
                _FrequencyCurveVisualizer(
                  isEnabled: eqState.isEnabled,
                  gains: eqState.bandGains,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Presets Carousel
                Row(
                  children: [
                    Text(
                      'PRESETS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            children: [
                              Icon(Icons.refresh_rounded, size: 14, color: AppColors.neonLime),
                              const SizedBox(width: 4),
                              Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.neonLime,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.neonLime
                                : (isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F3F5)),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.neonLime
                                  : (isDark ? const Color(0xFF2C3040) : const Color(0xFFE2E4E8)),
                              width: 1.0,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

                const SizedBox(height: 20),

                // 5 Frequency Band Faders with Liquid Glass Sliders
                Text(
                  'BAND GAINS (-12 dB to +12 dB)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 10),

                ...List.generate(eqState.bandGains.length, (index) {
                  final freq = index < EqualizerPresets.bandFrequencies.length
                      ? EqualizerPresets.bandFrequencies[index]
                      : '${index + 1}';
                  final label = index < EqualizerPresets.bandLabels.length
                      ? EqualizerPresets.bandLabels[index]
                      : '';
                  final gain = eqState.bandGains[index];

                  return _BandGainRow(
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
                  );
                }),

                const SizedBox(height: 16),

                // Studio Enhancements (Bass Boost & Spatial Soundstage)
                Text(
                  'DSP ENHANCEMENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 10),

                _EnhancementSliderRow(
                  icon: Icons.speaker_group_rounded,
                  title: 'Sub-Bass & Punch',
                  subtitle: '${(eqState.bassBoost * 100).round()}%',
                  value: eqState.bassBoost,
                  isEnabled: eqState.isEnabled,
                  isDark: isDark,
                  onChanged: (val) => eqNotifier.setBassBoost(val),
                ),

                const SizedBox(height: 8),

                _EnhancementSliderRow(
                  icon: Icons.surround_sound_rounded,
                  title: 'Spatial Soundstage',
                  subtitle: '${(eqState.virtualizer * 100).round()}%',
                  value: eqState.virtualizer,
                  isEnabled: eqState.isEnabled,
                  isDark: isDark,
                  onChanged: (val) => eqNotifier.setVirtualizer(val),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic Spline Visualizer of the 5 EQ bands
class _FrequencyCurveVisualizer extends StatelessWidget {
  final bool isEnabled;
  final List<double> gains;
  final bool isDark;

  const _FrequencyCurveVisualizer({
    required this.isEnabled,
    required this.gains,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0D12) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF222634) : const Color(0xFFE2E4E9),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EqualizerSplinePainter(
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'HARDWARE DSP BYPASSED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Colors.white70,
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

class _EqualizerSplinePainter extends CustomPainter {
  final List<double> gains;
  final bool isEnabled;
  final bool isDark;

  _EqualizerSplinePainter({
    required this.gains,
    required this.isEnabled,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    // Draw grid horizontal dashed lines (+12 dB, 0 dB, -12 dB)
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.15), Offset(size.width, size.height * 0.15), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.85), Offset(size.width, size.height * 0.85), gridPaint);

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

    // Generate smooth Bézier spline path
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

    // Gradient fill under the curve down to center
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

    // Stroke the spline
    final strokePaint = Paint()
      ..color = isEnabled ? AppColors.neonLime : (isDark ? Colors.white38 : Colors.black38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Draw glowing pins at each node
    for (final pt in points) {
      if (isEnabled) {
        final glowPaint = Paint()
          ..color = AppColors.neonLime.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(pt, 5.0, glowPaint);
      }

      final pinPaint = Paint()
        ..color = isEnabled ? AppColors.neonLime : (isDark ? Colors.white70 : Colors.black54)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 3.2, pinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerSplinePainter oldDelegate) {
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Frequency and Subtitle
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  frequency,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isEnabled
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
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

          const SizedBox(width: 8),

          // Tappable Decibel Readout (Tap to zero-reset)
          GestureDetector(
            onTap: isEnabled && isNonZero ? onResetBand : null,
            child: Container(
              width: 58,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isNonZero && isEnabled
                    ? activeColor.withValues(alpha: 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isNonZero && isEnabled
                      ? activeColor.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                _formatGain(gain),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: isEnabled
                      ? (isNonZero ? activeColor : (isDark ? Colors.white70 : Colors.black87))
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ),
          ),
        ],
      ),
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
    final inactiveTrack = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isEnabled && value > 0.01
              ? activeColor
              : (isDark ? Colors.white38 : Colors.black38),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 115,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isEnabled
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isEnabled && value > 0.01
                      ? activeColor
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
