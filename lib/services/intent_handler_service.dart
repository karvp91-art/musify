import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../data/sources/youtube_source_adapter.dart';
import '../domain/models/track.dart';
import 'audio_player_handler.dart';

/// Service responsible for receiving and processing system "Open with" and
/// "Share to" intents (audio files, audio streams, and shared music links).
class IntentHandlerService {
  static StreamSubscription<List<SharedMediaFile>>? _intentMediaSub;
  static bool _initialized = false;

  static const _supportedAudioExtensions = {
    '.mp3',
    '.m4a',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.aac',
    '.wma',
  };

  /// Initializes intent listeners for both cold start and background runtime sharing.
  static Future<void> initialize(MusifyAudioHandler audioHandler) async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Listen to shared audio/links while app is already running in memory
      _intentMediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (files) => _handleSharedFiles(files, audioHandler),
        onError: (err) {
          debugPrint('IntentHandlerService mediaStream error: $err');
        },
      );

      // 2. Handle audio/links shared when app was terminated (Cold start)
      final initialFiles = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initialFiles.isNotEmpty) {
        await _handleSharedFiles(initialFiles, audioHandler);
        await ReceiveSharingIntent.instance.reset();
      }
    } catch (e) {
      debugPrint('IntentHandlerService initialization error: $e');
    }
  }

  /// Process list of shared media items (files or text/links) and start playback
  static Future<void> _handleSharedFiles(
    List<SharedMediaFile> files,
    MusifyAudioHandler audioHandler,
  ) async {
    if (files.isEmpty) return;

    final audioTracks = <Track>[];

    for (final file in files) {
      final content = file.path.trim();
      if (content.isEmpty) continue;

      // Check if item is a shared web link (e.g. YouTube music link)
      if (file.type == SharedMediaType.url ||
          file.type == SharedMediaType.text ||
          content.startsWith('http://') ||
          content.startsWith('https://')) {
        await _handleSharedUrlOrText(content, audioHandler);
        continue;
      }

      // Otherwise, treat as an audio file
      final ext = p.extension(content).toLowerCase();
      final isAudioExt = _supportedAudioExtensions.contains(ext);
      final isAudioType = file.type == SharedMediaType.file ||
          (file.mimeType != null && file.mimeType!.toLowerCase().startsWith('audio/'));

      if (!isAudioExt && !isAudioType) continue;

      final ioFile = File(content);
      final fileExists = ioFile.existsSync();
      final fileSize = fileExists ? ioFile.lengthSync() : 0;

      final rawName = p.basenameWithoutExtension(content);
      var artist = 'Local Audio';
      var title = rawName;

      // Extract "Artist - Title" if formatted with standard delimiter
      if (rawName.contains(' - ')) {
        final parts = rawName.split(' - ');
        if (parts.length >= 2) {
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      audioTracks.add(
        Track(
          id: 'local:$content',
          title: title.isEmpty ? 'Audio Track' : title,
          artistName: artist,
          source: AudioSourceType.local,
          sourceId: content,
          durationMs: 0,
          audioUrl: content,
          filePath: content,
          fileSizeBytes: fileSize,
          codec: ext.isNotEmpty ? ext.replaceFirst('.', '') : 'mp3',
          isDownloaded: true,
          addedAt: DateTime.now(),
        ),
      );
    }

    if (audioTracks.isNotEmpty) {
      await audioHandler.playTrackList(audioTracks, startIndex: 0);
    }
  }

  /// Process shared URL or text (e.g. YouTube music link)
  static Future<void> _handleSharedUrlOrText(
    String text,
    MusifyAudioHandler audioHandler,
  ) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Detect YouTube URL patterns (youtube.com, music.youtube.com, youtu.be)
    final ytRegex = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.|music\.)?(?:youtube\.com\/(?:watch\?v=|embed\/|v\/|shorts\/)|youtu\.be\/)([\w-]{11})',
      caseSensitive: false,
    );

    final match = ytRegex.firstMatch(trimmed);
    if (match != null) {
      final videoId = match.group(1);
      if (videoId != null && videoId.isNotEmpty) {
        final yt = YoutubeExplode();
        try {
          final video = await yt.videos.get(videoId);
          final parsed = YouTubeSourceAdapter.parseTitleAndArtist(
            video.title,
            video.author,
          );

          final track = Track(
            id: 'youtube:${video.id.value}',
            title: parsed.title,
            artistName: parsed.artist,
            source: AudioSourceType.youtube,
            sourceId: video.id.value,
            durationMs: video.duration?.inMilliseconds ?? 0,
            artworkUrl: video.thumbnails.highResUrl,
            audioUrl: '', // lazily resolved by YouTubeSourceAdapter
            codec: 'opus',
            bitrate: 160,
            isLiked: false,
            isDownloaded: false,
            addedAt: DateTime.now(),
          );

          await audioHandler.playTrackList([track], startIndex: 0);
        } catch (e) {
          debugPrint('Error loading shared YouTube track: $e');
        } finally {
          yt.close();
        }
      }
    }
  }

  /// Clean up subscriptions on app shutdown
  static void dispose() {
    _intentMediaSub?.cancel();
    _intentMediaSub = null;
    _initialized = false;
  }
}
