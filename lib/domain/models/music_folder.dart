import 'package:musify/domain/models/track.dart';

class MusicFolder {
  final String path;
  final String name;
  final List<Track> tracks;
  final int totalSizeBytes;

  const MusicFolder({
    required this.path,
    required this.name,
    required this.tracks,
    required this.totalSizeBytes,
  });

  int get trackCount => tracks.length;

  String get formattedSize {
    if (totalSizeBytes <= 0) return '';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
