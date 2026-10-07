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

  // ---------------------------------------------------------------------------
  // Decks / effects
  // ---------------------------------------------------------------------------
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

  final List<StreamSubscription<dynamic>> _subs = [];

  // ---------------------------------------------------------------------------
  // Queue / shuffle state
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Gapless & crossfade state
  // ---------------------------------------------------------------------------
  static const int _minFadeMs = 150;
  static const Duration _gaplessLead = Duration(milliseconds: 150);

  int _crossfadeDuration = 0; // seconds, 0..10
  bool _gaplessPlayback = true;

  int get crossfadeDuration => _crossfadeDuration;
  bool get isGaplessPlayback => _gaplessPlayback;

  bool _isCrossfading = false; // true from decision until fade completes/cancels
  int? _crossfadeTargetIndex;
  Timer? _crossfadeTimer;
  Stopwatch? _fadeWatch; // non-null only while the fade itself is running

  /// Bumped whenever whatever is loading/playing on the INACTIVE deck becomes
  /// stale (cancel, queue edit, deck swap, new prebuffer...).
  int _deckGen = 0;

  /// Bumped whenever a new load on the ACTIVE deck starts (or is aborted).
  int _activeGen = 0;
  bool _activeLoading = false;

  int? _prebufferReadyIndex; // inactive deck has this track loaded and ready
  int? _prebufferingIndex; // load in flight
  int? _prebufferFailedIndex; // do not retry until invalidated
  Future<void>? _prebufferFuture;

  final Stopwatch _emitThrottle = Stopwatch()..start();

  Future<String> Function(Track track)? _trackUrlResolver;

  void setTrackUrlResolver(Future<String> Function(Track track) resolver) {
    _trackUrlResolver = resolver;
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

  // ===========================================================================
  // Setup
  // ===========================================================================

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
    final prefs = preferencesService;
    if (prefs == null) return;
    applyEqualizerSettings(
      enabled: prefs.getEqualizerEnabled(),
      bandGains: prefs.getEqualizerBandGains(),
      bassBoost: prefs.getEqualizerBassBoost(),
      loudness: prefs.getEqualizerLoudness(),
    ).catchError((_) {});
  }

  void setCrossfadeDuration(int seconds) {
    _crossfadeDuration = seconds.clamp(0, 10);
    preferencesService?.setCrossfadeDuration(_crossfadeDuration);
    _invalidateUpcoming(keepFade: true);
  }

  void setGaplessPlayback(bool enabled) {
    _gaplessPlayback = enabled;
    preferencesService?.setGaplessPlayback(enabled);
    _invalidateUpcoming(keepFade: true);
  }

  Future<void> applyEqualizerSettings({
    required bool enabled,
    required List<double> bandGains,
    required double bassBoost,
    double loudness = 0.0,
  }) async {
    // Arguments are evaluated inside try so a failed late-init of a deck's
    // effects (unsupported hardware) degrades gracefully.
    try {
      await _applyEffectsToDeck(_equalizerA, _loudnessA, enabled, bandGains, bassBoost, loudness);
    } catch (_) {}
    try {
      await _applyEffectsToDeck(_equalizerB, _loudnessB, enabled, bandGains, bassBoost, loudness);
    } catch (_) {}
  }

  Future<void> _applyEffectsToDeck(
    AndroidEqualizer eq,
    AndroidLoudnessEnhancer loud,
    bool enabled,
    List<double> bandGains,
    double bassBoost,
    double loudness,
  ) async {
    try {
      await eq.setEnabled(enabled);
      final params = await eq.parameters;
      for (int i = 0; i < bandGains.length && i < params.bands.length; i++) {
        await params.bands[i].setGain(bandGains[i]);
      }
    } catch (_) {}

    try {
      final boostEnabled = enabled && (bassBoost > 0.01 || loudness > 0.01);
      await loud.setEnabled(boostEnabled);
      if (boostEnabled) {
        await loud.setTargetGain((bassBoost * 4.0) + (loudness * 4.0));
      }
    } catch (_) {}
  }

  // ===========================================================================
  // Player listeners
  // ===========================================================================

  void _initAudioStreams() {
    _attachPlayerListeners(_playerA);
    _attachPlayerListeners(_playerB);
  }

  void _attachPlayerListeners(AudioPlayer player) {
    _subs.add(player.playbackEventStream.listen((_) {
      if (identical(player, _activePlayer) || _isCrossfading) {
        _syncPlaybackState();
        _emitState();
      }
    }, onError: (Object _) {}));

    _subs.add(player.playerStateStream.listen((state) {
      if (!identical(player, _activePlayer)) return;
      if (state.processingState != ProcessingState.completed) return;

      if (_isCrossfading) {
        final target = _crossfadeTargetIndex;
        if (target == null) return;
        if (_fadeWatch != null) {
          // Outgoing deck ended during the fade: finish immediately.
          _completeCrossfade(target);
        } else {
          // Outgoing deck ended while the incoming deck was still loading.
          _cancelCrossfade();
          _advanceTo(target);
          unawaited(_playCurrentTrack());
        }
      } else {
        unawaited(_handleTrackCompleted());
      }
    }));

    // Fast position updates so the gapless hand-off can fire close to the end.
    _subs.add(player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 50),
          maxPeriod: const Duration(milliseconds: 200),
        )
        .listen((pos) {
      if (!identical(player, _activePlayer)) return;
      _checkUpcoming(pos);
      _emitStateThrottled();
    }));

    _subs.add(player.bufferedPositionStream.listen((_) {
      if (identical(player, _activePlayer)) _emitStateThrottled();
    }));

    _subs.add(player.durationStream.listen((duration) {
      if (!identical(player, _activePlayer)) return;
      if (duration == null || duration <= Duration.zero) return;
      final current = mediaItem.value;
      if (current != null && current.duration != duration) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    }));
  }

  void _syncPlaybackState() {
    final isPlaying =
        _activePlayer.playing || (_fadeWatch != null && _inactivePlayer.playing);
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

  // ===========================================================================
  // Helpers: indices, sources
  // ===========================================================================

  bool _validIndex(int i) => i >= 0 && i < _playlist.length;

  /// Finds [id] near [hint]; falls back to a search if the queue shifted.
  int _locate(int hint, String id) {
    if (_validIndex(hint) && _playlist[hint].id == id) return hint;
    return _playlist.indexWhere((t) => t.id == id);
  }

  bool _isNeedsUrlResolution(String? url) {
    if (url == null || url.isEmpty || !url.startsWith('http')) return true;
    return url.contains('jiotunepreview') ||
        url.contains('preview.saavncdn.com') ||
        url.contains('_p.mp4');
  }

  String? _localPath(Track t) {
    final p = t.filePath;
    if (p != null && p.isNotEmpty && File(p).existsSync()) return p;
    return null;
  }

  bool _looksLocal(String s) =>
      File(s).existsSync() || s.startsWith('/') || s.contains(':\\');

  /// Single loader used by active playback, prebuffering and crossfade.
  /// Returns true only if the source was loaded and [isStale] stayed false.
  Future<bool> _loadInto(
    AudioPlayer player,
    int index,
    bool Function() isStale, {
    required bool stopFirst,
  }) async {
    if (!_validIndex(index)) return false;
    final id = _playlist[index].id;
    try {
      if (stopFirst) {
        // Make sure a deck never auto-plays when its source changes.
        await player.stop();
        if (isStale()) return false;
      }

      var i = _locate(index, id);
      if (i < 0) return false;
      final track = _playlist[i];

      final local = _localPath(track);
      var isFile = local != null;
      var source = local ?? track.audioUrl;

      if (!isFile && _isNeedsUrlResolution(source) && _trackUrlResolver != null) {
        final resolved = await _trackUrlResolver!(track);
        if (isStale()) return false;
        i = _locate(i, id);
        if (i < 0 || resolved.isEmpty) return false;

        if (_looksLocal(resolved)) {
          _playlist[i] = _playlist[i].copyWith(filePath: resolved, isDownloaded: true);
          isFile = true;
        } else {
          _playlist[i] = _playlist[i].copyWith(audioUrl: resolved);
        }
        _invalidateQueueCache();
        source = resolved;
      }

      if (source.isEmpty) return false;

      if (isFile) {
        await player.setFilePath(source);
      } else {
        await player.setUrl(source);
      }
      return !isStale();
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // Single place that moves the "current track" pointer
  // ===========================================================================

  void _advanceTo(int index, {bool recordHistory = true}) {
    final prev = _currentIndex;

    if (_isShuffle) {
      final inSync = _shuffleIndices.length == _playlist.length;
      final wrapped = inSync &&
          _repeatMode == AppRepeatMode.all &&
          _shuffleIndices.isNotEmpty &&
          _shufflePointer == _shuffleIndices.length - 1 &&
          index == _shuffleIndices.first;
      final pos = inSync ? _shuffleIndices.indexOf(index) : -1;

      if (!inSync || wrapped || pos < 0) {
        _currentIndex = index;
        _setupShuffleIndices(); // fresh order, `index` first, history cleared
      } else {
        _shufflePointer = pos;
      }
      if (recordHistory && prev >= 0 && prev != index) {
        _historyIndices.add(prev);
      }
    }

    _currentIndex = index;
  }

  void _setupShuffleIndices() {
    _shuffleIndices.clear();
    _historyIndices.clear();
    if (_playlist.isEmpty) {
      _shufflePointer = -1;
      return;
    }
    final all = List.generate(_playlist.length, (i) => i);
    if (_validIndex(_currentIndex)) {
      all.remove(_currentIndex);
      all.shuffle(math.Random());
      _shuffleIndices.add(_currentIndex);
      _shuffleIndices.addAll(all);
    } else {
      all.shuffle(math.Random());
      _shuffleIndices.addAll(all);
    }
    _shufflePointer = 0;
  }

  void _ensureShuffle() {
    if (_isShuffle && _shuffleIndices.length != _playlist.length) {
      _setupShuffleIndices();
    }
  }

  /// [userSkip] ignores repeat-one (a manual "next" should really go next).
  int? _getNextIndex({bool userSkip = false}) {
    if (_playlist.isEmpty) return null;
    if (_repeatMode == AppRepeatMode.one && !userSkip) return _currentIndex;

    if (_isShuffle) {
      _ensureShuffle();
      if (_shufflePointer < _shuffleIndices.length - 1) {
        return _shuffleIndices[_shufflePointer + 1];
      }
      if (_repeatMode == AppRepeatMode.all) return _shuffleIndices.first;
      return null;
    }

    if (_currentIndex < _playlist.length - 1) return _currentIndex + 1;
    if (_repeatMode == AppRepeatMode.all) return 0;
    return null;
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
    if (_isShuffle) return _historyIndices.isNotEmpty || _shufflePointer > 0;
    return _currentIndex > 0;
  }

  // ===========================================================================
  // Upcoming-track logic: prebuffer, gapless, crossfade
  // ===========================================================================

  int _effectiveFadeMs(Duration duration) {
    return math.min(_crossfadeDuration * 1000, duration.inMilliseconds ~/ 2);
  }

  void _checkUpcoming(Duration position) {
    if (_isCrossfading || _activeLoading) return;
    if (!_activePlayer.playing) return;
    final duration = _activePlayer.duration;
    if (duration == null || duration <= const Duration(seconds: 4)) return;
    // Repeat-one loops in _handleTrackCompleted; nothing to prepare.
    if (_repeatMode == AppRepeatMode.one) return;

    final nextIdx = _getNextIndex();
    if (nextIdx == null || !_validIndex(nextIdx)) return;
    if (_prebufferFailedIndex == nextIdx) return; // normal load on completion

    final remaining = duration - position;
    final fadeMs = _effectiveFadeMs(duration);

    if (fadeMs > 0) {
      if (remaining <= Duration(milliseconds: fadeMs + 3000)) {
        _prebuffer(nextIdx);
      }
      if (remaining <= Duration(milliseconds: fadeMs + 300)) {
        // If the user seeked into the fade window, fade over what is left.
        final fade = math.min(fadeMs, remaining.inMilliseconds);
        if (fade >= _minFadeMs) {
          unawaited(_startCrossfade(nextIdx, fade));
          return;
        }
        // Too little time left to fade: fall through to a gapless hand-off.
      } else {
        return;
      }
    }

    if (_gaplessPlayback || fadeMs > 0) {
      if (remaining <= const Duration(seconds: 5)) _prebuffer(nextIdx);
      if (remaining <= _gaplessLead && _prebufferReadyIndex == nextIdx) {
        _gaplessHandoff(nextIdx, outgoingFinished: false);
      }
    }
  }

  void _clearPrebufferMarkers() {
    _prebufferReadyIndex = null;
    _prebufferingIndex = null;
    _prebufferFailedIndex = null;
    _prebufferFuture = null;
  }

  /// Called when the upcoming track may have changed (queue edit, shuffle or
  /// repeat toggle, settings). With [keepFade] an already-running fade is left
  /// alone; otherwise it is cancelled because its target index may be stale.
  void _invalidateUpcoming({bool keepFade = false}) {
    if (_isCrossfading) {
      if (!keepFade) _cancelCrossfade();
      return;
    }
    _deckGen++;
    _clearPrebufferMarkers();
  }

  void _prebuffer(int index) {
    if (!_validIndex(index)) return;
    if (index == _prebufferReadyIndex ||
        index == _prebufferingIndex ||
        index == _prebufferFailedIndex) {
      return;
    }
    final gen = ++_deckGen;
    _prebufferReadyIndex = null;
    _prebufferingIndex = index;
    _prebufferFuture = _runPrebuffer(index, gen);
  }

  Future<void> _runPrebuffer(int index, int gen) async {
    final ok = await _loadInto(
      _inactivePlayer,
      index,
      () => gen != _deckGen,
      stopFirst: true,
    );
    if (gen != _deckGen) return; // superseded: whoever bumped owns the state
    _prebufferingIndex = null;
    _prebufferFuture = null;
    if (ok) {
      _prebufferReadyIndex = index;
    } else {
      _prebufferFailedIndex = index; // remembered, so no retry storm
    }
  }

  void _swapDecks() {
    _deckGen++;
    final t = _activePlayer;
    _activePlayer = _inactivePlayer;
    _inactivePlayer = t;
  }

  /// Everything that must happen once a different track is actually playing.
  void _commitTrackChange(int index) {
    _advanceTo(index);
    _clearPrebufferMarkers();

    final track = _playlist[index];
    var item = _trackToMediaItem(track);
    final d = _activePlayer.duration;
    if (d != null && d > Duration.zero) item = item.copyWith(duration: d);
    mediaItem.add(item);
    _trackPlayedController.add(track);
    _syncPlaybackState();
    _emitState();
  }

  void _gaplessHandoff(int nextIndex, {required bool outgoingFinished}) {
    if (_prebufferReadyIndex != nextIndex || !_validIndex(nextIndex)) return;
    final incoming = _inactivePlayer;
    final outgoing = _activePlayer;
    _clearPrebufferMarkers();

    // Start the incoming deck first; the outgoing deck simply plays out its
    // last ~150ms (or is stopped if it already completed).
    unawaited(incoming.setVolume(1.0));
    unawaited(incoming.play());
    if (outgoingFinished) unawaited(outgoing.stop());

    _swapDecks();
    _commitTrackChange(nextIndex);
  }

  Future<void> _startCrossfade(int nextIndex, int fadeMs) async {
    if (_isCrossfading || !_validIndex(nextIndex)) return;
    if (_prebufferFailedIndex == nextIndex) return;

    _isCrossfading = true;
    _crossfadeTargetIndex = nextIndex;

    int gen;
    if (_prebufferReadyIndex == nextIndex) {
      gen = _deckGen;
    } else if (_prebufferingIndex == nextIndex && _prebufferFuture != null) {
      gen = _deckGen;
      await _prebufferFuture;
      if (gen != _deckGen || !_isCrossfading) return;
      if (_prebufferReadyIndex != nextIndex) {
        _abortCrossfadeAndKeepPlaying(nextIndex);
        return;
      }
    } else {
      gen = ++_deckGen;
      _clearPrebufferMarkers();
      final ok = await _loadInto(
        _inactivePlayer,
        nextIndex,
        () => gen != _deckGen,
        stopFirst: true,
      );
      if (gen != _deckGen || !_isCrossfading) return;
      if (!ok) {
        _abortCrossfadeAndKeepPlaying(nextIndex);
        return;
      }
    }

    // Loading may have taken a while: never fade longer than what is left.
    var fade = fadeMs;
    final dur = _activePlayer.duration;
    if (dur != null) {
      final left = (dur - _activePlayer.position).inMilliseconds;
      fade = math.max(100, math.min(fade, left));
    }

    _clearPrebufferMarkers();
    await _inactivePlayer.setVolume(0.0);
    if (gen != _deckGen || !_isCrossfading) return;

    final watch = Stopwatch();
    _fadeWatch = watch;
    // If the user paused while loading, start the fade on resume (see play()).
    if (_activePlayer.playing) {
      unawaited(_inactivePlayer.play());
      watch.start();
    }

    _crossfadeTimer?.cancel();
    _crossfadeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (gen != _deckGen) {
        timer.cancel();
        return;
      }
      final t = math.min(1.0, watch.elapsedMilliseconds / fade);
      // Equal-power curve.
      unawaited(_activePlayer.setVolume(math.max(0.0, math.cos(t * math.pi / 2))));
      unawaited(_inactivePlayer.setVolume(math.max(0.0, math.sin(t * math.pi / 2))));
      if (t >= 1.0) {
        timer.cancel();
        _completeCrossfade(nextIndex);
      }
    });
  }

  /// The incoming track could not be loaded: don't cut the current song short.
  /// Let it finish; the completion handler will try a normal load.
  void _abortCrossfadeAndKeepPlaying(int failedIndex) {
    _cancelCrossfade();
    _prebufferFailedIndex = failedIndex;
  }

  void _completeCrossfade(int nextIndex) {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _fadeWatch = null;
    _crossfadeTargetIndex = null;
    _isCrossfading = false;

    final outgoing = _activePlayer;
    unawaited(outgoing.stop());
    unawaited(outgoing.setVolume(1.0));
    unawaited(_inactivePlayer.setVolume(1.0));

    _swapDecks();
    _commitTrackChange(nextIndex);
  }

  void _cancelCrossfade() {
    _deckGen++; // invalidates any in-flight load/timer for the inactive deck
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _fadeWatch = null;
    _crossfadeTargetIndex = null;
    _isCrossfading = false;
    _clearPrebufferMarkers();
    unawaited(_activePlayer.setVolume(1.0));
    unawaited(_inactivePlayer.stop());
    unawaited(_inactivePlayer.setVolume(1.0));
  }

  Future<void> _handleTrackCompleted() async {
    if (_repeatMode == AppRepeatMode.one) {
      await _activePlayer.seek(Duration.zero);
      unawaited(_activePlayer.play());
      return;
    }

    final next = _getNextIndex();
    if (next == null) return;

    if (_prebufferReadyIndex == next) {
      _gaplessHandoff(next, outgoingFinished: true);
      return;
    }

    _advanceTo(next);
    await _playCurrentTrack();
  }

  // ===========================================================================
  // State emission
  // ===========================================================================

  List<Track>? _cachedUnmodifiableQueue;

  List<Track> get _unmodifiablePlaylist =>
      _cachedUnmodifiableQueue ??= List.unmodifiable(_playlist);

  void _invalidateQueueCache() => _cachedUnmodifiableQueue = null;

  void _emitStateThrottled() {
    if (_emitThrottle.elapsedMilliseconds >= 200) {
      _emitThrottle.reset();
      _emitState();
    }
  }

  void _emitState() {
    Track? currentTrack;
    if (_validIndex(_currentIndex)) currentTrack = _playlist[_currentIndex];

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

  // ===========================================================================
  // Playback entry points
  // ===========================================================================

  Future<void> playTrackList(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _cancelCrossfade();
    _playlist = List.from(tracks);
    _invalidateQueueCache();
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    if (_isShuffle) _setupShuffleIndices();

    queue.add(_playlist.map(_trackToMediaItem).toList());
    await playTrackAtIndex(_currentIndex);
  }

  Future<void> playTrackAtIndex(int index) async {
    if (!_validIndex(index)) return;
    _advanceTo(index);
    await _playCurrentTrack();
  }

  Future<void> _goToWithoutHistory(int index) async {
    if (!_validIndex(index)) return;
    _advanceTo(index, recordHistory: false);
    await _playCurrentTrack();
  }

  Future<void> _playCurrentTrack() async {
    if (!_validIndex(_currentIndex)) return;
    _cancelCrossfade();

    final gen = ++_activeGen;
    _activeLoading = true;

    final index = _currentIndex;
    final track = _playlist[index];
    mediaItem.add(_trackToMediaItem(track));
    _trackPlayedController.add(track);

    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.buffering,
    ));

    unawaited(_activePlayer.setVolume(1.0));
    // No stop() on the active deck: an idle state can tear down the
    // foreground notification.
    final ok = await _loadInto(
      _activePlayer,
      index,
      () => gen != _activeGen,
      stopFirst: false,
    );
    if (gen != _activeGen) return; // a newer request owns the state now
    _activeLoading = false;

    // play() only completes when playback ends/pauses: never await it here.
    if (ok) unawaited(_activePlayer.play());
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

  // ===========================================================================
  // Transport controls
  // ===========================================================================

  @override
  Future<void> play() async {
    // Resume a paused crossfade as a unit.
    if (_isCrossfading && _fadeWatch != null) {
      _fadeWatch!.start();
      unawaited(_inactivePlayer.play());
    }
    unawaited(_activePlayer.play());
  }

  @override
  Future<void> pause() async {
    _fadeWatch?.stop(); // freeze the fade clock
    await _activePlayer.pause();
    if (_isCrossfading && _fadeWatch != null) {
      await _inactivePlayer.pause();
    }
  }

  @override
  Future<void> stop() async {
    _activeGen++;
    _activeLoading = false;
    _cancelCrossfade();
    await _activePlayer.stop();
    await _inactivePlayer.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    _emitState();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    final isPlaying =
        _activePlayer.playing || (_fadeWatch != null && _inactivePlayer.playing);
    if (!isPlaying) await stop();
    await super.onTaskRemoved();
  }

  @override
  Future<void> onNotificationDeleted() async {
    await stop();
    await super.onNotificationDeleted();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isCrossfading) _cancelCrossfade();
    await _activePlayer.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;
    final next = _getNextIndex(userSkip: true);
    if (next == null) return;
    _advanceTo(next);
    await _playCurrentTrack(); // cancels any crossfade itself
  }

  @override
  Future<void> skipToPrevious() async {
    if (_isCrossfading) _cancelCrossfade();

    if (_activePlayer.position.inSeconds > 3) {
      await _activePlayer.seek(Duration.zero);
      return;
    }

    if (_isShuffle) {
      if (_historyIndices.isNotEmpty) {
        await _goToWithoutHistory(_historyIndices.removeLast());
        return;
      }
      if (_shufflePointer > 0) {
        await _goToWithoutHistory(_shuffleIndices[_shufflePointer - 1]);
        return;
      }
      await _activePlayer.seek(Duration.zero);
      return;
    }

    if (hasPrevious) {
      await _goToWithoutHistory(_currentIndex - 1);
    } else {
      await _activePlayer.seek(Duration.zero);
    }
  }

  // ===========================================================================
  // Shuffle / repeat
  // ===========================================================================

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
    _invalidateUpcoming(keepFade: true);
    _emitState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final shouldShuffle = shuffleMode != AudioServiceShuffleMode.none;
    if (_isShuffle != shouldShuffle) toggleShuffle();
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
    _invalidateUpcoming(keepFade: true);
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
    _invalidateUpcoming(keepFade: true);
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
    _invalidateUpcoming(keepFade: true);
    _emitState();
  }

  // ===========================================================================
  // Queue editing (every edit invalidates the prebuffer / running fade)
  // ===========================================================================

  void addToQueue(Track track) {
    _invalidateUpcoming();
    _playlist.add(track);
    if (_isShuffle) _shuffleIndices.add(_playlist.length - 1);
    _invalidateQueueCache();
    queue.add(_playlist.map(_trackToMediaItem).toList());
    _emitState();
  }

  void insertNextInQueue(Track track) {
    _invalidateUpcoming();
    final insertIndex = (_currentIndex + 1).clamp(0, _playlist.length);
    _playlist.insert(insertIndex, track);
    if (_isShuffle) {
      for (int i = 0; i < _shuffleIndices.length; i++) {
        if (_shuffleIndices[i] >= insertIndex) _shuffleIndices[i]++;
      }
      for (int i = 0; i < _historyIndices.length; i++) {
        if (_historyIndices[i] >= insertIndex) _historyIndices[i]++;
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
    if (!_validIndex(index)) return;
    _invalidateUpcoming();

    final wasCurrent = index == _currentIndex;
    _playlist.removeAt(index);
    _invalidateQueueCache();

    if (_isShuffle) {
      _shuffleIndices.remove(index);
      for (int i = 0; i < _shuffleIndices.length; i++) {
        if (_shuffleIndices[i] > index) _shuffleIndices[i]--;
      }
      _historyIndices.removeWhere((i) => i == index);
      for (int i = 0; i < _historyIndices.length; i++) {
        if (_historyIndices[i] > index) _historyIndices[i]--;
      }
    }

    if (index < _currentIndex) _currentIndex--;

    // Recompute the pointer only after _currentIndex has been adjusted.
    if (_isShuffle && !wasCurrent && _currentIndex >= 0) {
      _shufflePointer = _shuffleIndices.indexOf(_currentIndex);
    }

    queue.add(_playlist.map(_trackToMediaItem).toList());

    if (wasCurrent) {
      if (_playlist.isEmpty) {
        _currentIndex = -1;
        _shufflePointer = -1;
        _activeGen++;
        _activeLoading = false;
        await _activePlayer.stop();
      } else {
        await _goToWithoutHistory(_currentIndex.clamp(0, _playlist.length - 1));
      }
    }
    _emitState();
  }

  Future<void> removeTrackById(String trackId) async {
    final index = _playlist.indexWhere((t) => t.id == trackId);
    if (index != -1) await removeQueueItemAt(index);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (!_validIndex(oldIndex)) return;
    _invalidateUpcoming();
    if (oldIndex < newIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, _playlist.length - 1);

    final item = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, item);
    _invalidateQueueCache();

    // Where does a track that used to be at `i` live now?
    int remap(int i) {
      if (i == oldIndex) return newIndex;
      if (oldIndex < newIndex && i > oldIndex && i <= newIndex) return i - 1;
      if (oldIndex > newIndex && i >= newIndex && i < oldIndex) return i + 1;
      return i;
    }

    if (_currentIndex >= 0) _currentIndex = remap(_currentIndex);
    if (_isShuffle) {
      for (int i = 0; i < _shuffleIndices.length; i++) {
        _shuffleIndices[i] = remap(_shuffleIndices[i]);
      }
      for (int i = 0; i < _historyIndices.length; i++) {
        _historyIndices[i] = remap(_historyIndices[i]);
      }
    }

    queue.add(_playlist.map(_trackToMediaItem).toList());
    _emitState();
  }

  void clearQueue() {
    _activeGen++;
    _activeLoading = false;
    _cancelCrossfade();
    _playlist.clear();
    _invalidateQueueCache();
    _currentIndex = -1;
    _shuffleIndices.clear();
    _historyIndices.clear();
    _shufflePointer = -1;
    unawaited(_activePlayer.stop());
    unawaited(_inactivePlayer.stop());
    queue.add([]);
    _emitState();
  }

  Future<void> dispose() async {
    _activeGen++;
    _deckGen++;
    _crossfadeTimer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _activePlayer.dispose();
    await _inactivePlayer.dispose();
    await _playerStateController.close();
    await _trackPlayedController.close();
  }
}