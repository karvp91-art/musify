class SanitizedTrackInfo {
  final String title;
  final String artist;

  const SanitizedTrackInfo({
    required this.title,
    required this.artist,
  });
}

class AudioNameSanitizer {
  // Regex to remove downloader domains / website watermarks
  static final RegExp _domainTagsRegExp = RegExp(
    r'\[.*?(\.com|\.pk|\.is|\.net|\.in|\.org|\.co|world|music|songs|download|mp3|m4a|pagal|djpunjab|starmusiq|masstamilan|hungama|gaana|wynk|jiosaavn).*?\]|\(.*?(www\.|\.com|\.pk|\.is|\.net|\.in|\.org|\.co|world|music|songs|download|mp3|m4a|pagal|djpunjab|starmusiq|masstamilan|hungama|gaana|wynk|jiosaavn).*?\)',
    caseSensitive: false,
  );

  // Regex to remove common YouTube / audio ripper junk phrases with surrounding brackets or delimiters
  static final RegExp _bracketedJunkRegExp = RegExp(
    r'(\[|\()(full\s*audio\s*song|full\s*video\s*song|full\s*audio|full\s*song|full\s*video|official\s*music\s*video|official\s*video\s*song|official\s*lyrical\s*video|official\s*lyric\s*video|official\s*video|official\s*audio|official\s*track|lyrics?\s*video|lyric\s*video|lyrics?|visualizer|audio\s*song|audio|video|320\s*kbps|128\s*kbps|64\s*kbps|320kbps|128kbps|64kbps|320k|128k|hd\s*video|hd|hq|4k|1080p|720p|slowed\s*\+\s*reverb|slowed\s*&\s*reverb|bass\s*boosted|remastered|extended\s*mix|pagalworld|songs\.pk|djpunjab)(\]|\))',
    caseSensitive: false,
  );

  static final RegExp _bareJunkPhrasesRegExp = RegExp(
    r'\b(full\s*audio\s*song|full\s*video\s*song|full\s*audio|full\s*song|full\s*video|official\s*music\s*video|official\s*video\s*song|official\s*lyrical\s*video|official\s*lyric\s*video|official\s*video|official\s*audio|lyrics?\s*video|lyric\s*video|320\s*kbps|128\s*kbps|64\s*kbps|320kbps|128kbps|64kbps|320k|128k|slowed\s*\+\s*reverb|slowed\s*&\s*reverb|bass\s*boosted)\b',
    caseSensitive: false,
  );

  // Regex to remove track numbering at beginning (e.g. "01. ", "01 - ", "01_")
  static final RegExp _trackNumberPrefixRegExp = RegExp(
    r'^\s*(\d{1,3}[\.\-_\s]+)+',
  );

  // Regex to clean multiple separators and spaces
  static final RegExp _multipleSpacesRegExp = RegExp(r'\s+');

  /// Cleans a raw text string by stripping downloader junk, normalizing underscores, and trimming.
  static String cleanText(String input) {
    var text = input;

    // 1. Remove domain tags e.g. [PagalWorld], (www.Songs.pk)
    text = text.replaceAll(_domainTagsRegExp, ' ');

    // 2. Remove bracketed junk e.g. [Official Video], [Lyrics], (Audio)
    text = text.replaceAll(_bracketedJunkRegExp, ' ');

    // 3. Replace underscores with spaces (common in downloaded media)
    text = text.replaceAll('_', ' ');

    // 4. Remove bare junk phrases
    text = text.replaceAll(_bareJunkPhrasesRegExp, ' ');

    // 5. Remove empty brackets or parentheses left behind: "()", "[]"
    text = text.replaceAll(RegExp(r'\(\s*\)|\[\s*\]'), ' ');

    // 6. Collapse multiple spaces
    text = text.replaceAll(_multipleSpacesRegExp, ' ').trim();

    // 7. Strip outer enclosing quotes, hyphens, and delimiters safely
    return _stripOuterEnclosures(text);
  }

  static String _stripOuterEnclosures(String input) {
    var text = input.trim();
    text = text.replaceAll(RegExp(r'''^[\s"'‘’“”\-\~:]+|[\s"'‘’“”\-\~:]+$'''), '').trim();

    // If whole string is wrapped in [...] or (...), strip outer container
    if (text.startsWith('[') && text.endsWith(']')) {
      text = text.substring(1, text.length - 1).trim();
    } else if (text.startsWith('(') && text.endsWith(')') && !text.substring(1, text.length - 1).contains('(')) {
      text = text.substring(1, text.length - 1).trim();
    }
    return text.replaceAll(RegExp(r'''^[\s"'‘’“”\-\~:]+|[\s"'‘’“”\-\~:]+$'''), '').trim();
  }

  /// Intelligently parses a filename and optional folder context into a clean Song Title and Artist.
  static SanitizedTrackInfo parseFileName(
    String rawFileName, {
    String? folderName,
    String? fallbackArtist,
  }) {
    var baseName = cleanText(rawFileName);

    // Remove leading track numbers e.g. "01. Song" -> "Song"
    baseName = baseName.replaceAll(_trackNumberPrefixRegExp, '').trim();

    // Check for standard separators: " - ", " – ", " — ", " ~ "
    final separatorMatch = RegExp(r'\s+[\-–—~]\s+').firstMatch(baseName);

    String title = baseName;
    String artist = fallbackArtist ?? 'Unknown Artist';

    if (separatorMatch != null) {
      final part1 = cleanText(baseName.substring(0, separatorMatch.start));
      final part2 = cleanText(baseName.substring(separatorMatch.end));

      if (part1.isNotEmpty && part2.isNotEmpty) {
        // Decide if format is "Artist - Title" or "Title - Artist"
        // If part1 has "feat." or "ft.", it's usually "Title (feat. X) - Artist"
        final part1HasFeat = part1.toLowerCase().contains('feat.') || part1.toLowerCase().contains('ft.');
        final part2HasFeat = part2.toLowerCase().contains('feat.') || part2.toLowerCase().contains('ft.');

        if (part1HasFeat && !part2HasFeat) {
          title = part1;
          artist = part2;
        } else {
          // Standard convention: "Artist - Title"
          artist = part1;
          title = part2;
        }
      } else if (part1.isNotEmpty) {
        title = part1;
      } else if (part2.isNotEmpty) {
        title = part2;
      }
    } else {
      // No separator in filename. Check if parent folder name is a valid artist name
      if (folderName != null && _isValidArtistFolderName(folderName)) {
        artist = cleanText(folderName);
      }
    }

    // Final cleanup of title and artist
    title = cleanText(title);
    artist = cleanText(artist);

    if (title.isEmpty) {
      title = cleanText(rawFileName);
      if (title.isEmpty) title = 'Untitled Audio';
    }

    if (artist.isEmpty || artist.toLowerCase() == 'unknown') {
      if (folderName != null && _isValidArtistFolderName(folderName)) {
        artist = cleanText(folderName);
      } else {
        artist = 'Unknown Artist';
      }
    }

    return SanitizedTrackInfo(
      title: title,
      artist: artist,
    );
  }

  static bool _isValidArtistFolderName(String folder) {
    final lower = folder.toLowerCase().trim();
    if (lower.isEmpty) return false;
    final ignored = {
      'music',
      'download',
      'downloads',
      'audio',
      'songs',
      'sound',
      'sounds',
      'media',
      'documents',
      'podcasts',
      'recordings',
      'bluetooth',
      '0',
      'emulated',
      'storage',
      'sdcard',
      'internal storage',
    };
    return !ignored.contains(lower);
  }
}
