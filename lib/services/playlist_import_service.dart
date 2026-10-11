import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:musify/data/sources/saavn_source_adapter.dart';
import 'package:musify/data/sources/youtube_source_adapter.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

class ExternalTrackItem {
  final String id;
  final String title;
  final String artist;
  final String? artworkUrl;
  final int? durationMs;
  Track? resolvedTrack;
  bool isMatched;
  bool isSelected;

  ExternalTrackItem({
    required this.id,
    required this.title,
    required this.artist,
    this.artworkUrl,
    this.durationMs,
    this.resolvedTrack,
    this.isMatched = false,
    this.isSelected = true,
  });
}

class ExternalPlaylistResult {
  final String title;
  final String? description;
  final String? artworkUrl;
  final String platform; // 'spotify', 'youtube', 'jiosaavn'
  final List<ExternalTrackItem> tracks;

  const ExternalPlaylistResult({
    required this.title,
    this.description,
    this.artworkUrl,
    required this.platform,
    required this.tracks,
  });
}

class PlaylistImportService {
  final SaavnSourceAdapter _saavn;
  final YouTubeSourceAdapter _youtube;
  final AudioRepository _audioRepo;
  final Dio _dio;

  PlaylistImportService({
    required SaavnSourceAdapter saavnAdapter,
    required YouTubeSourceAdapter youtubeAdapter,
    required AudioRepository audioRepository,
    Dio? dio,
  })  : _saavn = saavnAdapter,
        _youtube = youtubeAdapter,
        _audioRepo = audioRepository,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                },
              ),
            );

  /// Extracts YouTube playlist ID from various URL formats or raw ID
  static String? extractYouTubePlaylistId(String input) {
    final trimmed = input.trim();
    if (RegExp(r'^(PL|OLAK5uy_|RD|UU|FL|LP)[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      return trimmed.startsWith('VL') ? trimmed.substring(2) : trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters.containsKey('list')) {
      final id = uri.queryParameters['list']!;
      return id.startsWith('VL') ? id.substring(2) : id;
    }
    final regExp = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(trimmed);
    if (match != null) {
      final id = match.group(1)!;
      return id.startsWith('VL') ? id.substring(2) : id;
    }
    return null;
  }

  /// Detects the target streaming platform from a given URL or query
  static String detectPlatform(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('spotify.com') || trimmed.startsWith('spotify:playlist:')) {
      return 'spotify';
    } else if (trimmed.contains('youtube.com') ||
        trimmed.contains('youtu.be') ||
        extractYouTubePlaylistId(trimmed) != null) {
      return 'youtube';
    } else if (trimmed.contains('jiosaavn.com') || RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'jiosaavn';
    }
    return 'unknown';
  }

  /// Identifies the platform and extracts playlist metadata and track list
  Future<ExternalPlaylistResult> extractPlaylistFromUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Please enter a playlist URL or ID.');
    }

    final platform = detectPlatform(trimmed);
    if (platform == 'spotify') {
      return _extractSpotifyPlaylist(trimmed);
    } else if (platform == 'youtube') {
      return _extractYouTubePlaylist(trimmed);
    } else if (platform == 'jiosaavn') {
      return _extractJioSaavnPlaylist(trimmed);
    } else {
      throw const FormatException(
        'Unsupported link format. Please provide a Spotify, YouTube, or JioSaavn playlist URL.',
      );
    }
  }

  /// Extracts tracks from Spotify embed endpoint without requiring developer API keys
  Future<ExternalPlaylistResult> _extractSpotifyPlaylist(String url) async {
    String? playlistId;
    if (url.startsWith('spotify:playlist:')) {
      playlistId = url.replaceFirst('spotify:playlist:', '').split('?').first.trim();
    } else {
      final regExp = RegExp(r'playlist\/([a-zA-Z0-9]+)');
      final match = regExp.firstMatch(url);
      playlistId = match?.group(1);
    }

    if (playlistId == null || playlistId.isEmpty) {
      throw const FormatException('Could not extract Spotify playlist ID from URL.');
    }

    try {
      final response = await _dio.get<String>(
        'https://open.spotify.com/embed/playlist/$playlistId',
      );
      final html = response.data ?? '';

      final nextDataMatch = RegExp(
        r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
        dotAll: true,
      ).firstMatch(html);

      if (nextDataMatch == null) {
        throw const FormatException(
          'Unable to read Spotify playlist details. Please ensure the playlist is public.',
        );
      }

      final jsonStr = nextDataMatch.group(1)!;
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final entity = parsed['props']?['pageProps']?['state']?['data']?['entity'];

      if (entity == null) {
        throw const FormatException('Spotify playlist is empty or private.');
      }

      final title = entity['name']?.toString() ?? 'Spotify Playlist';
      final subtitle = entity['subtitle']?.toString();
      final artworkUrl = entity['coverArt']?['sources']?[0]?['url']?.toString();
      final trackList = entity['trackList'] as List<dynamic>? ?? [];

      final List<ExternalTrackItem> tracks = [];
      for (int i = 0; i < trackList.length; i++) {
        final item = trackList[i];
        if (item is Map<String, dynamic>) {
          final trackTitle = item['title']?.toString() ?? '';
          final trackArtist = item['subtitle']?.toString() ?? '';
          final durationMs = item['duration'] as int?;
          final itemArtwork = item['coverArt']?['sources']?[0]?['url']?.toString() ?? artworkUrl;

          if (trackTitle.isNotEmpty) {
            tracks.add(
              ExternalTrackItem(
                id: 'spot_$i',
                title: trackTitle,
                artist: trackArtist.isNotEmpty ? trackArtist : 'Unknown Artist',
                artworkUrl: itemArtwork,
                durationMs: durationMs,
              ),
            );
          }
        }
      }

      if (tracks.isEmpty) {
        throw const FormatException('No playable tracks found in this Spotify playlist.');
      }

      return ExternalPlaylistResult(
        title: title,
        description: subtitle,
        artworkUrl: artworkUrl,
        platform: 'spotify',
        tracks: tracks,
      );
    } catch (e) {
      if (e is FormatException) rethrow;
      throw Exception('Failed to fetch Spotify playlist: $e');
    }
  }

  /// Extracts tracks from YouTube / YouTube Music playlist using direct ytInitialData parsing + fallback
  Future<ExternalPlaylistResult> _extractYouTubePlaylist(String url) async {
    final playlistId = extractYouTubePlaylistId(url);
    if (playlistId == null || playlistId.isEmpty) {
      throw const FormatException('Could not find YouTube playlist ID in link.');
    }

    // Strategy 1: Direct YouTube page ytInitialData parsing (fast, supports modern lockupViewModel)
    try {
      final res = await _dio.get<String>(
        'https://www.youtube.com/playlist?list=$playlistId',
      );
      final html = res.data ?? '';

      final match = RegExp(r'var ytInitialData\s*=\s*(\{.*?\});\s*<\/script>', dotAll: true).firstMatch(html)
          ?? RegExp(r'ytInitialData\s*=\s*(\{.*?\});', dotAll: true).firstMatch(html);

      if (match != null) {
        final data = jsonDecode(match.group(1)!) as Map<String, dynamic>;
        final metadata = data['metadata']?['playlistMetadataRenderer'];
        final playlistTitle = metadata?['title']?.toString() ?? 'YouTube Playlist';
        final playlistDesc = metadata?['description']?.toString() ?? 'Imported from YouTube';

        final List<ExternalTrackItem> tracks = [];

        void extractFromNode(dynamic node) {
          if (node is Map<String, dynamic>) {
            if (node.containsKey('lockupViewModel')) {
              if (tracks.length >= 100) return;
              final lvm = node['lockupViewModel'] as Map<String, dynamic>;
              final contentId = lvm['contentId']?.toString();
              final meta = lvm['metadata']?['lockupMetadataViewModel'];
              final rawTitle = meta?['title']?['content']?.toString();

              String rawAuthor = '';
              final rows = meta?['metadata']?['contentMetadataViewModel']?['metadataRows'] as List?;
              if (rows != null && rows.isNotEmpty) {
                final parts = rows.first['metadataParts'] as List?;
                if (parts != null && parts.isNotEmpty) {
                  rawAuthor = parts.first['text']?['content']?.toString() ?? '';
                }
              }

              if (contentId != null && rawTitle != null && rawTitle.isNotEmpty) {
                final parsed = YouTubeSourceAdapter.parseTitleAndArtist(rawTitle, rawAuthor);
                tracks.add(
                  ExternalTrackItem(
                    id: 'yt_$contentId',
                    title: parsed.title,
                    artist: parsed.artist,
                    artworkUrl: 'https://i.ytimg.com/vi/$contentId/hqdefault.jpg',
                  ),
                );
              }
            } else if (node.containsKey('playlistVideoRenderer')) {
              if (tracks.length >= 100) return;
              final pvr = node['playlistVideoRenderer'] as Map<String, dynamic>;
              final videoId = pvr['videoId']?.toString();
              final rawTitle = pvr['title']?['runs']?[0]?['text'] ?? pvr['title']?['simpleText'];
              final rawAuthor = pvr['shortBylineText']?['runs']?[0]?['text'] ?? '';
              final lengthSeconds = pvr['lengthSeconds'] != null ? int.tryParse(pvr['lengthSeconds'].toString()) : null;

              if (videoId != null && rawTitle != null) {
                final parsed = YouTubeSourceAdapter.parseTitleAndArtist(rawTitle.toString(), rawAuthor.toString());
                tracks.add(
                  ExternalTrackItem(
                    id: 'yt_$videoId',
                    title: parsed.title,
                    artist: parsed.artist,
                    artworkUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                    durationMs: lengthSeconds != null ? lengthSeconds * 1000 : null,
                  ),
                );
              }
            } else {
              for (final val in node.values) {
                extractFromNode(val);
              }
            }
          } else if (node is List) {
            for (final item in node) {
              extractFromNode(item);
            }
          }
        }

        if (data.containsKey('contents')) {
          extractFromNode(data['contents']);
        }

        if (tracks.isNotEmpty) {
          return ExternalPlaylistResult(
            title: playlistTitle,
            description: playlistDesc,
            artworkUrl: tracks.first.artworkUrl,
            platform: 'youtube',
            tracks: tracks,
          );
        }
      }
    } catch (_) {
      // Continue to Strategy 2 (fallback)
    }

    // Strategy 2: Fallback to YoutubeExplode
    final yt = YoutubeExplode();
    try {
      final playlist = await yt.playlists.get(playlistId);
      final List<ExternalTrackItem> tracks = [];

      final videoStream = yt.playlists.getVideos(playlist.id);
      await for (final video in videoStream) {
        if (tracks.length >= 100) break; // Keep payload responsive and memory safe
        if (video.duration == null || video.duration == Duration.zero) continue;
        if (video.duration!.inMinutes > 30) continue; // Filter out 1-hour loops

        final parsed = YouTubeSourceAdapter.parseTitleAndArtist(video.title, video.author);

        tracks.add(
          ExternalTrackItem(
            id: 'yt_${video.id.value}',
            title: parsed.title,
            artist: parsed.artist,
            artworkUrl: video.thumbnails.highResUrl,
            durationMs: video.duration?.inMilliseconds,
          ),
        );
      }

      if (tracks.isEmpty) {
        throw const FormatException('No tracks found in this YouTube playlist.');
      }

      return ExternalPlaylistResult(
        title: playlist.title,
        description: playlist.description.isNotEmpty ? playlist.description : 'Imported from YouTube',
        artworkUrl: tracks.first.artworkUrl,
        platform: 'youtube',
        tracks: tracks,
      );
    } catch (e) {
      if (e is FormatException) rethrow;
      throw Exception('Failed to load YouTube playlist: $e');
    } finally {
      yt.close();
    }
  }

  /// Extracts tracks from JioSaavn playlist or ID
  Future<ExternalPlaylistResult> _extractJioSaavnPlaylist(String input) async {
    String? playlistId;

    if (RegExp(r'^\d+$').hasMatch(input)) {
      playlistId = input;
    } else {
      // Parse URL
      final uri = Uri.tryParse(input);
      if (uri != null) {
        // 1. Direct query param or path digits
        final segments = uri.pathSegments;
        for (final seg in segments) {
          if (RegExp(r'^\d+$').hasMatch(seg)) {
            playlistId = seg;
            break;
          }
        }

        // 2. Otherwise extract title slug from /featured/<slug>/... or /playlist/<slug>/...
        if (playlistId == null && segments.isNotEmpty) {
          String? slug;
          for (int i = 0; i < segments.length; i++) {
            if ((segments[i] == 'featured' || segments[i] == 'playlist') && i + 1 < segments.length) {
              slug = segments[i + 1].replaceAll('-', ' ');
              break;
            }
          }
          slug ??= segments.first.replaceAll('-', ' ');

          // Search JioSaavn autocomplete for the playlist
          final multi = await _saavn.searchMulti(slug);
          if (multi.playlists.isNotEmpty) {
            playlistId = multi.playlists.first.id;
          }
        }
      }
    }

    if (playlistId == null || playlistId.isEmpty) {
      throw const FormatException('Could not resolve JioSaavn playlist ID from URL.');
    }

    final details = await _saavn.getPlaylistDetails(playlistId);
    if (details == null || details.songs.isEmpty) {
      throw const FormatException('JioSaavn playlist is empty or unavailable.');
    }

    final tracks = details.songs.map((track) {
      return ExternalTrackItem(
        id: 'saavn_${track.id}',
        title: track.title,
        artist: track.artistName,
        artworkUrl: track.artworkUrl,
        durationMs: track.durationMs,
        resolvedTrack: track,
        isMatched: true,
      );
    }).toList();

    return ExternalPlaylistResult(
      title: details.title,
      description: details.subtitle ?? details.description,
      artworkUrl: details.imageUrl,
      platform: 'jiosaavn',
      tracks: tracks,
    );
  }

  @visibleForTesting
  static String deepCleanTitle(String title, {String artist = ''}) =>
      _deepCleanTitle(title, artist: artist);

  static final RegExp _noiseRegex = RegExp(
    r'\b(official\s*(music\s*)?video|official\s*audio|lyrical\s*video|lyric\s*video|'
    r'lyrical|lyrics?|video\s*song|full\s*song|full\s*video|audio|visualizer|'
    r'hd|4k|hq|mv|remastered|ultra\s*slowed|slowed\s*(?:\+|and|&)?\s*reverb|'
    r'slowed|reverb|bass\s*boosted|8d\s*audio|speed\s*up|sped\s*up|nightcore)\b',
    caseSensitive: false,
  );

  /// Strips YouTube noise from a title for clean search queries
  static String _deepCleanTitle(String title, {String artist = ''}) {
    // 1. Remove (...) and [...] tags
    var clean = title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ');

    // 2. Remove noise words
    clean = clean.replaceAll(_noiseRegex, ' ');

    // 3. Normalize whitespace and trim dangling separators ("Kalank Title Track –")
    clean = clean
        .replaceAll(RegExp(r'[•·]'), ' ')
        .replaceAll(RegExp(r'(?:[-–—|]\s*)+[-–—|]'), ' - ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s\-–—|]+|[\s\-–—|]+$'), '');

    // 4. Split only on spaced separators so "Lo-Fi" etc. stay intact
    final parts = clean
        .split(RegExp(r'\s+[-–—|]\s+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.length > 1) {
      // Drop parts that look like the artist; keep the rest
      final nonArtist = artist.isEmpty
          ? parts
          : parts.where((p) => _fuzzyScore(p, artist) < 0.6).toList();
      final candidates = nonArtist.isNotEmpty ? nonArtist : parts;
      clean = candidates.first;
    }

    clean = clean.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return clean.isNotEmpty ? clean : title.trim();
  }

  /// Normalizes a string for fuzzy comparison: lowercase, remove diacritics & punctuation
  static String _normalize(String text) {
    // Lowercase
    var n = text.toLowerCase();

    // Common diacritic transliterations
    const diacriticMap = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
      'ş': 's', 'ğ': 'g', 'ı': 'i', 'ř': 'r', 'ž': 'z',
      'ð': 'd', 'þ': 'th', 'ß': 'ss',
    };
    for (final entry in diacriticMap.entries) {
      n = n.replaceAll(entry.key, entry.value);
    }

    // Strip everything except alphanumeric and spaces
    n = n.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    return n;
  }

  /// Computes a fuzzy word-overlap similarity score between 0.0 and 1.0
  static double _fuzzyScore(String a, String b) {
    final wordsA = _normalize(a).split(' ').where((w) => w.length > 1).toSet();
    final wordsB = _normalize(b).split(' ').where((w) => w.length > 1).toSet();

    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;

    final intersection = wordsA.intersection(wordsB).length;
    final smaller = wordsA.length < wordsB.length ? wordsA.length : wordsB.length;
    return intersection / smaller;
  }

  /// Picks the best matching track from a list of candidates using fuzzy scoring
  static Track? _bestMatch(String cleanTitle, String artist, List<Track> candidates) {
    if (candidates.isEmpty) return null;

    Track? best;
    double bestScore = 0.0;

    final normalizedQuery = _normalize(cleanTitle);

    for (final t in candidates) {
      final normalizedTitle = _normalize(t.title);

      // Title-based score (weighted highest)
      double titleScore = _fuzzyScore(cleanTitle, t.title);

      // Bonus for exact normalized match
      if (normalizedTitle == normalizedQuery) {
        titleScore = 1.0;
      }
      // Bonus for containment
      else if (normalizedTitle.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedTitle)) {
        titleScore = titleScore.clamp(0.7, 1.0);
      }

      // Artist overlap score (secondary)
      final artistScore = artist.isNotEmpty ? _fuzzyScore(artist, t.artistName) : 0.0;

      // Combined weighted score: 75% title, 25% artist
      final totalScore = (titleScore * 0.75) + (artistScore * 0.25);

      if (totalScore > bestScore) {
        bestScore = totalScore;
        best = t;
      }
    }

    // Require at least 40% confidence to accept a match
    return bestScore >= 0.4 ? best : null;
  }

  /// Resolves extracted tracks against our streaming catalogs (JioSaavn 320kbps first, then YouTube)
  Stream<({int current, int total, ExternalTrackItem item})> resolveTracksStream(
    List<ExternalTrackItem> items,
  ) async* {
    final total = items.length;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      // If already resolved (e.g. native JioSaavn playlist), skip network query
      if (item.resolvedTrack != null) {
        item.isMatched = true;
        yield (current: i + 1, total: total, item: item);
        continue;
      }

      Track? matched;

      // Clean the artist name (strip YouTube channel suffixes)
      final cleanArtist = item.artist
          .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*VEVO$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*Official$', caseSensitive: false), '')
          .trim();

      // Deep-clean the title with artist-aware tiebreaker
      final cleanTitle = _deepCleanTitle(item.title, artist: cleanArtist);

      // Search queries: primary (title + artist), fallback (title only)
      final primaryQuery = '$cleanTitle $cleanArtist'.trim();
      final titleOnlyQuery = cleanTitle.trim();

      // 1. Try matching with JioSaavn for studio master 320kbps audio
      try {
        // Primary search: title + artist
        var saavnMatches = await _saavn.search(primaryQuery, limit: 5);

        // If primary search returned no confident match, try title-only
        matched = _bestMatch(cleanTitle, cleanArtist, saavnMatches);

        if (matched == null && titleOnlyQuery != primaryQuery) {
          saavnMatches = await _saavn.search(titleOnlyQuery, limit: 5);
          matched = _bestMatch(cleanTitle, cleanArtist, saavnMatches);
        }
      } catch (_) {}

      // 2. If no JioSaavn match, fallback to YouTube streaming source
      if (matched == null) {
        try {
          final ytMatches = await _youtube.search(primaryQuery, limit: 3);
          matched = _bestMatch(cleanTitle, cleanArtist, ytMatches);

          // Fallback: title-only YouTube search
          if (matched == null && titleOnlyQuery != primaryQuery) {
            final ytFallback = await _youtube.search(titleOnlyQuery, limit: 3);
            matched = _bestMatch(cleanTitle, cleanArtist, ytFallback);
          }
        } catch (_) {}
      }

      if (matched != null) {
        item.resolvedTrack = matched;
        item.isMatched = true;
      }

      yield (current: i + 1, total: total, item: item);
    }
  }

  /// Persists matched tracks to our local SQLite / Drift database as a permanent in-app playlist
  Future<Playlist> saveAsInAppPlaylist({
    required String name,
    String? description,
    required List<Track> tracks,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('Playlist name cannot be empty.');
    }

    if (tracks.isEmpty) {
      throw const FormatException('No tracks selected to add to the playlist.');
    }

    // 1. Create playlist entry in SQLite
    final playlist = await _audioRepo.createPlaylist(
      trimmedName,
      description: description?.trim().isNotEmpty == true ? description!.trim() : null,
    );

    // 2. Insert and link each track to the playlist
    for (final track in tracks) {
      await _audioRepo.addTrackToPlaylist(playlist.id, track);
    }

    return playlist;
  }
}
