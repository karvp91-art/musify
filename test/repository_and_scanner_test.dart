import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/data/database/app_database.dart';
import 'package:musify/data/repositories/audio_repository_impl.dart';
import 'package:musify/data/repositories/local_files_scanner.dart';
import 'package:musify/domain/models/track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AudioRepositoryImpl repository;
  late LocalFilesScanner scanner;

  setUp(() {
    // In-memory SQLite database for isolated fast unit tests
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = AudioRepositoryImpl(db);
    scanner = LocalFilesScanner(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AudioRepository & Local Database Tests', () {
    test('LocalFilesScanner instance can be initialized', () {
      expect(scanner, isNotNull);
    });

    test('Initial database is empty', () async {
      final tracks = await repository.getLocalTracks();
      expect(tracks, isEmpty);

      final liked = await repository.getLikedTracks();
      expect(liked, isEmpty);

      final playlists = await repository.getPlaylists();
      expect(playlists, isEmpty);
    });

    test('Add and toggle like on tracks', () async {
      final track = Track(
        id: 'local:test_1',
        title: 'Ambient Sunrise',
        artistName: 'Aura Sound',
        albumTitle: 'Chill Vibes',
        source: AudioSourceType.local,
        sourceId: '/path/test_1.wav',
        durationMs: 12000,
        audioUrl: '/path/test_1.wav',
        filePath: '/path/test_1.wav',
        isLiked: false,
        isDownloaded: true,
        addedAt: DateTime.now(),
      );

      // Initially not liked
      expect(await repository.isTrackLiked(track.id), isFalse);

      // Toggle like -> liked
      await repository.toggleLike(track);
      expect(await repository.isTrackLiked(track.id), isTrue);

      final likedList = await repository.getLikedTracks();
      expect(likedList.length, 1);
      expect(likedList.first.title, 'Ambient Sunrise');
      expect(likedList.first.isLiked, isTrue);

      // Toggle like again -> unliked
      await repository.toggleLike(likedList.first);
      expect(await repository.isTrackLiked(track.id), isFalse);

      final unlikedList = await repository.getLikedTracks();
      expect(unlikedList, isEmpty);
    });

    test('Create playlist and manage playlist tracks', () async {
      final playlist = await repository.createPlaylist('Study Session', description: 'Lo-fi study tracks');
      expect(playlist.name, 'Study Session');
      expect(playlist.description, 'Lo-fi study tracks');

      final playlists = await repository.getPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.name, 'Study Session');

      final track1 = Track(
        id: 'local:song_1',
        title: 'Focus Beat',
        artistName: 'Lo-fi Guy',
        source: AudioSourceType.local,
        sourceId: 'song_1',
        durationMs: 180000,
        audioUrl: '/path/1.mp3',
        addedAt: DateTime.now(),
      );

      final track2 = Track(
        id: 'local:song_2',
        title: 'Deep Work',
        artistName: 'Study Wave',
        source: AudioSourceType.local,
        sourceId: 'song_2',
        durationMs: 210000,
        audioUrl: '/path/2.mp3',
        addedAt: DateTime.now(),
      );

      await repository.addTrackToPlaylist(playlist.id, track1);
      await repository.addTrackToPlaylist(playlist.id, track2);

      final playlistTracks = await repository.getPlaylistTracks(playlist.id);
      expect(playlistTracks.length, 2);
      expect(playlistTracks[0].title, 'Focus Beat');
      expect(playlistTracks[1].title, 'Deep Work');

      // Remove track 1
      await repository.removeTrackFromPlaylist(playlist.id, track1.id);
      final remaining = await repository.getPlaylistTracks(playlist.id);
      expect(remaining.length, 1);
      expect(remaining.first.title, 'Deep Work');

      // Delete playlist
      await repository.deletePlaylist(playlist.id);
      final emptyPlaylists = await repository.getPlaylists();
      expect(emptyPlaylists, isEmpty);
    });

    test('Update, reorder, watch, and toggle playlist tracks', () async {
      final playlist = await repository.createPlaylist('Work Focus', description: 'Original description');
      expect(playlist.name, 'Work Focus');

      // Update playlist
      await repository.updatePlaylist(playlist.id, name: 'Deep Coding', description: 'Updated description');
      final updatedPlaylists = await repository.getPlaylists();
      final fetched = updatedPlaylists.firstWhere((p) => p.id == playlist.id);
      expect(fetched.name, 'Deep Coding');
      expect(fetched.description, 'Updated description');

      final trackA = Track(
        id: 'local:track_a',
        title: 'Track A',
        artistName: 'Artist A',
        source: AudioSourceType.local,
        sourceId: 'a',
        durationMs: 120000,
        audioUrl: '/path/a.mp3',
        addedAt: DateTime.now(),
      );
      final trackB = Track(
        id: 'local:track_b',
        title: 'Track B',
        artistName: 'Artist B',
        source: AudioSourceType.local,
        sourceId: 'b',
        durationMs: 140000,
        audioUrl: '/path/b.mp3',
        addedAt: DateTime.now(),
      );
      final trackC = Track(
        id: 'local:track_c',
        title: 'Track C',
        artistName: 'Artist C',
        source: AudioSourceType.local,
        sourceId: 'c',
        durationMs: 160000,
        audioUrl: '/path/c.mp3',
        addedAt: DateTime.now(),
      );

      // Add tracks
      await repository.addTrackToPlaylist(playlist.id, trackA);
      await repository.addTrackToPlaylist(playlist.id, trackB);
      await repository.addTrackToPlaylist(playlist.id, trackC);

      // Check containing playlist IDs
      final containingA = await repository.getPlaylistIdsForTrack(trackA.id);
      expect(containingA.contains(playlist.id), isTrue);

      final initialOrder = await repository.getPlaylistTracks(playlist.id);
      expect(initialOrder.map((t) => t.id).toList(), ['local:track_a', 'local:track_b', 'local:track_c']);

      // Reorder tracks: C, A, B
      await repository.reorderPlaylistTracks(playlist.id, ['local:track_c', 'local:track_a', 'local:track_b']);
      final reordered = await repository.getPlaylistTracks(playlist.id);
      expect(reordered.map((t) => t.id).toList(), ['local:track_c', 'local:track_a', 'local:track_b']);

      // Toggle track (remove track C)
      final isNowInAfterToggle = await repository.toggleTrackInPlaylist(playlist.id, trackC);
      expect(isNowInAfterToggle, isFalse);
      final afterRemove = await repository.getPlaylistTracks(playlist.id);
      expect(afterRemove.map((t) => t.id).toList(), ['local:track_a', 'local:track_b']);

      // Toggle track back in (add track C)
      final isNowInAgain = await repository.toggleTrackInPlaylist(playlist.id, trackC);
      expect(isNowInAgain, isTrue);
      final afterAdd = await repository.getPlaylistTracks(playlist.id);
      expect(afterAdd.length, 3);
    });

    test('Search query matches title or artist', () async {
      final track = Track(
        id: 'local:search_1',
        title: 'Velvet Chill Harmony',
        artistName: 'Ketsa Composer',
        albumTitle: 'Night Owls',
        source: AudioSourceType.local,
        sourceId: 's1',
        durationMs: 150000,
        audioUrl: '/path/s1.mp3',
        addedAt: DateTime.now(),
      );

      // Insert via repository
      await repository.toggleLike(track);

      // Search by title keyword
      final titleMatches = await repository.searchTracks('Velvet');
      expect(titleMatches.length, 1);
      expect(titleMatches.first.id, 'local:search_1');

      // Search by artist keyword
      final artistMatches = await repository.searchTracks('Ketsa');
      expect(artistMatches.length, 1);

      // Search by album keyword
      final albumMatches = await repository.searchTracks('Owls');
      expect(albumMatches.length, 1);

      // Non-matching query
      final noMatches = await repository.searchTracks('NonexistentTrack');
      expect(noMatches, isEmpty);
    });

    test('Supported file extensions include mp3, wav, flac, m4a', () {
      expect(LocalFilesScanner.supportedExtensions, contains('.mp3'));
      expect(LocalFilesScanner.supportedExtensions, contains('.wav'));
      expect(LocalFilesScanner.supportedExtensions, contains('.flac'));
      expect(LocalFilesScanner.supportedExtensions, contains('.m4a'));
    });

    test('Track model serialization toMap and fromMap', () {
      final now = DateTime.now();
      final track = Track(
        id: 'local:serial_1',
        title: 'Serialization Test',
        artistName: 'Test Artist',
        albumTitle: 'Test Album',
        source: AudioSourceType.local,
        sourceId: 'src_1',
        durationMs: 120000,
        audioUrl: '/test.mp3',
        addedAt: now,
      );

      final map = track.toMap();
      final parsed = Track.fromMap(map);

      expect(parsed.id, track.id);
      expect(parsed.title, track.title);
      expect(parsed.artistName, track.artistName);
      expect(parsed.source, AudioSourceType.local);
      expect(parsed.durationMs, 120000);
    });

    test('Record listening history and query play counts', () async {
      final track1 = Track(
        id: 'local:history_1',
        title: 'Song One',
        artistName: 'Artist A',
        source: AudioSourceType.local,
        sourceId: '1',
        durationMs: 180000,
        audioUrl: '/1.mp3',
        addedAt: DateTime.now(),
      );
      final track2 = Track(
        id: 'local:history_2',
        title: 'Song Two',
        artistName: 'Artist B',
        source: AudioSourceType.local,
        sourceId: '2',
        durationMs: 180000,
        audioUrl: '/2.mp3',
        addedAt: DateTime.now(),
      );

      // Play track1 twice, track2 once
      await repository.recordTrackPlay(track1);
      await repository.recordTrackPlay(track1);
      await repository.recordTrackPlay(track2);

      final counts = await repository.getTrackPlayCounts();
      expect(counts['local:history_1'], 2);
      expect(counts['local:history_2'], 1);
    });

    test('saveDownloadedTrack persists online track and watchLocalTracks emits it', () async {
      final onlineTrack = Track(
        id: 'saavn:online_dl_1',
        title: 'Kesariya',
        artistName: 'Arijit Singh',
        source: AudioSourceType.saavn,
        sourceId: 'dl_1',
        durationMs: 240000,
        audioUrl: 'https://example.com/audio.m4a',
        isDownloaded: false,
        addedAt: DateTime.now(),
      );

      // Initially not in local tracks
      expect(await repository.getLocalTracks(), isEmpty);

      // Save as downloaded
      await repository.saveDownloadedTrack(
        onlineTrack,
        filePath: '/storage/musify_downloads/kesariya.m4a',
        fileSizeBytes: 5242880,
      );

      final localTracks = await repository.getLocalTracks();
      expect(localTracks.length, 1);
      final saved = localTracks.first;
      expect(saved.id, 'saavn:online_dl_1');
      expect(saved.title, 'Kesariya');
      expect(saved.filePath, '/storage/musify_downloads/kesariya.m4a');
      expect(saved.isDownloaded, isTrue);
      expect(saved.fileSizeBytes, 5242880);

      // removeDownloadedTrack removes it from local tracks
      await repository.removeDownloadedTrack(saved.id);
      expect(await repository.getLocalTracks(), isEmpty);
    });

    test('deleteTrack removes track from playlists, history, and local tracks', () async {
      final track = Track(
        id: 'local:to_delete_1',
        title: 'Delete Me Track',
        artistName: 'Test Artist',
        source: AudioSourceType.local,
        sourceId: '/storage/delete_me.mp3',
        durationMs: 180000,
        audioUrl: '/storage/delete_me.mp3',
        filePath: '/storage/delete_me.mp3',
        isDownloaded: true,
        addedAt: DateTime.now(),
      );

      await repository.saveDownloadedTrack(track, filePath: '/storage/delete_me.mp3', fileSizeBytes: 1024);
      final playlist = await repository.createPlaylist('Favorites');
      await repository.addTrackToPlaylist(playlist.id, track);
      await repository.recordTrackPlay(track);

      // Verify it exists in playlist and history
      final playlistTracksBefore = await repository.getPlaylistTracks(playlist.id);
      expect(playlistTracksBefore.length, 1);
      final historyBefore = await repository.getTrackPlayCounts();
      expect(historyBefore.containsKey(track.id), isTrue);

      // Delete track
      await repository.deleteTrack(track);

      // Verify cascade deletion
      final playlistTracksAfter = await repository.getPlaylistTracks(playlist.id);
      expect(playlistTracksAfter, isEmpty);
      final historyAfter = await repository.getTrackPlayCounts();
      expect(historyAfter.containsKey(track.id), isFalse);
      final localTracksAfter = await repository.getLocalTracks();
      expect(localTracksAfter.any((t) => t.id == track.id), isFalse);
    });
  });
}
