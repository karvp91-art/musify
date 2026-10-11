import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/shaders/shader_service.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

/// Atmospheric GPU Fragment Shader living background.
/// Renders fluid organic aura currents [assets/shaders/ambient_mesh_aura.frag]
/// with graceful CPU radial gradient fallback.
class AmbientShaderBackdrop extends ConsumerStatefulWidget {
  /// Base opacity intensity of the ambient fluid field (0.0 to 1.0).
  final double intensity;

  /// Optional override for dominant primary color.
  final Color? primaryColor;

  /// Optional override for companion vibrant color.
  final Color? secondaryColor;

  const AmbientShaderBackdrop({
    super.key,
    this.intensity = 0.42,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  ConsumerState<AmbientShaderBackdrop> createState() => _AmbientShaderBackdropState();
}

class _AmbientShaderBackdropState extends ConsumerState<AmbientShaderBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeController;
  FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    // 24-second looping period for calm, organic liquid drift
    _timeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _loadShader();
  }

  Future<void> _loadShader() async {
    final cached = ShaderService.instance.getCached(AppShaders.ambientMeshAura);
    if (cached != null) {
      if (mounted) setState(() => _program = cached);
      return;
    }

    final loaded = await ShaderService.instance.getProgram(AppShaders.ambientMeshAura);
    if (mounted && loaded != null) {
      setState(() => _program = loaded);
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Base background tone matching the theme
    final baseColor = isDark ? const Color(0xFF0A0B0E) : const Color(0xFFF9FAFB);

    // Current playback state for dynamic musical aura reactivity
    final isPlaying = ref.watch(isPlaybackPlayingProvider);

    // Primary dominant color: track artwork accent or app neon lime
    final defaultPrimary = isDark ? AppColors.neonLime : const Color(0xFF67B01A);
    final c1 = widget.primaryColor ?? defaultPrimary;

    // Companion color: vibrant cyan/teal nebula
    final hsl = HSLColor.fromColor(c1);
    final defaultSecondary = isDark
        ? hsl.withHue((hsl.hue + 55) % 360).withSaturation(0.85).toColor()
        : hsl.withHue((hsl.hue + 45) % 360).toColor();
    final c2 = widget.secondaryColor ?? defaultSecondary;

    final targetIntensity = isPlaying ? widget.intensity : (widget.intensity * 0.75);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _timeController,
        builder: (context, _) {
          final timeSeconds = _timeController.value * 24.0;

          if (_program != null) {
            return CustomPaint(
              size: Size.infinite,
              painter: _MeshAuraPainter(
                program: _program!,
                time: timeSeconds,
                color1: c1,
                color2: c2,
                baseColor: baseColor,
                intensity: targetIntensity,
              ),
            );
          }

          // Elegant CPU fallback: breathing organic radial gradient
          final anim = _timeController.value * 2 * math.pi;
          final alignX = 0.2 * math.sin(anim);
          final alignY = -0.5 + 0.15 * math.cos(anim);

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(alignX, alignY),
                radius: 1.2,
                colors: [
                  c1.withValues(alpha: isDark ? 0.20 : 0.15),
                  c2.withValues(alpha: isDark ? 0.08 : 0.05),
                  baseColor,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _MeshAuraPainter extends CustomPainter {
  final FragmentProgram program;
  final double time;
  final Color color1;
  final Color color2;
  final Color baseColor;
  final double intensity;

  _MeshAuraPainter({
    required this.program,
    required this.time,
    required this.color1,
    required this.color2,
    required this.baseColor,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final shader = program.fragmentShader();

    // 0, 1: uResolution
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // 2: uTime
    shader.setFloat(2, time);

    // 3, 4, 5, 6: uColor1 (dominant vibrant color)
    shader.setFloat(3, color1.r);
    shader.setFloat(4, color1.g);
    shader.setFloat(5, color1.b);
    shader.setFloat(6, color1.a);

    // 7, 8, 9, 10: uColor2 (companion secondary color)
    shader.setFloat(7, color2.r);
    shader.setFloat(8, color2.g);
    shader.setFloat(9, color2.b);
    shader.setFloat(10, color2.a);

    // 11, 12, 13, 14: uColorBase (neutral background)
    shader.setFloat(11, baseColor.r);
    shader.setFloat(12, baseColor.g);
    shader.setFloat(13, baseColor.b);
    shader.setFloat(14, baseColor.a);

    // 15: uIntensity
    shader.setFloat(15, intensity.clamp(0.0, 1.0));

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _MeshAuraPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2 ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.intensity != intensity;
  }
}
