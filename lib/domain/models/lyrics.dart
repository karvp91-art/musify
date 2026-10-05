class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => '[${timestamp.inSeconds}s] $text';
}

class Lyrics {
  final String trackId;
  final String plainLyrics;
  final List<LyricLine> lines;
  final bool isSynced;
  final String? copyright;
  final String source; // 'JioSaavn' or 'LRCLIB'

  const Lyrics({
    required this.trackId,
    required this.plainLyrics,
    this.lines = const [],
    this.isSynced = false,
    this.copyright,
    this.source = 'JioSaavn',
  });

  bool get isEmpty => plainLyrics.trim().isEmpty && lines.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Finds the index of the line that corresponds to [position] using O(log n) binary search
  int findCurrentLineIndex(Duration position) {
    if (!isSynced || lines.isEmpty) return -1;
    if (position < lines.first.timestamp) return 0;
    if (position >= lines.last.timestamp) return lines.length - 1;

    int low = 0;
    int high = lines.length - 1;
    int result = 0;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].timestamp <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }
}
