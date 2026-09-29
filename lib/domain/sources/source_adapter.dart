import '../models/track.dart';

abstract class SourceAdapter {
  AudioSourceType get sourceType;
  String get name;

  Future<List<Track>> search(String query);
  Future<String> getStreamUrl(Track track);
  Future<Track?> getMetadata(String sourceId);
  Future<String?> getArtworkUrl(String sourceId);
}
