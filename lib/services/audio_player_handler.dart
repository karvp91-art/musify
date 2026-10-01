import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain/models/track.dart';
import '../domain/models/playback_state.dart';
import 'preferences_service.dart';

class MusifyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final PreferencesService? preferencesService;
  final AudioPlayer _player = AudioPlayer();
  List<Track> _playlist = [];
  int _currentIndex = -1;

  final _playerStateController = StreamController<PlayerStateModel>.broadcast();
  Stream<PlayerStateModel> get playerStateStream => _playerStateController.stream;

  final _trackPlayedController = StreamController<Track>.broadcast();
  Stream<Track> get trackPlayedStream => _trackPlayedController.stream;

  late AppRepeatMode _repeatMode;
  late bool _isShuffle;

  bool get isShuffle => _isShuffle;
  AppRepeatMode get repeatMode => _repeatMode;

  final List<int> _shuffleIndices = [];
  int _shufflePointer = -1;
  final List<int> _historyIndices = [];

  void _setupShuffleIndices() {
    _shuffleIndices.clear();
    _historyIndices.clear();
    if (_playlist.isEmpty) {
      _shufflePointer = -1;
      return;
    }
    final allIndices = List.generate(_playlist.length, (i) => i);
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      allIndices.remove(_currentIndex);
      allIndices.shuffle(math.Random());
      _shuffleIndices.add(_currentIndex);
      _shuffleIndices.addAll(allIndices);
      _shufflePointer = 0;
    } else {
      allIndices.shuffle(math.Random());
      _shuffleIndices.addAll(allIndices);
      _shufflePointer = 0;
    }
  }

  MusifyAudioHandler({this.preferencesService}) {
    _isShuffle = preferencesService?.getShuffleMode() ?? false;
    _repeatMode = preferencesService?.getRepeatMode() ?? AppRepeatMode.off;
    _initAudioStreams();
    _emitState();
  }

  void _initAudioStreams() {
    // Propagate player state to audio_service and custom stream
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final isPlaying = _player.playing;
      final processingState = _player.processingState;

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[processingState]!,
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex >= 0 ? _currentIndex : null,
      ));

      _emitState();
    });

    // Handle track completion
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_repeatMode == AppRepeatMode.one) {
          _player.seek(Duration.zero);
          _player.play();
        } else if (_isShuffle) {
          if (hasNext) {
            skipToNext();
          } else if (_repeatMode == AppRepeatMode.all && _playlist.isNotEmpty) {
            _setupShuffleIndices();
            if (_shuffleIndices.isNotEmpty) {
              skipToNext();
            }
          }
        } else if (hasNext) {
          skipToNext();
        } else if (_repeatMode == AppRepeatMode.all && _playlist.isNotEmpty) {
          playTrackAtIndex(0);
        }
      }
    });

    _player.positionStream.listen((_) => _emitState());
    _player.bufferedPositionStream.listen((_) => _emitState());

    // Keep MediaItem duration in sync with actual loaded track duration for the system scrubber
    _player.durationStream.listen((duration) {
      if (duration != null && duration > Duration.zero) {
        final current = mediaItem.value;
        if (current != null && current.duration != duration) {
          mediaItem.add(current.copyWith(duration: duration));
        }
      }
    });
  }

  bool get hasNext {
    if (_playlist.isEmpty) return false;
    if (_isShuffle) {
      if (_repeatMode == AppRepeatMode.all) return true;
      return _shufflePointer < _shuffleIndices.length - 1;
    }
    if (_repeatMode == AppRepeatMode.all) return true;
    return _currentIndex < _playlist.length - 1;
  }

  bool get hasPrevious {
    if (_playlist.isEmpty) return false;
    if (_isShuffle) {
      return _historyIndices.isNotEmpty || _shufflePointer > 0;
    }
    return _currentIndex > 0;
  }

  List<Track>? _cachedUnmodifiableQueue;

  List<Track> get _unmodifiablePlaylist {
    return _cachedUnmodifiableQueue ??= List.unmodifiable(_playlist);
  }

  void _invalidateQueueCache() {
    _cachedUnmodifiableQueue = null;
  }

  void _emitState() {
    Track? currentTrack;
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      currentTrack = _playlist[_currentIndex];
    }

    _playerStateController.add(PlayerStateModel(
      currentTrack: currentTrack,
      isPlaying: _player.playing,
      isBuffering: _player.processingState == ProcessingState.buffering,
      position: _player.position,
      duration: _player.duration ?? Duration.zero,
      bufferedPosition: _player.bufferedPosition,
      isShuffleEnabled: _isShuffle,
      repeatMode: _repeatMode,
      queue: _unmodifiablePlaylist,
      currentIndex: _currentIndex,
    ));
  }

  Future<void> playTrackList(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _playlist = List.from(tracks);
    _invalidateQueueCache();
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    if (_isShuffle) {
      _setupShuffleIndices();
    }

    // Update queue in audio_service
    queue.add(_playlist.map(_trackToMediaItem).toList());

    await playTrackAtIndex(_currentIndex);
  }

  Future<void> playTrackAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;

    if (_isShuffle) {
      if (_shuffleIndices.isEmpty || _shuffleIndices.length != _playlist.length) {
        _setupShuffleIndices();
      } else {
        final pos = _shuffleIndices.indexOf(index);
        if (pos != -1) {
          _shufflePointer = pos;
        }
      }
    }

    await _playCurrentTrack();
  }

  Future<void> _playTrackInternal(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    await _playCurrentTrack();
  }

  Future<void> _playCurrentTrack() async {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) return;
    final track = _playlist[_currentIndex];

    // Update lock screen media item
    final item = _trackToMediaItem(track);
    mediaItem.add(item);
    _trackPlayedController.add(track);

    // Ensure notification permission is requested on Android so the system media player shows
    if (Platform.isAndroid) {
      Permission.notification.status.then((status) {
        if (status.isDenied) {
          Permission.notification.request();
        }
      });
    }

    try {
      final hasLocalFile = track.filePath != null &&
          track.filePath!.isNotEmpty &&
          File(track.filePath!).existsSync();
      if (hasLocalFile) {
        await _player.setFilePath(track.filePath!);
      } else {
        await _player.setUrl(track.audioUrl);
      }
      await _player.play();
    } catch (e) {
      // Audio load error handled gracefully
    }

    _emitState();
  }

  MediaItem _trackToMediaItem(Track track) {
    Uri? artUri;
    if (track.artworkUrl != null && track.artworkUrl!.trim().isNotEmpty) {
      final uriString = track.artworkUrl!.trim();
      final parsed = Uri.tryParse(uriString);
      if (parsed != null &&
          (parsed.scheme == 'http' ||
              parsed.scheme == 'https' ||
              parsed.scheme == 'file' ||
              parsed.scheme == 'content')) {
        artUri = parsed;
      } else if (uriString.startsWith('/') || uriString.contains(':\\')) {
        artUri = Uri.file(uriString);
      }
    }

    return MediaItem(
      id: track.id,
      album: track.albumTitle?.isNotEmpty == true ? track.albumTitle! : 'Musify',
      title: track.title.isNotEmpty ? track.title : 'Unknown Title',
      artist: track.artistName.isNotEmpty ? track.artistName : 'Unknown Artist',
      duration: track.durationMs > 0 ? Duration(milliseconds: track.durationMs) : null,
      artUri: artUri,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;

    if (_isShuffle) {
      if (_shuffleIndices.isEmpty || _shuffleIndices.length != _playlist.length) {
        _setupShuffleIndices();
      }
      if (_shufflePointer < _shuffleIndices.length - 1) {
        _historyIndices.add(_currentIndex);
        _shufflePointer++;
        final nextIndex = _shuffleIndices[_shufflePointer];
        await _playTrackInternal(nextIndex);
      } else if (_repeatMode == AppRepeatMode.all) {
        if (_playlist.length > 1) {
          _historyIndices.add(_currentIndex);
          _setupShuffleIndices();
          if (_shuffleIndices.length > 1) {
            _shufflePointer = 1;
            await _playTrackInternal(_shuffleIndices[_shufflePointer]);
          }
        } else if (_playlist.length == 1) {
          await _player.seek(Duration.zero);
          await _player.play();
        }
      }
      return;
    }

    if (_currentIndex < _playlist.length - 1) {
      await playTrackAtIndex(_currentIndex + 1);
    } else if (_repeatMode == AppRepeatMode.all && _playlist.isNotEmpty) {
      await playTrackAtIndex(0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      // If played for more than 3 seconds, replay from start of track
      await _player.seek(Duration.zero);
      return;
    }

    if (_isShuffle) {
      if (_historyIndices.isNotEmpty) {
        final prevIndex = _historyIndices.removeLast();
        _shufflePointer = _shuffleIndices.indexOf(prevIndex);
        await _playTrackInternal(prevIndex);
        return;
      } else if (_shufflePointer > 0) {
        _shufflePointer--;
        final prevIndex = _shuffleIndices[_shufflePointer];
        await _playTrackInternal(prevIndex);
        return;
      } else {
        await _player.seek(Duration.zero);
        return;
      }
    }

    if (hasPrevious) {
      await playTrackAtIndex(_currentIndex - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    preferencesService?.setShuffleMode(_isShuffle);
    if (_isShuffle) {
      _setupShuffleIndices();
    } else {
      _shuffleIndices.clear();
      _shufflePointer = -1;
      _historyIndices.clear();
    }
    _emitState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final shouldShuffle = shuffleMode != AudioServiceShuffleMode.none;
    if (_isShuffle != shouldShuffle) {
      toggleShuffle();
    }
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case AppRepeatMode.off:
        _repeatMode = AppRepeatMode.all;
        break;
      case AppRepeatMode.all:
        _repeatMode = AppRepeatMode.one;
        break;
      case AppRepeatMode.one:
        _repeatMode = AppRepeatMode.off;
        break;
    }
    preferencesService?.setRepeatMode(_repeatMode);
    _emitState();
  }

  /// Cycles through the 3-way playback modes:
  /// Shuffle -> Repeat All -> Repeat One -> Shuffle ...
  void cyclePlaybackMode() {
    if (_isShuffle) {
      // From Shuffle -> Repeat All ("all")
      _isShuffle = false;
      _repeatMode = AppRepeatMode.all;
      _shuffleIndices.clear();
      _shufflePointer = -1;
      _historyIndices.clear();
    } else if (_repeatMode == AppRepeatMode.all || _repeatMode == AppRepeatMode.off) {
      // From Repeat All -> Repeat One ("repeat")
      _isShuffle = false;
      _repeatMode = AppRepeatMode.one;
    } else {
      // From Repeat One -> Shuffle ("shuffle")
      _isShuffle = true;
      _repeatMode = AppRepeatMode.all;
      _setupShuffleIndices();
    }
    preferencesService?.setShuffleMode(_isShuffle);
    preferencesService?.setRepeatMode(_repeatMode);
    _emitState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _repeatMode = AppRepeatMode.off;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        _repeatMode = AppRepeatMode.all;
        break;
      case AudioServiceRepeatMode.one:
        _repeatMode = AppRepeatMode.one;
        break;
    }
    preferencesService?.setRepeatMode(_repeatMode);
    _emitState();
  }

  void addToQueue(Track track) {
    _playlist.add(track);
    if (_isShuffle) {
      _shuffleIndices.add(_playlist.length - 1);
    }
    _invalidateQueueCache();
    queue.add(_playlist.map(_trackToMediaItem).toList());
    _emitState();
  }

  void insertNextInQueue(Track track) {
    final insertIndex = (_currentIndex + 1).clamp(0, _playlist.length);
    _playlist.insert(insertIndex, track);
    if (_isShuffle) {
      for (int i = 0; i < _shuffleIndices.length; i++) {
        if (_shuffleIndices[i] >= insertIndex) {
          _shuffleIndices[i]++;
        }
      }
      final targetPos = (_shufflePointer + 1).clamp(0, _shuffleIndices.length);
      _shuffleIndices.insert(targetPos, insertIndex);
    }
    _invalidateQueueCache();
    queue.add(_playlist.map(_trackToMediaItem).toList());
    _emitState();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _playlist.removeAt(index);
      _invalidateQueueCache();
      if (_isShuffle) {
        _shuffleIndices.remove(index);
        for (int i = 0; i < _shuffleIndices.length; i++) {
          if (_shuffleIndices[i] > index) {
            _shuffleIndices[i]--;
          }
        }
        _historyIndices.removeWhere((i) => i == index);
        for (int i = 0; i < _historyIndices.length; i++) {
          if (_historyIndices[i] > index) {
            _historyIndices[i]--;
          }
        }
        if (_currentIndex >= 0) {
          _shufflePointer = _shuffleIndices.indexOf(_currentIndex);
        }
      }
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _playlist.isNotEmpty) {
        playTrackAtIndex(_currentIndex.clamp(0, _playlist.length - 1));
      }
      queue.add(_playlist.map(_trackToMediaItem).toList());
      _emitState();
    }
  }

  Future<void> removeTrackById(String trackId) async {
    final index = _playlist.indexWhere((t) => t.id == trackId);
    if (index != -1) {
      await removeQueueItemAt(index);
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, item);
    _invalidateQueueCache();

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    queue.add(_playlist.map(_trackToMediaItem).toList());
    _emitState();
  }

  void clearQueue() {
    _playlist.clear();
    _invalidateQueueCache();
    _currentIndex = -1;
    _player.stop();
    queue.add([]);
    _emitState();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _playerStateController.close();
    await _trackPlayedController.close();
  }
}
