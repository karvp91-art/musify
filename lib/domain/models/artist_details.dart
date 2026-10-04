import 'package:musify/domain/models/search_result_models.dart';
import 'package:musify/domain/models/track.dart';

class ArtistDetails {
  final String id;
  final String name;
  final String? imageUrl;
  final String? fanCount;
  final bool isVerified;
  final List<Track> topSongs;
  final List<SearchAlbumItem> topAlbums;

  const ArtistDetails({
    required this.id,
    required this.name,
    this.imageUrl,
    this.fanCount,
    this.isVerified = false,
    this.topSongs = const [],
    this.topAlbums = const [],
  });
}
