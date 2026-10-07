import 'package:musify/domain/models/search_result_models.dart';
import 'package:musify/domain/models/track.dart';

/// Represents a top chart (e.g. JioSaavn Weekly Top 50, Viral Hits).
class TopChartItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? count;
  final String? badge;
  final List<Track> sampleTracks;

  const TopChartItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.count,
    this.badge,
    this.sampleTracks = const [],
  });
}

/// Represents a mood or activity category (e.g. Lo-Fi Chill, Workout, Focus).
class MoodCategory {
  final String id;
  final String title;
  final String subtitle;
  final String query;
  final List<int> gradientColors; // 0xFF... hex integers
  final String iconName;

  const MoodCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.gradientColors,
    this.iconName = 'music',
  });
}

/// Represents complete details of an online streamed playlist / chart.
class StreamPlaylistDetails {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String? followerCount;
  final int songCount;
  final List<Track> songs;

  const StreamPlaylistDetails({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.followerCount,
    this.songCount = 0,
    this.songs = const [],
  });
}

/// Generic container for dynamic JioSaavn home modules.
class HomepageModule {
  final String id;
  final String title;
  final String? subtitle;
  final String type; // 'songs', 'albums', 'playlists', 'artists', 'charts'
  final List<dynamic> items;

  const HomepageModule({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    this.items = const [],
  });
}

/// Comprehensive streaming home screen data bundle.
class StreamHomepageData {
  final List<Track> quickPicks;
  final List<Track> recentlyPlayed;
  final List<Track> trendingTracks;
  final List<SearchAlbumItem> newReleases;
  final List<SearchArtistItem> popularArtists;
  final List<SearchAlbumItem> movieAlbums;
  final List<TopChartItem> topCharts;
  final List<MoodCategory> moodCategories;
  final List<SearchPlaylistItem> editorialPlaylists;
  final List<HomepageModule> modules;
  final DateTime fetchedAt;

  StreamHomepageData({
    this.quickPicks = const [],
    this.recentlyPlayed = const [],
    this.trendingTracks = const [],
    this.newReleases = const [],
    this.popularArtists = const [],
    this.movieAlbums = const [],
    this.topCharts = const [],
    this.moodCategories = const [],
    this.editorialPlaylists = const [],
    this.modules = const [],
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  bool get isEmpty =>
      quickPicks.isEmpty &&
      recentlyPlayed.isEmpty &&
      trendingTracks.isEmpty &&
      newReleases.isEmpty &&
      popularArtists.isEmpty &&
      movieAlbums.isEmpty &&
      topCharts.isEmpty &&
      editorialPlaylists.isEmpty;

  bool get isNotEmpty => !isEmpty;
}
