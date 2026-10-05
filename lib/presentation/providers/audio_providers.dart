import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musify/data/database/app_database.dart' hide Playlist;
import 'package:musify/data/repositories/audio_repository_impl.dart';
import 'package:musify/data/repositories/local_files_scanner.dart';
import 'package:musify/data/repositories/search_history_repository.dart';
import 'package:musify/data/sources/local_source_adapter.dart';
import 'package:musify/data/sources/saavn_source_adapter.dart';
import 'package:musify/data/sources/youtube_source_adapter.dart';
import 'package:musify/data/sources/source_router.dart';
import 'package:musify/data/repositories/lyrics_repository.dart';
import 'package:musify/domain/models/lyrics.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/models/track_sort_option.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import 'package:musify/services/audio_player_handler.dart';
import 'package:musify/services/download_manager.dart';
import 'package:musify/services/preferences_service.dart';

import 'package:musify/domain/models/equalizer_state.dart';
import 'package:musify/domain/models/search_result_models.dart';
import 'package:musify/domain/models/artist_details.dart';
import 'package:musify/domain/models/album_details.dart';
import 'package:path/path.dart' as p;
import 'package:musify/domain/models/music_folder.dart';
import 'package:musify/services/palette_service.dart';
export 'package:musify/domain/models/equalizer_state.dart';
export 'package:musify/domain/models/search_result_models.dart';
export 'package:musify/domain/models/artist_details.dart';
export 'package:musify/domain/models/album_details.dart';
export 'package:musify/domain/models/music_folder.dart';
export 'package:musify/services/preferences_service.dart';
export 'package:musify/services/palette_service.dart';

// Download Manager Provider
final downloadManagerProvider = Provider<AudioDownloadManager>((ref) {
  final repo = ref.watch(audioRepositoryProvider);
  final saavn = ref.watch(saavnAdapterProvider);
  final youtube = ref.watch(youtubeAdapterProvider);
  final router = ref.watch(sourceRouterProvider);
  final manager = AudioDownloadManager(
    repo: repo,
    saavnAdapter: saavn,
    youtubeAdapter: youtube,
    sourceRouter: router,
  );
  ref.onDispose(() => manager.dispose());
  return manager;
});

// Database & Core Providers
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AudioRepositoryImpl(db);
});

final localScannerProvider = Provider<LocalFilesScanner>((ref) {
  final db = ref.watch(databaseProvider);
  return LocalFilesScanner(db);
});

final saavnAdapterProvider = Provider<SaavnSourceAdapter>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return SaavnSourceAdapter(preferencesService: prefs);
});

final youtubeAdapterProvider = Provider<YouTubeSourceAdapter>((ref) {
  final saavn = ref.watch(saavnAdapterProvider);
  final repo = ref.watch(audioRepositoryProvider);
  final adapter = YouTubeSourceAdapter(saavnAdapter: saavn, repo: repo);
  ref.onDispose(() => adapter.close());
  return adapter;
});

final sourceRouterProvider = Provider<SourceRouter>((ref) {
  final repo = ref.watch(audioRepositoryProvider);
  final saavn = ref.watch(saavnAdapterProvider);
  final youtube = ref.watch(youtubeAdapterProvider);
  final router = SourceRouter();
  router.registerAdapter(LocalSourceAdapter(repo));
  router.registerAdapter(saavn);
  router.registerAdapter(youtube);

  // Connect lazy audio stream resolution to MusifyAudioHandler
  final audioHandler = ref.read(audioHandlerProvider);
  audioHandler.setTrackUrlResolver((track) => router.resolvePlayUrl(track));

  return router;
});

final saavnTrendingTracksProvider = FutureProvider<List<Track>>((ref) async {
  final saavn = ref.watch(saavnAdapterProvider);
  return saavn.getTrendingTracks(limit: 15);
});

final saavnGenreTracksProvider = FutureProvider.family<List<Track>, String>((ref, genre) async {
  final saavn = ref.watch(saavnAdapterProvider);
  return saavn.getTracksByGenre(genre, limit: 15);
});

