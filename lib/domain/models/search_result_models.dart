import 'package:musify/domain/models/track.dart';

class SearchTopResult {
  final String id;
  final String title;
  final String? subtitle;
  final String type; // 'artist', 'album', 'song', 'playlist'
  final String? imageUrl;
  final String? description;
  final Map<String, dynamic>? raw;

  const SearchTopResult({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    this.imageUrl,
    this.description,
    this.raw,
  });

  bool get isArtist => type.toLowerCase() == 'artist';
  bool get isAlbum => type.toLowerCase() == 'album';
  bool get isSong => type.toLowerCase() == 'song';
  bool get isPlaylist => type.toLowerCase() == 'playlist';
}

class SearchArtistItem {
  final String id;
  final String title;
  final String? imageUrl;
  final String description;

  const SearchArtistItem({
    required this.id,
    required this.title,
    this.imageUrl,
    this.description = 'Artist',
  });
}

class SearchAlbumItem {
  final String id;
  final String title;
  final String? imageUrl;
  final String? music;
  final String description;
  final String? year;
  final int? songCount;

  const SearchAlbumItem({
    required this.id,
    required this.title,
    this.imageUrl,
    this.music,
    this.description = '',
    this.year,
    this.songCount,
  });
}

class SearchPlaylistItem {
  final String id;
  final String title;
  final String? imageUrl;
  final String description;
  final String? language;

  const SearchPlaylistItem({
    required this.id,
    required this.title,
    this.imageUrl,
    this.description = '',
    this.language,
  });
}

class SearchMultiResult {
  final List<SearchTopResult> topResults;
  final List<SearchArtistItem> artists;
  final List<SearchAlbumItem> albums;
  final List<SearchPlaylistItem> playlists;
  final List<Track> songs;

  const SearchMultiResult({
    this.topResults = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
    this.songs = const [],
  });

  bool get isEmpty =>
      topResults.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty &&
      songs.isEmpty;

  bool get isNotEmpty => !isEmpty;
}
