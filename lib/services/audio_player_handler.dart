import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../domain/models/track.dart';
import '../domain/models/playback_state.dart';

class MusifyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  List<Track> _playlist = [];
  int _currentIndex = -1;

  final _playerStateController = StreamController<PlayerStateModel>.broadcast();
  Stream<PlayerStateModel> get playerStateStream => _playerStateController.stream;

  final _trackPlayedController = StreamController<Track>.broadcast();
  Stream<Track> get trackPlayedStream => _trackPlayedController.stream;

  AppRepeatMode _repeatMode = AppRepeatMode.off;
  bool _isShuffle = false;

  MusifyAudioHandler() {
    _initAudioStreams();
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
          MediaControl.stop,
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
        } else if (hasNext) {
          skipToNext();
        } else if (_repeatMode == AppRepeatMode.all && _playlist.isNotEmpty) {
          playTrackAtIndex(0);
        }
      }
    });

    _player.positionStream.listen((_) => _emitState());
    _player.bufferedPositionStream.listen((_) => _emitState());
  }

  bool get hasNext => _playlist.isNotEmpty && _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _playlist.isNotEmpty && _currentIndex > 0;

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

    // Update queue in audio_service
    queue.add(_playlist.map(_trackToMediaItem).toList());

    await playTrackAtIndex(_currentIndex);
  }

  Future<void> playTrackAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    final track = _playlist[_currentIndex];

    // Update lock screen media item
    final item = _trackToMediaItem(track);
    mediaItem.add(item);
    _trackPlayedController.add(track);

    try {
      if (track.source == AudioSourceType.local && track.filePath != null) {
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
    return MediaItem(
      id: track.id,
      album: track.albumTitle ?? 'Musify',
      title: track.title,
      artist: track.artistName,
      duration: Duration(milliseconds: track.durationMs),
      artUri: track.artworkUrl != null ? Uri.tryParse(track.artworkUrl!) : null,
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
    if (hasNext) {
      await playTrackAtIndex(_currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      // If played for more than 3 seconds, replay from start of track
      await _player.seek(Duration.zero);
    } else if (hasPrevious) {
      await playTrackAtIndex(_currentIndex - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _emitState();
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
    _emitState();
  }

  void addToQueue(Track track) {
    _playlist.add(track);
    _invalidateQueueCache();
    queue.add(_playlist.map(_trackToMediaItem).toList());
    _emitState();
  }

  void insertNextInQueue(Track track) {
    final insertIndex = (_currentIndex + 1).clamp(0, _playlist.length);
    _playlist.insert(insertIndex, track);
    _invalidateQueueCache();
    queue.add(_playlist.map(_trackToMediaItem).toList());
    _emitState();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _playlist.removeAt(index);
      _invalidateQueueCache();
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _playlist.isNotEmpty) {
        playTrackAtIndex(_currentIndex.clamp(0, _playlist.length - 1));
      }
      queue.add(_playlist.map(_trackToMediaItem).toList());
      _emitState();
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
