import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/online_artwork_enricher.dart';

void main() {
  group('OnlineArtworkEnricher Unit Tests', () {
    test('cleanTitleForSearch strips file extensions and junk bracketed modifiers', () {
      expect(
        OnlineArtworkEnricher.cleanTitleForSearch('Shape Of You (Official Audio).mp3'),
        'Shape Of You',
      );
      expect(
        OnlineArtworkEnricher.cleanTitleForSearch('Blinding Lights [Slowed + Reverb].flac'),
        'Blinding Lights',
      );
      expect(
        OnlineArtworkEnricher.cleanTitleForSearch('Mockingbird (Remix) #trending.m4a'),
        'Mockingbird',
      );
      expect(
        OnlineArtworkEnricher.cleanTitleForSearch('Stay (Sped Up Version).wav'),
        'Stay',
      );
    });

    test('computeSimilarity correctly measures text similarity', () {
      expect(OnlineArtworkEnricher.computeSimilarity('Shape of You', 'Shape of You'), 1.0);
      expect(OnlineArtworkEnricher.computeSimilarity('Shape of You', 'Shape of You (Deluxe)'), greaterThanOrEqualTo(0.85));
      expect(OnlineArtworkEnricher.computeSimilarity('Shape of You', 'Photograph'), lessThan(0.2));
      expect(OnlineArtworkEnricher.computeSimilarity('', 'Ed Sheeran'), 0.0);
    });

    test('calculateConfidence scores high for authentic matches with duration', () {
      final score = OnlineArtworkEnricher.calculateConfidence(
        localTitle: 'Shape of You',
        localArtist: 'Ed Sheeran',
        localDurationMs: 233713,
        candTitle: 'Shape of You',
        candArtist: 'Ed Sheeran',
        candDurationMs: 235000, // within 2 seconds
      );

      expect(score, greaterThanOrEqualTo(0.90));
    });

    test('calculateConfidence penalizes mismatched durations heavily', () {
      final score = OnlineArtworkEnricher.calculateConfidence(
        localTitle: 'Shape of You',
        localArtist: 'Ed Sheeran',
        localDurationMs: 233713,
        candTitle: 'Shape of You',
        candArtist: 'Ed Sheeran',
        candDurationMs: 120000, // 2 minutes shorter (preview or teaser)
      );

      // Even though title and artist match, duration mismatch incurs penalty
      expect(score, lessThan(0.80));
    });

    test('calculateConfidence handles unknown local artists safely', () {
      final scoreMatch = OnlineArtworkEnricher.calculateConfidence(
        localTitle: 'Stay',
        localArtist: 'Unknown Artist',
        localDurationMs: 140000,
        candTitle: 'Stay',
        candArtist: 'The Kid LAROI',
        candDurationMs: 141000,
      );

      // Title matches and duration matches closely
      expect(scoreMatch, greaterThanOrEqualTo(0.85));

      final scoreMismatch = OnlineArtworkEnricher.calculateConfidence(
        localTitle: 'Stay',
        localArtist: 'Unknown Artist',
        localDurationMs: 140000,
        candTitle: 'Stay',
        candArtist: 'Rihanna',
        candDurationMs: 240000, // 100 seconds difference!
      );

      // Duration penalty prevents wrong auto-assignment
      expect(scoreMismatch, lessThan(0.75));
    });

    test('ArtworkCandidate holds metadata accurately', () {
      const candidate = ArtworkCandidate(
        imageUrl: 'https://example.com/cover.jpg',
        title: 'Starboy',
        artistName: 'The Weeknd',
        albumName: 'Starboy',
        source: 'Apple Music',
        durationMs: 230000,
        confidenceScore: 0.95,
        isDurationMatch: true,
      );

      expect(candidate.source, 'Apple Music');
      expect(candidate.confidenceScore, 0.95);
      expect(candidate.isDurationMatch, true);
    });
  });
}
