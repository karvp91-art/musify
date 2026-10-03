import 'package:flutter_test/flutter_test.dart';
import 'package:musify/data/sources/youtube_source_adapter.dart';
import 'package:musify/domain/models/track.dart';

void main() {
  group('YouTubeSourceAdapter Tests', () {
    late YouTubeSourceAdapter adapter;

    setUp(() {
      adapter = YouTubeSourceAdapter();
    });

    tearDown(() {
      adapter.close();
    });

    test('Source type and name verification', () {
      expect(adapter.sourceType, equals(AudioSourceType.youtube));
      expect(adapter.name, equals('YouTube'));
    });

    test('Artwork URL generation follows YouTube standard format', () async {
      final artworkUrl = await adapter.getArtworkUrl('dQw4w9WgXcQ');
      expect(artworkUrl, equals('https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg'));
    });

    test('parseTitleAndArtist cleans up common YouTube suffixes and separates artist/title', () {
      // Case 1: "Artist - Title (Official Music Video)"
      final res1 = YouTubeSourceAdapter.parseTitleAndArtist(
        'The Weeknd - Blinding Lights (Official Video)',
        'The Weeknd',
      );
      expect(res1.artist, equals('The Weeknd'));
      expect(res1.title, equals('Blinding Lights'));

      // Case 2: "Artist - Title [Official Audio]"
      final res2 = YouTubeSourceAdapter.parseTitleAndArtist(
        'Dua Lipa - Levitating [Official Audio]',
        'Dua Lipa',
      );
      expect(res2.artist, equals('Dua Lipa'));
      expect(res2.title, equals('Levitating'));

      // Case 3: Topic channel author cleanup
      final res3 = YouTubeSourceAdapter.parseTitleAndArtist(
        'Starboy',
        'The Weeknd - Topic',
      );
      expect(res3.artist, equals('The Weeknd'));
      expect(res3.title, equals('Starboy'));

      // Case 4: Title with 4K/HD badge and pipe delimiter
      final res4 = YouTubeSourceAdapter.parseTitleAndArtist(
        'Coldplay - Yellow (Official 4K Video) | Warner Records',
        'Coldplay',
      );
      expect(res4.artist, equals('Coldplay'));
      expect(res4.title, equals('Yellow'));
    });

    test('Track model instantiation with AudioSourceType.youtube', () {
      final track = Track(
        id: 'youtube:test1234',
        title: 'Starboy',
        artistName: 'The Weeknd',
        source: AudioSourceType.youtube,
        sourceId: 'test1234',
        durationMs: 230000,
        artworkUrl: 'https://img.youtube.com/vi/test1234/hqdefault.jpg',
        audioUrl: '',
        codec: 'opus',
        bitrate: 160,
        addedAt: DateTime.now(),
      );

      expect(track.source, equals(AudioSourceType.youtube));
      expect(track.isLocal, isFalse);
      expect(track.id, equals('youtube:test1234'));
      expect(track.codec, equals('opus'));
    });

    test('getSafeFilename generates sanitized filenames without invalid characters', () {
      final track = Track(
        id: 'youtube:123/456*789',
        title: 'Song: The Best <Hit>?',
        artistName: 'Artist / "Band" | Group',
        source: AudioSourceType.youtube,
        sourceId: '123_456',
        durationMs: 180000,
        audioUrl: '',
        codec: 'mp4',
        bitrate: 160,
        addedAt: DateTime.now(),
      );

      final filename = YouTubeSourceAdapter.getSafeFilename(track, '.mp4');
      expect(filename.contains('/'), isFalse);
      expect(filename.contains(':'), isFalse);
      expect(filename.contains('?'), isFalse);
      expect(filename.contains('<'), isFalse);
      expect(filename.contains('>'), isFalse);
      expect(filename.contains('|'), isFalse);
      expect(filename.contains('"'), isFalse);
      expect(filename.endsWith('.mp4'), isTrue);
    });

    test('getExistingDownloadedFile returns file when track has valid local filePath', () async {
      final track = Track(
        id: 'youtube:test_local',
        title: 'Local Test',
        artistName: 'Local Artist',
        source: AudioSourceType.youtube,
        sourceId: 'test_local',
        durationMs: 180000,
        filePath: 'pubspec.yaml', // existing file
        audioUrl: '',
        codec: 'mp4',
        bitrate: 160,
        addedAt: DateTime.now(),
      );

      final file = await adapter.getExistingDownloadedFile(track);
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
    });
  });
}
