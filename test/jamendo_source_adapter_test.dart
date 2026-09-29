import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/data/sources/jamendo_source_adapter.dart';
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
  group('JamendoSourceAdapter Tests', () {
    late Dio dio;
    late JamendoSourceAdapter adapter;

    final mockJamendoResponse = {
      'headers': {
        'status': 'success',
        'code': 0,
        'results_count': 2,
      },
      'results': [
        {
          'id': '1873456',
          'name': 'Midnight Neon City',
          'duration': 195,
          'artist_id': '4502',
          'artist_name': 'Retro Wave Project',
          'album_name': 'Synth Horizons',
          'album_id': '89012',
          'image': 'https://usercontent.jamendo.com?type=album&id=89012&width=300',
          'album_image': 'https://usercontent.jamendo.com?type=album&id=89012&width=300',
          'audio': 'https://prod-1.storage.jamendo.com/?trackid=1873456&format=mp32',
        },
        {
          'id': '1984210',
          'name': 'Acoustic Sunrise Meditation',
          'duration': 142,
          'artist_id': '6720',
          'artist_name': 'Peaceful Strings',
          'album_name': 'Morning Dew',
          'album_id': '90214',
          'image': 'https://usercontent.jamendo.com?type=album&id=90214&width=300',
          'album_image': 'https://usercontent.jamendo.com?type=album&id=90214&width=300',
          'audio': 'https://prod-1.storage.jamendo.com/?trackid=1984210&format=mp32',
        }
      ]
    };

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.jamendo.com/v3.0'));
      adapter = JamendoSourceAdapter(dio: dio, clientId: 'test_client_id');
    });

    test('SourceType and adapter name are correct', () {
      expect(adapter.sourceType, AudioSourceType.jamendo);
      expect(adapter.name, 'Jamendo');
    });

    test('Search with empty query returns empty list without network call', () async {
      final results = await adapter.search('   ');
      expect(results, isEmpty);
    });

    test('Search parses Jamendo tracks correctly', () async {
      dio.httpClientAdapter = MockHttpAdapter((options) async {
        expect(options.path, '/tracks/');
        expect(options.queryParameters['client_id'], 'test_client_id');
        expect(options.queryParameters['namesearch'], 'synth');
        expect(options.queryParameters['audioformat'], 'mp32');

        final jsonString = jsonEncode(mockJamendoResponse);
        return ResponseBody.fromString(
          jsonString,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final tracks = await adapter.search('synth');
      expect(tracks.length, 2);

      final track1 = tracks[0];
      expect(track1.id, 'jamendo:1873456');
      expect(track1.sourceId, '1873456');
      expect(track1.title, 'Midnight Neon City');
      expect(track1.artistName, 'Retro Wave Project');
      expect(track1.albumTitle, 'Synth Horizons');
      expect(track1.durationMs, 195000);
      expect(track1.source, AudioSourceType.jamendo);
      expect(track1.audioUrl, contains('trackid=1873456'));
      expect(track1.artworkUrl, contains('id=89012'));

      final track2 = tracks[1];
      expect(track2.id, 'jamendo:1984210');
      expect(track2.title, 'Acoustic Sunrise Meditation');
      expect(track2.durationMs, 142000);
    });

    test('getFeaturedTracks queries popularity_total and parses results', () async {
      dio.httpClientAdapter = MockHttpAdapter((options) async {
        expect(options.path, '/tracks/');
        expect(options.queryParameters['order'], 'popularity_total');
        expect(options.queryParameters['limit'], 6);

        final jsonString = jsonEncode(mockJamendoResponse);
        return ResponseBody.fromString(
          jsonString,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final tracks = await adapter.getFeaturedTracks(limit: 6);
      expect(tracks.length, 2);
      expect(tracks.first.title, 'Midnight Neon City');
    });

    test('getTracksByTag queries specific genre tag', () async {
      dio.httpClientAdapter = MockHttpAdapter((options) async {
        expect(options.path, '/tracks/');
        expect(options.queryParameters['tags'], 'chillout');

        final jsonString = jsonEncode(mockJamendoResponse);
        return ResponseBody.fromString(
          jsonString,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final tracks = await adapter.getTracksByTag('Chillout');
      expect(tracks.length, 2);
    });

    test('getMetadata queries track by id', () async {
      dio.httpClientAdapter = MockHttpAdapter((options) async {
        expect(options.path, '/tracks/');
        expect(options.queryParameters['id'], '1873456');

        final jsonString = jsonEncode(mockJamendoResponse);
        return ResponseBody.fromString(
          jsonString,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final track = await adapter.getMetadata('1873456');
      expect(track, isNotNull);
      expect(track!.title, 'Midnight Neon City');
      expect(track.sourceId, '1873456');
    });

    test('getStreamUrl returns track audioUrl', () async {
      final track = Track(
        id: 'jamendo:1873456',
        title: 'Midnight Neon City',
        artistName: 'Retro Wave Project',
        source: AudioSourceType.jamendo,
        sourceId: '1873456',
        durationMs: 195000,
        audioUrl: 'https://prod-1.storage.jamendo.com/?trackid=1873456&format=mp32',
        addedAt: DateTime.now(),
      );

      final streamUrl = await adapter.getStreamUrl(track);
      expect(streamUrl, track.audioUrl);
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

      final featuredResults = await adapter.getFeaturedTracks();
      expect(featuredResults, isEmpty);

      final tagResults = await adapter.getTracksByTag('rock');
      expect(tagResults, isEmpty);

      final metadata = await adapter.getMetadata('99999');
      expect(metadata, isNull);
    });
  });

  group('SourceRouter Tests', () {
    test('Parallel search across multiple registered adapters', () async {
      final router = SourceRouter();

      final mockTrack1 = Track(
        id: 'local:1',
        title: 'Local Chill Beat',
        artistName: 'Local Artist',
        source: AudioSourceType.local,
        sourceId: 'loc_1',
        durationMs: 60000,
        audioUrl: '/local/1.mp3',
        addedAt: DateTime.now(),
      );

      final mockTrack2 = Track(
        id: 'jamendo:2',
        title: 'Jamendo Chill Groove',
        artistName: 'Jamendo Artist',
        source: AudioSourceType.jamendo,
        sourceId: 'jam_2',
        durationMs: 90000,
        audioUrl: 'https://jamendo.com/audio/2.mp3',
        addedAt: DateTime.now(),
      );

      // Register mock adapter 1
      router.registerAdapter(_StubSourceAdapter(
        sourceType: AudioSourceType.local,
        name: 'Local',
        searchResult: [mockTrack1],
      ));

      // Register mock adapter 2
      router.registerAdapter(_StubSourceAdapter(
        sourceType: AudioSourceType.jamendo,
        name: 'Jamendo',
        searchResult: [mockTrack2],
      ));

      final combined = await router.searchAll('Chill');
      expect(combined.length, 2);
      expect(combined.map((t) => t.id), containsAll(['local:1', 'jamendo:2']));
    });

    test('Faulty adapter failure does not prevent other adapter results', () async {
      final router = SourceRouter();

      final goodTrack = Track(
        id: 'jamendo:success',
        title: 'Online Song',
        artistName: 'Great Band',
        source: AudioSourceType.jamendo,
        sourceId: '100',
        durationMs: 120000,
        audioUrl: 'https://stream.mp3',
        addedAt: DateTime.now(),
      );

      router.registerAdapter(_FaultySourceAdapter(AudioSourceType.local));
      router.registerAdapter(_StubSourceAdapter(
        sourceType: AudioSourceType.jamendo,
        name: 'Jamendo',
        searchResult: [goodTrack],
      ));

      final results = await router.searchAll('Song');
      expect(results.length, 1);
      expect(results.first.id, 'jamendo:success');
    });
  });
}

class _StubSourceAdapter implements SourceAdapter {
  @override
  final AudioSourceType sourceType;
  @override
  final String name;
  final List<Track> searchResult;

  _StubSourceAdapter({
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

class _FaultySourceAdapter implements SourceAdapter {
  @override
  final AudioSourceType sourceType;
  @override
  final String name = 'Faulty';

  _FaultySourceAdapter(this.sourceType);

  @override
  Future<List<Track>> search(String query) async {
    throw Exception('Disk read error!');
  }

  @override
  Future<String> getStreamUrl(Track track) async => throw Exception();

  @override
  Future<Track?> getMetadata(String sourceId) async => throw Exception();

  @override
  Future<String?> getArtworkUrl(String sourceId) async => throw Exception();
}
