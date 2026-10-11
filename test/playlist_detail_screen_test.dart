import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/playlist/playlist_detail_screen.dart';
import 'package:musify/presentation/widgets/add_songs_to_playlist_modal.dart';
import 'package:musify/presentation/widgets/shimmer_skeleton.dart';
import 'package:musify/services/audio_player_handler.dart';
import 'package:musify/services/download_manager.dart';
import 'package:musify/services/preferences_service.dart';

class FakeAudioHandler extends Fake implements MusifyAudioHandler {
  final List<Track> fakeQueue = [];
  Track? lastPlayedTrack;

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> playTrackList(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isNotEmpty) {
      lastPlayedTrack = tracks[startIndex];
    }
  }

  @override
  Future<void> insertNextInQueue(Track track) async {
    fakeQueue.insert(0, track);
  }

  @override
  Future<void> addToQueue(Track track) async {
    fakeQueue.add(track);
  }
}

class FakeAudioRepo extends Fake implements AudioRepository {
  final List<Track> playlistTracks = [];
  final List<Track> likedTracks = [];

  @override
  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    playlistTracks.add(track);
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    playlistTracks.removeWhere((t) => t.id == trackId);
  }

  @override
  Future<void> toggleLike(Track track) async {
    if (likedTracks.any((t) => t.id == track.id)) {
      likedTracks.removeWhere((t) => t.id == track.id);
    } else {
      likedTracks.add(track);
    }
  }

  @override
  Stream<List<Track>> watchPlaylistTracks(String playlistId) {
    return Stream.value(playlistTracks);
  }

  @override
  Stream<List<Track>> watchLikedTracks() {
    return Stream.value(likedTracks);
  }

  @override
  Stream<List<Playlist>> watchPlaylists() {
    return Stream.value([]);
  }
}

class FakeDownloadManager extends AudioDownloadManager {
  FakeDownloadManager({required super.repo});

  final Set<String> downloadedIds = {};

  @override
  bool isDownloaded(String trackId) => downloadedIds.contains(trackId);

  @override
  bool isDownloading(String trackId) => false;

  @override
  Future<bool> downloadTrack(Track track) async {
    downloadedIds.add(track.id);
    return true;
  }

  @override
  Track? get activeDownloadingTrack => null;

  @override
  double get activeProgress => 0.0;

  @override
  Track? get lastCompletedTrack => null;
}

void main() {
  final sampleTrack1 = Track(
    id: 'local:1',
    title: 'Song One',
    artistName: 'Artist A',
    source: AudioSourceType.local,
    sourceId: '1',
    durationMs: 180000,
    audioUrl: '/test/1.mp3',
    addedAt: DateTime.now(),
  );

  final sampleTrack2 = Track(
    id: 'local:2',
    title: 'Song Two',
    artistName: 'Artist B',
    source: AudioSourceType.local,
    sourceId: '2',
    durationMs: 240000,
    audioUrl: '/test/2.mp3',
    addedAt: DateTime.now(),
  );

  final samplePlaylist = Playlist(
    id: 'pl:1',
    name: 'My Cool Vibes',
    description: 'A test playlist',
    tracks: [sampleTrack1, sampleTrack2],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  testWidgets('PlaylistDetailScreen renders and favorite heart button toggles persistence', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeRepo = FakeAudioRepo();
    fakeRepo.playlistTracks.addAll([sampleTrack1, sampleTrack2]);
    final fakeHandler = FakeAudioHandler();
    final fakePrefs = PreferencesService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesServiceProvider.overrideWithValue(fakePrefs),
          audioRepositoryProvider.overrideWithValue(fakeRepo),
          audioHandlerProvider.overrideWithValue(fakeHandler),
          downloadManagerProvider.overrideWithValue(FakeDownloadManager(repo: fakeRepo)),
          playlistTracksProvider('pl:1').overrideWithValue(AsyncData([sampleTrack1, sampleTrack2])),
          playlistsStreamProvider.overrideWithValue(AsyncData([samplePlaylist])),
        ],
        child: MaterialApp(
          home: PlaylistDetailScreen(
            title: samplePlaylist.name,
            playlist: samplePlaylist,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify title and subtitle
    expect(find.text('My Cool Vibes'), findsOneWidget);
    expect(find.text('Song One'), findsOneWidget);
    expect(find.text('Song Two'), findsOneWidget);

    // Verify favorite toggle
    expect(fakePrefs.isPlaylistFavorite('pl:1'), isFalse);
    final heartFinder = find.byIcon(Icons.favorite_border_rounded);
    expect(heartFinder, findsWidgets);

    // Tap the header action heart
    await tester.tap(heartFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Should now be favorite in preferences
    expect(fakePrefs.isPlaylistFavorite('pl:1'), isTrue);

    // Drain toast timer
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Empty playlist displays functional empty state that opens Add Songs sheet', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final emptyPlaylist = Playlist(
      id: 'pl:empty',
      name: 'Empty Playlist',
      tracks: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final fakeRepo = FakeAudioRepo();
    final fakeHandler = FakeAudioHandler();
    final fakePrefs = PreferencesService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesServiceProvider.overrideWithValue(fakePrefs),
          audioRepositoryProvider.overrideWithValue(fakeRepo),
          audioHandlerProvider.overrideWithValue(fakeHandler),
          downloadManagerProvider.overrideWithValue(FakeDownloadManager(repo: fakeRepo)),
          playlistTracksProvider('pl:empty').overrideWithValue(const AsyncData([])),
          playlistsStreamProvider.overrideWithValue(AsyncData([emptyPlaylist])),
          localTracksProvider.overrideWithValue(AsyncData([sampleTrack1, sampleTrack2])),
        ],
        child: MaterialApp(
          home: PlaylistDetailScreen(
            title: emptyPlaylist.name,
            playlist: emptyPlaylist,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('This playlist is empty'), findsOneWidget);

    // Tapping the "Add songs" pill opens the add songs modal sheet
    final addSongsPill = find.text('Add songs');
    expect(addSongsPill, findsOneWidget);

    await tester.tap(addSongsPill);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Bottom sheet is displayed
    expect(find.byType(AddSongsToPlaylistSheet), findsOneWidget);
  });
}
