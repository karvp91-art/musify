import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/player/now_playing_screen.dart';
import 'package:musify/services/audio_player_handler.dart';

class FakeAudioHandler extends Fake implements MusifyAudioHandler {
  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}
}

void main() {
  final testTrack = Track(
    id: 'local:1',
    title: 'Test Song Title',
    artistName: 'Test Artist',
    source: AudioSourceType.local,
    sourceId: '1',
    durationMs: 211000,
    audioUrl: '/path/song.mp3',
    addedAt: DateTime.now(),
  );

  testWidgets('NowPlayingScreen builds and renders cleanly', (tester) async {
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
          isPlaybackPlayingProvider.overrideWithValue(false),
          playerStateStreamProvider.overrideWith((ref) => Stream.value(playerState)),
        ],
        child: MaterialApp(
          home: NowPlayingScreen(
            onMinimize: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('Test Song Title'), findsOneWidget);
    expect(find.text('Test Artist'), findsOneWidget);
  });
}
