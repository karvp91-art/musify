import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:musify/domain/models/track.dart';
import 'audio_player_handler.dart';

/// Service that coordinates between Musify and the Android Home Screen Widget.
class HomeWidgetService {
  static const MethodChannel _channel = MethodChannel('com.musify/widget');
  static HomeWidgetService? _instance;
  final MusifyAudioHandler _audioHandler;
  final Dio _dio = Dio();

  String? _lastArtworkUrl;
  String? _cachedArtworkPath;

  HomeWidgetService._(this._audioHandler) {
    _initChannel();
    _listenToPlayback();
  }

  static HomeWidgetService initialize(MusifyAudioHandler audioHandler) {
    _instance ??= HomeWidgetService._(audioHandler);
    return _instance!;
  }

  static HomeWidgetService? get instance => _instance;

  void _initChannel() {
    if (!Platform.isAndroid) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetAction') {
        final action = call.arguments as String?;
        if (action == 'playPause') {
          final isPlaying = _audioHandler.playbackState.value.playing;
          if (isPlaying) {
            await _audioHandler.pause();
          } else {
            await _audioHandler.play();
          }
        } else if (action == 'skipToNext') {
          await _audioHandler.skipToNext();
        } else if (action == 'skipToPrevious') {
          await _audioHandler.skipToPrevious();
        }
      }
    });
  }

  void _listenToPlayback() {
    if (!Platform.isAndroid) return;

    // Listen to combined player state
    _audioHandler.playerStateStream.listen((state) {
      updateWidget(
        track: state.currentTrack,
        isPlaying: state.isPlaying,
      );
    });
  }

  /// Pushes track metadata and playback state directly to the Android Home Screen Widget
  Future<void> updateWidget({
    Track? track,
    required bool isPlaying,
    String? source,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      if (track != null) {
        String? artworkPath;
        final artworkUrl = track.artworkUrl;

        // Check if artwork is already cached or local
        if (artworkUrl != null && artworkUrl.isNotEmpty) {
          if (!artworkUrl.startsWith('http') && File(artworkUrl).existsSync()) {
            artworkPath = artworkUrl;
          } else if (artworkUrl == _lastArtworkUrl &&
              _cachedArtworkPath != null &&
              File(_cachedArtworkPath!).existsSync()) {
            artworkPath = _cachedArtworkPath;
          } else if (artworkUrl.startsWith('http')) {
            try {
              final tempDir = await getTemporaryDirectory();
              final file = File('${tempDir.path}/musify_widget_art.png');
              final response = await _dio.get<List<int>>(
                artworkUrl,
                options: Options(
                  responseType: ResponseType.bytes,
                  sendTimeout: const Duration(seconds: 4),
                  receiveTimeout: const Duration(seconds: 4),
                ),
              );
              if (response.data != null && response.data!.isNotEmpty) {
                await file.writeAsBytes(response.data!);
                artworkPath = file.path;
                _lastArtworkUrl = artworkUrl;
                _cachedArtworkPath = artworkPath;
              }
            } catch (_) {
              // Fallback to passing remote URL to Android native loader
            }
          }
        }

        await _channel.invokeMethod('updateWidget', {
          'title': track.title.isNotEmpty ? track.title : 'Unknown Title',
          'artist': track.artistName.isNotEmpty ? track.artistName : 'Unknown Artist',
          'artworkPath': artworkPath,
          'artworkUrl': artworkUrl,
          'isPlaying': isPlaying,
          'source': source ?? 'My Music',
        });
      } else {
        await _channel.invokeMethod('updateWidget', {
          'title': 'Musify',
          'artist': 'Tap to play music',
          'artworkPath': null,
          'artworkUrl': null,
          'isPlaying': false,
          'source': 'My Music',
        });
      }
    } catch (_) {
      // Platform communication fails gracefully if widget is not active
    }
  }
}
