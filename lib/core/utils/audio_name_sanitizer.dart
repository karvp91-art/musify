class SanitizedTrackInfo {
  final String title;
  final String artist;
  final String? album;

  const SanitizedTrackInfo({
    required this.title,
    required this.artist,
    this.album,
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
    r'(\[|\()(full\s*audio\s*song|full\s*video\s*song|full\s*audio|full\s*song|full\s*video|official\s*music\s*video|official\s*video\s*song|official\s*lyrical\s*video|official\s*lyric\s*video|official\s*video|official\s*audio|official\s*track|lyrics?\s*video|lyric\s*video|lyrics?|visualizer|audio\s*song|audio|video|320\s*kbps|128\s*kbps|64\s*kbps|320kbps|128kbps|64kbps|320k|128k|hd\s*video|hd|hq|4k|1080p|720p|slowed\s*\+\s*reverb|slowed\s*&\s*reverb|bass\s*boosted|remastered|extended\s*mix|pagalworld|songs\.pk|djpunjab|snaptube)(\]|\))',
    caseSensitive: false,
  );

  static final RegExp _bareJunkPhrasesRegExp = RegExp(
    r'\b(full\s*audio\s*song|full\s*video\s*song|full\s*audio|full\s*song|full\s*video|official\s*music\s*video|official\s*video\s*song|official\s*lyrical\s*video|official\s*lyric\s*video|official\s*video|official\s*audio|lyrics?\s*video|lyric\s*video|320\s*kbps|128\s*kbps|64\s*kbps|320kbps|128kbps|64kbps|320k|128k|slowed\s*\+\s*reverb|slowed\s*&\s*reverb|bass\s*boosted|pagalworld|songs\.pk|djpunjab|snaptube)\b',
    caseSensitive: false,
  );

  // Regex to remove track numbering at beginning (e.g. "01. ", "01 - ", "01_")
  static final RegExp _trackNumberPrefixRegExp = RegExp(
    r'^\s*(\d{1,3}[\.\-_\s]+)+',
  );

  // Regex to clean multiple separators and spaces
  static final RegExp _multipleSpacesRegExp = RegExp(r'\s+');

  // Separators commonly used in file and video names: " - ", " – ", " — ", " ~ ", " | ", " • ", " _-_ "
  static final RegExp _separatorRegExp = RegExp(r'\s+[\-–—~•]\s+|\s*\|\s*|\s+_-_+\s*');

  static bool hasSeparator(String text) => _separatorRegExp.hasMatch(text);

  // Curated list of known prominent artists (Bollywood, Punjabi, Pakistani, Indian, Global Pop/Rock/Hip-hop)
  static final Set<String> _knownArtists = {
    // Bollywood / Hindi / Urdu / Indian Pop & Classical
    'atif aslam', 'pritam', 'arijit singh', 'neha kakkar', 'tony kakkar', 'sonu kakkar',
    'shreya ghoshal', 'sonu nigam', 'sunidhi chauhan', 'mohit chauhan', 'jubin nautiyal',
    'badshah', 'honey singh', 'yo yo honey singh', 'guru randhawa', 'diljit dosanjh',
    'sidhu moosewala', 'sidhu moose wala', 'ap dhillon', 'karan aujla', 'b praak',
    'jasleen royal', 'amit trivedi', 'vishal dadlani', 'shekhar ravjiani',
    'vishal shekhar', 'vishal-shekhar', 'shankar mahadevan', 'shankar ehsaan loy',
    'shankar-ehsaan-loy', 'ar rahman', 'a.r. rahman', 'a r rahman', 'kumar sanu',
    'alka yagnik', 'udit narayan', 'kishore kumar', 'lata mangeshkar', 'mohammed rafi',
    'mohd rafi', 'asha bhosle', 'kk', 'k.k.', 'anuv jain', 'prateek kuhad',
    'darshan raval', 'armaan malik', 'amaal mallik', 'sachin jigar', 'sachin-jigar',
    'meet bros', 'tanishk bagchi', 'mithoon', 'himesh reshammiya', 'rahat fateh ali khan',
    'nusrat fateh ali khan', 'mika singh', 'sukhwinder singh', 'lucky ali', 'shaan',
    'javed ali', 'shilpa rao', 'jonita gandhi', 'monali thakur', 'benny dayal',
    'neeti mohan', 'papon', 'stebin ben', 'divine', 'mc stan', 'raftaar', 'ikka',
    'king', 'emiway bantai', 'seedhe maut', 'kr\$na', 'krsna', 'paradox', 'akhil sachdeva',
    'ankit tiwari', 'palak muchhal', 'tulsi kumar', 'dhvani bhanushali', 'shirley setia',
    'harrdy sandhu', 'jassie gill', 'ammy virk', 'parmish verma', 'sharry mann',
    'sharry maan', 'garry sandhu', 'jordan sandhu', 'mankirt aulakh', 'bilal saeed',
    'ali zafar', 'falak shabir', 'mustafa zahid', 'farhan saeed', 'ali sethi',
    'shae gill', 'asim azhar', 'young stunners', 'talha anjum', 'talhah yunus',
    'hasan raheem', 'abdul hannan', 'kaifi khalil', 'anirudh ravichander', 'anirudh',
    'sid sriram', 'harris jayaraj', 'yuvan shankar raja', 'ilaiyaraaja', 'ilayaraja',
    'devi sri prasad', 'dsp', 'thaman s', 'santhosh narayanan', 'm.m. keeravani',
    'mm keeravani', 'keeravani', 's.p. balasubrahmanyam', 'spb', 'k.j. yesudas',
    'hariharan', 'anuradha paudwal', 'sadhana sargam', 'kavita krishnamurthy',
    'hemant kumar', 'manna dey', 'mukesh', 'jagjit singh', 'ghulam ali', 'mehdi hassan',
    'pankaj udhas', 'bhupen hazarika', 'daler mehndi', 'sukh-e', 'sukhe', 'jass manak',
    'gurnam bhullar', 'amrit maan', 'kulwinder billa', 'bohemia', 'asees kaur',
    'parampara tandon', 'sachet tandon', 'sachet parampara', 'sachet-parampara',
    'nikhil d souza', 'nikhil d\'souza', 'shankar tucker', 'raghav chaitanya',
    'ash king', 'shashwat singh', 'vishal mishra', 'adnan sami', 'alisha chinai',
    'babul supriyo', 'himesh', 'amitabh bhattacharya', 'salim merchant',
    'sulaiman merchant', 'salim-sulaiman', 'sajid wajid', 'sajid-wajid',
    'anand milind', 'anand-milind', 'laxmikant pyarelal', 'rd burman',
    'r.d. burman', 'sd burman', 'r d burman', 's d burman',

    // Global / Western / International
    'the weeknd', 'taylor swift', 'drake', 'ed sheeran', 'justin bieber', 'billie eilish',
    'eminem', 'rihanna', 'ariana grande', 'bruno mars', 'dua lipa', 'post malone',
    'coldplay', 'imagine dragons', 'maroon 5', 'queen', 'the beatles', 'beatles',
    'michael jackson', 'adele', 'beyonce', 'beyoncé', 'katy perry', 'shawn mendes',
    'selena gomez', 'charlie puth', 'camila cabello', 'sia', 'alan walker', 'marshmello',
    'david guetta', 'calvin harris', 'avicii', 'the chainsmokers', 'chainsmokers',
    'kendrick lamar', 'j. cole', 'travis scott', 'kanye west', 'bts', 'blackpink',
    'lady gaga', 'shakira', 'pitbull', 'akon', 'linkin park', 'green day', 'nirvana',
    'metallica', 'ac/dc', 'guns n roses', 'guns n\' roses', 'pink floyd', 'led zeppelin',
    'bon jovi', 'aerosmith', 'red hot chili peppers', 'radiohead', 'u2', 'oasis',
    'arctic monkeys', 'twenty one pilots', 'one direction', 'zayn', 'zayn malik',
    'harry styles', 'niall horan', 'liam payne', 'louis tomlinson', 'sam smith',
    'khalid', 'sza', 'doja cat', 'megan thee stallion', 'cardi b', 'nicki minaj',
    'lil nas x', 'olivia rodrigo', 'sabrina carpenter', 'lana del rey', 'lorde',
    'halsey', 'bebe rexha', 'rita ora', 'ellie goulding', 'zara larsson', 'clean bandit',
    'kygo', 'martin garrix', 'dj snake', 'zedd', 'skrillex', 'diplo', 'major lazer',
    'robin schulz', 'alok', 'tiesto', 'tiësto', 'afrojack', 'hardwell', 'steve aoki',
    'deadmau5', 'daft punk', 'daddy yankee', 'luis fonsi', 'bad bunny', 'j balvin',
    'ozuna', 'maluma', 'rosalia', 'rosalía',
  };

  static final List<String> _sortedKnownArtists = _knownArtists.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  /// Checks if an artist field is a downloader watermark, generic placeholder or junk.
  static bool isJunkArtist(String? artist) {
    if (artist == null) return true;
    final lower = artist.trim().toLowerCase();
    if (lower.isEmpty ||
        lower == 'unknown' ||
        lower == 'unknown artist' ||
        lower == 'soundtrack' ||
        lower == 'audio' ||
        lower == 'track' ||
        lower == 'download' ||
        lower == 'downloads') {
      return true;
    }
    final junkSubstrings = [
      'snaptube',
      'pagalworld',
      'songs.pk',
      'djpunjab',
      'starmusiq',
      'masstamilan',
      'hungama',
      'gaana',
      'wynk',
      'jiosaavn',
      'audiotrack',
      'audio song',
      'full song',
      'official video',
      'music video',
      '320kbps',
      '128kbps',
      '64kbps',
      'www.',
      '.com',
      '.pk',
      '.in',
      '.net',
      '.org',
      '.is',
      '.co',
    ];
    for (final junk in junkSubstrings) {
      if (lower.contains(junk)) return true;
    }
    return false;
  }

  /// Identifies any known artists present within a text string.
  static List<String> findKnownArtistsInText(String text) {
    if (text.isEmpty) return const [];
    final lower = text.toLowerCase();
    final matched = <String>[];
    final matchedSpans = <(int, int)>[];

    for (final artist in _sortedKnownArtists) {
      int startIndex = 0;
      while (startIndex < lower.length) {
        final index = lower.indexOf(artist, startIndex);
        if (index == -1) break;

        final endIndex = index + artist.length;

        // Check word boundary before and after
        final bool validStart = index == 0 ||
            !RegExp(r'[a-zA-Z0-9]').hasMatch(lower[index - 1]);
        final bool validEnd = endIndex == lower.length ||
            !RegExp(r'[a-zA-Z0-9]').hasMatch(lower[endIndex]);

        if (validStart && validEnd) {
          final overlaps = matchedSpans.any((span) =>
              !(endIndex <= span.$1 || index >= span.$2));
          if (!overlaps) {
            matchedSpans.add((index, endIndex));
            final originalCase = text.substring(index, endIndex);
            matched.add(originalCase);
          }
        }
        startIndex = index + 1;
      }
    }
    return matched;
  }

  /// Calculates a heuristic score representing the likelihood that [text] is an artist name.
  static int calculateArtistScore(String text) {
    if (text.isEmpty) return 0;
    final lower = text.toLowerCase().trim();
    if (isJunkArtist(lower)) return -50;

    int score = 0;

    // Check for known artists (+15 per known artist matched)
    final matchedArtists = findKnownArtistsInText(text);
    score += matchedArtists.length * 15;

    // Artist keywords
    if (RegExp(r'\b(feat|ft|featuring|with)\b', caseSensitive: false).hasMatch(text)) {
      if (RegExp(r'\((feat|ft|featuring)\b', caseSensitive: false).hasMatch(text)) {
        score += 2;
      } else {
        score += 8;
      }
    }
    if (RegExp(r'\b(prod\.|prod by|produced by|music by|sung by|singer:?|vocal:?)\b', caseSensitive: false).hasMatch(text)) {
      score += 10;
    }
    // Multiple artist indicators like "Artist 1 & Artist 2" or "Artist 1, Artist 2"
    if (RegExp(r'[A-Za-z0-9]+\s*[,&xX+]\s*[A-Za-z0-9]+').hasMatch(text)) {
      score += 5;
    }
    if (RegExp(r'^(dj|mc|lil|dr\.)\s+', caseSensitive: false).hasMatch(text)) {
      score += 6;
    }

    // Title indicators that reduce artist likelihood
    if (RegExp(r'\b(remix|acoustic|lofi|lo-fi|cover|live|instrumental|reprise|mashup|soundtrack|ost|theme)\b', caseSensitive: false).hasMatch(text)) {
      score -= 8;
    }
    if (RegExp(r'^(tu|tum|tere|teri|mera|meri|dil|pyar|ishq|kabhi|hum|main|yeh|woh)\b', caseSensitive: false).hasMatch(text)) {
      score -= 5;
    }

    return score;
  }

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
    text = text.replaceAll(RegExp(r'''^[\s"'‘’“”\-\~:|]+|[\s"'‘’“”\-\~:|]+$'''), '').trim();

    // If whole string is wrapped in [...] or (...), strip outer container
    if (text.startsWith('[') && text.endsWith(']')) {
      text = text.substring(1, text.length - 1).trim();
    } else if (text.startsWith('(') && text.endsWith(')') && !text.substring(1, text.length - 1).contains('(')) {
      text = text.substring(1, text.length - 1).trim();
    }
    return text.replaceAll(RegExp(r'''^[\s"'‘’“”\-\~:|]+|[\s"'‘’“”\-\~:|]+$'''), '').trim();
  }

  /// Disambiguates Title and Artist, swapping them if reversed and separating trailing movie/album names.
  static SanitizedTrackInfo disambiguateTitleAndArtist({
    required String title,
    required String artist,
    String? album,
  }) {
    var cleanT = cleanText(title);
    var cleanA = cleanText(artist);
    var cleanAlb = album != null && album.isNotEmpty ? cleanText(album) : null;

    if (isJunkArtist(cleanA)) {
      cleanA = '';
    }

    // 1. If title contains a separator and artist is empty, parse from title
    if (cleanT.isNotEmpty && hasSeparator(cleanT) && cleanA.isEmpty) {
      final parsed = parseFileName(cleanT, fallbackAlbum: cleanAlb);
      cleanT = parsed.title;
      cleanA = parsed.artist;
      if (parsed.album != null && (cleanAlb == null || cleanAlb.isEmpty || cleanAlb == 'Local Audio')) {
        cleanAlb = parsed.album;
      }
    }

    // 2. Check if title and artist are reversed
    final titleArtistScore = calculateArtistScore(cleanT);
    final artistScore = calculateArtistScore(cleanA);

    final titleKnown = findKnownArtistsInText(cleanT);
    final artistKnown = findKnownArtistsInText(cleanA);

    final shouldSwap = (titleKnown.isNotEmpty && artistKnown.isEmpty) ||
        (titleArtistScore >= 10 && artistScore <= 0) ||
        (titleArtistScore - artistScore >= 12);

    if (shouldSwap && cleanA.isNotEmpty && cleanA.toLowerCase() != 'unknown artist') {
      final temp = cleanT;
      cleanT = cleanA;
      cleanA = temp;
    }

    // 3. Post-process artist if it contains known artists and trailing movie/album text
    if (cleanA.isNotEmpty) {
      final known = findKnownArtistsInText(cleanA);
      if (known.isNotEmpty) {
        final refined = _extractArtistsAndTrailingAlbum(cleanA, known);
        cleanA = refined.artist;
        if (refined.album != null && (cleanAlb == null || cleanAlb.isEmpty || cleanAlb == 'Local Audio')) {
          cleanAlb = refined.album;
        }
      }
    }

    if (cleanT.isEmpty) cleanT = 'Untitled Audio';
    if (cleanA.isEmpty) cleanA = 'Unknown Artist';

    return SanitizedTrackInfo(
      title: cleanT,
      artist: cleanA,
      album: cleanAlb,
    );
  }

  static ({String artist, String? album}) _extractArtistsAndTrailingAlbum(
    String artistText,
    List<String> knownArtists,
  ) {
    if (knownArtists.isEmpty) {
      return (artist: cleanText(artistText), album: null);
    }

    final formattedArtists = knownArtists.join(', ');

    var remaining = artistText;
    for (final a in knownArtists) {
      remaining = remaining.replaceAll(RegExp(RegExp.escape(a), caseSensitive: false), ' ');
    }

    remaining = cleanText(remaining);
    remaining = remaining.replaceAll(RegExp(r'''^[\s,&xX+\-\~:|]+|[\s,&xX+\-\~:|]+$'''), '').trim();

    if (remaining.isNotEmpty &&
        remaining.length >= 3 &&
        !isJunkArtist(remaining) &&
        !RegExp(r'^(feat|ft|featuring|prod|with|and)$', caseSensitive: false).hasMatch(remaining)) {
      return (artist: formattedArtists, album: remaining);
    }

    return (artist: formattedArtists, album: null);
  }

  /// Intelligently parses a filename and optional folder context into a clean Song Title, Artist, and Album.
  static SanitizedTrackInfo parseFileName(
    String rawFileName, {
    String? folderName,
    String? fallbackArtist,
    String? fallbackAlbum,
  }) {
    var baseName = cleanText(rawFileName);

    // Remove leading track numbers e.g. "01. Song" -> "Song"
    baseName = baseName.replaceAll(_trackNumberPrefixRegExp, '').trim();

    String title = baseName;
    String artist = fallbackArtist ?? 'Unknown Artist';
    String? album = fallbackAlbum;

    final parts = baseName
        .split(_separatorRegExp)
        .map((p) => cleanText(p))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      if (parts.length == 2) {
        final part1 = parts[0];
        final part2 = parts[1];

        final part1Score = calculateArtistScore(part1);
        final part2Score = calculateArtistScore(part2);

        final part1HasFeatInParens =
            RegExp(r'\((feat|ft|featuring)\b', caseSensitive: false).hasMatch(part1);
        final part2HasFeatInParens =
            RegExp(r'\((feat|ft|featuring)\b', caseSensitive: false).hasMatch(part2);

        if (part1HasFeatInParens && !part2HasFeatInParens) {
          title = part1;
          artist = part2;
        } else if (part2HasFeatInParens && !part1HasFeatInParens) {
          title = part2;
          artist = part1;
        } else if (part2Score > part1Score) {
          title = part1;
          artist = part2;
        } else if (part1Score > part2Score) {
          artist = part1;
          title = part2;
        } else {
          // Standard default convention: "Artist - Title"
          artist = part1;
          title = part2;
        }
      } else {
        // 3 or more parts: e.g. ["Tu Chahiye", "Bajrangi Bhaijaan", "Atif Aslam"]
        int bestArtistIdx = 0;
        int highestArtistScore = -999;
        for (int i = 0; i < parts.length; i++) {
          final s = calculateArtistScore(parts[i]);
          if (s > highestArtistScore) {
            highestArtistScore = s;
            bestArtistIdx = i;
          }
        }

        artist = parts[bestArtistIdx];
        final remainingParts = <String>[];
        for (int i = 0; i < parts.length; i++) {
          if (i != bestArtistIdx) remainingParts.add(parts[i]);
        }

        title = remainingParts.first;
        if (remainingParts.length > 1 &&
            (album == null || album.isEmpty || album == 'Local Audio')) {
          album = remainingParts[1];
        }
      }
    } else {
      // No separator in filename. Check for "Song (Artist)" or "Artist (Song)" pattern
      final bracketMatch =
          RegExp(r'^(.*?)\s*[\(\[]([^\)\]]+)[\)\]]\s*$').firstMatch(baseName);
      if (bracketMatch != null) {
        final outside = cleanText(bracketMatch.group(1)!);
        final inside = cleanText(bracketMatch.group(2)!);
        final insideScore = calculateArtistScore(inside);
        final outsideScore = calculateArtistScore(outside);

        if (insideScore >= 10 && outsideScore < insideScore) {
          title = outside;
          artist = inside;
        } else if (outsideScore >= 10 && insideScore < outsideScore) {
          artist = outside;
          title = inside;
        }
      }

      if (artist == 'Unknown Artist' &&
          folderName != null &&
          _isValidArtistFolderName(folderName)) {
        artist = cleanText(folderName);
      }
    }

    return disambiguateTitleAndArtist(
      title: title,
      artist: artist,
      album: album,
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
