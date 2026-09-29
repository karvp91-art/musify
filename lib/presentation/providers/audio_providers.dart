import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/data/database/app_database.dart' hide Playlist;
import 'package:musify/data/repositories/audio_repository_impl.dart';
import 'package:musify/data/repositories/local_files_scanner.dart';
import 'package:musify/data/repositories/search_history_repository.dart';
import 'package:musify/data/sources/local_source_adapter.dart';
import 'package:musify/data/sources/saavn_source_adapter.dart';
import 'package:musify/data/sources/source_router.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/models/track_sort_option.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import 'package:musify/services/audio_player_handler.dart';

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
  return SaavnSourceAdapter();
});

final sourceRouterProvider = Provider<SourceRouter>((ref) {
  final repo = ref.watch(audioRepositoryProvider);
  final saavn = ref.watch(saavnAdapterProvider);
  final router = SourceRouter();
  router.registerAdapter(LocalSourceAdapter(repo));
  router.registerAdapter(saavn);
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

// Sort Option Notifier
class LocalTrackSortNotifier extends Notifier<TrackSortOption> {
  @override
  TrackSortOption build() => TrackSortOption.recentlyAdded;

  void setSortOption(TrackSortOption option) => state = option;
}

final localTrackSortOptionProvider = NotifierProvider<LocalTrackSortNotifier, TrackSortOption>(
  LocalTrackSortNotifier.new,
);

// Raw Local Tracks Provider (all tracks from DB)
final localTracksProvider = FutureProvider<List<Track>>((ref) async {
  final repo = ref.watch(audioRepositoryProvider);
  return repo.getLocalTracks();
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

// Playlists Stream Provider
final playlistsStreamProvider = StreamProvider<List<Playlist>>((ref) {
  final repo = ref.watch(audioRepositoryProvider);
  return repo.watchPlaylists();
});

// Navigation Bar Tab Index
class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final currentTabIndexProvider = NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);

// App Theme Mode Provider
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void setThemeMode(ThemeMode mode) => state = mode;
  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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


