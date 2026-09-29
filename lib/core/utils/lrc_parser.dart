import 'package:musify/domain/models/lyrics.dart';

class LrcParser {
  static final RegExp _timestampRegex = RegExp(
    r'^\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)$',
  );

  /// Parses an LRC formatted string into a list of [LyricLine]s.
  /// If the string contains no valid timestamps, returns an empty list.
  static List<LyricLine> parseLrc(String lrcContent) {
    final lines = lrcContent.split('\n');
    final List<LyricLine> result = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = _timestampRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final millisStr = match.group(3);
        int millis = 0;
        if (millisStr != null) {
          if (millisStr.length == 2) {
            millis = (int.tryParse(millisStr) ?? 0) * 10;
          } else {
            millis = int.tryParse(millisStr) ?? 0;
          }
        }

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );

        final text = match.group(4)?.trim() ?? '';
        result.add(LyricLine(timestamp: timestamp, text: text));
      }
    }

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  /// Parses plain text or HTML (<br>) formatted lyrics into a list of [LyricLine]s without timestamps.
  static List<LyricLine> parsePlain(String plainContent) {
    final clean = plainContent
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');

    final lines = clean.split('\n');
    final List<LyricLine> result = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isNotEmpty) {
        result.add(LyricLine(timestamp: Duration.zero, text: line));
      }
    }

    return result;
  }
}
