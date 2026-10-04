import 'dart:io';
import 'package:flutter/services.dart';
import 'package:musify/domain/models/track.dart';
import 'audio_player_handler.dart';

/// Service that coordinates between Musify and the Android Home Screen Widget.
class HomeWidgetService {
  static const MethodChannel _channel = MethodChannel('com.musify/widget');
  static HomeWidgetService? _instance;
  final MusifyAudioHandler _audioHandler;

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
          if (_audioHandler.playbackState.value.playing) {
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
  }) async {
    if (!Platform.isAndroid) return;

    try {
      if (track != null) {
        String? artworkPath;
        String? artworkUrl = track.artworkUrl;

        // Check if artwork or track has a local file path
        if (track.filePath != null && track.filePath!.isNotEmpty && File(track.filePath!).existsSync()) {
          artworkPath = track.filePath;
        }

        await _channel.invokeMethod('updateWidget', {
          'title': track.title.isNotEmpty ? track.title : 'Unknown Title',
          'artist': track.artistName.isNotEmpty ? track.artistName : 'Unknown Artist',
          'artworkPath': artworkPath,
          'artworkUrl': artworkUrl,
          'isPlaying': isPlaying,
        });
      } else {
        await _channel.invokeMethod('updateWidget', {
          'title': 'Musify',
          'artist': 'Tap to play music',
          'artworkPath': null,
          'artworkUrl': null,
          'isPlaying': false,
        });
      }
    } catch (_) {
      // Platform communication fails gracefully if widget is not active
    }
  }
}
