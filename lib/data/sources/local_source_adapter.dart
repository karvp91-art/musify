import '../../domain/models/track.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/sources/source_adapter.dart';

class LocalSourceAdapter implements SourceAdapter {
  final AudioRepository _repository;

  LocalSourceAdapter(this._repository);

  @override
  AudioSourceType get sourceType => AudioSourceType.local;

  @override
  String get name => 'Local Files';

  @override
  Future<List<Track>> search(String query) async {
    return _repository.searchTracks(query);
  }

  @override
  Future<String> getStreamUrl(Track track) async {
    // For local files, the audioUrl is already the local file path or uri
    return track.filePath ?? track.audioUrl;
  }

  @override
  Future<Track?> getMetadata(String sourceId) async {
    final localTracks = await _repository.getLocalTracks();
    try {
      return localTracks.firstWhere((t) => t.sourceId == sourceId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getArtworkUrl(String sourceId) async {
    final track = await getMetadata(sourceId);
    return track?.artworkUrl;
  }
}
