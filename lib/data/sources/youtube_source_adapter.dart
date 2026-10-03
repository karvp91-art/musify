import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../domain/models/track.dart';
import '../../domain/sources/source_adapter.dart';

class YouTubeSourceAdapter implements SourceAdapter {
  final YoutubeExplode _yt;
  final Map<String, ({String url, DateTime expiresAt})> _streamCache = {};

  YouTubeSourceAdapter({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

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

  @override
  Future<String> getStreamUrl(Track track) async {
    final videoId = track.sourceId.isNotEmpty ? track.sourceId : track.id.replaceFirst('youtube:', '');
    if (videoId.isEmpty) return track.audioUrl;

    // Check memory cache
    final cached = _streamCache[videoId];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.url;
    }

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // Prefer highest bitrate audio-only stream
      AudioStreamInfo? audioStream;
      try {
        audioStream = manifest.audioOnly.withHighestBitrate();
      } catch (_) {
        if (manifest.audio.isNotEmpty) {
          audioStream = manifest.audio.withHighestBitrate();
        }
      }

      if (audioStream != null) {
        final url = audioStream.url.toString();
        // YouTube stream URLs are valid for ~6 hours; cache for 4 hours
        _streamCache[videoId] = (
          url: url,
          expiresAt: DateTime.now().add(const Duration(hours: 4)),
        );
        return url;
      }
    } catch (_) {
      // Fallback on error
    }

    return track.audioUrl;
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
