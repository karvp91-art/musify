import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';

import 'package:musify/presentation/providers/audio_providers.dart';

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
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
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
    // Play button is hidden in selection mode
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
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
}

