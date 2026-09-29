import 'package:flutter_test/flutter_test.dart';
import 'package:musify/core/utils/lrc_parser.dart';
import 'package:musify/domain/models/lyrics.dart';

void main() {
  group('LrcParser Tests', () {
    test('Parses standard LRC timestamps correctly', () {
      const lrcContent = '''
[00:05.50] First line of the song
[00:12.80] Second line follows
[01:05.12] Chorus kicks in here
''';

      final lines = LrcParser.parseLrc(lrcContent);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals('First line of the song'));
      expect(lines[0].timestamp, equals(const Duration(seconds: 5, milliseconds: 500)));

      expect(lines[1].text, equals('Second line follows'));
      expect(lines[1].timestamp, equals(const Duration(seconds: 12, milliseconds: 800)));

      expect(lines[2].text, equals('Chorus kicks in here'));
      expect(lines[2].timestamp, equals(const Duration(minutes: 1, seconds: 5, milliseconds: 120)));
    });

    test('Ignores metadata tags and empty lines', () {
      const lrcContent = '''
[ti:Kesariya]
[ar:Arijit Singh]
[al:Brahmastra]

[00:15.00] Mujhko itna bataye koi
[00:22.00] Kaise tujhse dil na lagaye koi
''';

      final lines = LrcParser.parseLrc(lrcContent);
      expect(lines.length, equals(2));
      expect(lines[0].text, equals('Mujhko itna bataye koi'));
      expect(lines[1].text, equals('Kaise tujhse dil na lagaye koi'));
    });

    test('Parses HTML <br> separated plain lyrics correctly', () {
      const plainHtml = 'Ishq Mein Dil Banna Hai<br>Ishq Mein Dil Fanna Hai Ho Ho<br><br>Mita De Ya Bana De';
      final lines = LrcParser.parsePlain(plainHtml);

      expect(lines.length, equals(3));
      expect(lines[0].text, equals('Ishq Mein Dil Banna Hai'));
      expect(lines[1].text, equals('Ishq Mein Dil Fanna Hai Ho Ho'));
      expect(lines[2].text, equals('Mita De Ya Bana De'));
    });

    test('Unescapes HTML entities in plain lyrics', () {
      const plainHtml = 'Lost &amp; Found<br>&quot;Hello World&quot;<br>It&#039;s mine';
      final lines = LrcParser.parsePlain(plainHtml);

      expect(lines.length, equals(3));
      expect(lines[0].text, equals('Lost & Found'));
      expect(lines[1].text, equals('"Hello World"'));
      expect(lines[2].text, equals("It's mine"));
    });
  });

  group('Lyrics Model Tests', () {
    test('findCurrentLineIndex finds correct active line for playback position', () {
      const lyrics = Lyrics(
        trackId: 'test_1',
        plainLyrics: 'Line 1\nLine 2\nLine 3',
        isSynced: true,
        lines: [
          LyricLine(timestamp: Duration(seconds: 10), text: 'Line 1'),
          LyricLine(timestamp: Duration(seconds: 20), text: 'Line 2'),
          LyricLine(timestamp: Duration(seconds: 30), text: 'Line 3'),
        ],
      );

      // Before first line
      expect(lyrics.findCurrentLineIndex(const Duration(seconds: 5)), equals(0));

      // At first line
      expect(lyrics.findCurrentLineIndex(const Duration(seconds: 10)), equals(0));
      expect(lyrics.findCurrentLineIndex(const Duration(seconds: 15)), equals(0));

      // At second line
      expect(lyrics.findCurrentLineIndex(const Duration(seconds: 20)), equals(1));
      expect(lyrics.findCurrentLineIndex(const Duration(seconds: 25)), equals(1));

      // At third line
      expect(lyrics.findCurrentLineIndex(const Duration(seconds: 30)), equals(2));
      expect(lyrics.findCurrentLineIndex(const Duration(seconds: 45)), equals(2));
    });

    test('findCurrentLineIndex returns -1 for unsynced lyrics', () {
      const lyrics = Lyrics(
        trackId: 'test_2',
        plainLyrics: 'Plain text',
        isSynced: false,
        lines: [LyricLine(timestamp: Duration.zero, text: 'Plain text')],
      );

      expect(lyrics.findCurrentLineIndex(const Duration(seconds: 10)), equals(-1));
    });
  });
}