final saavnMultiSearchProvider = FutureProvider.family<SearchMultiResult, String>((ref, query) async {
  final saavn = ref.watch(saavnAdapterProvider);
  return saavn.searchMulti(query);
});

final saavnArtistDetailsProvider = FutureProvider.family<ArtistDetails?, String>((ref, artistId) async {
  final saavn = ref.watch(saavnAdapterProvider);
  return saavn.getArtistDetails(artistId);
});

final saavnAlbumDetailsProvider = FutureProvider.family<AlbumDetails?, String>((ref, albumId) async {
  final saavn = ref.watch(saavnAdapterProvider);
  return saavn.getAlbumDetails(albumId);
});

// Audio Handler (Global Audio Service singleton injected at startup)
final audioHandlerProvider = Provider<MusifyAudioHandler>((ref) {
  throw UnimplementedError('MusifyAudioHandler must be overridden in main() ProviderScope');
});

// Player State Stream Provider
final playerStateStreamProvider = StreamProvider<PlayerStateModel>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playerStateStream;
});

// Granular Selectors to prevent rebuilds on position stream ticks
final currentPlayingTrackIdProvider = Provider<String?>((ref) {
  final playerState = ref.watch(playerStateStreamProvider).value;
  return playerState?.currentTrack?.id;
});

final currentPlayingTrackProvider = Provider<Track?>((ref) {
  final playerState = ref.watch(playerStateStreamProvider).value;
  return playerState?.currentTrack;
});

final isPlaybackPlayingProvider = Provider<bool>((ref) {
  final playerState = ref.watch(playerStateStreamProvider).value;
  return playerState?.isPlaying ?? false;
});

// Play counts from listening history
final trackPlayCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final repo = ref.watch(audioRepositoryProvider);
  final handler = ref.watch(audioHandlerProvider);

  final sub = handler.trackPlayedStream.listen((track) {
    repo.recordTrackPlay(track);
  });
  ref.onDispose(() => sub.cancel());

  return repo.watchTrackPlayCounts();
});

// Sort Option Notifier (persisted across sessions)
class LocalTrackSortNotifier extends Notifier<TrackSortOption> {
  @override
  TrackSortOption build() {
    final service = ref.watch(preferencesServiceProvider);
    return service.getTrackSortOption();
  }

  Future<void> setSortOption(TrackSortOption option) async {
    state = option;
    final service = ref.read(preferencesServiceProvider);
    await service.setTrackSortOption(option);
  }
}

final localTrackSortOptionProvider = NotifierProvider<LocalTrackSortNotifier, TrackSortOption>(
  LocalTrackSortNotifier.new,
);

// Raw Local Tracks Provider (reactive stream of all local and downloaded tracks from DB)
final localTracksProvider = StreamProvider<List<Track>>((ref) {
  final repo = ref.watch(audioRepositoryProvider);
  return repo.watchLocalTracks();
});

// Sorted Local Tracks Provider (reactive to sort option and play counts)
final sortedLocalTracksProvider = Provider<AsyncValue<List<Track>>>((ref) {
  final localTracksAsync = ref.watch(localTracksProvider);
  final sortOption = ref.watch(localTrackSortOptionProvider);
  // Only watch trackPlayCountsProvider if the user actually sorts by mostPlayed
  final playCounts = sortOption == TrackSortOption.mostPlayed
      ? (ref.watch(trackPlayCountsProvider).value ?? const {})
      : const <String, int>{};

  return localTracksAsync.whenData((tracks) {
    return sortOption.sortTracks(tracks, playCounts: playCounts);
  });
});

// Liked Tracks Stream Provider
final likedTracksStreamProvider = StreamProvider<List<Track>>((ref) {
  final repo = ref.watch(audioRepositoryProvider);
  return repo.watchLikedTracks();
});

