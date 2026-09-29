import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/data/sources/saavn_source_adapter.dart';
import 'package:musify/data/sources/source_router.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/sources/source_adapter.dart';

class MockHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  MockHttpAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('SaavnSourceAdapter Tests', () {
    late Dio dio;
    late SaavnSourceAdapter adapter;

    // Real JioSaavn API response payload sample
    final mockSaavnSearchResponse = {
      'total': 2,
      'start': 1,
      'results': [
        {
          'id': 'kesariya_1',
          'song': 'Kesariya (From &quot;Brahmastra&quot;)',
          'album': 'Brahmastra',
          'year': '2022',
          'primary_artists': 'Pritam, Arijit Singh &amp; Amitabh Bhattacharya',
          'singers': 'Arijit Singh',
          'image': 'https://c.saavncdn.com/562/Arijit-Singh-150x150.jpg',
          'duration': '268',
          'encrypted_media_url':
              'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyi/UBycVv1zZKNPorGJFZFR0/NbM1Djc2lgUSPZa0Q1DU/bJdcvD45hw7tS9a8Gtq',
          'media_preview_url': 'https://preview.saavncdn.com/562/sample_96_p.mp4',
        },
        {
          'id': 'apna_bana_le_2',
          'song': 'Apna Bana Le',
          'album': 'Bhediya',
          'year': '2022',
          'primary_artists': 'Sachin-Jigar, Arijit Singh',
          'singers': 'Arijit Singh',
          'image': 'https://c.saavncdn.com/123/Bhediya-150x150.jpg',
          'duration': '261',
          'encrypted_media_url': '',
          'media_preview_url': 'https://preview.saavncdn.com/123/sample_96_p.mp4',
        }
      ]
    };

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://www.jiosaavn.com/api.php'));
      adapter = SaavnSourceAdapter(dio: dio);
    });

    test('SourceType and adapter name are correct', () {
      expect(adapter.sourceType, AudioSourceType.saavn);
      expect(adapter.name, 'JioSaavn 320k');
    });

    test('Search with empty query returns empty list without network call', () async {
      final results = await adapter.search('   ');
      expect(results, isEmpty);
    });

    test('Search parses JioSaavn 320kbps tracks correctly', () async {
      dio.httpClientAdapter = MockHttpAdapter((options) async {
        expect(options.queryParameters['__call'], 'search.getResults');
        expect(options.queryParameters['q'], 'kesariya');

        final jsonString = jsonEncode(mockSaavnSearchResponse);
        return ResponseBody.fromString(
          jsonString,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final tracks = await adapter.search('kesariya');
      expect(tracks.length, 2);

      final track1 = tracks[0];
      expect(track1.id, 'saavn:kesariya_1');
      expect(track1.sourceId, 'kesariya_1');
      // HTML entity unescaped
      expect(track1.title, 'Kesariya (From "Brahmastra")');
      expect(track1.artistName, 'Pritam, Arijit Singh & Amitabh Bhattacharya');
      expect(track1.albumTitle, 'Brahmastra');
      expect(track1.durationMs, 268000);
      expect(track1.source, AudioSourceType.saavn);
      // High-res 500x500 artwork
      expect(track1.artworkUrl, 'https://c.saavncdn.com/562/Arijit-Singh-500x500.jpg');
      // Decrypted 320kbps DDL URL
      expect(track1.audioUrl, contains('https://aac.saavncdn.com/'));
      expect(track1.audioUrl, contains('_320.mp4'));
      expect(track1.bitrate, 320);
      expect(track1.codec, 'aac');

      final track2 = tracks[1];
      expect(track2.id, 'saavn:apna_bana_le_2');
      expect(track2.title, 'Apna Bana Le');
      expect(track2.durationMs, 261000);
      // Fallback to media_preview_url when encrypted_media_url is empty
      expect(track2.audioUrl, 'https://preview.saavncdn.com/123/sample_96_p.mp4');
    });

    test('getTrendingTracks queries top hits and parses results', () async {
      dio.httpClientAdapter = MockHttpAdapter((options) async {
        expect(options.queryParameters['__call'], 'search.getResults');
        expect(options.queryParameters['n'], 10);

        final jsonString = jsonEncode(mockSaavnSearchResponse);
        return ResponseBody.fromString(
          jsonString,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final tracks = await adapter.getTrendingTracks(limit: 10);
      expect(tracks.length, 2);
      expect(tracks.first.title, contains('Kesariya'));
    });

    test('getTracksByGenre queries specific genre', () async {
      dio.httpClientAdapter = MockHttpAdapter((options) async {
        expect(options.queryParameters['__call'], 'search.getResults');
        expect(options.queryParameters['q'], contains('bollywood'));

        final jsonString = jsonEncode(mockSaavnSearchResponse);
        return ResponseBody.fromString(
          jsonString,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final tracks = await adapter.getTracksByGenre('bollywood');
      expect(tracks.length, 2);
    });

    test('getStreamUrl returns 320kbps audioUrl', () async {
      final track = Track(
        id: 'saavn:kesariya_1',
        title: 'Kesariya',
        artistName: 'Arijit Singh',
        source: AudioSourceType.saavn,
        sourceId: 'kesariya_1',
        durationMs: 268000,
        audioUrl: 'https://aac.saavncdn.com/562/sample_320.mp4',
        addedAt: DateTime.now(),
      );

      final streamUrl = await adapter.getStreamUrl(track);
      expect(streamUrl, 'https://aac.saavncdn.com/562/sample_320.mp4');
    });

    test('Network error returns empty list gracefully without throwing', () async {
      dio.httpClientAdapter = MockHttpAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          error: 'Connection timeout',
        );
      });

      final searchResults = await adapter.search('test');
      expect(searchResults, isEmpty);

      final trending = await adapter.getTrendingTracks();
      expect(trending, isEmpty);

      final genre = await adapter.getTracksByGenre('pop');
      expect(genre, isEmpty);

      final metadata = await adapter.getMetadata('99999');
      expect(metadata, isNull);
    });
  });

  group('SourceRouter with Saavn Tests', () {
    test('Parallel search and deduplication across local and Saavn', () async {
      final router = SourceRouter();

      final mockLocalTrack = Track(
        id: 'local:1',
        title: 'Kesariya',
        artistName: 'Arijit Singh',
        source: AudioSourceType.local,
        sourceId: 'loc_1',
        durationMs: 268000,
        audioUrl: '/local/kesariya.mp3',
        addedAt: DateTime.now(),
      );

      final mockSaavnTrack = Track(
        id: 'saavn:kesariya_1',
        title: 'Kesariya',
        artistName: 'Arijit Singh',
        source: AudioSourceType.saavn,
        sourceId: 'kesariya_1',
        durationMs: 268000,
        audioUrl: 'https://aac.saavncdn.com/562/kesariya_320.mp4',
        addedAt: DateTime.now(),
      );

      final mockSaavnTrack2 = Track(
        id: 'saavn:apna_bana_le',
        title: 'Apna Bana Le',
        artistName: 'Arijit Singh',
        source: AudioSourceType.saavn,
        sourceId: 'apna_bana_le',
        durationMs: 261000,
        audioUrl: 'https://aac.saavncdn.com/123/apna_320.mp4',
        addedAt: DateTime.now(),
      );

      router.registerAdapter(_StubAdapter(
        sourceType: AudioSourceType.local,
        name: 'Local',
        searchResult: [mockLocalTrack],
      ));

      router.registerAdapter(_StubAdapter(
        sourceType: AudioSourceType.saavn,
        name: 'JioSaavn 320k',
        searchResult: [mockSaavnTrack, mockSaavnTrack2],
      ));

      final results = await router.searchAll('kesariya');

      // Local track kept, duplicate Saavn version filtered out, unique Saavn track included
      expect(results.length, 2);
      expect(results[0].source, AudioSourceType.local);
      expect(results[1].id, 'saavn:apna_bana_le');
    });
  });
}

class _StubAdapter implements SourceAdapter {
  @override
  final AudioSourceType sourceType;
  @override
  final String name;
  final List<Track> searchResult;

  _StubAdapter({
    required this.sourceType,
    required this.name,
    required this.searchResult,
  });

  @override
  Future<List<Track>> search(String query) async => searchResult;

  @override
  Future<String> getStreamUrl(Track track) async => track.audioUrl;

  @override
  Future<Track?> getMetadata(String sourceId) async => null;

  @override
  Future<String?> getArtworkUrl(String sourceId) async => null;
}
