import 'package:dio/dio.dart';
import 'package:musify/core/constants/app_constants.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/sources/source_adapter.dart';

class JamendoSourceAdapter implements SourceAdapter {
  final Dio _dio;
  final String _clientId;

  JamendoSourceAdapter({
    Dio? dio,
    String? clientId,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.jamendoApiBase,
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            ),
        _clientId = clientId ?? AppConstants.jamendoClientId;

  @override
  AudioSourceType get sourceType => AudioSourceType.jamendo;

  @override
  String get name => 'Jamendo';

  @override
  Future<List<Track>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        '/tracks/',
        queryParameters: {
          'client_id': _clientId,
          'format': 'json',
          'limit': 25,
          'namesearch': query.trim(),
          'include': 'musicinfo',
          'audioformat': 'mp32',
        },
      );

      return _parseTrackResults(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<List<Track>> getFeaturedTracks({int limit = 12}) async {
    try {
      final response = await _dio.get(
        '/tracks/',
        queryParameters: {
          'client_id': _clientId,
          'format': 'json',
          'limit': limit,
          'order': 'popularity_total',
          'include': 'musicinfo',
          'audioformat': 'mp32',
        },
      );

      return _parseTrackResults(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<List<Track>> getTracksByTag(String tag, {int limit = 12}) async {
    try {
      final response = await _dio.get(
        '/tracks/',
        queryParameters: {
          'client_id': _clientId,
          'format': 'json',
          'limit': limit,
          'tags': tag.toLowerCase().trim(),
          'order': 'popularity_total',
          'include': 'musicinfo',
          'audioformat': 'mp32',
        },
      );

      return _parseTrackResults(response.data);
    } catch (_) {
      return [];
    }
  }

  List<Track> _parseTrackResults(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) return [];
    final results = data['results'] as List<dynamic>?;
    if (results == null) return [];

    final List<Track> tracks = [];
    for (final item in results) {
      if (item is Map<String, dynamic>) {
        final trackId = item['id']?.toString();
        final name = item['name'] as String?;
        final artistName = item['artist_name'] as String?;
        final audioUrl = item['audio'] as String?;

        if (trackId != null && name != null && artistName != null && audioUrl != null) {
          final durationSec = (item['duration'] as num?)?.toInt() ?? 0;
          final artwork = item['album_image'] as String? ?? item['image'] as String?;

          tracks.add(
            Track(
              id: 'jamendo:$trackId',
              title: name,
              artistName: artistName,
              albumTitle: item['album_name'] as String? ?? 'Jamendo',
              artistId: item['artist_id']?.toString(),
              albumId: item['album_id']?.toString(),
              source: AudioSourceType.jamendo,
              sourceId: trackId,
              durationMs: durationSec * 1000,
              artworkUrl: artwork,
              audioUrl: audioUrl,
              codec: 'mp3',
              bitrate: 128,
              isLiked: false,
              isDownloaded: false,
              addedAt: DateTime.now(),
            ),
          );
        }
      }
    }
    return tracks;
  }

  @override
  Future<String> getStreamUrl(Track track) async {
    return track.audioUrl;
  }

  @override
  Future<Track?> getMetadata(String sourceId) async {
    try {
      final response = await _dio.get(
        '/tracks/',
        queryParameters: {
          'client_id': _clientId,
          'format': 'json',
          'id': sourceId,
          'include': 'musicinfo',
          'audioformat': 'mp32',
        },
      );
      final tracks = _parseTrackResults(response.data);
      return tracks.isNotEmpty ? tracks.first : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getArtworkUrl(String sourceId) async {
    final track = await getMetadata(sourceId);
    return track?.artworkUrl;
  }
}
