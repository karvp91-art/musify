import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:musify/core/utils/des_cipher.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/models/search_result_models.dart';
import 'package:musify/domain/models/artist_details.dart';
import 'package:musify/domain/models/album_details.dart';
import 'package:musify/domain/models/stream_home_models.dart';
import 'package:musify/domain/sources/source_adapter.dart';
import 'package:musify/services/preferences_service.dart';

class SaavnSourceAdapter implements SourceAdapter {
  final Dio _dio;
  final PreferencesService? preferencesService;

  SaavnSourceAdapter({Dio? dio, this.preferencesService})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://www.jiosaavn.com/api.php',
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  'Accept': 'application/json, text/plain, */*',
                },
              ),
            );

  @override
  AudioSourceType get sourceType => AudioSourceType.saavn;

  @override
  String get name => 'JioSaavn 320k';

  static String unescapeHtml(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  /// Normalizes song titles to prevent duplicate compilation/version entries
  static String normalizeSongTitle(String title) {
    var clean = unescapeHtml(title).toLowerCase().trim();
    // Strip (From "Movie"), [From Movie], - From Movie
    clean = clean.replaceAll(RegExp(r'\s*[\(\[]from\s+["\u201c\u201d\x27]?[^()\]]+["\u201c\u201d\x27]?[\)\]]', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s*-\s*from\s+.*$', caseSensitive: false), '');
    // Strip (Feat. ...), (With ...), [Feat. ...]
    clean = clean.replaceAll(RegExp(r'\s*[\(\[](feat\.|featuring|with)[^()\]]+[\)\]]', caseSensitive: false), '');
    // Strip (Title Track), - Title Track
    clean = clean.replaceAll(RegExp(r'\s*[\(\[]title\s+track[\)\]]', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s*-\s*title\s+track', caseSensitive: false), '');
    // Strip version tags like (Lofi), (Reprise), (Acoustic), (Male), (Female), (Audio), (Eclipsa Audio)
    clean = clean.replaceAll(RegExp(r'\s*[\(\[](lofi|slowed|reverb|reprise|acoustic|remix|version|audio|male|female|eclipsa)[^()\]]*[\)\]]', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s*(eclipsa\s+audio|audio\s+song)$', caseSensitive: false), '');
    // Strip punctuation & extra whitespace
    clean = clean.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  @override
  Future<List<Track>> search(String query, {int limit = 25}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'search.getResults',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'n': limit,
          'p': 1,
          'q': trimmed,
        },
      );

      return _parseSearchResults(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<List<Track>> getTrendingTracks({int limit = 15}) async {
    return search('trending hindi english top hits', limit: limit);
  }

  Future<List<Track>> getTracksByGenre(String genre, {int limit = 15}) async {
    return search('$genre top hits', limit: limit);
  }

  List<Track> _parseSearchResults(dynamic data) {
    if (data == null) return [];

    Map<String, dynamic>? jsonMap;
    if (data is String) {
      try {
        jsonMap = jsonDecode(data) as Map<String, dynamic>?;
      } catch (_) {
        return [];
      }
    } else if (data is Map<String, dynamic>) {
      jsonMap = data;
    }

    if (jsonMap == null) return [];

    final results = jsonMap['results'] as List<dynamic>?;
    if (results == null) return [];

    final List<Track> tracks = [];
    for (final item in results) {
      if (item is Map<String, dynamic>) {
        final parsed = _parseSingleSong(item);
        if (parsed != null) {
          tracks.add(parsed);
        }
      }
    }

    return tracks;
  }

  Track? _parseSingleSong(Map<String, dynamic> item) {
    final songId = item['id']?.toString();
    final rawTitle = item['song'] as String? ?? item['title'] as String?;
    if (songId == null || rawTitle == null || rawTitle.isEmpty) return null;

    final title = unescapeHtml(rawTitle);
    final moreInfo = item['more_info'] is Map<String, dynamic>
        ? item['more_info'] as Map<String, dynamic>
        : null;

    final rawArtist = item['primary_artists'] as String? ??
        item['singers'] as String? ??
        item['music'] as String? ??
        moreInfo?['primary_artists'] as String? ??
        moreInfo?['singers'] as String? ??
        'Unknown Artist';
    final artistName = unescapeHtml(rawArtist);

    final rawAlbum = item['album'] as String? ??
        moreInfo?['album'] as String? ??
        'Single';
    final albumTitle = unescapeHtml(rawAlbum);

    final durationSec = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;
    final durationMs = durationSec > 0 ? durationSec * 1000 : 0;

    // High quality 500x500 album artwork (filtered for placeholders)
    var artwork = item['image'] as String?;
    if (artwork != null) {
      if (isPlaceholderArtwork(artwork)) {
        artwork = null;
      } else {
        artwork = artwork
            .replaceAll('150x150.jpg', '500x500.jpg')
            .replaceAll('50x50.jpg', '500x500.jpg');
      }
    }

    // Direct audio URL resolution with preferred bitrate
    final quality = preferencesService?.getAudioQuality() ?? '320k';
    final encryptedUrl = item['encrypted_media_url'] as String? ??
        moreInfo?['encrypted_media_url'] as String?;
    final streamUrl = DesCipher.decryptJioSaavnDirectUrl(encryptedUrl, quality: quality) ?? '';

    final bitrateVal = switch (quality) {
      '96k' => 96,
      '160k' => 160,
      '256k' => 256,
      _ => 320,
    };

    return Track(
      id: 'saavn:$songId',
      title: title,
      artistName: artistName,
      albumTitle: albumTitle,
      albumId: item['albumid']?.toString(),
      artistId: item['primary_artists_id']?.toString(),
      source: AudioSourceType.saavn,
      sourceId: songId,
      durationMs: durationMs,
      artworkUrl: artwork,
      audioUrl: streamUrl,
      codec: 'aac',
      bitrate: bitrateVal,
      isLiked: false,
      isDownloaded: false,
      addedAt: DateTime.now(),
    );
  }

  @override
  Future<String> getStreamUrl(Track track) async {
    final currentUrl = track.audioUrl;
    final isPreviewUrl = currentUrl.contains('jiotunepreview') ||
        currentUrl.contains('preview.saavncdn.com') ||
        currentUrl.contains('_p.mp4');

    if (currentUrl.isNotEmpty && currentUrl.startsWith('http') && !isPreviewUrl) {
      return currentUrl;
    }

    // Try fetching full details if audioUrl wasn't resolved or is only a preview
    try {
      final metadata = await getMetadata(track.sourceId);
      if (metadata != null &&
          metadata.audioUrl.isNotEmpty &&
          !metadata.audioUrl.contains('jiotunepreview') &&
          !metadata.audioUrl.contains('preview.saavncdn.com')) {
        return metadata.audioUrl;
      }
    } catch (_) {}

    return currentUrl;
  }

  @override
  Future<Track?> getMetadata(String sourceId) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'song.getDetails',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'pids': sourceId,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        // song.getDetails returns a map keyed by pid or with songs array
        if (data.containsKey(sourceId) && data[sourceId] is Map<String, dynamic>) {
          return _parseSingleSong(data[sourceId] as Map<String, dynamic>);
        } else if (data['songs'] is List && (data['songs'] as List).isNotEmpty) {
          return _parseSingleSong((data['songs'] as List).first as Map<String, dynamic>);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getArtworkUrl(String sourceId) async {
    final track = await getMetadata(sourceId);
    return track?.artworkUrl;
  }

  /// Fetches free lyrics from JioSaavn for a given songId.
  Future<Map<String, dynamic>?> getLyrics(String songId) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'lyrics.getLyrics',
          'lyrics_id': songId,
          '_format': 'json',
          'ctx': 'web6dot0',
        },
      );

      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is Map<String, dynamic> && data['lyrics'] != null) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// Searches JioSaavn by title and artist, then attempts to fetch lyrics.
  Future<Map<String, dynamic>?> searchAndGetLyrics(String title, String artist) async {
    try {
      final query = '$title $artist'.trim();
      final results = await search(query, limit: 5);
      for (final track in results) {
        if (track.sourceId.isNotEmpty) {
          final lyrics = await getLyrics(track.sourceId);
          if (lyrics != null && lyrics['lyrics'] != null) {
            return lyrics;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Checks if artwork URL is a JioSaavn default placeholder
  static bool isPlaceholderArtwork(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final lower = url.toLowerCase();
    return lower.contains('default-film') ||
        lower.contains('default-music') ||
        lower.contains('artist-default') ||
        lower.contains('album-default') ||
        lower.contains('playlist-default') ||
        lower.contains('show-default') ||
        lower.contains('episode-default') ||
        lower.contains('default-artist') ||
        lower.contains('default-album') ||
        lower.contains('default_artist') ||
        lower.contains('default_album') ||
        lower.contains('/_i/3.0/') ||
        lower.contains('/_i/') ||
        lower.contains('artists/default') ||
        lower.contains('albums/default') ||
        lower.contains('c.saavncdn.com/_artists/');
  }

  /// Upgrades low-resolution artwork to high-fidelity 500x500 CDN URLs, returning empty if placeholder.
  static String upgradeArtwork(String? artwork) {
    if (artwork == null || artwork.isEmpty || isPlaceholderArtwork(artwork)) return '';
    return artwork
        .replaceAll('150x150.jpg', '500x500.jpg')
        .replaceAll('50x50.jpg', '500x500.jpg');
  }

  /// Formats raw numerical strings with standard locale comma grouping.
  static String formatWithCommas(dynamic number) {
    if (number == null) return '';
    final str = number.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (str.isEmpty) return number.toString();
    final chars = str.split('').reversed.toList();
    final result = <String>[];
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        result.add(',');
      }
      result.add(chars[i]);
    }
    return result.reversed.join();
  }

  /// Comprehensive multi-result search (autocomplete endpoint) yielding Top Result, Artists, Albums, Playlists, and Songs.
  Future<SearchMultiResult> searchMulti(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const SearchMultiResult();

    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'autocomplete.get',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'query': trimmed,
        },
      );

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          return const SearchMultiResult();
        }
      }
      if (data is! Map<String, dynamic>) {
        return const SearchMultiResult();
      }

      // 1. Top Results
      final List<SearchTopResult> topResults = [];
      final topData = data['topquery']?['data'] as List<dynamic>?;
      if (topData != null) {
        for (final item in topData) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? '';
            final title = unescapeHtml(item['title'] as String? ?? '');
            final type = (item['type'] as String? ?? 'artist').toLowerCase();
            final image = upgradeArtwork(item['image'] as String?);
            final desc = unescapeHtml(item['description'] as String? ?? '');
            if (id.isNotEmpty && title.isNotEmpty) {
              topResults.add(SearchTopResult(
                id: id,
                title: title,
                type: type,
                imageUrl: image,
                description: desc,
                raw: item,
              ));
            }
          }
        }
      }

      // 2. Artists
      final List<SearchArtistItem> artists = [];
      final artistsData = data['artists']?['data'] as List<dynamic>?;
      if (artistsData != null) {
        for (final item in artistsData) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? '';
            final title = unescapeHtml(item['title'] as String? ?? '');
            final image = upgradeArtwork(item['image'] as String?);
            final desc = unescapeHtml(item['description'] as String? ?? 'Artist');
            if (id.isNotEmpty && title.isNotEmpty) {
              artists.add(SearchArtistItem(
                id: id,
                title: title,
                imageUrl: image,
                description: desc.isNotEmpty ? desc : 'Artist',
              ));
            }
          }
        }
      }

      // 3. Albums
      final List<SearchAlbumItem> albums = [];
      final albumsData = data['albums']?['data'] as List<dynamic>?;
      if (albumsData != null) {
        for (final item in albumsData) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? '';
            final title = unescapeHtml(item['title'] as String? ?? '');
            final image = upgradeArtwork(item['image'] as String?);
            final music = unescapeHtml(item['music'] as String? ?? '');
            final desc = unescapeHtml(item['description'] as String? ?? '');
            final year = item['more_info']?['year']?.toString();
            if (id.isNotEmpty && title.isNotEmpty) {
              albums.add(SearchAlbumItem(
                id: id,
                title: title,
                imageUrl: image,
                music: music,
                description: desc,
                year: year,
              ));
            }
          }
        }
      }

      // 4. Playlists
      final List<SearchPlaylistItem> playlists = [];
      final playlistsData = data['playlists']?['data'] as List<dynamic>?;
      if (playlistsData != null) {
        for (final item in playlistsData) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? '';
            final title = unescapeHtml(item['title'] as String? ?? '');
            final image = upgradeArtwork(item['image'] as String?);
            final desc = unescapeHtml(item['description'] as String? ?? '');
            final lang = item['language'] as String?;
            if (id.isNotEmpty && title.isNotEmpty) {
              playlists.add(SearchPlaylistItem(
                id: id,
                title: title,
                imageUrl: image,
                description: desc,
                language: lang,
              ));
            }
          }
        }
      }

      // 5. Songs
      final List<Track> songs = [];
      final songsData = data['songs']?['data'] as List<dynamic>?;
      if (songsData != null) {
        for (final item in songsData) {
          if (item is Map<String, dynamic>) {
            final track = _parseSingleSong(item);
            if (track != null) {
              songs.add(track);
            }
          }
        }
      }

      return SearchMultiResult(
        topResults: topResults,
        artists: artists,
        albums: albums,
        playlists: playlists,
        songs: songs,
      );
    } catch (_) {
      return const SearchMultiResult();
    }
  }

  /// Fetches artist profile details, top songs, and top albums.
  Future<ArtistDetails?> getArtistDetails(String artistId) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'artist.getArtistPageDetails',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'artistId': artistId,
          'n_song': 100,
          'n_album': 50,
        },
      );

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          return null;
        }
      }
      if (data is! Map<String, dynamic>) return null;

      final name = unescapeHtml(data['name'] as String? ?? 'Artist');
      final image = upgradeArtwork(data['image'] as String?);

      // Fans formatting
      String? fanCountStr;
      final rawFollowers = data['fan_count'] ?? data['follower_count'];
      if (rawFollowers != null) {
        final formatted = formatWithCommas(rawFollowers);
        if (formatted.isNotEmpty) {
          fanCountStr = 'Artist • $formatted Fans';
        }
      }
      if (fanCountStr == null && data['subtitle'] != null) {
        fanCountStr = unescapeHtml(data['subtitle'] as String);
      }

      final isVerified = data['isVerified'] == true || data['isVerified'] == 'true';

      // Parse Top Songs with smart title deduplication (filters out duplicate re-releases across compilation albums)
      final List<Track> topSongs = [];
      final seenSongKeys = <String>{};
      final songsList = data['topSongs']?['songs'] as List<dynamic>?;
      if (songsList != null) {
        for (final song in songsList) {
          if (song is Map<String, dynamic>) {
            final parsed = _parseSingleSong(song);
            if (parsed != null) {
              final normKey = normalizeSongTitle(parsed.title);
              if (normKey.isNotEmpty && seenSongKeys.add(normKey)) {
                topSongs.add(parsed);
              }
            }
          }
        }
      }

      // Parse Top Albums
      final List<SearchAlbumItem> topAlbums = [];
      final albumsList = data['topAlbums']?['albums'] as List<dynamic>?;
      if (albumsList != null) {
        for (final alb in albumsList) {
          if (alb is Map<String, dynamic>) {
            final albumId = alb['albumid']?.toString() ?? alb['id']?.toString() ?? '';
            final title = unescapeHtml(alb['album'] as String? ?? alb['title'] as String? ?? '');
            final albImage = upgradeArtwork(alb['imageUrl'] as String? ?? alb['image'] as String?);
            final music = unescapeHtml(alb['primaryArtists'] as String? ?? alb['music'] as String? ?? '');
            final year = alb['year']?.toString();
            final songCount = int.tryParse(alb['numSongs']?.toString() ?? '0');
            if (albumId.isNotEmpty && title.isNotEmpty) {
              topAlbums.add(SearchAlbumItem(
                id: albumId,
                title: title,
                imageUrl: albImage,
                music: music,
                description: year != null ? '$year · Album' : 'Album',
                year: year,
                songCount: songCount,
              ));
            }
          }
        }
      }

      return ArtistDetails(
        id: artistId,
        name: name,
        imageUrl: image,
        fanCount: fanCountStr,
        isVerified: isVerified,
        topSongs: topSongs,
        topAlbums: topAlbums,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parses a raw song map from JioSaavn API directly into a Track model
  Track? parseSongDirect(Map<String, dynamic> item) => _parseSingleSong(item);

  /// Fetches paginated catalog songs for an artist beyond the initial top songs.
  Future<List<Track>> getArtistMoreSongs({
    String? artistId,
    required String artistName,
    int page = 1,
    int limit = 50,
  }) async {
    // 1. Try artist.getArtistMoreSong endpoint first if artistId is available
    if (artistId != null && artistId.isNotEmpty) {
      try {
        final response = await _dio.get(
          '',
          queryParameters: {
            '__call': 'artist.getArtistMoreSong',
            '_format': 'json',
            '_marker': '0',
            'cc': 'in',
            'artistId': artistId,
            'p': page,
            'n': limit,
          },
        );
        dynamic data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (_) {}
        }
        if (data is Map<String, dynamic>) {
          final songsList = data['topSongs']?['songs'] as List<dynamic>? ??
              data['songs'] as List<dynamic>? ??
              data['results'] as List<dynamic>?;
          if (songsList != null && songsList.isNotEmpty) {
            final List<Track> tracks = [];
            for (final s in songsList) {
              if (s is Map<String, dynamic>) {
                final parsed = _parseSingleSong(s);
                if (parsed != null) tracks.add(parsed);
              }
            }
            if (tracks.isNotEmpty) return tracks;
          }
        } else if (data is List<dynamic>) {
          final List<Track> tracks = [];
          for (final s in data) {
            if (s is Map<String, dynamic>) {
              final parsed = _parseSingleSong(s);
              if (parsed != null) tracks.add(parsed);
            }
          }
          if (tracks.isNotEmpty) return tracks;
        }
      } catch (_) {}
    }

    // 2. Fallback to search.getResults endpoint for artist query
    final trimmed = artistName.trim();
    if (trimmed.isEmpty) return [];

    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'search.getResults',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'n': limit,
          'p': page,
          'q': trimmed,
        },
      );

      return _parseSearchResults(response.data);
    } catch (_) {
      return [];
    }
  }

  /// Fetches complete album details and track stream list.
  Future<AlbumDetails?> getAlbumDetails(String albumId) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'content.getAlbumDetails',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'albumid': albumId,
        },
      );

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          return null;
        }
      }
      if (data is! Map<String, dynamic>) return null;

      final title = unescapeHtml(data['title'] as String? ?? data['name'] as String? ?? 'Album');
      final primaryArtists = unescapeHtml(data['primary_artists'] as String? ?? data['music'] as String? ?? '');
      final image = upgradeArtwork(data['image'] as String?);
      final year = data['year']?.toString();

      // Parse songs
      final List<Track> songs = [];
      int totalPlayCount = 0;
      final songsList = data['songs'] as List<dynamic>?;
      if (songsList != null) {
        for (final song in songsList) {
          if (song is Map<String, dynamic>) {
            final parsed = _parseSingleSong(song);
            if (parsed != null) {
              songs.add(parsed);
              final pCount = int.tryParse(song['play_count']?.toString() ?? '0') ?? 0;
              totalPlayCount += pCount;
            }
          }
        }
      }

      String? playCountStr;
      final rawPlays = data['play_count'] ?? (totalPlayCount > 0 ? totalPlayCount : null);
      if (rawPlays != null) {
        final formatted = formatWithCommas(rawPlays);
        if (formatted.isNotEmpty) {
          playCountStr = 'Album • $formatted Plays';
        }
      }
      if (playCountStr == null && year != null) {
        playCountStr = 'Album • $year';
      }

      return AlbumDetails(
        id: albumId,
        title: title,
        primaryArtists: primaryArtists,
        imageUrl: image,
        playCount: playCountStr,
        year: year,
        songs: songs,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches complete playlist details and track stream list for JioSaavn playlist / chart.
  Future<StreamPlaylistDetails?> getPlaylistDetails(String playlistId) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          '__call': 'playlist.getDetails',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'listid': playlistId,
        },
      );

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          return null;
        }
      }
      if (data is! Map<String, dynamic>) return null;

      final title = unescapeHtml(data['title'] as String? ?? data['listname'] as String? ?? 'Playlist');
      final subtitle = unescapeHtml(data['subtitle'] as String? ?? data['header_desc'] as String? ?? '');
      final description = unescapeHtml(data['description'] as String? ?? '');
      final image = upgradeArtwork(data['image'] as String?);
      final rawFollowers = data['fan_count'] ?? data['follower_count'] ?? data['count'];
      String? followerStr;
      if (rawFollowers != null) {
        final formatted = formatWithCommas(rawFollowers);
        if (formatted.isNotEmpty) {
          followerStr = '$formatted Followers';
        }
      }

      final List<Track> songs = [];
      final songsList = data['songs'] as List<dynamic>? ?? data['list'] as List<dynamic>?;
      if (songsList != null) {
        for (final song in songsList) {
          if (song is Map<String, dynamic>) {
            final parsed = _parseSingleSong(song);
            if (parsed != null) {
              songs.add(parsed);
            }
          }
        }
      }

      return StreamPlaylistDetails(
        id: playlistId,
        title: title,
        subtitle: subtitle.isNotEmpty ? subtitle : null,
        description: description.isNotEmpty ? description : null,
        imageUrl: image,
        followerCount: followerStr,
        songCount: songs.length,
        songs: songs,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches new releases (albums & singles)
  Future<List<SearchAlbumItem>> getNewReleases({int limit = 20}) async {
    try {
      final multiRes = await searchMulti('New Releases Latest Albums 2025 2026');
      if (multiRes.albums.isNotEmpty) {
        return multiRes.albums.take(limit).toList();
      }
    } catch (_) {}

    try {
      final fallbackMulti = await searchMulti('Top Bollywood Punjabi Pop Albums');
      if (fallbackMulti.albums.isNotEmpty) {
        return fallbackMulti.albums.take(limit).toList();
      }
    } catch (_) {}

    return [];
  }

  /// Returns curated and dynamic Top Charts with rich metadata and artwork
  Future<List<TopChartItem>> getTopCharts() async {
    const chartConfigs = [
      (
        query: 'Trending Today',
        badge: '🔥 TRENDING',
        defaultId: '110858205',
        defaultTitle: 'Trending Today',
        defaultSubtitle: 'Hottest viral tracks right now',
        fallbackImage: 'https://c.saavncdn.com/editorial/TrendingToday_20231122115124.jpg',
      ),
      (
        query: 'Weekly Top 50 Hindi',
        badge: '👑 #1 HINDI',
        defaultId: '104845512',
        defaultTitle: 'Weekly Top 50 Hindi',
        defaultSubtitle: 'Most streamed songs this week',
        fallbackImage: 'https://c.saavncdn.com/editorial/WeeklyTop50Hindi_20231122115203.jpg',
      ),
      (
        query: 'Global Top Hits',
        badge: '🌍 GLOBAL',
        defaultId: '107450700',
        defaultTitle: 'Global Top Hits',
        defaultSubtitle: 'International chart toppers',
        fallbackImage: 'https://c.saavncdn.com/editorial/GlobalTopHits_20231122115220.jpg',
      ),
      (
        query: 'Punjabi 100',
        badge: '⚡ PUNJABI',
        defaultId: '113454321',
        defaultTitle: 'Punjabi 100',
        defaultSubtitle: 'Biggest Punjabi bangers',
        fallbackImage: 'https://c.saavncdn.com/editorial/Punjabi100_20231122115245.jpg',
      ),
      (
        query: 'Romantic Hits',
        badge: '💖 ROMANCE',
        defaultId: '108923412',
        defaultTitle: 'Romantic Hits',
        defaultSubtitle: 'Soulful love songs & melodies',
        fallbackImage: 'https://c.saavncdn.com/editorial/RomanticHits_20231122115310.jpg',
      ),
    ];

    try {
      final futures = chartConfigs.map((cfg) => searchMulti(cfg.query));
      final results = await Future.wait(futures);

      final List<TopChartItem> charts = [];
      for (int i = 0; i < chartConfigs.length; i++) {
        final cfg = chartConfigs[i];
        final multi = results[i];

        SearchPlaylistItem? found;
        if (multi.playlists.isNotEmpty) {
          found = multi.playlists.first;
        }

        charts.add(TopChartItem(
          id: found?.id ?? cfg.defaultId,
          title: cfg.defaultTitle,
          subtitle: cfg.defaultSubtitle,
          imageUrl: found?.imageUrl ?? cfg.fallbackImage,
          count: 'Top 50',
          badge: cfg.badge,
        ));
      }
      return charts;
    } catch (_) {
      return chartConfigs.map((cfg) => TopChartItem(
        id: cfg.defaultId,
        title: cfg.defaultTitle,
        subtitle: cfg.defaultSubtitle,
        imageUrl: cfg.fallbackImage,
        count: 'Top 50',
        badge: cfg.badge,
      )).toList();
    }
  }

  /// Fetches popular superstar artists with real JioSaavn IDs and verified artwork
  Future<List<SearchArtistItem>> getPopularArtists() async {
    const artistQueries = [
      'Arijit Singh',
      'Diljit Dosanjh',
      'Shreya Ghoshal',
      'The Weeknd',
      'Taylor Swift',
      'Karan Aujla',
      'Billie Eilish',
      'Anirudh Ravichander',
      'Atif Aslam',
      'AP Dhillon',
      'Pritam',
      'Sidhu Moose Wala',
    ];

    final List<SearchArtistItem> artists = [];
    final seenIds = <String>{};

    try {
      final futures = artistQueries.map((name) => searchMulti(name));
      final results = await Future.wait(futures);

      for (int i = 0; i < results.length; i++) {
        final multi = results[i];
        final queryName = artistQueries[i].toLowerCase();

        SearchArtistItem? matchedArtist;

        // 1. First priority: Check topResults for verified artist
        for (final top in multi.topResults) {
          if (top.isArtist) {
            matchedArtist = SearchArtistItem(
              id: top.id,
              title: top.title,
              imageUrl: top.imageUrl,
              description: 'Artist',
            );
            break;
          }
        }

        // 2. Second priority: Find exact/best match in artists list
        if (matchedArtist == null && multi.artists.isNotEmpty) {
          for (final a in multi.artists) {
            if (a.title.toLowerCase() == queryName ||
                a.title.toLowerCase().contains(queryName)) {
              matchedArtist = a;
              break;
            }
          }
          matchedArtist ??= multi.artists.first;
        }

        if (matchedArtist != null && seenIds.add(matchedArtist.id)) {
          artists.add(matchedArtist);
        }
      }
    } catch (_) {}

    return artists;
  }

  /// Curated pool of iconic & blockbuster Indian movie soundtrack albums
  static const _movieSoundtrackPool = [
    'OK Jaanu',
    'Raabta',
    'Dunki',
    'Jab Harry Met Sejal',
    'Dhurandhar',
    'Animal',
    'Kabir Singh',
    'Brahmastra',
    'Jawan',
    'Pathaan',
    'Aashiqui 2',
    'Rockstar',
    'Yeh Jawaani Hai Deewani',
    'Gully Boy',
    'Shershaah',
    'Sita Ramam',
    'Pushpa',
    'Kantara',
    'Stree 2',
    'Fighter',
    'Laila Majnu',
    'Ae Dil Hai Mushkil',
    'Kalank',
    'Tamasha',
    'Kedarnath',
    'War',
    'Zara Hatke Zara Bachke',
    'Tu Jhoothi Main Makkaar',
    'Bhediya',
    'Vikram Vedha',
    'Gangubai Kathiawadi',
    'Satyaprem Ki Katha',
    'Chhichhore',
    'Sanju',
    'Bajirao Mastani',
    'Dilwale',
    'Cocktail',
  ];

  /// Fetches randomized movie soundtrack albums from JioSaavn
  Future<List<SearchAlbumItem>> getPopularMovieAlbums({int count = 12}) async {
    final shuffled = List<String>.from(_movieSoundtrackPool)..shuffle();
    final selectedQueries = shuffled.take(count).toList();

    final List<SearchAlbumItem> movieAlbums = [];
    final seenIds = <String>{};

    try {
      final futures = selectedQueries.map((name) => searchMulti(name));
      final results = await Future.wait(futures);

      for (int i = 0; i < results.length; i++) {
        final multi = results[i];
        final query = selectedQueries[i].toLowerCase();

        SearchAlbumItem? matchedAlbum;

        // 1. First check topResults if it is an album
        for (final top in multi.topResults) {
          if (top.isAlbum) {
            matchedAlbum = SearchAlbumItem(
              id: top.id,
              title: top.title,
              imageUrl: top.imageUrl,
              music: top.description ?? 'Movie Album',
              description: 'Movie Album',
            );
            break;
          }
        }

        // 2. Otherwise check albums list
        if (matchedAlbum == null && multi.albums.isNotEmpty) {
          for (final a in multi.albums) {
            if (a.title.toLowerCase().contains(query) || query.contains(a.title.toLowerCase())) {
              matchedAlbum = a;
              break;
            }
          }
          matchedAlbum ??= multi.albums.first;
        }

        if (matchedAlbum != null && seenIds.add(matchedAlbum.id)) {
          movieAlbums.add(matchedAlbum);
        }
      }
    } catch (_) {}

    return movieAlbums;
  }

  /// Fetches editorial playlists
  Future<List<SearchPlaylistItem>> getEditorialPlaylists() async {
    try {
      final multi = await searchMulti('Best Chill Workout Party Vibes Playlist');
      if (multi.playlists.isNotEmpty) {
        return multi.playlists.take(15).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Returns standard mood and activity categories
  static List<MoodCategory> getMoodCategories() {
    return const [
      MoodCategory(
        id: 'lofi_chill',
        title: 'Lo-Fi Chill',
        subtitle: 'Relaxing beats & ambient vibes',
        query: 'Lo-Fi Chill Beats relax study',
        gradientColors: [0xFF6A11CB, 0xFF2575FC],
        iconName: 'spa',
      ),
      MoodCategory(
        id: 'workout_energy',
        title: 'Workout & Gym',
        subtitle: 'High BPM beast mode tracks',
        query: 'Gym Workout Energy motivation edm',
        gradientColors: [0xFFFF416C, 0xFFFF4B2B],
        iconName: 'fitness_center',
      ),
      MoodCategory(
        id: 'deep_focus',
        title: 'Deep Focus',
        subtitle: 'Concentration & coding flow',
        query: 'Focus Instrumental study ambient piano',
        gradientColors: [0xFF11998E, 0xFF38EF7D],
        iconName: 'psychology',
      ),
      MoodCategory(
        id: 'night_drive',
        title: 'Night Drive',
        subtitle: 'Synthwave & late night cruising',
        query: 'Night Drive Synthwave phonk car music',
        gradientColors: [0xFF8E2DE2, 0xFF4A00E0],
        iconName: 'directions_car',
      ),
      MoodCategory(
        id: 'party_bangers',
        title: 'Party & Dance',
        subtitle: 'Club hits & non-stop energy',
        query: 'Party Club Dance EDM bangers',
        gradientColors: [0xFFF857A6, 0xFFFF5858],
        iconName: 'celebration',
      ),
      MoodCategory(
        id: 'acoustic_peace',
        title: 'Acoustic Peace',
        subtitle: 'Unplugged guitar & coffee vibe',
        query: 'Acoustic Unplugged Indie Coffee',
        gradientColors: [0xFFE65C00, 0xFFF9D423],
        iconName: 'music_note',
      ),
    ];
  }
}


