import '../../domain/models/track.dart';
import '../../domain/sources/source_adapter.dart';

class SourceRouter {
  final Map<AudioSourceType, SourceAdapter> _adapters = {};

  void registerAdapter(SourceAdapter adapter) {
    _adapters[adapter.sourceType] = adapter;
  }

  SourceAdapter? getAdapter(AudioSourceType type) => _adapters[type];

  Future<List<Track>> searchAll(String query, {bool includeLocal = true}) async {
    final targetAdapters = includeLocal
        ? _adapters.values
        : _adapters.values.where((adapter) => adapter.sourceType != AudioSourceType.local);

    final futures = targetAdapters.map((adapter) async {
      try {
        return await adapter.search(query);
      } catch (_) {
        return <Track>[];
      }
    });

    final resultsList = await Future.wait(futures);
    final allTracks = resultsList.expand((list) => list).toList();

    // Prioritize: Local (0) -> JioSaavn 320k (1) -> YouTube (2) -> Others (3)
    allTracks.sort((a, b) {
      int score(Track t) {
        if (t.source == AudioSourceType.local) return 0;
        if (t.source == AudioSourceType.saavn) return 1;
        if (t.source == AudioSourceType.youtube) return 2;
        return 3;
      }
      return score(a).compareTo(score(b));
    });

    // De-duplicate by title & artist signature
    final List<Track> combined = [];
    final Set<String> seenSignatures = {};

    for (final track in allTracks) {
      final signature = '${_normalize(track.title)}|${_normalize(track.artistName)}';
      if (track.source == AudioSourceType.local || !seenSignatures.contains(signature)) {
        seenSignatures.add(signature);
        combined.add(track);
      }
    }

    return combined;
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }


  Future<String> resolvePlayUrl(Track track) async {
    final adapter = _adapters[track.source];
    if (adapter != null) {
      return adapter.getStreamUrl(track);
    }
    return track.filePath ?? track.audioUrl;
  }
}