// Derived Set<String> of liked track IDs for O(1) lookup in list tiles.
// Each tile watches `.select((ids) => ids.contains(trackId))` so only the
// specific tile whose liked-state actually changed will rebuild.
final likedTrackIdsProvider = Provider<Set<String>>((ref) {
  final likedTracks = ref.watch(likedTracksStreamProvider).value;
  if (likedTracks == null) return const {};
  return {for (final t in likedTracks) t.id};
});

// Playlists Stream Provider
final playlistsStreamProvider = StreamProvider<List<Playlist>>((ref) {
  final repo = ref.watch(audioRepositoryProvider);
  return repo.watchPlaylists();
});

// Playlist Tracks Stream Provider (reacts in real-time to adds, removes, and reorders)
final playlistTracksProvider = StreamProvider.family<List<Track>, String>((ref, playlistId) {
  final repo = ref.watch(audioRepositoryProvider);
  return repo.watchPlaylistTracks(playlistId);
});

// Navigation Bar Tab Index
class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final currentTabIndexProvider = NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);

// Preferences Providers
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});

// Theme Preference Notifier (tracks user selection: system, light, dark, autoTime)
class ThemePreferenceNotifier extends Notifier<AppThemePreference> {
  @override
  AppThemePreference build() {
    final service = ref.watch(preferencesServiceProvider);
    return service.getThemePreference();
  }

  Future<void> setPreference(AppThemePreference pref) async {
    state = pref;
    final service = ref.read(preferencesServiceProvider);
    await service.setThemePreference(pref);
    ref.read(themeModeProvider.notifier).syncTheme();
  }
}

final themePreferenceProvider = NotifierProvider<ThemePreferenceNotifier, AppThemePreference>(
  ThemePreferenceNotifier.new,
);

// App Theme Mode Provider (resolves effective ThemeMode for MaterialApp with time-based switching)
class ThemeModeNotifier extends Notifier<ThemeMode> with WidgetsBindingObserver {
  Timer? _periodicTimer;

  @override
  ThemeMode build() {
    // Listen for lifecycle changes to refresh time-based theme when coming to foreground
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _periodicTimer?.cancel();
    });

    // Periodic check every 30 seconds for seamless transition between day and night in autoTime mode
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAutoTimeTransition();
    });

    final service = ref.watch(preferencesServiceProvider);
    final pref = service.getThemePreference();
    return service.resolveThemeMode(pref);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAutoTimeTransition();
    }
  }

  void _checkAutoTimeTransition() {
    final service = ref.read(preferencesServiceProvider);
    final pref = service.getThemePreference();
    if (pref == AppThemePreference.autoTime) {
      final expected = service.resolveThemeMode(AppThemePreference.autoTime);
      if (state != expected) {
        state = expected;
      }
    }
  }

  /// Recalculates and updates the effective ThemeMode from preferences
  void syncTheme() {
    final service = ref.read(preferencesServiceProvider);
    final pref = service.getThemePreference();
    state = service.resolveThemeMode(pref);
  }

  /// Updates the theme preference and recalculates the active ThemeMode
  Future<void> setThemePreference(AppThemePreference pref) async {
    final service = ref.read(preferencesServiceProvider);
    await service.setThemePreference(pref);
    ref.read(themePreferenceProvider.notifier).state = pref;
    state = service.resolveThemeMode(pref);
  }

  /// Updates custom day / night start hours for auto mode
  Future<void> setDayNightSchedule({
    required TimeOfDay dayStart,
    required TimeOfDay nightStart,
  }) async {
    final service = ref.read(preferencesServiceProvider);
    await service.setDayStartTime(dayStart);
    await service.setNightStartTime(nightStart);
    syncTheme();
  }

  /// Direct theme mode setter (updates underlying preference)
  void setThemeMode(ThemeMode mode) {
    final pref = mode == ThemeMode.light
        ? AppThemePreference.light
        : (mode == ThemeMode.dark ? AppThemePreference.dark : AppThemePreference.system);
    setThemePreference(pref);
  }

  /// Toggle between light and dark
  Future<void> toggleTheme() async {
    final nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final nextPref = nextMode == ThemeMode.light ? AppThemePreference.light : AppThemePreference.dark;
    await setThemePreference(nextPref);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Search History Provider
final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>((ref) {
  return SearchHistoryRepositoryImpl();
});

class SearchHistoryNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final repo = ref.watch(searchHistoryRepositoryProvider);
    return repo.getSearchHistory();
  }

  Future<void> addQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final repo = ref.read(searchHistoryRepositoryProvider);
    await repo.addSearchQuery(trimmed);
    state = AsyncData(await repo.getSearchHistory());
  }

  Future<void> removeQuery(String query) async {
    final repo = ref.read(searchHistoryRepositoryProvider);
    await repo.removeSearchQuery(query);
    state = AsyncData(await repo.getSearchHistory());
  }

  Future<void> clearAll() async {
    final repo = ref.read(searchHistoryRepositoryProvider);
    await repo.clearSearchHistory();
    state = const AsyncData([]);
  }
}

