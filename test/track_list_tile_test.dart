import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';
import 'package:musify/services/download_manager.dart';

class FakeAudioRepository extends Fake implements AudioRepository {}

class MockDownloadManager extends AudioDownloadManager {
  Track? downloadedTrack;
  bool isTrackDownloaded;

  MockDownloadManager({this.isTrackDownloaded = false})
      : super(repo: FakeAudioRepository());

  @override
  bool isDownloaded(String trackId) => isTrackDownloaded;

  @override
  DownloadState getState(String trackId) {
    if (isTrackDownloaded) {
      return const DownloadState(status: DownloadStatus.downloaded, progress: 1.0);
    }
    return const DownloadState(status: DownloadStatus.notDownloaded);
  }

  @override
  Future<bool> downloadTrack(Track track) async {
    downloadedTrack = track;
    notifyListeners();
    return true;
  }
}

void main() {
  final testTrack = Track(
    id: 'local:test_song',
    title: 'Despacito',
    artistName: 'Luis Fonsi',
    source: AudioSourceType.local,
    sourceId: '/storage/despacito.mp3',
    durationMs: 230000,
    audioUrl: '/storage/despacito.mp3',
    addedAt: DateTime.now(),
  );

  final testYtTrack = Track(
    id: 'youtube:dQw4w9WgXcQ',
    title: 'Never Gonna Give You Up',
    artistName: 'Rick Astley',
    source: AudioSourceType.youtube,
    sourceId: 'dQw4w9WgXcQ',
    durationMs: 213000,
    audioUrl: '',
    addedAt: DateTime.now(),
  );

  testWidgets('TrackListTile renders normal mode with play button', (tester) async {
    bool tapped = false;
    bool longPressed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          likedTrackIdsProvider.overrideWithValue({}),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TrackListTile(
              track: testTrack,
              onTap: () => tapped = true,
              onLongPress: () => longPressed = true,
              isSelectionMode: false,
              isSelected: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Despacito'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.tap(find.text('Despacito'));
    expect(tapped, isTrue);

    await tester.longPress(find.text('Despacito'));
    expect(longPressed, isTrue);
  });

  testWidgets('TrackListTile renders selection mode with check indicator and hides play button', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          likedTrackIdsProvider.overrideWithValue({}),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TrackListTile(
              track: testTrack,
              onTap: () => tapped = true,
              isSelectionMode: true,
              isSelected: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Despacito'), findsOneWidget);
    // More options button is hidden in selection mode
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    // Selected checkbox is visible
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('Despacito'));
    expect(tapped, isTrue);
  });

  testWidgets('TrackListTile renders inside GlassScaffold with transparent Material without assertion error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          likedTrackIdsProvider.overrideWithValue({}),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Material(
              type: MaterialType.transparency,
              child: TrackListTile(
                track: testTrack,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Despacito'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TrackListTile for undownloaded YouTube track only shows download button and note', (tester) async {
    final mockManager = MockDownloadManager(isTrackDownloaded: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          likedTrackIdsProvider.overrideWithValue({}),
          downloadManagerProvider.overrideWithValue(mockManager),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TrackListTile(
              track: testYtTrack,
              isYouTubeSection: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    // Track title and YT badge
    expect(find.text('Never Gonna Give You Up'), findsOneWidget);
    expect(find.text('YT'), findsOneWidget);

    // Note that YouTube is only for download not streaming
    expect(find.textContaining('Download only (no streaming)'), findsOneWidget);

    // Play button must NOT be rendered
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    // Download button MUST be rendered
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);

    // Tap download button
    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(mockManager.downloadedTrack?.id, equals(testYtTrack.id));
  });

  testWidgets('TrackListTile for downloaded YouTube track shows play button and duration', (tester) async {
    final downloadedYtTrack = testYtTrack.copyWith(isDownloaded: true);
    final mockManager = MockDownloadManager(isTrackDownloaded: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          likedTrackIdsProvider.overrideWithValue({}),
          downloadManagerProvider.overrideWithValue(mockManager),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TrackListTile(
              track: downloadedYtTrack,
              isYouTubeSection: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    // Downloaded track shows duration, not 'Download only'
    expect(find.textContaining('Download only (no streaming)'), findsNothing);
    expect(find.textContaining('3:33'), findsOneWidget);

    // More options menu IS visible
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

    // Download button is NOT rendered as trailing action
    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });
}


