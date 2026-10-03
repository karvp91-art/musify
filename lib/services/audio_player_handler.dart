import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../domain/models/track.dart';
import '../domain/models/playback_state.dart';
import 'preferences_service.dart';

class MusifyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final PreferencesService? preferencesService;

  // Hardware Audio Effects & Dual Player Decks
  late final AndroidEqualizer _equalizerA;
  late final AndroidEqualizer _equalizerB;
  late final AndroidLoudnessEnhancer _loudnessA;
  late final AndroidLoudnessEnhancer _loudnessB;

  late final AudioPipeline _pipelineA;
  late final AudioPipeline _pipelineB;

  late final AudioPlayer _playerA;
  late final AudioPlayer _playerB;

  late AudioPlayer _activePlayer;
  late AudioPlayer _inactivePlayer;

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

  // Gapless & Crossfade State
  int _crossfadeDuration = 0; // 0 to 10 seconds
  bool _gaplessPlayback = true;
  bool _isCrossfading = false;
  Timer? _crossfadeTimer;
  int? _prebufferedTrackIndex;
  int? _crossfadeTargetIndex; // Target track index during an active crossfade

  int get crossfadeDuration => _crossfadeDuration;
  bool get isGaplessPlayback => _gaplessPlayback;

  Future<String> Function(Track track)? _trackUrlResolver;

  void setTrackUrlResolver(Future<String> Function(Track track) resolver) {
    _trackUrlResolver = resolver;
  }

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
    _crossfadeDuration = preferencesService?.getCrossfadeDuration() ?? 0;
    _gaplessPlayback = preferencesService?.getGaplessPlayback() ?? true;

    _initHardwareEffectsAndPlayers();
    _initAudioStreams();
    _initSavedEqualizer();
    _emitState();
  }

  void _initHardwareEffectsAndPlayers() {
    try {
      _equalizerA = AndroidEqualizer();
      _loudnessA = AndroidLoudnessEnhancer();
      _pipelineA = AudioPipeline(androidAudioEffects: [_equalizerA, _loudnessA]);
      _playerA = AudioPlayer(audioPipeline: _pipelineA);
    } catch (_) {
      _playerA = AudioPlayer();
    }

    try {
      _equalizerB = AndroidEqualizer();
      _loudnessB = AndroidLoudnessEnhancer();
      _pipelineB = AudioPipeline(androidAudioEffects: [_equalizerB, _loudnessB]);
      _playerB = AudioPlayer(audioPipeline: _pipelineB);
    } catch (_) {
      _playerB = AudioPlayer();
    }

    _activePlayer = _playerA;
    _inactivePlayer = _playerB;
  }

  void _initSavedEqualizer() {
    if (preferencesService != null) {
      final isEnabled = preferencesService!.getEqualizerEnabled();
      final gains = preferencesService!.getEqualizerBandGains();
      final bass = preferencesService!.getEqualizerBassBoost();
      // Apply asynchronously without blocking player startup
      applyEqualizerSettings(
        enabled: isEnabled,
        bandGains: gains,
        bassBoost: bass,
      ).catchError((_) {});
    }
  }

  void setCrossfadeDuration(int seconds) {
    _crossfadeDuration = seconds.clamp(0, 10);
    preferencesService?.setCrossfadeDuration(_crossfadeDuration);
  }

  void setGaplessPlayback(bool enabled) {
    _gaplessPlayback = enabled;
    preferencesService?.setGaplessPlayback(enabled);
  }

  Future<void> applyEqualizerSettings({
    required bool enabled,
    required List<double> bandGains,
    required double bassBoost,
  }) async {
    // Equalizer bands on Android Hardware for Deck A
    try {
      await _equalizerA.setEnabled(enabled);
      final paramsA = await _equalizerA.parameters;
      for (int i = 0; i < bandGains.length; i++) {
        final gain = bandGains[i];
        if (i < paramsA.bands.length) {
          await paramsA.bands[i].setGain(gain);
        }
      }
    } catch (_) {
      // Platform audio effects degrade gracefully on unsupported hardware/sessions
    }

    // Equalizer bands on Android Hardware for Deck B
    try {
      await _equalizerB.setEnabled(enabled);
      final paramsB = await _equalizerB.parameters;
      for (int i = 0; i < bandGains.length; i++) {
        final gain = bandGains[i];
        if (i < paramsB.bands.length) {
          await paramsB.bands[i].setGain(gain);
        }
      }
    } catch (_) {
      // Platform audio effects degrade gracefully
    }

    // Loudness enhancer / Bass boost for Deck A
    try {
      final boostEnabled = enabled && bassBoost > 0.01;
      await _loudnessA.setEnabled(boostEnabled);
      if (boostEnabled) {
        final gainDb = bassBoost * 6.0;
        await _loudnessA.setTargetGain(gainDb);
      }
    } catch (_) {
      // Platform effects degrade gracefully
    }

    // Loudness enhancer / Bass boost for Deck B
    try {
      final boostEnabled = enabled && bassBoost > 0.01;
      await _loudnessB.setEnabled(boostEnabled);
      if (boostEnabled) {
        final gainDb = bassBoost * 6.0;
        await _loudnessB.setTargetGain(gainDb);
      }
    } catch (_) {
      // Platform effects degrade gracefully
    }
  }

  void _initAudioStreams() {
    _attachPlayerListeners(_playerA);
    _attachPlayerListeners(_playerB);
  }

  void _attachPlayerListeners(AudioPlayer player) {
    player.playbackEventStream.listen((PlaybackEvent event) {
      if (identical(player, _activePlayer) || _isCrossfading) {
        _syncPlaybackState();
        _emitState();
      }
    });

    player.playerStateStream.listen((state) {
      if (identical(player, _activePlayer) && state.processingState == ProcessingState.completed) {
        if (_isCrossfading && _crossfadeTargetIndex != null) {
          // Outgoing track finished during crossfade — snap to completion instantly
          _completeCrossfade(_crossfadeTargetIndex!);
        } else if (!_isCrossfading) {
          _handleTrackCompleted();
        }
      }
    });

    player.positionStream.listen((pos) {
      if (identical(player, _activePlayer)) {
        _checkCrossfadeOrPrebuffer(pos);
        _emitState();
      }
    });

    player.bufferedPositionStream.listen((_) {
      if (identical(player, _activePlayer)) {
        _emitState();
      }
    });

    player.durationStream.listen((duration) {
      if (identical(player, _activePlayer)) {
        if (duration != null && duration > Duration.zero) {
          final current = mediaItem.value;
          if (current != null && current.duration != duration) {
            mediaItem.add(current.copyWith(duration: duration));
          }
        }
      }
    });
  }

  void _syncPlaybackState() {
    final isPlaying = _activePlayer.playing || (_isCrossfading && _inactivePlayer.playing);
    final processingState = _activePlayer.processingState;

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
      updatePosition: _activePlayer.position,
      bufferedPosition: _activePlayer.bufferedPosition,
      speed: _activePlayer.speed,
      queueIndex: _currentIndex >= 0 ? _currentIndex : null,
    ));
  }

  void _checkCrossfadeOrPrebuffer(Duration position) {
    final duration = _activePlayer.duration;
    if (duration == null || duration <= const Duration(seconds: 4)) return;
    if (_isCrossfading) return;

    final remaining = duration - position;

    if (_crossfadeDuration > 0) {
      // Pre-buffer for crossfade: start loading the next track 3s before fade window
      final prebufferWindow = Duration(seconds: _crossfadeDuration + 3);
      if (remaining <= prebufferWindow && remaining > Duration(seconds: _crossfadeDuration)) {
        final nextIdx = _getNextIndex();
        if (nextIdx != null && _prebufferedTrackIndex != nextIdx) {
          _prebufferTrack(nextIdx);
        }
      }

      // Crossfade trigger (+300ms buffer for position stream latency)
      final crossfadeWindow = Duration(seconds: _crossfadeDuration, milliseconds: 300);
      if (remaining <= crossfadeWindow) {
        final nextIdx = _getNextIndex();
        if (nextIdx != null) {
          _startCrossfade(nextIdx);
        }
      }
      return;
    }

    // Gapless pre-buffer trigger (~5s before track end)
    if (_gaplessPlayback && remaining <= const Duration(seconds: 5)) {
      final nextIdx = _getNextIndex();
      if (nextIdx != null && _prebufferedTrackIndex != nextIdx) {
        _prebufferTrack(nextIdx);
      }
    }
  }

  Future<void> _prebufferTrack(int nextIndex) async {
    if (nextIndex < 0 || nextIndex >= _playlist.length) return;
    _prebufferedTrackIndex = nextIndex;
    final track = _playlist[nextIndex];

    try {
      // Stop inactive player first to ensure it doesn't auto-play on source load
      await _inactivePlayer.stop();
      final hasLocal = track.filePath != null &&
          track.filePath!.isNotEmpty &&
          File(track.filePath!).existsSync();
      if (hasLocal) {
        await _inactivePlayer.setFilePath(track.filePath!);
      } else {
        var url = track.audioUrl;
        if ((url.isEmpty || !url.startsWith('http')) && _trackUrlResolver != null) {
          url = await _trackUrlResolver!(track);
          if (url.isNotEmpty && nextIndex >= 0 && nextIndex < _playlist.length) {
            _playlist[nextIndex] = track.copyWith(audioUrl: url);
          }
        }
        if (url.isNotEmpty) {
          await _inactivePlayer.setUrl(url);
        }
      }
      // Player is now in ready state with source loaded, not playing
    } catch (_) {
      _prebufferedTrackIndex = null;
    }
  }

  void _startCrossfade(int nextIndex) {
    if (_isCrossfading || nextIndex < 0 || nextIndex >= _playlist.length) return;
    _isCrossfading = true;
    _crossfadeTargetIndex = nextIndex;

    final nextTrack = _playlist[nextIndex];
    final totalFadeMs = _crossfadeDuration * 1000;
    const intervalMs = 50;
    int elapsedMs = 0;

    () async {
      try {
        await _inactivePlayer.setVolume(0.0);
        final hasLocal = nextTrack.filePath != null &&
            nextTrack.filePath!.isNotEmpty &&
            File(nextTrack.filePath!).existsSync();
        if (_prebufferedTrackIndex == nextIndex) {
          // Track is already pre-buffered in _inactivePlayer
        } else if (hasLocal) {
          await _inactivePlayer.setFilePath(nextTrack.filePath!);
        } else {
          var url = nextTrack.audioUrl;
          if ((url.isEmpty || !url.startsWith('http')) && _trackUrlResolver != null) {
            url = await _trackUrlResolver!(nextTrack);
            if (url.isNotEmpty && nextIndex >= 0 && nextIndex < _playlist.length) {
              _playlist[nextIndex] = nextTrack.copyWith(audioUrl: url);
            }
          }
          if (url.isNotEmpty) {
            await _inactivePlayer.setUrl(url);
          }
        }

        await _inactivePlayer.play();

        _crossfadeTimer?.cancel();
        _crossfadeTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
          elapsedMs += intervalMs;
          final t = (elapsedMs / totalFadeMs).clamp(0.0, 1.0);

          // Smooth cosine curve for natural acoustic power fade
          final fadeOutVol = math.cos(t * math.pi / 2).clamp(0.0, 1.0);
          final fadeInVol = math.sin(t * math.pi / 2).clamp(0.0, 1.0);

          _activePlayer.setVolume(fadeOutVol);
          _inactivePlayer.setVolume(fadeInVol);

          if (elapsedMs >= totalFadeMs) {
            timer.cancel();
            _completeCrossfade(nextIndex);
          }
        });
      } catch (_) {
        _cancelCrossfade();
        _playTrackInternal(nextIndex);
      }
    }();
  }

  void _completeCrossfade(int nextIndex) {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _crossfadeTargetIndex = null;

    _activePlayer.stop();
    _activePlayer.setVolume(1.0);
    _inactivePlayer.setVolume(1.0);

    // Swap players
    final temp = _activePlayer;
    _activePlayer = _inactivePlayer;
    _inactivePlayer = temp;

    _isCrossfading = false;
    _prebufferedTrackIndex = null;
    _currentIndex = nextIndex;

    final track = _playlist[nextIndex];
    mediaItem.add(_trackToMediaItem(track));
    _trackPlayedController.add(track);
    _syncPlaybackState();
    _emitState();
  }

  void _cancelCrossfade() {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _crossfadeTargetIndex = null;
    _isCrossfading = false;
    _activePlayer.setVolume(1.0);
    _inactivePlayer.stop();
    _inactivePlayer.setVolume(1.0);
  }

  int? _getNextIndex() {
    if (_playlist.isEmpty) return null;
    if (_repeatMode == AppRepeatMode.one) return _currentIndex;
    if (_isShuffle) {
      if (_shufflePointer < _shuffleIndices.length - 1) {
        return _shuffleIndices[_shufflePointer + 1];
      } else if (_repeatMode == AppRepeatMode.all && _playlist.isNotEmpty) {
        return _shuffleIndices.isNotEmpty ? _shuffleIndices[0] : 0;
      }
      return null;
    }
    if (_currentIndex < _playlist.length - 1) {
      return _currentIndex + 1;
    } else if (_repeatMode == AppRepeatMode.all && _playlist.isNotEmpty) {
      return 0;
    }
    return null;
  }

  void _handleTrackCompleted() {
    if (_repeatMode == AppRepeatMode.one) {
      _activePlayer.seek(Duration.zero);
      _activePlayer.play();
    } else if (_prebufferedTrackIndex != null) {
      // Instant Gapless handoff to pre-buffered deck
      final nextIdx = _prebufferedTrackIndex!;
      _prebufferedTrackIndex = null;

      // Start incoming track FIRST for true zero-gap transition
      _inactivePlayer.setVolume(1.0);
      _inactivePlayer.seek(Duration.zero);
      _inactivePlayer.play();

      // Then stop the outgoing player
      _activePlayer.stop();
      _activePlayer.setVolume(1.0);

      // Swap player decks
      final temp = _activePlayer;
      _activePlayer = _inactivePlayer;
      _inactivePlayer = temp;

      _currentIndex = nextIdx;
      if (_isShuffle) {
        _shufflePointer = _shuffleIndices.indexOf(nextIdx);
      }
      final track = _playlist[nextIdx];
      mediaItem.add(_trackToMediaItem(track));
      _trackPlayedController.add(track);
      _syncPlaybackState();
      _emitState();
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
      isPlaying: _activePlayer.playing,
      isBuffering: _activePlayer.processingState == ProcessingState.buffering,
      position: _activePlayer.position,
      duration: _activePlayer.duration ?? Duration.zero,
      bufferedPosition: _activePlayer.bufferedPosition,
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
    _cancelCrossfade();
    _prebufferedTrackIndex = null;

    final track = _playlist[_currentIndex];
    mediaItem.add(_trackToMediaItem(track));
    _trackPlayedController.add(track);

    try {
      _activePlayer.setVolume(1.0);
      final hasLocal = track.filePath != null &&
          track.filePath!.isNotEmpty &&
          File(track.filePath!).existsSync();
      if (hasLocal) {
        await _activePlayer.setFilePath(track.filePath!);
      } else {
        var url = track.audioUrl;
        if ((url.isEmpty || !url.startsWith('http')) && _trackUrlResolver != null) {
          url = await _trackUrlResolver!(track);
          if (url.isNotEmpty && _currentIndex >= 0 && _currentIndex < _playlist.length) {
            _playlist[_currentIndex] = track.copyWith(audioUrl: url);
          }
        }
        if (url.isNotEmpty) {
          await _activePlayer.setUrl(url);
        }
      }
      await _activePlayer.play();
    } catch (_) {
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
  Future<void> play() => _activePlayer.play();

  @override
  Future<void> pause() async {
    if (_isCrossfading) {
      await _inactivePlayer.pause();
    }
    await _activePlayer.pause();
  }

  @override
  Future<void> stop() async {
    _cancelCrossfade();
    await _activePlayer.stop();
    await _inactivePlayer.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) {
    if (_isCrossfading) {
      _cancelCrossfade();
    }
    return _activePlayer.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;

    if (_isCrossfading) {
      _cancelCrossfade();
    }

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
          await _activePlayer.seek(Duration.zero);
          await _activePlayer.play();
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
    if (_isCrossfading) {
      _cancelCrossfade();
    }

    if (_activePlayer.position.inSeconds > 3) {
      await _activePlayer.seek(Duration.zero);
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
        await _activePlayer.seek(Duration.zero);
        return;
      }
    }

    if (hasPrevious) {
      await playTrackAtIndex(_currentIndex - 1);
    } else {
      await _activePlayer.seek(Duration.zero);
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

  void cyclePlaybackMode() {
    if (_isShuffle) {
      _isShuffle = false;
      _repeatMode = AppRepeatMode.all;
      _shuffleIndices.clear();
      _shufflePointer = -1;
      _historyIndices.clear();
    } else if (_repeatMode == AppRepeatMode.all || _repeatMode == AppRepeatMode.off) {
      _isShuffle = false;
      _repeatMode = AppRepeatMode.one;
    } else {
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
    _cancelCrossfade();
    _activePlayer.stop();
    _inactivePlayer.stop();
    queue.add([]);
    _emitState();
  }

  Future<void> dispose() async {
    _crossfadeTimer?.cancel();
    await _activePlayer.dispose();
    await _inactivePlayer.dispose();
    await _playerStateController.close();
    await _trackPlayedController.close();
  }
}
