import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/data/sources/saavn_source_adapter.dart';
import 'package:musify/data/sources/youtube_source_adapter.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/playlist/import_playlist_screen.dart';
import 'package:musify/services/audio_player_handler.dart';
import 'package:musify/services/download_manager.dart';
import 'package:musify/services/playlist_import_service.dart';

class FakeMusifyAudioHandler extends Fake implements MusifyAudioHandler {
  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> skipToNext() async {}
}

class FakeAudioRepoWithTracking extends Fake implements AudioRepository {
  final List<String> createdPlaylists = [];
  final Map<String, List<Track>> addedTracksByPlaylistId = {};
  int _nextId = 1;

  @override
  Future<Playlist> createPlaylist(String name, {String? description}) async {
    final id = (_nextId++).toString();
    createdPlaylists.add(name);
    return Playlist(
      id: id,
      name: name,
      description: description,
      tracks: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    addedTracksByPlaylistId.putIfAbsent(playlistId, () => []).add(track);
  }
}

class FakeDownloadManager extends AudioDownloadManager {
  FakeDownloadManager({required super.repo});

  @override
  Track? get activeDownloadingTrack => null;

  @override
  double get activeProgress => 0.0;

  @override
  Track? get lastCompletedTrack => null;
}

void main() {
  group('PlaylistImportService Unit Tests', () {
    test('detectPlatform accurately identifies supported and unsupported formats', () {
      // Spotify
      expect(
        PlaylistImportService.detectPlatform('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        'spotify',
      );
      expect(
        PlaylistImportService.detectPlatform('https://open.spotify.com/embed/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        'spotify',
      );
      expect(
        PlaylistImportService.detectPlatform('spotify:playlist:37i9dQZF1DXcBWIGoYBM5M'),
        'spotify',
      );

      // YouTube
      expect(
        PlaylistImportService.detectPlatform('https://www.youtube.com/playlist?list=PL123456789'),
        'youtube',
      );
      expect(
        PlaylistImportService.detectPlatform('https://music.youtube.com/playlist?list=PL123456789'),
        'youtube',
      );
      expect(
        PlaylistImportService.detectPlatform('https://youtu.be/playlist?list=PL123456789'),
        'youtube',
      );
      expect(
        PlaylistImportService.detectPlatform('PL123456789'),
        'youtube',
      );
      expect(
        PlaylistImportService.extractYouTubePlaylistId('https://www.youtube.com/playlist?list=PL123456789'),
        'PL123456789',
      );
      expect(
        PlaylistImportService.extractYouTubePlaylistId('https://music.youtube.com/playlist?list=PL123456789'),
        'PL123456789',
      );
      expect(
        PlaylistImportService.extractYouTubePlaylistId('https://www.youtube.com/watch?v=xyz&list=VLPL123456789'),
        'PL123456789',
      );
      expect(
        PlaylistImportService.extractYouTubePlaylistId('PL123456789'),
        'PL123456789',
      );

      // JioSaavn
      expect(
        PlaylistImportService.detectPlatform('https://www.jiosaavn.com/featured/weekly-top-songs/xyz'),
        'jiosaavn',
      );
      expect(
        PlaylistImportService.detectPlatform('https://www.jiosaavn.com/playlist/romantic-hits/123'),
        'jiosaavn',
      );
      expect(
        PlaylistImportService.detectPlatform('1145244939'),
        'jiosaavn',
      );

      // Unsupported
      expect(
        PlaylistImportService.detectPlatform('https://soundcloud.com/artist/playlist'),
        'unknown',
      );
      expect(
        PlaylistImportService.detectPlatform('random text without platform'),
        'unknown',
      );
    });

    test('deepCleanTitle accurately strips YouTube noise tags, preserves hyphenated words, and filters artist', () {
      // 1. "Kalank Title Track – Lyrical" strips Lyrical and dangling separator
      expect(
        PlaylistImportService.deepCleanTitle('Kalank Title Track – Lyrical'),
        'Kalank Title Track',
      );

      // 2. "Tum Hi Ho - Arijit Singh" with artist Arijit Singh drops artist part
      expect(
        PlaylistImportService.deepCleanTitle('Tum Hi Ho - Arijit Singh', artist: 'Arijit Singh'),
        'Tum Hi Ho',
      );

      // 3. "PROS BANDIDO (ULTRA SLOWED)" strips parenthesized tag
      expect(
        PlaylistImportService.deepCleanTitle('PROS BANDIDO (ULTRA SLOWED)'),
        'PROS BANDIDO',
      );

      // 4. Preserves hyphenated words without spaces (Lo-Fi, Ek-Do-Teen)
      expect(
        PlaylistImportService.deepCleanTitle('Lo-Fi Beats'),
        'Lo-Fi Beats',
      );
      expect(
        PlaylistImportService.deepCleanTitle('Ek-Do-Teen'),
        'Ek-Do-Teen',
      );

      // 5. Preserves legitimate title words like "Song", "Live"
      expect(
        PlaylistImportService.deepCleanTitle('Song of the Sea'),
        'Song of the Sea',
      );
      expect(
        PlaylistImportService.deepCleanTitle("Live While We're Young"),
        "Live While We're Young",
      );
    });

    test('saveAsInAppPlaylist creates playlist and adds all tracks into Drift SQLite', () async {
      final fakeRepo = FakeAudioRepoWithTracking();
      final importer = PlaylistImportService(
        saavnAdapter: FakeSaavnSourceAdapter(),
        youtubeAdapter: FakeYouTubeSourceAdapter(),
        audioRepository: fakeRepo,
      );

      final mockTracks = [
        Track(
          id: 't1',
          title: 'Kesariya',
          artistName: 'Arijit Singh',
          source: AudioSourceType.saavn,
          sourceId: 's1',
          audioUrl: 'https://cdn.example.com/audio1.mp3',
          durationMs: 268000,
          addedAt: DateTime.now(),
        ),
        Track(
          id: 't2',
          title: 'Starboy',
          artistName: 'The Weeknd',
          source: AudioSourceType.saavn,
          sourceId: 's2',
          audioUrl: 'https://cdn.example.com/audio2.mp3',
          durationMs: 230000,
          addedAt: DateTime.now(),
        ),
      ];

      final result = await importer.saveAsInAppPlaylist(
        name: 'My Imported Hits',
        description: 'Imported from SPOTIFY',
        tracks: mockTracks,
      );

      expect(result.name, 'My Imported Hits');
      expect(fakeRepo.createdPlaylists, contains('My Imported Hits'));
      expect(fakeRepo.addedTracksByPlaylistId[result.id]?.length, 2);
      expect(fakeRepo.addedTracksByPlaylistId[result.id]?.first.title, 'Kesariya');
      expect(fakeRepo.addedTracksByPlaylistId[result.id]?.last.title, 'Starboy');
    });
  });

  group('ImportPlaylistScreen Widget Tests', () {
    testWidgets('Renders studio equalizer pattern header, platform pills, and input', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakeAudioRepoWithTracking();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRepositoryProvider.overrideWithValue(fakeRepo),
            audioHandlerProvider.overrideWithValue(FakeMusifyAudioHandler()),
            downloadManagerProvider.overrideWithValue(FakeDownloadManager(repo: fakeRepo)),
            playerStateStreamProvider.overrideWith((ref) => Stream.value(
              PlayerStateModel(
                isPlaying: false,
                position: Duration.zero,
                duration: Duration.zero,
              ),
            )),
            currentPlayingTrackProvider.overrideWithValue(null),
            isPlaybackPlayingProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: ImportPlaylistScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Header following studio equalizer UI pattern
      expect(find.text('Import Playlist'), findsOneWidget);
      expect(find.text('Import External Playlist'), findsOneWidget);
      expect(
        find.text('Convert Spotify, YouTube & JioSaavn playlists into in-app playlists'),
        findsOneWidget,
      );

      // Verify Platform Pills
      expect(find.text('Auto Detect'), findsOneWidget);
      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('JioSaavn'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);

      // Verify Link Input and Action Button
      expect(find.text('Paste playlist link or URL...'), findsOneWidget);
      expect(find.text('Fetch & Match Songs'), findsOneWidget);

      // Tapping Action Button with empty input shows validation error
      await tester.tap(find.text('Fetch & Match Songs'));
      await tester.pump();
      expect(find.text('Please paste a playlist URL or ID.'), findsOneWidget);

      // Enter a valid URL
      await tester.enterText(
        find.byType(TextField).first,
        'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
      );
      await tester.pump();

      // Clear button should now be visible
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap clear button to reset
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(find.text('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'), findsNothing);
    });
  });
}

class FakeSaavnSourceAdapter extends Fake implements SaavnSourceAdapter {}
class FakeYouTubeSourceAdapter extends Fake implements YouTubeSourceAdapter {}
