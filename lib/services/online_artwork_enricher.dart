import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';

/// Intelligent background service that detects local music tracks without album artwork,
/// queries online music catalogs (JioSaavn) using cleaned title/artist metadata, and
/// updates SQLite so high-definition 500x500 cover art appears automatically in Musify.
class OnlineArtworkEnricher {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://www.jiosaavn.com/api.php',
      connectTimeout: const Duration(seconds: 7),
      receiveTimeout: const Duration(seconds: 7),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
      },
    ),
  );

  /// In-memory cache of track IDs attempted during this app session to avoid redundant queries
  static final Set<String> _sessionAttemptedTrackIds = {};
  static bool _isBatchRunning = false;

  /// Sanitizes track titles by removing remix tags, speed modifiers, bracketed labels, and extensions
  static String cleanTitleForSearch(String rawTitle) {
    var title = rawTitle.trim();

    // Strip audio file extensions if present
    title = title.replaceAll(RegExp(r'\.(mp3|m4a|flac|wav|aac|ogg|opus)$', caseSensitive: false), '');

    // Strip common bracketed modifiers like (Ultra Slowed), (Slowed + Reverb), (Official Audio), [8D Audio]
    title = title.replaceAll(
      RegExp(
        r'\s*[\(\[](?:ultra\s*)?(?:slowed|reverb|official|lyrics|remix|bass\s*boosted|8d|music\s*video|audio|extended|clean|explicit|version|mix|sped\s*up)[^\)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );

    // Strip trailing hashtags or junk
    title = title.replaceAll(RegExp(r'#\w+'), '');

    // Clean whitespace
    return title.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Searches JioSaavn for the official cover artwork corresponding to a local track
  static Future<String?> fetchArtworkUrl(Track track) async {
    final cleanTitle = cleanTitleForSearch(track.title);
    if (cleanTitle.isEmpty) return null;

    final hasArtist = track.artistName.trim().isNotEmpty &&
        track.artistName.trim().toLowerCase() != 'unknown artist';

    // 1. Try search with Title + Artist
    String? artworkUrl;
    if (hasArtist) {
      artworkUrl = await _queryJioSaavn('$cleanTitle ${track.artistName}');
    }

    // 2. Fallback: Search with cleaned Title alone if first attempt produced nothing
    artworkUrl ??= await _queryJioSaavn(cleanTitle);

    return artworkUrl;
  }

  static Future<String?> _queryJioSaavn(String query) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'search.getResults',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'n': 3,
          'p': 1,
          'q': query.trim(),
        },
      );

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          return null;
        }
      }

      if (data is! Map<String, dynamic>) return null;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      for (final item in results) {
        if (item is Map<String, dynamic>) {
          var image = item['image'] as String?;
          if (image != null && image.isNotEmpty && !TrackArtwork.isPlaceholderUrl(image)) {
            // Upgrade resolution to 500x500 high-definition artwork
            return image
                .replaceAll('150x150', '500x500')
                .replaceAll('50x50', '500x500');
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Enriches a single track by fetching online cover art and saving it to the SQLite database
  static Future<bool> enrichTrack(Track track, AudioRepository repository) async {
    // If track already has real artwork, nothing to enrich
    if (track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        !TrackArtwork.isPlaceholderUrl(track.artworkUrl)) {
      return false;
    }

    final artworkUrl = await fetchArtworkUrl(track);
    if (artworkUrl != null && artworkUrl.isNotEmpty) {
      await repository.updateTrackArtwork(track.id, artworkUrl);
      return true;
    }
    return false;
  }

  /// Silently enriches all local tracks in the background that are missing album artwork
  static Future<int> enrichMissingArtworksBatch(
    List<Track> tracks,
    AudioRepository repository, {
    void Function(int updatedCount)? onProgress,
  }) async {
    if (_isBatchRunning) return 0;
    _isBatchRunning = true;

    int updatedCount = 0;
    try {
      // Find candidate music tracks (exclude auxiliary voice notes, recordings, and ringtones)
      final candidates = tracks.where((t) {
        if (!t.isLocal || t.isAudioClip) return false;
        if (_sessionAttemptedTrackIds.contains(t.id)) return false;
        final art = t.artworkUrl;
        return art == null || art.trim().isEmpty || TrackArtwork.isPlaceholderUrl(art);
      }).toList();

      for (final track in candidates) {
        _sessionAttemptedTrackIds.add(track.id);

        final artworkUrl = await fetchArtworkUrl(track);
        if (artworkUrl != null && artworkUrl.isNotEmpty) {
          await repository.updateTrackArtwork(track.id, artworkUrl);
          updatedCount++;
          onProgress?.call(updatedCount);
        }

        // Polite delay to prevent rate limiting
        await Future.delayed(const Duration(milliseconds: 180));
      }
    } catch (_) {
    } finally {
      _isBatchRunning = false;
    }

    return updatedCount;
  }

  /// Helper to trigger silent background enrichment using Riverpod WidgetRef
  static void triggerBackgroundEnrichment(WidgetRef ref) {
    Future.microtask(() async {
      final repo = ref.read(audioRepositoryProvider);
      final tracks = await repo.getLocalTracks();
      await enrichMissingArtworksBatch(tracks, repo);
    });
  }
}
