import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:musify/core/utils/des_cipher.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/sources/source_adapter.dart';

import 'package:musify/services/preferences_service.dart';

class SaavnSourceAdapter implements SourceAdapter {
  final Dio _dio;
  final PreferencesService? preferencesService;

  SaavnSourceAdapter({Dio? dio, this.preferencesService})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://www.jiosaavn.com/api.php',
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  'Accept': 'application/json, text/plain, */*',
                },
              ),
            );

  @override
  AudioSourceType get sourceType => AudioSourceType.saavn;

  @override
  String get name => 'JioSaavn 320k';

  static String unescapeHtml(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  @override
  Future<List<Track>> search(String query, {int limit = 25}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'search.getResults',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'n': limit,
          'p': 1,
          'q': trimmed,
        },
      );

      return _parseSearchResults(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<List<Track>> getTrendingTracks({int limit = 15}) async {
    return search('trending hindi english top hits', limit: limit);
  }

  Future<List<Track>> getTracksByGenre(String genre, {int limit = 15}) async {
    return search('$genre top hits', limit: limit);
  }

  List<Track> _parseSearchResults(dynamic data) {
    if (data == null) return [];

    Map<String, dynamic>? jsonMap;
    if (data is String) {
      try {
        jsonMap = jsonDecode(data) as Map<String, dynamic>?;
      } catch (_) {
        return [];
      }
    } else if (data is Map<String, dynamic>) {
      jsonMap = data;
    }

    if (jsonMap == null) return [];

    final results = jsonMap['results'] as List<dynamic>?;
    if (results == null) return [];

    final List<Track> tracks = [];
    for (final item in results) {
      if (item is Map<String, dynamic>) {
        final parsed = _parseSingleSong(item);
        if (parsed != null) {
          tracks.add(parsed);
        }
      }
    }

    return tracks;
  }

  Track? _parseSingleSong(Map<String, dynamic> item) {
    final songId = item['id']?.toString();
    final rawTitle = item['song'] as String? ?? item['title'] as String?;
    if (songId == null || rawTitle == null || rawTitle.isEmpty) return null;

    final title = unescapeHtml(rawTitle);
    final rawArtist = item['primary_artists'] as String? ??
        item['singers'] as String? ??
        item['music'] as String? ??
        'Unknown Artist';
    final artistName = unescapeHtml(rawArtist);

    final rawAlbum = item['album'] as String? ?? 'Single';
    final albumTitle = unescapeHtml(rawAlbum);

    final durationSec = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;
    final durationMs = durationSec > 0 ? durationSec * 1000 : 0;

    // High quality 500x500 album artwork
    var artwork = item['image'] as String?;
    if (artwork != null) {
      artwork = artwork
          .replaceAll('150x150.jpg', '500x500.jpg')
          .replaceAll('50x50.jpg', '500x500.jpg');
    }

    // Direct audio URL resolution with preferred bitrate
    final quality = preferencesService?.getAudioQuality() ?? '320k';
    final encryptedUrl = item['encrypted_media_url'] as String?;
    var streamUrl = DesCipher.decryptJioSaavnDirectUrl(encryptedUrl, quality: quality);

    // Fallback to media_preview_url if direct decryption failed
    if (streamUrl == null || streamUrl.isEmpty) {
      streamUrl = item['media_preview_url'] as String? ?? '';
    }

    final bitrateVal = switch (quality) {
      '96k' => 96,
      '160k' => 160,
      '256k' => 256,
      _ => 320,
    };

    return Track(
      id: 'saavn:$songId',
      title: title,
      artistName: artistName,
      albumTitle: albumTitle,
      albumId: item['albumid']?.toString(),
      artistId: item['primary_artists_id']?.toString(),
      source: AudioSourceType.saavn,
      sourceId: songId,
      durationMs: durationMs,
      artworkUrl: artwork,
      audioUrl: streamUrl,
      codec: 'aac',
      bitrate: bitrateVal,
      isLiked: false,
      isDownloaded: false,
      addedAt: DateTime.now(),
    );
  }

  @override
  Future<String> getStreamUrl(Track track) async {
    if (track.audioUrl.isNotEmpty && track.audioUrl.startsWith('http')) {
      return track.audioUrl;
    }

    // Try fetching details if audioUrl wasn't resolved
    try {
      final metadata = await getMetadata(track.sourceId);
      if (metadata != null && metadata.audioUrl.isNotEmpty) {
        return metadata.audioUrl;
      }
    } catch (_) {}

    return track.audioUrl;
  }

  @override
  Future<Track?> getMetadata(String sourceId) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'song.getDetails',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'pids': sourceId,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        // song.getDetails returns a map keyed by pid or with songs array
        if (data.containsKey(sourceId) && data[sourceId] is Map<String, dynamic>) {
          return _parseSingleSong(data[sourceId] as Map<String, dynamic>);
        } else if (data['songs'] is List && (data['songs'] as List).isNotEmpty) {
          return _parseSingleSong((data['songs'] as List).first as Map<String, dynamic>);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getArtworkUrl(String sourceId) async {
    final track = await getMetadata(sourceId);
    return track?.artworkUrl;
  }

  /// Fetches free lyrics from JioSaavn for a given songId.
  Future<Map<String, dynamic>?> getLyrics(String songId) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'lyrics.getLyrics',
          'lyrics_id': songId,
          '_format': 'json',
          'ctx': 'web6dot0',
        },
      );

      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is Map<String, dynamic> && data['lyrics'] != null) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// Searches JioSaavn by title and artist, then attempts to fetch lyrics.
  Future<Map<String, dynamic>?> searchAndGetLyrics(String title, String artist) async {
    try {
      final query = '$title $artist'.trim();
      final results = await search(query, limit: 5);
      for (final track in results) {
        if (track.sourceId.isNotEmpty) {
          final lyrics = await getLyrics(track.sourceId);
          if (lyrics != null && lyrics['lyrics'] != null) {
            return lyrics;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
