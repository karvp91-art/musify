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

  /// Finds the index of the line that corresponds to [position]
  int findCurrentLineIndex(Duration position) {
    if (!isSynced || lines.isEmpty) return -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].timestamp) {
        return i;
      }
    }
    return 0;
  }
}
