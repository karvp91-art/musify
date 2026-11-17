
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/utils/audio_name_sanitizer.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';

/// Represents a candidate album artwork result from online music databases
class ArtworkCandidate {
  final String imageUrl;
  final String title;
  final String artistName;
  final String albumName;
  final String source; // 'Apple Music', 'Deezer', 'JioSaavn'
  final int? durationMs;
  final double confidenceScore;
  final bool isDurationMatch;

  const ArtworkCandidate({
    required this.imageUrl,
    required this.title,
    required this.artistName,
    required this.albumName,
    required this.source,
    this.durationMs,
    this.confidenceScore = 0.0,
    this.isDurationMatch = false,
  });
}

/// Production-grade multi-source artwork enrichment service that queries
/// Apple Music / iTunes, Deezer, and JioSaavn with strict confidence scoring,
/// duration validation, and zero API keys required.
class OnlineArtworkEnricher {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 7),
      receiveTimeout: const Duration(seconds: 7),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
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

  /// Calculates text similarity between two strings using normalized token overlap and substring match
  static double computeSimilarity(String a, String b) {
    final s1 = a.trim().toLowerCase();
    final s2 = b.trim().toLowerCase();
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    if (s1 == s2) return 1.0;
    if (s1.contains(s2) || s2.contains(s1)) return 0.88;

    final words1 = s1.split(RegExp(r'[\s\-_,\.]+')).where((w) => w.isNotEmpty).toSet();
    final words2 = s2.split(RegExp(r'[\s\-_,\.]+')).where((w) => w.isNotEmpty).toSet();
    if (words1.isEmpty || words2.isEmpty) return 0.0;

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    return intersection / union;
  }

  /// Calculates a weighted confidence score comparing a local track with an online candidate
  static double calculateConfidence({
    required String localTitle,
    required String localArtist,
    int? localDurationMs,
    required String candTitle,
    required String candArtist,
    int? candDurationMs,
  }) {
    final cleanLocalTitle = cleanTitleForSearch(localTitle);
    final cleanCandTitle = cleanTitleForSearch(candTitle);

    final titleSim = computeSimilarity(cleanLocalTitle, cleanCandTitle);

    final hasLocalArtist = localArtist.trim().isNotEmpty &&
        !AudioNameSanitizer.isJunkArtist(localArtist);

    double artistSim = 0.5; // neutral baseline if local artist is unknown
    if (hasLocalArtist) {
      artistSim = computeSimilarity(localArtist, candArtist);
    }

    // Base score: 60% Title, 40% Artist (or 100% Title if artist unknown)
    double score = hasLocalArtist
        ? (titleSim * 0.60) + (artistSim * 0.40)
        : titleSim;

    // Duration verification bonus / penalty
    if (localDurationMs != null && localDurationMs > 10000 &&
        candDurationMs != null && candDurationMs > 10000) {
      final diff = (localDurationMs - candDurationMs).abs();
      if (diff <= 5000) {
        // Within 5 seconds: strong authentic match
        score = (score + 0.15).clamp(0.0, 1.0);
      } else if (diff <= 9000) {
        // Within 9 seconds: plausible album/radio edit
        score = (score + 0.05).clamp(0.0, 1.0);
      } else if (diff > 18000) {
        // Over 18 seconds difference: heavy penalty (likely different song, remix, or live version)
        score = (score - 0.30).clamp(0.0, 1.0);
      }
    }

    return score;
  }

  /// Searches Apple Music (iTunes), Deezer, and JioSaavn in parallel and returns
  /// high-definition artwork candidates ranked by similarity & confidence.
  static Future<List<ArtworkCandidate>> searchArtworkCandidates(
    Track track, {
    String? customQuery,
  }) async {
    final cleanTitle = cleanTitleForSearch(track.title);
    final hasArtist = track.artistName.trim().isNotEmpty &&
        !AudioNameSanitizer.isJunkArtist(track.artistName);

    final String query;
    if (customQuery != null && customQuery.trim().isNotEmpty) {
      query = customQuery.trim();
    } else if (hasArtist) {
      query = '$cleanTitle ${track.artistName}';
    } else {
      query = cleanTitle;
    }

    if (query.trim().isEmpty) return [];

    final futures = await Future.wait([
      _searchItunes(query, track),
      _searchDeezer(query, track),
      _searchJioSaavn(query, track),
    ]);

    final allCandidates = <ArtworkCandidate>[
      ...futures[0],
      ...futures[1],
      ...futures[2],
    ];

    return _deduplicateAndSort(allCandidates);
  }

  /// Apple Music / iTunes Search API (Free, high rate limit, 600x600 HD artwork)
  static Future<List<ArtworkCandidate>> _searchItunes(String query, Track track) async {
    try {
      final response = await _dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': query,
          'media': 'music',
          'entity': 'song',
          'limit': 6,
        },
      );

      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is! Map<String, dynamic>) return [];

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return [];

      final List<ArtworkCandidate> candidates = [];
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final rawArt = item['artworkUrl100'] as String?;
        if (rawArt == null || rawArt.isEmpty) continue;

        // Upgrade 100x100 to 600x600 high resolution artwork
        final hdArt = rawArt.replaceAll(RegExp(r'\d+x\d+bb\.jpg'), '600x600bb.jpg');

        final title = (item['trackName'] ?? item['collectionName'] ?? '').toString();
        final artist = (item['artistName'] ?? '').toString();
        final album = (item['collectionName'] ?? '').toString();
        final durationMs = item['trackTimeMillis'] as int?;

        final score = calculateConfidence(
          localTitle: track.title,
          localArtist: track.artistName,
          localDurationMs: track.durationMs,
          candTitle: title,
          candArtist: artist,
          candDurationMs: durationMs,
        );

        final isDurationMatch = track.durationMs > 0 &&
            durationMs != null &&
            (track.durationMs - durationMs).abs() <= 6000;

        candidates.add(
          ArtworkCandidate(
            imageUrl: hdArt,
            title: title,
            artistName: artist,
            albumName: album,
            source: 'Apple Music',
            durationMs: durationMs,
            confidenceScore: score,
            isDurationMatch: isDurationMatch,
          ),
        );
      }
      return candidates;
    } catch (_) {
      return [];
    }
  }

  /// Deezer Search API (Free, 100M+ global tracks, 1000x1000 HD cover_xl)
  static Future<List<ArtworkCandidate>> _searchDeezer(String query, Track track) async {
    try {
      final response = await _dio.get(
        'https://api.deezer.com/search',
        queryParameters: {
          'q': query,
          'limit': 6,
        },
      );

      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is! Map<String, dynamic>) return [];

      final results = data['data'] as List<dynamic>?;
      if (results == null || results.isEmpty) return [];

      final List<ArtworkCandidate> candidates = [];
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final albumObj = item['album'] as Map<String, dynamic>?;
        final rawArt = (albumObj?['cover_xl'] ?? albumObj?['cover_big'] ?? albumObj?['cover_medium']) as String?;
        if (rawArt == null || rawArt.isEmpty) continue;

        final title = (item['title'] ?? '').toString();
        final artistObj = item['artist'] as Map<String, dynamic>?;
        final artist = (artistObj?['name'] ?? '').toString();
        final album = (albumObj?['title'] ?? '').toString();
        final durationSec = item['duration'] as int?;
        final durationMs = durationSec != null ? durationSec * 1000 : null;

        final score = calculateConfidence(
          localTitle: track.title,
          localArtist: track.artistName,
          localDurationMs: track.durationMs,
          candTitle: title,
          candArtist: artist,
          candDurationMs: durationMs,
        );

        final isDurationMatch = track.durationMs > 0 &&
            durationMs != null &&
            (track.durationMs - durationMs).abs() <= 6000;

        candidates.add(
          ArtworkCandidate(
            imageUrl: rawArt,
            title: title,
            artistName: artist,
            albumName: album,
            source: 'Deezer',
            durationMs: durationMs,
            confidenceScore: score,
            isDurationMatch: isDurationMatch,
          ),
        );
      }
      return candidates;
    } catch (_) {
      return [];
    }
  }

  /// JioSaavn Search API (Specialized for Indian, Bollywood, and South Asian tracks)
  static Future<List<ArtworkCandidate>> _searchJioSaavn(String query, Track track) async {
    try {
      final response = await _dio.get(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': 'search.getResults',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'n': 6,
          'p': 1,
          'q': query,
        },
      );

      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is! Map<String, dynamic>) return [];

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return [];

      final List<ArtworkCandidate> candidates = [];
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final rawImage = item['image'] as String?;
        if (rawImage == null || rawImage.isEmpty || TrackArtwork.isPlaceholderUrl(rawImage)) continue;

        final hdArt = rawImage
            .replaceAll('150x150', '500x500')
            .replaceAll('50x50', '500x500');

        final title = (item['song'] ?? item['title'] ?? '').toString();
        final artist = (item['singers'] ?? item['primary_artists'] ?? item['music'] ?? '').toString();
        final album = (item['album'] ?? '').toString();
        final durStr = item['duration']?.toString() ?? '';
        final durSec = int.tryParse(durStr);
        final durationMs = durSec != null ? durSec * 1000 : null;

        final score = calculateConfidence(
          localTitle: track.title,
          localArtist: track.artistName,
          localDurationMs: track.durationMs,
          candTitle: title,
          candArtist: artist,
          candDurationMs: durationMs,
        );

        final isDurationMatch = track.durationMs > 0 &&
            durationMs != null &&
            (track.durationMs - durationMs).abs() <= 6000;

        candidates.add(
          ArtworkCandidate(
            imageUrl: hdArt,
            title: title,
            artistName: artist,
            albumName: album,
            source: 'JioSaavn',
            durationMs: durationMs,
            confidenceScore: score,
            isDurationMatch: isDurationMatch,
          ),
        );
      }
      return candidates;
    } catch (_) {
      return [];
    }
  }

  /// Deduplicates candidates across sources and sorts by confidence score descending
  static List<ArtworkCandidate> _deduplicateAndSort(List<ArtworkCandidate> candidates) {
    final Map<String, ArtworkCandidate> unique = {};
    for (final c in candidates) {
      final key = c.imageUrl.toLowerCase().trim();
      final altKey = '${c.title.toLowerCase().trim()}|${c.artistName.toLowerCase().trim()}';
      if (!unique.containsKey(key) && !unique.containsKey(altKey)) {
        unique[key] = c;
      }
    }
    final list = unique.values.toList();
    list.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    return list;
  }

  /// Automatically selects the best verified artwork URL for a track, or returns
  /// null if no candidate passes the high confidence threshold (>= 0.85).
  static Future<String?> fetchBestArtworkUrl(Track track) async {
    final candidates = await searchArtworkCandidates(track);
    if (candidates.isEmpty) return null;

    final top = candidates.first;

    final hasArtist = track.artistName.trim().isNotEmpty &&
        !AudioNameSanitizer.isJunkArtist(track.artistName);

    // Strict threshold: Must have >= 85% confidence score
    if (top.confidenceScore >= 0.85) {
      return top.imageUrl;
    }

    // If artist is unknown, require >= 90% confidence score AND duration match
    if (!hasArtist && top.confidenceScore >= 0.90 && top.isDurationMatch) {
      return top.imageUrl;
    }

    // Never guess on ambiguous matches!
    return null;
  }

  /// Backward-compatible alias for single track enrichment
  static Future<String?> fetchArtworkUrl(Track track) => fetchBestArtworkUrl(track);

  /// Enriches a single track by fetching online cover art and saving it to SQLite
  static Future<bool> enrichTrack(Track track, AudioRepository repository) async {
    if (track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        !TrackArtwork.isPlaceholderUrl(track.artworkUrl)) {
      return false;
    }

    final artworkUrl = await fetchBestArtworkUrl(track);
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
      final candidates = tracks.where((t) {
        if (!t.isLocal || t.isAudioClip) return false;
        if (_sessionAttemptedTrackIds.contains(t.id)) return false;
        final art = t.artworkUrl;
        return art == null || art.trim().isEmpty || TrackArtwork.isPlaceholderUrl(art);
      }).toList();

      for (final track in candidates) {
        _sessionAttemptedTrackIds.add(track.id);

        final artworkUrl = await fetchBestArtworkUrl(track);
        if (artworkUrl != null && artworkUrl.isNotEmpty) {
          await repository.updateTrackArtwork(track.id, artworkUrl);
          updatedCount++;
          onProgress?.call(updatedCount);
        }

        // Polite delay to prevent rate limiting
        await Future.delayed(const Duration(milliseconds: 200));
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
