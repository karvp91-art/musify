import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

void main() {
  test('Track isLocal getter returns true for local source and false for saavn', () {
    final localTrack = Track(
      id: 'local:1',
      title: 'Local Song',
      artistName: 'Local Artist',
      source: AudioSourceType.local,
      sourceId: '1',
      durationMs: 180000,
      audioUrl: '/path/song.mp3',
      addedAt: DateTime.now(),
    );

    final saavnTrack = Track(
      id: 'saavn:2',
      title: 'Saavn Song',
      artistName: 'Saavn Artist',
      source: AudioSourceType.saavn,
      sourceId: '2',
      durationMs: 200000,
      audioUrl: 'https://saavn.cdn/song.mp3',
      addedAt: DateTime.now(),
    );

    expect(localTrack.isLocal, isTrue);
    expect(saavnTrack.isLocal, isFalse);
  });

  test('TabIndexNotifier default index is 0 and switches correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(currentTabIndexProvider), 0);
    container.read(currentTabIndexProvider.notifier).setIndex(1);
    expect(container.read(currentTabIndexProvider), 1);
  });
}
