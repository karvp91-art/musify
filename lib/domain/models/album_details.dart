import 'package:musify/domain/models/track.dart';

class AlbumDetails {
  final String id;
  final String title;
  final String? primaryArtists;
  final String? imageUrl;
  final String? playCount;
  final String? year;
  final List<Track> songs;

  const AlbumDetails({
    required this.id,
    required this.title,
    this.primaryArtists,
    this.imageUrl,
    this.playCount,
    this.year,
    this.songs = const [],
  });
}
