import 'package:dio/dio.dart';
import 'package:musify/core/utils/lrc_parser.dart';
import 'package:musify/data/sources/saavn_source_adapter.dart';
import 'package:musify/domain/models/lyrics.dart';
import 'package:musify/domain/models/track.dart';

class LyricsRepository {
  final SaavnSourceAdapter _saavnAdapter;
  final Dio _lrclibDio;
  final Map<String, Lyrics> _cache = {};

  LyricsRepository({
    SaavnSourceAdapter? saavnAdapter,
    Dio? lrclibDio,
  })  : _saavnAdapter = saavnAdapter ?? SaavnSourceAdapter(),
        _lrclibDio = lrclibDio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://lrclib.net/api',
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
                headers: {
                  'User-Agent': 'MusifyApp/1.0.0 (https://github.com/karvp91-art/musify)',
                  'Accept': 'application/json',
                },
              ),
            );

  /// Retrieves lyrics for [track], trying LRCLIB (for synced lyrics) and JioSaavn (for Indian catalog).
  Future<Lyrics?> getLyrics(Track track) async {
    // 1. Check in-memory cache
    if (_cache.containsKey(track.id)) {
      return _cache[track.id];
    }

    Lyrics? lyrics;

    // 2. If track is from JioSaavn, fetch from JioSaavn and LRCLIB in parallel for best result
    if (track.source == AudioSourceType.saavn && track.sourceId.isNotEmpty) {
      lyrics = await _fetchForSaavnTrack(track);
    } else {
      // 3. For local or other tracks, try LRCLIB first, then search JioSaavn
      lyrics = await _fetchForOtherTrack(track);
    }

    if (lyrics != null && lyrics.isNotEmpty) {
      _cache[track.id] = lyrics;
    }

    return lyrics;
  }

  Future<Lyrics?> _fetchForSaavnTrack(Track track) async {
    final results = await Future.wait([
      _fetchLrclib(track.title, track.artistName, track.durationMs),
      _saavnAdapter.getLyrics(track.sourceId),
    ]);

    final lrclibData = results[0];
    final saavnData = results[1];

    // Prefer LRCLIB if it has synchronized lyrics
    if (lrclibData != null) {
      final synced = lrclibData['syncedLyrics'] as String?;
      if (synced != null && synced.trim().isNotEmpty) {
        final lines = LrcParser.parseLrc(synced);
        if (lines.isNotEmpty) {
          return Lyrics(
            trackId: track.id,
            plainLyrics: lrclibData['plainLyrics'] as String? ?? synced,
            lines: lines,
            isSynced: true,
            source: 'LRCLIB (Synced)',
          );
        }
      }
    }

    // Fall back to JioSaavn plain lyrics
    if (saavnData != null && saavnData['lyrics'] != null) {
      final rawLyrics = saavnData['lyrics'].toString();
      final lines = LrcParser.parsePlain(rawLyrics);
      final plain = lines.map((l) => l.text).join('\n');
      return Lyrics(
        trackId: track.id,
        plainLyrics: plain,
        lines: lines,
        isSynced: false,
        copyright: saavnData['lyrics_copyright']?.toString(),
        source: 'JioSaavn',
      );
    }

    // Fall back to LRCLIB plain lyrics
    if (lrclibData != null && lrclibData['plainLyrics'] != null) {
      final plain = lrclibData['plainLyrics'].toString();
      final lines = LrcParser.parsePlain(plain);
      return Lyrics(
        trackId: track.id,
        plainLyrics: plain,
        lines: lines,
        isSynced: false,
        source: 'LRCLIB',
      );
    }

    return null;
  }

  Future<Lyrics?> _fetchForOtherTrack(Track track) async {
    // 1. Try LRCLIB
    final lrclibData = await _fetchLrclib(track.title, track.artistName, track.durationMs);
    if (lrclibData != null) {
      final synced = lrclibData['syncedLyrics'] as String?;
      if (synced != null && synced.trim().isNotEmpty) {
        final lines = LrcParser.parseLrc(synced);
        if (lines.isNotEmpty) {
          return Lyrics(
            trackId: track.id,
            plainLyrics: lrclibData['plainLyrics'] as String? ?? synced,
            lines: lines,
            isSynced: true,
            source: 'LRCLIB (Synced)',
          );
        }
      }

      final plain = lrclibData['plainLyrics'] as String?;
      if (plain != null && plain.trim().isNotEmpty) {
        final lines = LrcParser.parsePlain(plain);
        return Lyrics(
          trackId: track.id,
          plainLyrics: plain,
          lines: lines,
          isSynced: false,
          source: 'LRCLIB',
        );
      }
    }

    // 2. Search JioSaavn by title + artist
    final saavnData = await _saavnAdapter.searchAndGetLyrics(track.title, track.artistName);
    if (saavnData != null && saavnData['lyrics'] != null) {
      final rawLyrics = saavnData['lyrics'].toString();
      final lines = LrcParser.parsePlain(rawLyrics);
      final plain = lines.map((l) => l.text).join('\n');
      return Lyrics(
        trackId: track.id,
        plainLyrics: plain,
        lines: lines,
        isSynced: false,
        copyright: saavnData['lyrics_copyright']?.toString(),
        source: 'JioSaavn',
      );
    }

    return null;
  }

  Future<Map<String, dynamic>?> _fetchLrclib(String title, String artist, int durationMs) async {
    try {
      final cleanTitle = _sanitizeSearchQuery(title);
      final cleanArtist = _sanitizeSearchQuery(artist);

      final queryParams = <String, dynamic>{
        'track_name': cleanTitle,
        'artist_name': cleanArtist,
      };

      if (durationMs > 0) {
        queryParams['duration'] = (durationMs / 1000).round();
      }

      final response = await _lrclibDio.get(
        '/get',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  String _sanitizeSearchQuery(String text) {
    return text
        .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'[_-]'), ' ')
        .trim();
  }
}
