import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/player/mini_player.dart';
import 'package:musify/services/audio_player_handler.dart';

class FakeAudioHandler extends Fake implements MusifyAudioHandler {
  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> skipToNext() async {}
}

void main() {
  final testTrack = Track(
    id: 'local:1',
    title: 'shup buqqin tokyodrift danzaku',
    artistName: 'Unknown Artist',
    source: AudioSourceType.local,
    sourceId: '1',
    durationMs: 211000, // 3:31
    audioUrl: '/path/song.mp3',
    addedAt: DateTime.now(),
  );

  testWidgets('MiniPlayer renders matching reference UI elements', (tester) async {
    final playerState = PlayerStateModel(
      currentTrack: testTrack,
      isPlaying: true,
      position: const Duration(seconds: 42),
      duration: const Duration(minutes: 3, seconds: 31),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
          currentPlayingTrackProvider.overrideWithValue(testTrack),
          isPlaybackPlayingProvider.overrideWithValue(true),
          playerStateStreamProvider.overrideWith((ref) => Stream.value(playerState)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MiniPlayer(
              onExpand: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Title & Artist
    expect(find.text('shup buqqin tokyodrift danzaku'), findsOneWidget);
    expect(find.text('Unknown Artist'), findsOneWidget);

    // 2. Timestamps from reference UI
    expect(find.text('0:42'), findsOneWidget);
    expect(find.text('3:31'), findsOneWidget);

    // 3. Play/Pause and Next action buttons
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
  });

  testWidgets('MiniPlayer handles large text scaling and small viewport without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final playerState = PlayerStateModel(
      currentTrack: testTrack,
      isPlaying: true,
      position: const Duration(seconds: 42),
      duration: const Duration(minutes: 3, seconds: 31),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
          currentPlayingTrackProvider.overrideWithValue(testTrack),
          isPlaybackPlayingProvider.overrideWithValue(true),
          playerStateStreamProvider.overrideWith((ref) => Stream.value(playerState)),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: MiniPlayer(
                onExpand: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('shup buqqin tokyodrift danzaku'), findsWidgets);
    expect(find.text('0:42'), findsOneWidget);
    expect(find.text('3:31'), findsOneWidget);
  });
}
