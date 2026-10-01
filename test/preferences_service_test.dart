import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/track_sort_option.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/services/audio_player_handler.dart';
import 'package:musify/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesService Tests', () {
    late SharedPreferences prefs;
    late PreferencesService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = PreferencesService(prefs);
    });

    test('Initial default theme preference is dark', () {
      expect(service.getThemePreference(), AppThemePreference.dark);
    });

    test('Setting and getting theme preference persists correctly', () async {
      await service.setThemePreference(AppThemePreference.light);
      expect(service.getThemePreference(), AppThemePreference.light);

      await service.setThemePreference(AppThemePreference.autoTime);
      expect(service.getThemePreference(), AppThemePreference.autoTime);

      await service.setThemePreference(AppThemePreference.system);
      expect(service.getThemePreference(), AppThemePreference.system);

      await service.setThemePreference(AppThemePreference.dark);
      expect(service.getThemePreference(), AppThemePreference.dark);
    });

    test('Default day and night schedule times are 06:00 and 18:00', () {
      final day = service.getDayStartTime();
      final night = service.getNightStartTime();

      expect(day.hour, 6);
      expect(day.minute, 0);
      expect(night.hour, 18);
      expect(night.minute, 0);
    });

    test('Custom day and night schedule times persist correctly', () async {
      await service.setDayStartTime(const TimeOfDay(hour: 7, minute: 30));
      await service.setNightStartTime(const TimeOfDay(hour: 19, minute: 45));

      final day = service.getDayStartTime();
      final night = service.getNightStartTime();

      expect(day.hour, 7);
      expect(day.minute, 30);
      expect(night.hour, 19);
      expect(night.minute, 45);
    });

    test('isDayTime accurately calculates day vs night for standard schedule', () {
      final day = const TimeOfDay(hour: 6, minute: 0);
      final night = const TimeOfDay(hour: 18, minute: 0);

      // 05:59 AM -> Night
      expect(
        service.isDayTime(time: DateTime(2026, 1, 1, 5, 59), dayStart: day, nightStart: night),
        isFalse,
      );

      // 06:00 AM -> Day
      expect(
        service.isDayTime(time: DateTime(2026, 1, 1, 6, 0), dayStart: day, nightStart: night),
        isTrue,
      );

      // 12:30 PM -> Day
      expect(
        service.isDayTime(time: DateTime(2026, 1, 1, 12, 30), dayStart: day, nightStart: night),
        isTrue,
      );

      // 17:59 PM -> Day
      expect(
        service.isDayTime(time: DateTime(2026, 1, 1, 17, 59), dayStart: day, nightStart: night),
        isTrue,
      );

      // 18:00 PM -> Night
      expect(
        service.isDayTime(time: DateTime(2026, 1, 1, 18, 0), dayStart: day, nightStart: night),
        isFalse,
      );

      // 23:45 PM -> Night
      expect(
        service.isDayTime(time: DateTime(2026, 1, 1, 23, 45), dayStart: day, nightStart: night),
        isFalse,
      );

      // 02:00 AM -> Night
      expect(
        service.isDayTime(time: DateTime(2026, 1, 1, 2, 0), dayStart: day, nightStart: night),
        isFalse,
      );
    });

    test('isDayTime supports cross-midnight inverted schedule', () {
      // Inverted: Daytime is 20:00 to 06:00
      final day = const TimeOfDay(hour: 20, minute: 0);
      final night = const TimeOfDay(hour: 6, minute: 0);

      // 21:00 -> Day
      expect(
        service.isDayTime(time: DateTime(2026, 1, 1, 21, 0), dayStart: day, nightStart: night),
        isTrue,
      );

      // 02:00 -> Day
      expect(
        service.isDayTime(time: DateTime(2026, 1, 1, 2, 0), dayStart: day, nightStart: night),
        isTrue,
      );

      // 12:00 -> Night
      expect(
        service.isDayTime(time: DateTime(2026, 1, 1, 12, 0), dayStart: day, nightStart: night),
        isFalse,
      );
    });

    test('resolveThemeMode maps correctly for all preferences', () {
      expect(service.resolveThemeMode(AppThemePreference.light), ThemeMode.light);
      expect(service.resolveThemeMode(AppThemePreference.dark), ThemeMode.dark);
      expect(service.resolveThemeMode(AppThemePreference.system), ThemeMode.system);

      // Auto: during daytime -> Light, during nighttime -> Dark
      final noon = DateTime(2026, 1, 1, 12, 0);
      final midnight = DateTime(2026, 1, 1, 0, 0);

      expect(
        service.resolveThemeMode(AppThemePreference.autoTime, time: noon),
        ThemeMode.light,
      );
      expect(
        service.resolveThemeMode(AppThemePreference.autoTime, time: midnight),
        ThemeMode.dark,
      );
    });

    test('TrackSortOption persists and defaults to recentlyAdded', () async {
      expect(service.getTrackSortOption(), TrackSortOption.recentlyAdded);

      await service.setTrackSortOption(TrackSortOption.titleAsc);
      expect(service.getTrackSortOption(), TrackSortOption.titleAsc);

      await service.setTrackSortOption(TrackSortOption.mostPlayed);
      expect(service.getTrackSortOption(), TrackSortOption.mostPlayed);

      await service.setTrackSortOption(TrackSortOption.artistAsc);
      expect(service.getTrackSortOption(), TrackSortOption.artistAsc);
    });

    test('Shuffle and repeat modes persist and load correctly', () async {
      // Defaults
      expect(service.getShuffleMode(), isFalse);
      expect(service.getRepeatMode(), AppRepeatMode.off);

      // Update shuffle
      await service.setShuffleMode(true);
      expect(service.getShuffleMode(), isTrue);

      // Update repeat
      await service.setRepeatMode(AppRepeatMode.all);
      expect(service.getRepeatMode(), AppRepeatMode.all);

      await service.setRepeatMode(AppRepeatMode.one);
      expect(service.getRepeatMode(), AppRepeatMode.one);
    });

    test('Generic key-value helpers work correctly', () async {
      await service.setString('sample_key', 'sample_val');
      expect(service.getString('sample_key'), 'sample_val');

      await service.setInt('count_key', 42);
      expect(service.getInt('count_key'), 42);

      await service.setBool('bool_key', true);
      expect(service.getBool('bool_key'), isTrue);

      await service.remove('sample_key');
      expect(service.getString('sample_key'), isNull);
    });

    test('Works gracefully with in-memory fallback when SharedPreferences is null', () async {
      final fallbackService = PreferencesService(null);

      expect(fallbackService.getThemePreference(), AppThemePreference.dark);
      expect(fallbackService.getTrackSortOption(), TrackSortOption.recentlyAdded);
      expect(fallbackService.getShuffleMode(), isFalse);
      expect(fallbackService.getRepeatMode(), AppRepeatMode.off);

      await fallbackService.setTrackSortOption(TrackSortOption.durationDesc);
      expect(fallbackService.getTrackSortOption(), TrackSortOption.durationDesc);

      await fallbackService.setShuffleMode(true);
      expect(fallbackService.getShuffleMode(), isTrue);

      await fallbackService.setRepeatMode(AppRepeatMode.one);
      expect(fallbackService.getRepeatMode(), AppRepeatMode.one);

      await fallbackService.setString('test', 'fallback_val');
      expect(fallbackService.getString('test'), 'fallback_val');
    });
  });

  group('Providers & Playback Integration Tests', () {
    test('themePreferenceProvider and themeModeProvider sync seamlessly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Initially dark
      expect(container.read(themePreferenceProvider), AppThemePreference.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      // Switch to light
      await container.read(themePreferenceProvider.notifier).setPreference(AppThemePreference.light);
      expect(container.read(themePreferenceProvider), AppThemePreference.light);
      expect(container.read(themeModeProvider), ThemeMode.light);

      // Toggle theme
      await container.read(themeModeProvider.notifier).toggleTheme();
      expect(container.read(themePreferenceProvider), AppThemePreference.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      // Switch to Auto
      await container.read(themePreferenceProvider.notifier).setPreference(AppThemePreference.autoTime);
      expect(container.read(themePreferenceProvider), AppThemePreference.autoTime);
      // Resolved theme will match current hour of day
      final currentIsDay = container.read(preferencesServiceProvider).isDayTime();
      expect(container.read(themeModeProvider), currentIsDay ? ThemeMode.light : ThemeMode.dark);
    });

    test('localTrackSortOptionProvider initializes from preferences and persists changes', () async {
      SharedPreferences.setMockInitialValues({
        'track_sort_option': 'titleAsc',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Should load 'titleAsc' from SharedPreferences
      expect(container.read(localTrackSortOptionProvider), TrackSortOption.titleAsc);

      // Change to 'mostPlayed'
      await container.read(localTrackSortOptionProvider.notifier).setSortOption(TrackSortOption.mostPlayed);
      expect(container.read(localTrackSortOptionProvider), TrackSortOption.mostPlayed);

      // Verify it was written to SharedPreferences
      expect(prefs.getString('track_sort_option'), 'mostPlayed');
    });

    test('MusifyAudioHandler initializes with persisted shuffle and repeat modes and saves changes', () async {
      SharedPreferences.setMockInitialValues({
        'playback_shuffle_mode': true,
        'playback_repeat_mode': 'all',
      });
      final prefs = await SharedPreferences.getInstance();
      final preferencesService = PreferencesService(prefs);

      final handler = MusifyAudioHandler(preferencesService: preferencesService);
      addTearDown(handler.dispose);

      // Verify loaded from preferences
      expect(handler.isShuffle, isTrue);
      expect(handler.repeatMode, AppRepeatMode.all);

      // Toggle shuffle -> should now be false and written to prefs
      handler.toggleShuffle();
      expect(handler.isShuffle, isFalse);
      expect(preferencesService.getShuffleMode(), isFalse);
      expect(prefs.getBool('playback_shuffle_mode'), isFalse);

      // Cycle repeat -> was all, becomes one
      handler.cycleRepeatMode();
      expect(handler.repeatMode, AppRepeatMode.one);
      expect(preferencesService.getRepeatMode(), AppRepeatMode.one);
      expect(prefs.getString('playback_repeat_mode'), 'one');
    });
  });
}