final searchHistoryProvider = AsyncNotifierProvider<SearchHistoryNotifier, List<String>>(
  SearchHistoryNotifier.new,
);

class ScanProgressNotifier extends Notifier<ScanProgress?> {
  @override
  ScanProgress? build() => null;
  void setProgress(ScanProgress? progress) => state = progress;
}

final scanProgressProvider = NotifierProvider<ScanProgressNotifier, ScanProgress?>(ScanProgressNotifier.new);

class IsScanningNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setScanning(bool scanning) => state = scanning;
}

final isScanningProvider = NotifierProvider<IsScanningNotifier, bool>(IsScanningNotifier.new);

// Lyrics Providers
final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  final saavn = ref.watch(saavnAdapterProvider);
  return LyricsRepository(saavnAdapter: saavn);
});

final currentTrackLyricsProvider = FutureProvider<Lyrics?>((ref) async {
  final track = ref.watch(currentPlayingTrackProvider);
  if (track == null) return null;
  final repo = ref.watch(lyricsRepositoryProvider);
  return repo.getLyrics(track);
});

class IsMultiSelectionModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setMode(bool active) => state = active;
}

final isMultiSelectionModeProvider =
    NotifierProvider<IsMultiSelectionModeNotifier, bool>(IsMultiSelectionModeNotifier.new);

// Equalizer State Notifier
class EqualizerNotifier extends Notifier<EqualizerState> {
  @override
  EqualizerState build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return EqualizerState(
      isEnabled: prefs.getEqualizerEnabled(),
      preset: prefs.getEqualizerPreset(),
      bandGains: prefs.getEqualizerBandGains(),
      bassBoost: prefs.getEqualizerBassBoost(),
      virtualizer: prefs.getEqualizerVirtualizer(),
      loudness: prefs.getEqualizerLoudness(),
    );
  }

  void _applyToHandler(EqualizerState next) {
    state = next;
    final prefs = ref.read(preferencesServiceProvider);
    prefs.setEqualizerEnabled(next.isEnabled);
    prefs.setEqualizerPreset(next.preset);
    prefs.setEqualizerBandGains(next.bandGains);
    prefs.setEqualizerBassBoost(next.bassBoost);
    prefs.setEqualizerVirtualizer(next.virtualizer);
    prefs.setEqualizerLoudness(next.loudness);

    try {
      ref.read(audioHandlerProvider).applyEqualizerSettings(
        enabled: next.isEnabled,
        bandGains: next.bandGains,
        bassBoost: next.bassBoost,
        loudness: next.loudness,
      );
    } catch (_) {}
  }

  void setEnabled(bool enabled) {
    _applyToHandler(state.copyWith(isEnabled: enabled));
  }

  void setPreset(String presetName) {
    final gains = EqualizerPresets.presets[presetName] ?? state.bandGains;
    _applyToHandler(state.copyWith(
      preset: presetName,
      bandGains: List.from(gains),
    ));
  }

  void setBandGain(int bandIndex, double gain) {
    if (bandIndex < 0 || bandIndex >= state.bandGains.length) return;
    final updated = List<double>.from(state.bandGains);
    updated[bandIndex] = gain;
    _applyToHandler(state.copyWith(
      preset: 'Custom',
      bandGains: updated,
    ));
  }

  void setBassBoost(double value) {
    _applyToHandler(state.copyWith(bassBoost: value.clamp(0.0, 1.0)));
  }

  void setVirtualizer(double value) {
    _applyToHandler(state.copyWith(virtualizer: value.clamp(0.0, 1.0)));
  }

  void setLoudness(double value) {
    _applyToHandler(state.copyWith(loudness: value.clamp(0.0, 1.0)));
  }

  void resetToFlat() {
    _applyToHandler(state.copyWith(
      preset: 'Normal',
      bandGains: const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      bassBoost: 0.0,
      virtualizer: 0.0,
      loudness: 0.0,
    ));
  }
}

