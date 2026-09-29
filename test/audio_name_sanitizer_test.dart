import 'package:flutter_test/flutter_test.dart';
import 'package:musify/core/utils/audio_name_sanitizer.dart';

void main() {
  group('AudioNameSanitizer Tests', () {
    test('Cleans downloader noise and website tags', () {
      final input = '[PagalWorld.com] Kesariya - Brahmastra _ Full AUDIO Song _ 320kbps';
      final clean = AudioNameSanitizer.cleanText(input);
      expect(clean.contains('PagalWorld'), isFalse);
      expect(clean.contains('320kbps'), isFalse);
      expect(clean.contains('Full AUDIO Song'), isFalse);
      expect(clean.contains('_'), isFalse);
    });

    test('Parses Artist - Title format correctly', () {
      final parsed = AudioNameSanitizer.parseFileName(
        'Arijit Singh - Tum Hi Ho [Official Music Video]',
      );
      expect(parsed.artist, 'Arijit Singh');
      expect(parsed.title, 'Tum Hi Ho');
    });

    test('Parses Title - Artist format with feat correctly', () {
      final parsed = AudioNameSanitizer.parseFileName(
        'Despacito (feat. Daddy Yankee) - Luis Fonsi',
      );
      expect(parsed.title, 'Despacito (feat. Daddy Yankee)');
      expect(parsed.artist, 'Luis Fonsi');
    });

    test('Strips leading track numbers from filename', () {
      final parsed = AudioNameSanitizer.parseFileName(
        '01. Imagine Dragons - Believer [Lyrics]',
      );
      expect(parsed.artist, 'Imagine Dragons');
      expect(parsed.title, 'Believer');
    });

    test('Uses valid parent directory name as artist when filename has no artist', () {
      final parsed = AudioNameSanitizer.parseFileName(
        'Yellow_320kbps',
        folderName: 'Coldplay',
      );
      expect(parsed.title, 'Yellow');
      expect(parsed.artist, 'Coldplay');
    });

    test('Does not use generic system folder names (Download, Music) as artist', () {
      final parsed = AudioNameSanitizer.parseFileName(
        'Shape of You',
        folderName: 'Download',
      );
      expect(parsed.title, 'Shape of You');
      expect(parsed.artist, 'Unknown Artist');
    });

    test('Handles multiple underscores and quotes', () {
      final parsed = AudioNameSanitizer.parseFileName(
        '"Ed_Sheeran_-_Perfect_Official_Video_Song"',
      );
      expect(parsed.artist, 'Ed Sheeran');
      expect(parsed.title, 'Perfect');
    });
  });
}
