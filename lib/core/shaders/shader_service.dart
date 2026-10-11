import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Predefined asset paths for application GPU shaders
class AppShaders {
  static const String liquidWaveProgress = 'assets/shaders/liquid_wave_progress.frag';
  static const String vinylAnisotropic = 'assets/shaders/vinyl_anisotropic.frag';
  static const String ambientMeshAura = 'assets/shaders/ambient_mesh_aura.frag';
  static const String lyricsGlowWipe = 'assets/shaders/lyrics_glow_wipe.frag';
}

/// Global service for preloading, compiling, and caching GPU [FragmentProgram] instances.
class ShaderService {
  ShaderService._();
  static final ShaderService instance = ShaderService._();

  final Map<String, FragmentProgram> _cache = {};
  final Map<String, Future<FragmentProgram?>> _inFlight = {};

  /// Retrieves a compiled [FragmentProgram] from cache or loads it asynchronously.
  /// Gracefully returns `null` in headless test environments or if compilation fails.
  Future<FragmentProgram?> getProgram(String assetPath) async {
    if (_cache.containsKey(assetPath)) {
      return _cache[assetPath];
    }

    if (_inFlight.containsKey(assetPath)) {
      return _inFlight[assetPath];
    }

    final future = _loadProgram(assetPath);
    _inFlight[assetPath] = future;
    final result = await future;
    _inFlight.remove(assetPath);
    return result;
  }

  /// Synchronously returns a previously loaded program, or null if not yet compiled.
  FragmentProgram? getCached(String assetPath) => _cache[assetPath];

  /// Pre-warms core application shaders ahead of time (e.g. during splash screen).
  Future<void> preloadAll() async {
    await Future.wait([
      getProgram(AppShaders.liquidWaveProgress),
      getProgram(AppShaders.vinylAnisotropic),
      getProgram(AppShaders.ambientMeshAura),
      getProgram(AppShaders.lyricsGlowWipe),
    ]);
  }

  Future<FragmentProgram?> _loadProgram(String assetPath) async {
    try {
      final program = await FragmentProgram.fromAsset(assetPath);
      _cache[assetPath] = program;
      return program;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ShaderService] Shader compilation skipped or unavailable for "$assetPath": $e');
      }
      return null;
    }
  }
}

/// Riverpod provider for accessing [ShaderService]
final shaderServiceProvider = Provider<ShaderService>((ref) {
  return ShaderService.instance;
});

/// Riverpod provider for loading and caching a specific fragment program
final fragmentProgramProvider =
    FutureProvider.family<FragmentProgram?, String>((ref, assetPath) async {
  return ShaderService.instance.getProgram(assetPath);
});
