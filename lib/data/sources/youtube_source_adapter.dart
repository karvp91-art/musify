import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../domain/models/track.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/sources/source_adapter.dart';
import '../../services/download_manager.dart';
import 'saavn_source_adapter.dart';

class YouTubeSourceAdapter implements SourceAdapter {
  final YoutubeExplode _yt;
  final SaavnSourceAdapter? saavnAdapter;
  final AudioRepository? repo;
  final Dio _dio;
  final Map<String, ({String url, DateTime expiresAt})> _streamCache = {};

  YouTubeSourceAdapter({
    YoutubeExplode? yt,
    this.saavnAdapter,
    this.repo,
    Dio? dio,
  })  : _yt = yt ?? YoutubeExplode(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 45),
              ),
            );

  @override
  AudioSourceType get sourceType => AudioSourceType.youtube;

  @override
  String get name => 'YouTube';

  @override
  Future<List<Track>> search(String query, {int limit = 25}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final searchResults = await _yt.search.search(trimmed);
      final List<Track> tracks = [];

      for (final video in searchResults) {
        if (tracks.length >= limit) break;
        // Ignore live streams or videos without duration
        if (video.duration == null || video.duration == Duration.zero) continue;
        // Filter out excessively long videos (> 30 mins) for standard music tracks
        if (video.duration!.inMinutes > 30) continue;

        final parsed = parseTitleAndArtist(video.title, video.author);

        tracks.add(Track(
          id: 'youtube:${video.id.value}',
          title: parsed.title,
          artistName: parsed.artist,
          source: AudioSourceType.youtube,
          sourceId: video.id.value,
          durationMs: video.duration!.inMilliseconds,
          artworkUrl: video.thumbnails.highResUrl,
          audioUrl: '', // Resolved on-demand via getStreamUrl
          codec: 'opus',
          bitrate: 160,
          isLiked: false,
          isDownloaded: false,
          addedAt: DateTime.now(),
        ));
      }

      return tracks;
    } catch (_) {
      return [];
    }
  }

  static String getSafeFilename(Track track, String ext) {
    final safeTitle = track.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeArtist = track.artistName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeId = track.id.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return '${safeTitle}_${safeArtist}_$safeId$ext';
  }

  Future<File?> getExistingDownloadedFile(Track track) async {
    // 1. Direct path check on track model
    if (track.filePath != null && track.filePath!.isNotEmpty && File(track.filePath!).existsSync()) {
      return File(track.filePath!);
    }

    // 2. Check public Musify downloads directory
    try {
      final downloadDir = await AudioDownloadManager.getMusifyDownloadsDirectory();
      final safeId = track.id.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final entities = downloadDir.listSync();
      for (final entity in entities) {
        if (entity is File && p.basenameWithoutExtension(entity.path).endsWith(safeId)) {
          if (entity.lengthSync() > 100000) {
            return entity;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Downloads YouTube track completely to local storage (Music/Musify)
  /// and saves it to the local library.
  Future<File?> downloadTrackToFile(
    Track track, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // Check if track is already downloaded
    final existing = await getExistingDownloadedFile(track);
    if (existing != null) {
      onProgress?.call(1.0);
      return existing;
    }

    final downloadDir = await AudioDownloadManager.getMusifyDownloadsDirectory();

    // 1. Fast match attempt on JioSaavn (320kbps CDNs, completes in <1s)
    final saavn = saavnAdapter;
    final r = repo;
    if (saavn != null) {
      try {
        final query = '${track.title} ${track.artistName}'.trim();
        final saavnResults = await saavn.search(query, limit: 3);
        for (final s in saavnResults) {
          final isTitleMatch = s.title.toLowerCase().contains(track.title.toLowerCase()) ||
              track.title.toLowerCase().contains(s.title.toLowerCase());
          if (isTitleMatch) {
            final saavnUrl = await saavn.getStreamUrl(s);
            if (saavnUrl.isNotEmpty && saavnUrl.startsWith('http')) {
              var ext = '.m4a';
              if (saavnUrl.contains('.mp3')) ext = '.mp3';
              final savePath = p.join(downloadDir.path, getSafeFilename(track, ext));
              final tempPath = '$savePath.tmp';
              final tempFile = File(tempPath);
              if (tempFile.existsSync()) tempFile.deleteSync();

              await _dio.download(
                saavnUrl,
                tempPath,
                cancelToken: cancelToken,
                onReceiveProgress: (rec, total) {
                  if (total > 0 && onProgress != null) {
                    onProgress(rec / total);
                  }
                },
              );

              if (tempFile.existsSync() && tempFile.lengthSync() > 100000) {
                final finalFile = await tempFile.rename(savePath);
                if (r != null) {
                  await r.saveDownloadedTrack(
                    track.copyWith(filePath: finalFile.path, isDownloaded: true),
                    filePath: finalFile.path,
                    fileSizeBytes: finalFile.lengthSync(),
                  );
                }
                onProgress?.call(1.0);
                return finalFile;
              }
            }
          }
        }
      } catch (_) {
        // Fall back to direct YouTube stream download
      }
    }

    // 2. Direct YouTube Download via unthrottled muxed stream
    final videoId = track.sourceId.isNotEmpty ? track.sourceId : track.id.replaceFirst('youtube:', '');
    if (videoId.isEmpty) return null;

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidSdkless],
      );

      final stream = manifest.muxed.where((s) => s.tag == 18).firstOrNull ??
          manifest.muxed.firstOrNull ??
          manifest.audioOnly.sortByBitrate().lastOrNull;

      if (stream == null) return null;

      final totalBytes = stream.size.totalBytes;
      final url = stream.url.toString();
      const ua = 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';

      final ext = stream.container.name == 'webm' ? '.opus' : '.mp4';
      final savePath = p.join(downloadDir.path, getSafeFilename(track, ext));
      final tempPath = '$savePath.tmp';
      final tempFile = File(tempPath);
      if (tempFile.existsSync()) tempFile.deleteSync();

      final sink = tempFile.openWrite();
      int start = 0;
      const chunkSize = 500 * 1024; // 500 KB boundary

      try {
        while (start < totalBytes) {
          if (cancelToken?.isCancelled == true) {
            throw Exception('Download cancelled');
          }

          final end = (start + chunkSize - 1).clamp(0, totalBytes - 1);
          final res = await _dio.get<ResponseBody>(
            url,
            cancelToken: cancelToken,
            options: Options(
              responseType: ResponseType.stream,
              headers: {
                'User-Agent': ua,
                'Range': 'bytes=$start-$end',
              },
            ),
          );

          if (res.statusCode != 200 && res.statusCode != 206) {
            throw Exception('HTTP ${res.statusCode}');
          }

          await for (final chunk in res.data!.stream) {
            sink.add(chunk);
          }

          start = end + 1;
          if (totalBytes > 0 && onProgress != null) {
            onProgress((start / totalBytes).clamp(0.0, 1.0));
          }
        }

        await sink.flush();
        await sink.close();
      } catch (e) {
        await sink.close();
        if (tempFile.existsSync()) {
          try { tempFile.deleteSync(); } catch (_) {}
        }
        rethrow;
      }

      if (tempFile.existsSync() && tempFile.lengthSync() > 100000) {
        final finalFile = await tempFile.rename(savePath);
        if (r != null) {
          await r.saveDownloadedTrack(
            track.copyWith(filePath: finalFile.path, isDownloaded: true),
            filePath: finalFile.path,
            fileSizeBytes: finalFile.lengthSync(),
          );
        }
        onProgress?.call(1.0);
        return finalFile;
      }
    } catch (_) {
      // Download failed
    }

    return null;
  }

  @override
  Future<String> getStreamUrl(Track track) async {
    // Download-first architecture: download to local storage before playing
    try {
      final downloaded = await downloadTrackToFile(track);
      if (downloaded != null && downloaded.existsSync()) {
        return downloaded.path;
      }
    } catch (_) {}

    return track.filePath ?? track.audioUrl;
  }

  @override
  Future<Track?> getMetadata(String sourceId) async {
    try {
      final video = await _yt.videos.get(sourceId);
      final parsed = parseTitleAndArtist(video.title, video.author);

      return Track(
        id: 'youtube:${video.id.value}',
        title: parsed.title,
        artistName: parsed.artist,
        source: AudioSourceType.youtube,
        sourceId: video.id.value,
        durationMs: video.duration?.inMilliseconds ?? 0,
        artworkUrl: video.thumbnails.highResUrl,
        audioUrl: '',
        codec: 'opus',
        bitrate: 160,
        isLiked: false,
        isDownloaded: false,
        addedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getArtworkUrl(String sourceId) async {
    return 'https://img.youtube.com/vi/$sourceId/hqdefault.jpg';
  }

  static ({String artist, String title}) parseTitleAndArtist(String rawTitle, String channelAuthor) {
    // Strip trailing pipe delimiters e.g. "| Warner Records"
    String clean = rawTitle.replaceAll(RegExp(r'\s*\|.*$'), '');

    // Strip common YouTube bracketed tags/badges (Official 4K Video, Lyric Video, etc.)
    clean = clean
        .replaceAll(
          RegExp(
            r'\s*[\(\[][^\)\]]*(?:official|video|audio|lyric|visualizer|4k|hd|hq|mv|remastered)[^\)\]]*[\)\]]',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    if (clean.contains(' - ')) {
      final parts = clean.split(' - ');
      if (parts.length >= 2) {
        final artist = parts[0].trim();
        final title = parts.sublist(1).join(' - ').trim();
        if (artist.isNotEmpty && title.isNotEmpty) {
          return (artist: artist, title: title);
        }
      }
    }

    final cleanAuthor = channelAuthor
        .replaceAll(' - Topic', '')
        .replaceAll(RegExp(r'\s*VEVO$', caseSensitive: false), '')
        .trim();

    return (
      artist: cleanAuthor.isNotEmpty ? cleanAuthor : 'Unknown Artist',
      title: clean.isNotEmpty ? clean : rawTitle,
    );
  }

  void close() {
    _streamCache.clear();
    _yt.close();
  }
}
