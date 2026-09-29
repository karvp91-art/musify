class AppConstants {
  static const String appName = 'Musify';
  static const String appTagline = 'Minimalist, clutter-free music';

  // Audio Playback
  static const int defaultCrossfadeSeconds = 0;
  static const Duration defaultSeekInterval = Duration(seconds: 10);
  static const Duration debounceSearchDuration = Duration(milliseconds: 300);

  // Storage & Caching
  static const String localAudioDirectory = 'musify_downloads';
  static const int maxRecentSearches = 20;
  static const int maxQueuePersistence = 500;

  // Jamendo Catalog API
  static const String jamendoClientId = '56d30c95';
  static const String jamendoApiBase = 'https://api.jamendo.com/v3.0';

  // Notification Channel
  static const String audioChannelId = 'com.example.musify.audio';
  static const String audioChannelName = 'Musify Audio Playback';
  static const String audioChannelDescription = 'Notification channel for Musify background music playback';
}
