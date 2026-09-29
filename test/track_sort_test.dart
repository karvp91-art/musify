import 'package:flutter_test/flutter_test.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/models/track_sort_option.dart';

void main() {
  group('TrackSortOption Tests', () {
    final trackA = Track(
      id: 'local:1',
      title: 'A Beautiful Day',
      artistName: 'Zack Artist',
      source: AudioSourceType.local,
      sourceId: '1',
      durationMs: 120000,
      audioUrl: '/path/1.mp3',
      addedAt: DateTime(2026, 1, 1),
    );

    final trackB = Track(
      id: 'local:2',
      title: 'Zebra Groove',
      artistName: 'Alpha Artist',
      source: AudioSourceType.local,
      sourceId: '2',
      durationMs: 300000,
      audioUrl: '/path/2.mp3',
      addedAt: DateTime(2026, 5, 1),
    );

    final trackC = Track(
      id: 'local:3',
      title: 'Middle Rhythm',
      artistName: 'Beta Artist',
      source: AudioSourceType.local,
      sourceId: '3',
      durationMs: 200000,
      audioUrl: '/path/3.mp3',
      addedAt: DateTime(2026, 3, 1),
    );

    final allTracks = [trackA, trackB, trackC];

    test('Sort by recently added (newest first)', () {
      final sorted = TrackSortOption.recentlyAdded.sortTracks(allTracks);
      expect(sorted.map((t) => t.id).toList(), ['local:2', 'local:3', 'local:1']);
    });

    test('Sort by name A-Z', () {
      final sorted = TrackSortOption.titleAsc.sortTracks(allTracks);
      expect(sorted.map((t) => t.title).toList(), [
        'A Beautiful Day',
        'Middle Rhythm',
        'Zebra Groove',
      ]);
    });

    test('Sort by name Z-A', () {
      final sorted = TrackSortOption.titleDesc.sortTracks(allTracks);
      expect(sorted.map((t) => t.title).toList(), [
        'Zebra Groove',
        'Middle Rhythm',
        'A Beautiful Day',
      ]);
    });

    test('Sort by artist A-Z', () {
      final sorted = TrackSortOption.artistAsc.sortTracks(allTracks);
      expect(sorted.map((t) => t.artistName).toList(), [
        'Alpha Artist',
        'Beta Artist',
        'Zack Artist',
      ]);
    });

    test('Sort by duration (longest first)', () {
      final sorted = TrackSortOption.durationDesc.sortTracks(allTracks);
      expect(sorted.map((t) => t.durationMs).toList(), [
        300000,
        200000,
        120000,
      ]);
    });

    test('Sort by most played listening count', () {
      final playCounts = {
        'local:1': 15,
        'local:2': 2,
        'local:3': 40,
      };

      final sorted = TrackSortOption.mostPlayed.sortTracks(allTracks, playCounts: playCounts);
      expect(sorted.map((t) => t.id).toList(), [
        'local:3', // 40 plays
        'local:1', // 15 plays
        'local:2', // 2 plays
      ]);
    });
  });
}
