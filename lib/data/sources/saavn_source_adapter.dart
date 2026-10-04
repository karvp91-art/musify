import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:musify/core/utils/des_cipher.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/models/search_result_models.dart';
import 'package:musify/domain/models/artist_details.dart';
import 'package:musify/domain/models/album_details.dart';
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
    var streamUrl = DesCipher.decryptJioSaavnDirectUrl(encryptedUrl, quality: quality);

    // Fallback to media_preview_url or vlink if direct decryption failed
    if (streamUrl == null || streamUrl.isEmpty) {
      streamUrl = item['media_preview_url'] as String? ??
          moreInfo?['vlink'] as String? ??
          '';
    }

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
    if (track.audioUrl.isNotEmpty && track.audioUrl.startsWith('http')) {
      return track.audioUrl;
    }

    // Try fetching details if audioUrl wasn't resolved
    try {
      final metadata = await getMetadata(track.sourceId);
      if (metadata != null && metadata.audioUrl.isNotEmpty) {
        return metadata.audioUrl;
      }
    } catch (_) {}

    return track.audioUrl;
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
          'n_song': 30,
          'n_album': 20,
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

      // Parse Top Songs
      final List<Track> topSongs = [];
      final songsList = data['topSongs']?['songs'] as List<dynamic>?;
      if (songsList != null) {
        for (final song in songsList) {
          if (song is Map<String, dynamic>) {
            final parsed = _parseSingleSong(song);
            if (parsed != null) {
              topSongs.add(parsed);
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
}

