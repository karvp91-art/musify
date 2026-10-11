import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/data/repositories/stream_content_repository.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/stream/all_artists_screen.dart';
import 'package:musify/presentation/screens/stream/all_movie_soundtracks_screen.dart';
import 'package:musify/services/audio_player_handler.dart';
import 'package:musify/services/download_manager.dart';

class FakeAudioHandler extends Fake implements MusifyAudioHandler {
  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> skipToNext() async {}
}

class FakeAudioRepository extends Fake implements AudioRepository {}

class FakeDownloadManager extends AudioDownloadManager {
  FakeDownloadManager() : super(repo: FakeAudioRepository());

  @override
  Track? get activeDownloadingTrack => null;

  @override
  double get activeProgress => 0.0;

  @override
  Track? get lastCompletedTrack => null;
}

void main() {
  final fakeArtistsAll = [
    const SearchArtistItem(id: 'a1', title: 'Arijit Singh', description: 'Artist'),
    const SearchArtistItem(id: 'a2', title: 'The Weeknd', description: 'Artist'),
    const SearchArtistItem(id: 'a3', title: 'YOASOBI', description: 'Japanese Artist'),
  ];

  final fakeArtistsJapanese = [
    const SearchArtistItem(id: 'a3', title: 'YOASOBI', description: 'Japanese Artist'),
    const SearchArtistItem(id: 'a4', title: 'Kenshi Yonezu', description: 'Japanese Artist'),
  ];

  final fakeAlbumsAll = [
    const SearchAlbumItem(id: 'alb1', title: 'Animal', music: 'Pritam', year: '2023'),
    const SearchAlbumItem(id: 'alb2', title: 'Interstellar', music: 'Hans Zimmer', year: '2014'),
    const SearchAlbumItem(id: 'alb3', title: 'Your Name', music: 'RADWIMPS', year: '2016'),
  ];

  final fakeAlbumsJapanese = [
    const SearchAlbumItem(id: 'alb3', title: 'Your Name', music: 'RADWIMPS', year: '2016'),
    const SearchAlbumItem(id: 'alb4', title: 'Suzume', music: 'RADWIMPS', year: '2022'),
  ];

  testWidgets('AllArtistsScreen renders header, categories, and artists correctly', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
          downloadManagerProvider.overrideWithValue(FakeDownloadManager()),
          playerStateStreamProvider.overrideWith((ref) => Stream.value(
            PlayerStateModel(
              isPlaying: false,
              position: Duration.zero,
              duration: Duration.zero,
            ),
          )),
          currentPlayingTrackProvider.overrideWithValue(null),
          isPlaybackPlayingProvider.overrideWithValue(false),
          streamArtistsByCategoryProvider.overrideWith((ref, category) async {
            if (category == 'japanese') {
              return fakeArtistsJapanese;
            }
            return fakeArtistsAll;
          }),
        ],
        child: const MaterialApp(
          home: AllArtistsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Title & Subtitle
    expect(find.text('Explore Artists'), findsOneWidget);
    expect(find.text('Discover voices across cultures & languages'), findsOneWidget);

    // Verify Category Filter Chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Bollywood / Hindi'), findsOneWidget);
    expect(find.text('English / Global'), findsOneWidget);
    expect(find.text('Japanese / Anime'), findsOneWidget);
    expect(find.text('Punjabi'), findsOneWidget);
    expect(find.text('South Indian'), findsOneWidget);

    // Verify artists are rendered
    expect(find.text('Arijit Singh'), findsOneWidget);
    expect(find.text('The Weeknd'), findsOneWidget);
    expect(find.text('YOASOBI'), findsOneWidget);

    // Switch category to Japanese / Anime
    await tester.tap(find.text('Japanese / Anime'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Japanese category results
    expect(find.text('YOASOBI'), findsOneWidget);
    expect(find.text('Kenshi Yonezu'), findsOneWidget);
    expect(find.text('Arijit Singh'), findsNothing);

    // Test Search input
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Kenshi');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Kenshi Yonezu'), findsOneWidget);
    expect(find.text('YOASOBI'), findsNothing);
  });

  testWidgets('AllMovieSoundtracksScreen renders header, categories, and soundtrack albums correctly', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
          downloadManagerProvider.overrideWithValue(FakeDownloadManager()),
          playerStateStreamProvider.overrideWith((ref) => Stream.value(
            PlayerStateModel(
              isPlaying: false,
              position: Duration.zero,
              duration: Duration.zero,
            ),
          )),
          currentPlayingTrackProvider.overrideWithValue(null),
          isPlaybackPlayingProvider.overrideWithValue(false),
          streamSoundtracksByCategoryProvider.overrideWith((ref, category) async {
            if (category == 'japanese') {
              return fakeAlbumsJapanese;
            }
            return fakeAlbumsAll;
          }),
        ],
        child: const MaterialApp(
          home: AllMovieSoundtracksScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Title & Subtitle
    expect(find.text('Movie Soundtracks'), findsOneWidget);
    expect(find.text('Original scores, blockbusters & iconic albums'), findsOneWidget);

    // Verify Category Filter Chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Bollywood / Hindi'), findsOneWidget);
    expect(find.text('Hollywood / English'), findsOneWidget);
    expect(find.text('Japanese / Anime OST'), findsOneWidget);
    expect(find.text('South Indian'), findsOneWidget);
    expect(find.text('Punjabi'), findsOneWidget);

    // Verify albums rendered
    expect(find.text('Animal'), findsOneWidget);
    expect(find.text('Interstellar'), findsOneWidget);
    expect(find.text('Your Name'), findsOneWidget);

    // Switch category to Japanese / Anime OST
    await tester.tap(find.text('Japanese / Anime OST'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Japanese category albums
    expect(find.text('Your Name'), findsOneWidget);
    expect(find.text('Suzume'), findsOneWidget);
    expect(find.text('Animal'), findsNothing);

    // Test Search input
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Suzu');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Suzume'), findsOneWidget);
    expect(find.text('Your Name'), findsNothing);
  });

  testWidgets('AllArtistsScreen triggers pagination when scrolling to bottom', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = _MockStreamRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
          downloadManagerProvider.overrideWithValue(FakeDownloadManager()),
          playerStateStreamProvider.overrideWith((ref) => Stream.value(
            PlayerStateModel(
              isPlaying: false,
              position: Duration.zero,
              duration: Duration.zero,
            ),
          )),
          currentPlayingTrackProvider.overrideWithValue(null),
          isPlaybackPlayingProvider.overrideWithValue(false),
          streamContentRepositoryProvider.overrideWithValue(fakeRepo),
          streamArtistsByCategoryProvider.overrideWith((ref, category) async {
            return fakeRepo.getArtistsByCategory(category, page: 1);
          }),
        ],
        child: const MaterialApp(
          home: AllArtistsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Initially Page 1 artists are visible
    expect(find.text('Artist 1'), findsOneWidget);
    expect(find.text('Artist Page 2 Extra'), findsNothing);

    // Scroll to bottom to trigger load more
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Page 2 artist should now be fetched and displayed
    expect(find.text('Artist Page 2 Extra'), findsOneWidget);
  });

  testWidgets('AllMovieSoundtracksScreen triggers pagination when scrolling to bottom', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = _MockStreamRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
          downloadManagerProvider.overrideWithValue(FakeDownloadManager()),
          playerStateStreamProvider.overrideWith((ref) => Stream.value(
            PlayerStateModel(
              isPlaying: false,
              position: Duration.zero,
              duration: Duration.zero,
            ),
          )),
          currentPlayingTrackProvider.overrideWithValue(null),
          isPlaybackPlayingProvider.overrideWithValue(false),
          streamContentRepositoryProvider.overrideWithValue(fakeRepo),
          streamSoundtracksByCategoryProvider.overrideWith((ref, category) async {
            return fakeRepo.getMovieSoundtracksByCategory(category, page: 1);
          }),
        ],
        child: const MaterialApp(
          home: AllMovieSoundtracksScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Initially Page 1 albums are visible
    expect(find.text('Album 1'), findsOneWidget);
    expect(find.text('Album Page 2 Extra'), findsNothing);

    // Scroll to bottom to trigger load more
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Page 2 album should now be fetched and displayed
    expect(find.text('Album Page 2 Extra'), findsOneWidget);
  });
}

class _MockStreamRepo extends Fake implements StreamContentRepository {
  @override
  Future<List<SearchArtistItem>> getArtistsByCategory(
    String category, {
    int page = 1,
    int limit = 18,
    bool forceRefresh = false,
  }) async {
    if (page == 1) {
      return List.generate(
        15,
        (i) => SearchArtistItem(id: 'a$i', title: 'Artist ${i + 1}', description: 'Singer'),
      );
    } else {
      return [
        const SearchArtistItem(id: 'a_p2', title: 'Artist Page 2 Extra', description: 'Singer'),
      ];
    }
  }

  @override
  Future<List<SearchAlbumItem>> getMovieSoundtracksByCategory(
    String category, {
    int page = 1,
    int limit = 18,
    bool forceRefresh = false,
  }) async {
    if (page == 1) {
      return List.generate(
        10,
        (i) => SearchAlbumItem(id: 'alb$i', title: 'Album ${i + 1}', music: 'Composer'),
      );
    } else {
      return [
        const SearchAlbumItem(id: 'alb_p2', title: 'Album Page 2 Extra', music: 'Composer'),
      ];
    }
  }
}
