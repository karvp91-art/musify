import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:musify/data/sources/saavn_source_adapter.dart';
import 'package:musify/data/sources/source_router.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/repositories/audio_repository.dart';

enum DownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  error,
}

class DownloadState {
  final DownloadStatus status;
  final double progress;
  final String? error;

  const DownloadState({
    required this.status,
    this.progress = 0.0,
    this.error,
  });

  bool get isDownloaded => status == DownloadStatus.downloaded;
  bool get isDownloading => status == DownloadStatus.downloading;

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? error,
  }) {
    return DownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

class AudioDownloadManager extends ChangeNotifier {
  final AudioRepository repo;
  final Dio _dio;
  final SaavnSourceAdapter _saavnAdapter;
  final SourceRouter? sourceRouter;

  final Map<String, DownloadState> _states = {};
  final Map<String, CancelToken> _cancelTokens = {};
  DateTime _lastProgressUpdate = DateTime.now();

  Track? _activeDownloadingTrack;
  double _activeProgress = 0.0;
  Track? _lastCompletedTrack;

  Track? get activeDownloadingTrack => _activeDownloadingTrack;
  double get activeProgress => _activeProgress;
  Track? get lastCompletedTrack => _lastCompletedTrack;

  void dismissCompletedTrack() {
    if (_lastCompletedTrack != null) {
      _lastCompletedTrack = null;
      notifyListeners();
    }
  }

  AudioDownloadManager({
    required this.repo,
    Dio? dio,
    SaavnSourceAdapter? saavnAdapter,
    this.sourceRouter,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 45),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                },
              ),
            ),
        _saavnAdapter = saavnAdapter ?? SaavnSourceAdapter() {
    _initExistingDownloads();
  }

  /// Returns the permanent public download directory where songs persist even after app uninstall
  static Future<Directory> getMusifyDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // 1. Primary: Standard public Music/Musify directory (permanent, visible in phone's File Manager)
      final musicDir = Directory('/storage/emulated/0/Music/Musify');
      try {
        if (!musicDir.existsSync()) {
          await musicDir.create(recursive: true);
        }
        return musicDir;
      } catch (_) {}

      // 2. Secondary: Standard public Download/Musify directory
      final downloadDir = Directory('/storage/emulated/0/Download/Musify');
      try {
        if (!downloadDir.existsSync()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir;
      } catch (_) {}

      // 3. Fallback: External storage app-specific directory
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final dir = Directory(p.join(extDir.path, 'Musify'));
          if (!dir.existsSync()) await dir.create(recursive: true);
          return dir;
        }
      } catch (_) {}
    }

    // Desktop or other platforms: User Downloads folder
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final dir = Directory(p.join(downloadsDir.path, 'Musify'));
        if (!dir.existsSync()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}

    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'Musify'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _initExistingDownloads() async {
    try {
      final targetDir = await getMusifyDownloadsDirectory();

      // Automatically migrate any previous downloads from private sandbox to public Music/Musify folder
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final legacyDir = Directory(p.join(appDir.path, 'musify_downloads'));
        if (legacyDir.existsSync()) {
          for (final entity in legacyDir.listSync()) {
            if (entity is File) {
              final newPath = p.join(targetDir.path, p.basename(entity.path));
              final newFile = File(newPath);
              if (!newFile.existsSync()) {
                await entity.copy(newPath);
              }
              try { await entity.delete(); } catch (_) {}
            }
          }
          try { await legacyDir.delete(recursive: true); } catch (_) {}
        }
      } catch (_) {}

      final localTracks = await repo.getLocalTracks();
      for (final t in localTracks) {
        var path = t.filePath;
        if (path != null && !File(path).existsSync()) {
          final publicPath = p.join(targetDir.path, p.basename(path));
          if (File(publicPath).existsSync()) {
            path = publicPath;
            await repo.saveDownloadedTrack(
              t,
              filePath: publicPath,
              fileSizeBytes: await File(publicPath).length(),
            );
          }
        }

        if (t.isDownloaded || (path != null && path.isNotEmpty && File(path).existsSync())) {
          _states[t.id] = const DownloadState(
            status: DownloadStatus.downloaded,
            progress: 1.0,
          );
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  DownloadState getState(String trackId) {
    return _states[trackId] ?? const DownloadState(status: DownloadStatus.notDownloaded);
  }

  bool isDownloaded(String trackId) {
    return getState(trackId).isDownloaded;
  }

  bool isDownloading(String trackId) {
    return getState(trackId).isDownloading;
  }

  double getProgress(String trackId) {
    return getState(trackId).progress;
  }

  Future<bool> downloadTrack(Track track) async {
    final current = getState(track.id);
    if (current.isDownloading || current.isDownloaded) {
      return current.isDownloaded;
    }

    _activeDownloadingTrack = track;
    _activeProgress = 0.02;
    _lastCompletedTrack = null;

    _states[track.id] = const DownloadState(
      status: DownloadStatus.downloading,
      progress: 0.02,
    );
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[track.id] = cancelToken;

    try {
      // 1. Resolve Audio Streaming URL
      var downloadUrl = track.audioUrl;
      if (downloadUrl.isEmpty || !downloadUrl.startsWith('http')) {
        final router = sourceRouter;
        if (router != null) {
          downloadUrl = await router.resolvePlayUrl(track);
        } else if (track.source == AudioSourceType.saavn) {
          downloadUrl = await _saavnAdapter.getStreamUrl(track);
        }
      }

      if (downloadUrl.isEmpty || !downloadUrl.startsWith('http')) {
        _states[track.id] = const DownloadState(
          status: DownloadStatus.error,
          error: 'Unable to resolve direct audio download link.',
        );
        notifyListeners();
        return false;
      }

      // 2. Prepare Storage Destination Directory (Permanent Public Storage)
      final downloadDir = await getMusifyDownloadsDirectory();

      // 3. Format safe, clean filename
      var ext = '.m4a';
      if (downloadUrl.contains('.mp3') || track.codec.toLowerCase() == 'mp3') {
        ext = '.mp3';
      } else if (downloadUrl.contains('.flac') || track.codec.toLowerCase() == 'flac') {
        ext = '.flac';
      } else if (downloadUrl.contains('.webm') || track.codec.toLowerCase() == 'opus') {
        ext = '.opus';
      }

      final safeTitle = track.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final safeArtist = track.artistName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final safeId = track.id.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final fileName = '${safeTitle}_${safeArtist}_$safeId$ext';
      final savePath = p.join(downloadDir.path, fileName);

      // 4. Download file with progress callback
      await _dio.download(
        downloadUrl,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final now = DateTime.now();
            final progress = (received / total).clamp(0.0, 1.0);
            // Throttle notifications to max 10 times per second for smooth rendering
            if (progress >= 1.0 || now.difference(_lastProgressUpdate).inMilliseconds > 90) {
              _lastProgressUpdate = now;
              _activeProgress = progress;
              _states[track.id] = DownloadState(
                status: DownloadStatus.downloading,
                progress: progress,
              );
              notifyListeners();
            }
          }
        },
      );

      final downloadedFile = File(savePath);
      if (!downloadedFile.existsSync()) {
        throw Exception('Downloaded file was not created on disk.');
      }

      final fileSizeBytes = await downloadedFile.length();

      // 5. Persist to local database
      await repo.saveDownloadedTrack(
        track,
        filePath: savePath,
        fileSizeBytes: fileSizeBytes,
      );

      _cancelTokens.remove(track.id);
      _activeDownloadingTrack = null;
      _lastCompletedTrack = track;
      _activeProgress = 1.0;
      _states[track.id] = const DownloadState(
        status: DownloadStatus.downloaded,
        progress: 1.0,
      );
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 2600), () {
        if (_lastCompletedTrack?.id == track.id) {
          _lastCompletedTrack = null;
          notifyListeners();
        }
      });

      return true;
    } catch (e) {
      if (_activeDownloadingTrack?.id == track.id) {
        _activeDownloadingTrack = null;
      }
      if (cancelToken.isCancelled) {
        _states[track.id] = const DownloadState(status: DownloadStatus.notDownloaded);
      } else {
        _states[track.id] = DownloadState(
          status: DownloadStatus.error,
          error: e.toString(),
        );
      }
      _cancelTokens.remove(track.id);
      notifyListeners();
      return false;
    }
  }

  void cancelDownload(String trackId) {
    if (_activeDownloadingTrack?.id == trackId) {
      _activeDownloadingTrack = null;
    }
    final token = _cancelTokens.remove(trackId);
    if (token != null && !token.isCancelled) {
      token.cancel('Download cancelled by user');
    }
    _states[trackId] = const DownloadState(status: DownloadStatus.notDownloaded);
    notifyListeners();
  }

  Future<void> removeDownloadedTrack(Track track) async {
    await repo.removeDownloadedTrack(track.id);
    _states[track.id] = const DownloadState(status: DownloadStatus.notDownloaded);
    notifyListeners();
  }

  Future<bool> deleteTrackPermanently(Track track) async {
    final success = await repo.deleteTrack(track);
    if (success) {
      _states[track.id] = const DownloadState(status: DownloadStatus.notDownloaded);
      notifyListeners();
    }
    return success;
  }
}
