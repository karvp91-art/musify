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

    test('Parses Title - Artist format correctly for Indian / Bollywood songs', () {
      final parsed = AudioNameSanitizer.parseFileName(
        'Tu Chahiye - Atif Aslam Pritam Bajrangi Bhaijaan',
      );
      expect(parsed.title, 'Tu Chahiye');
      expect(parsed.artist, 'Atif Aslam, Pritam');
      expect(parsed.album, 'Bajrangi Bhaijaan');
    });

    test('Resolves reverse ordering Title - Artist without feat tags', () {
      final parsed = AudioNameSanitizer.parseFileName(
        'Tum Hi Ho - Arijit Singh',
      );
      expect(parsed.title, 'Tum Hi Ho');
      expect(parsed.artist, 'Arijit Singh');
    });

    test('Parses Title - Artist format with feat correctly', () {
      final parsed = AudioNameSanitizer.parseFileName(
        'Despacito (feat. Daddy Yankee) - Luis Fonsi',
      );
      expect(parsed.title, 'Despacito (feat. Daddy Yankee)');
      expect(parsed.artist, 'Luis Fonsi');
    });

    test('Parses 3-part multi-delimiter string (Title | Album | Artist)', () {
      final parsed = AudioNameSanitizer.parseFileName(
        'Tu Chahiye | Bajrangi Bhaijaan | Atif Aslam',
      );
      expect(parsed.title, 'Tu Chahiye');
      expect(parsed.artist, 'Atif Aslam');
      expect(parsed.album, 'Bajrangi Bhaijaan');
    });

    test('Disambiguates and fixes swapped ID3 tags', () {
      final disambiguated = AudioNameSanitizer.disambiguateTitleAndArtist(
        title: 'Atif Aslam Pritam Bajrangi Bhaijaan',
        artist: 'Tu Chahiye',
      );
      expect(disambiguated.title, 'Tu Chahiye');
      expect(disambiguated.artist, 'Atif Aslam, Pritam');
      expect(disambiguated.album, 'Bajrangi Bhaijaan');
    });

    test('Identifies and discards junk downloader artists', () {
      expect(AudioNameSanitizer.isJunkArtist('SnapTube Audio'), isTrue);
      expect(AudioNameSanitizer.isJunkArtist('PagalWorld.com'), isTrue);
      expect(AudioNameSanitizer.isJunkArtist('www.Songs.pk'), isTrue);
      expect(AudioNameSanitizer.isJunkArtist('Unknown Artist'), isTrue);
      expect(AudioNameSanitizer.isJunkArtist('Atif Aslam'), isFalse);
    });

    test('Disambiguates ID3 title with separator when artist is junk downloader tag', () {
      final disambiguated = AudioNameSanitizer.disambiguateTitleAndArtist(
        title: 'Tu Chahiye - Atif Aslam',
        artist: 'SnapTube Audio',
      );
      expect(disambiguated.title, 'Tu Chahiye');
      expect(disambiguated.artist, 'Atif Aslam');
    });

    test('Parses bracketed artist when no hyphen separator exists', () {
      final parsed = AudioNameSanitizer.parseFileName(
        'Tu Chahiye (Atif Aslam)',
      );
      expect(parsed.title, 'Tu Chahiye');
      expect(parsed.artist, 'Atif Aslam');
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