final equalizerProvider = NotifierProvider<EqualizerNotifier, EqualizerState>(
  EqualizerNotifier.new,
);

// Crossfade Duration Notifier (0s = Off / Gapless, 1s - 10s)
class CrossfadeNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return prefs.getCrossfadeDuration();
  }

  void setDuration(int seconds) {
    final clamped = seconds.clamp(0, 10);
    state = clamped;
    ref.read(preferencesServiceProvider).setCrossfadeDuration(clamped);
    try {
      ref.read(audioHandlerProvider).setCrossfadeDuration(clamped);
    } catch (_) {}
  }
}

final crossfadeProvider = NotifierProvider<CrossfadeNotifier, int>(
  CrossfadeNotifier.new,
);

// Gapless Playback Notifier
class GaplessPlaybackNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return prefs.getGaplessPlayback();
  }

  void setEnabled(bool enabled) {
    state = enabled;
    ref.read(preferencesServiceProvider).setGaplessPlayback(enabled);
    try {
      ref.read(audioHandlerProvider).setGaplessPlayback(enabled);
    } catch (_) {}
  }
}

final gaplessPlaybackProvider = NotifierProvider<GaplessPlaybackNotifier, bool>(
  GaplessPlaybackNotifier.new,
);

// Audio Quality Notifier ('320k', '256k', '160k', '96k')
class AudioQualityNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return prefs.getAudioQuality();
  }

  void setQuality(String quality) {
    state = quality;
    ref.read(preferencesServiceProvider).setAudioQuality(quality);
  }
}

final audioQualityProvider = NotifierProvider<AudioQualityNotifier, String>(
  AudioQualityNotifier.new,
);

// Music Folders Provider
final musicFoldersProvider = Provider<List<MusicFolder>>((ref) {
  final tracksAsync = ref.watch(localTracksProvider);
  final tracks = tracksAsync.value ?? [];

  final Map<String, List<Track>> folderMap = {};
  for (final track in tracks) {
    if (track.filePath != null && track.filePath!.isNotEmpty) {
      final dir = p.dirname(track.filePath!);
      folderMap.putIfAbsent(dir, () => []).add(track);
    }
  }

  final folders = folderMap.entries.map((entry) {
    final folderPath = entry.key;
    final folderTracks = entry.value;
    final name = p.basename(folderPath);
    final totalSize = folderTracks.fold<int>(0, (sum, t) => sum + t.fileSizeBytes);
    return MusicFolder(
      path: folderPath,
      name: name.isEmpty ? 'Internal Storage' : name,
      tracks: folderTracks,
      totalSizeBytes: totalSize,
    );
  }).toList();

  folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return folders;
});

// Palette Provider for Dynamic Artwork Coloring
final paletteServiceProvider = Provider<PaletteService>((ref) {
  return PaletteService.instance;
});

final trackPaletteProvider = FutureProvider.family<MiniPlayerPalette, ({Track track, bool isDark})>((ref, args) async {
  final service = ref.watch(paletteServiceProvider);
  return service.getPaletteForTrack(args.track, isDark: args.isDark);
});





