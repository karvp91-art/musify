import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/data/database/app_database.dart';
import 'package:musify/data/repositories/audio_repository_impl.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/services/download_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AudioRepositoryImpl repository;
  late AudioDownloadManager downloadManager;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = AudioRepositoryImpl(db);
    downloadManager = AudioDownloadManager(repo: repository);
  });

  tearDown(() async {
    downloadManager.dispose();
    await db.close();
  });

  group('AudioDownloadManager Unit Tests', () {
    test('Initial download state is notDownloaded', () {
      final state = downloadManager.getState('track_123');
      expect(state.status, DownloadStatus.notDownloaded);
      expect(state.isDownloaded, isFalse);
      expect(state.isDownloading, isFalse);
      expect(downloadManager.isDownloaded('track_123'), isFalse);
      expect(downloadManager.isDownloading('track_123'), isFalse);
    });

    test('cancelDownload resets state to notDownloaded', () {
      downloadManager.cancelDownload('track_123');
      final state = downloadManager.getState('track_123');
      expect(state.status, DownloadStatus.notDownloaded);
    });

    test('removeDownloadedTrack updates state and invokes repository', () async {
      final track = Track(
        id: 'saavn:test_dl',
        title: 'Channa Mereya',
        artistName: 'Arijit Singh',
        source: AudioSourceType.saavn,
        sourceId: 'test_dl',
        durationMs: 240000,
        audioUrl: 'https://example.com/channa.mp3',
        isDownloaded: true,
        addedAt: DateTime.now(),
      );

      await repository.saveDownloadedTrack(
        track,
        filePath: '/storage/channa.mp3',
        fileSizeBytes: 2048,
      );

      await downloadManager.removeDownloadedTrack(track);

      final state = downloadManager.getState(track.id);
      expect(state.status, DownloadStatus.notDownloaded);
      expect(await repository.getLocalTracks(), isEmpty);
    });

    test('deleteTrackPermanently cleans up local tracks and resets download state', () async {
      final track = Track(
        id: 'local:delete_perm',
        title: 'Sample Track',
        artistName: 'Sample Artist',
        source: AudioSourceType.local,
        sourceId: '/storage/sample.mp3',
        durationMs: 120000,
        audioUrl: '/storage/sample.mp3',
        filePath: '/storage/sample.mp3',
        isDownloaded: true,
        addedAt: DateTime.now(),
      );

      await repository.saveDownloadedTrack(
        track,
        filePath: '/storage/sample.mp3',
        fileSizeBytes: 4096,
      );

      await downloadManager.deleteTrackPermanently(track);

      final state = downloadManager.getState(track.id);
      expect(state.status, DownloadStatus.notDownloaded);
      expect(await repository.getLocalTracks(), isEmpty);
    });

    test('dismissCompletedTrack clears lastCompletedTrack', () {
      downloadManager.dismissCompletedTrack();
      expect(downloadManager.lastCompletedTrack, isNull);
    });
  });
}
