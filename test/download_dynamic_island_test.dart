import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/download_dynamic_island.dart';
import 'package:musify/services/download_manager.dart';

class FakeAudioRepository extends Fake implements AudioRepository {}

class FakeDownloadManager extends AudioDownloadManager {
  Track? _fakeActiveTrack;
  double _fakeProgress = 0.0;
  Track? _fakeCompletedTrack;

  FakeDownloadManager() : super(repo: FakeAudioRepository());

  @override
  Track? get activeDownloadingTrack => _fakeActiveTrack;

  @override
  double get activeProgress => _fakeProgress;

  @override
  Track? get lastCompletedTrack => _fakeCompletedTrack;

  void setActive(Track? track, double progress) {
    _fakeActiveTrack = track;
    _fakeProgress = progress;
    _fakeCompletedTrack = null;
    notifyListeners();
  }

  void setCompleted(Track? track) {
    _fakeActiveTrack = null;
    _fakeCompletedTrack = track;
    notifyListeners();
  }
}

void main() {
  final testTrack = Track(
    id: 'saavn:vic_lap',
    title: 'Victory Lap',
    artistName: 'Nipsey Hussle',
    source: AudioSourceType.saavn,
    sourceId: 'vic_lap',
    durationMs: 238000,
    audioUrl: 'https://example.com/stream.mp3',
    addedAt: DateTime.now(),
  );

  testWidgets('DownloadDynamicIsland renders downloading state with progress bar matching reference image', (tester) async {
    final fakeManager = FakeDownloadManager();
    fakeManager.setActive(testTrack, 0.62);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadManagerProvider.overrideWithValue(fakeManager),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DownloadDynamicIsland(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // 1. Title
    expect(find.text('Victory Lap'), findsOneWidget);

    // 2. Status & percentage matching reference image
    expect(find.text('Downloading • 62%'), findsOneWidget);

    // 3. Dismiss/cancel action button icon
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('DownloadDynamicIsland renders completed state', (tester) async {
    final fakeManager = FakeDownloadManager();
    fakeManager.setCompleted(testTrack);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadManagerProvider.overrideWithValue(fakeManager),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DownloadDynamicIsland(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Victory Lap'), findsOneWidget);
    expect(find.text('Downloaded • Ready offline'), findsOneWidget);
    // Artwork status badge + action button check icon
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });
}
