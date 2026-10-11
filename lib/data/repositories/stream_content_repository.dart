import 'dart:async';
import 'package:musify/data/sources/saavn_source_adapter.dart';
import 'package:musify/domain/models/search_result_models.dart';
import 'package:musify/domain/models/stream_home_models.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/repositories/audio_repository.dart';

class StreamContentRepository {
  final SaavnSourceAdapter _saavn;
  final AudioRepository _audioRepo;

  StreamHomepageData? _cachedHomepageData;
  DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(minutes: 15);

  final Map<String, ({StreamPlaylistDetails details, DateTime timestamp})> _playlistCache = {};
  final Map<String, ({List<Track> tracks, DateTime timestamp})> _genreTracksCache = {};
  final Map<String, ({List<SearchArtistItem> artists, DateTime timestamp})> _artistsCategoryCache = {};
  final Map<String, ({List<SearchAlbumItem> albums, DateTime timestamp})> _soundtracksCategoryCache = {};

  StreamContentRepository({
    required SaavnSourceAdapter saavnAdapter,
    required AudioRepository audioRepository,
  })  : _saavn = saavnAdapter,
        _audioRepo = audioRepository;

  bool get _isCacheValid {
    if (_cachedHomepageData == null || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheTtl;
  }

  /// Fetches complete homepage data bundle, utilizing in-memory cache if fresh.
  Future<StreamHomepageData> getHomepageData({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid && _cachedHomepageData != null) {
      return _cachedHomepageData!;
    }

    try {
      // 1. Fetch recently played tracks from database (streaming or local history)
      List<Track> recentHistory = [];
      try {
        recentHistory = await _audioRepo.getRecentlyPlayedTracks(limit: 15);
      } catch (_) {}

      // 2. Fetch all streaming sections concurrently
      final trendingFuture = _saavn.getTrendingTracks(limit: 20);
      final newReleasesFuture = _saavn.getNewReleases(limit: 15);
      final popularArtistsFuture = _saavn.getPopularArtists();
      final movieAlbumsFuture = _saavn.getPopularMovieAlbums(count: 12);
      final topChartsFuture = _saavn.getTopCharts();
      final editorialPlaylistsFuture = _saavn.getEditorialPlaylists();

      final results = await Future.wait([
        trendingFuture,
        newReleasesFuture,
        popularArtistsFuture,
        movieAlbumsFuture,
        topChartsFuture,
        editorialPlaylistsFuture,
      ]);

      final trending = results[0] as List<Track>;
      final newReleases = results[1] as List<SearchAlbumItem>;
      final popularArtists = results[2] as List<SearchArtistItem>;
      final movieAlbums = results[3] as List<SearchAlbumItem>;
      final topCharts = results[4] as List<TopChartItem>;
      final editorialPlaylists = results[5] as List<SearchPlaylistItem>;

      // Quick Picks: take a mix of top trending tracks + recent history if available
      final quickPicks = <Track>[];
      final seenTrackIds = <String>{};
      for (final t in recentHistory) {
        if (seenTrackIds.add(t.id)) quickPicks.add(t);
        if (quickPicks.length >= 6) break;
      }
      for (final t in trending) {
        if (seenTrackIds.add(t.id)) quickPicks.add(t);
        if (quickPicks.length >= 8) break;
      }

      final homepageData = StreamHomepageData(
        quickPicks: quickPicks,
        recentlyPlayed: recentHistory,
        trendingTracks: trending,
        newReleases: newReleases,
        popularArtists: popularArtists,
        movieAlbums: movieAlbums,
        topCharts: topCharts,
        moodCategories: SaavnSourceAdapter.getMoodCategories(),
        editorialPlaylists: editorialPlaylists,
        fetchedAt: DateTime.now(),
      );

      _cachedHomepageData = homepageData;
      _lastFetchTime = DateTime.now();

      return homepageData;
    } catch (_) {
      // If error occurs, fallback to cached data if available, otherwise return empty
      if (_cachedHomepageData != null) return _cachedHomepageData!;
      return StreamHomepageData(
        moodCategories: SaavnSourceAdapter.getMoodCategories(),
      );
    }
  }

  /// Fetches playlist details with cache
  Future<StreamPlaylistDetails?> getPlaylistDetails(String playlistId, {bool forceRefresh = false}) async {
    final cached = _playlistCache[playlistId];
    if (!forceRefresh && cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      return cached.details;
    }

    final details = await _saavn.getPlaylistDetails(playlistId);
    if (details != null) {
      _playlistCache[playlistId] = (details: details, timestamp: DateTime.now());
    }
    return details;
  }

  /// Fetches tracks for a mood or genre
  Future<List<Track>> getTracksForMood(String query, {bool forceRefresh = false}) async {
    final cached = _genreTracksCache[query];
    if (!forceRefresh && cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      return cached.tracks;
    }

    final tracks = await _saavn.search(query, limit: 25);
    if (tracks.isNotEmpty) {
      _genreTracksCache[query] = (tracks: tracks, timestamp: DateTime.now());
    }
    return tracks;
  }

  /// Fetches artists filtered by language/type category with in-memory caching and pagination
  Future<List<SearchArtistItem>> getArtistsByCategory(
    String category, {
    int page = 1,
    int limit = 18,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${category}_p$page';
    final cached = _artistsCategoryCache[cacheKey];
    if (!forceRefresh && cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      return cached.artists;
    }

    final artists = await _saavn.getArtistsByCategory(category, page: page, limit: limit);
    if (artists.isNotEmpty) {
      _artistsCategoryCache[cacheKey] = (artists: artists, timestamp: DateTime.now());
    }
    return artists;
  }

  /// Fetches movie soundtrack albums filtered by category with in-memory caching and pagination
  Future<List<SearchAlbumItem>> getMovieSoundtracksByCategory(
    String category, {
    int page = 1,
    int limit = 18,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${category}_p$page';
    final cached = _soundtracksCategoryCache[cacheKey];
    if (!forceRefresh && cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      return cached.albums;
    }

    final albums = await _saavn.getMovieSoundtracksByCategory(category, page: page, limit: limit);
    if (albums.isNotEmpty) {
      _soundtracksCategoryCache[cacheKey] = (albums: albums, timestamp: DateTime.now());
    }
    return albums;
  }

  /// Clears in-memory caches
  void clearCache() {
    _cachedHomepageData = null;
    _lastFetchTime = null;
    _playlistCache.clear();
    _genreTracksCache.clear();
    _artistsCategoryCache.clear();
    _soundtracksCategoryCache.clear();
  }
}

