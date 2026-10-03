import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/track_sort_option.dart';

enum AppThemePreference {
  system,
  light,
  dark,
  autoTime;

  static AppThemePreference fromString(String? value) {
    switch (value) {
      case 'system':
        return AppThemePreference.system;
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      case 'autoTime':
      case 'auto':
        return AppThemePreference.autoTime;
      default:
        return AppThemePreference.dark;
    }
  }

  String toPrefString() => name;

  String get displayName {
    switch (this) {
      case AppThemePreference.system:
        return 'System Default';
      case AppThemePreference.light:
        return 'Light Mode';
      case AppThemePreference.dark:
        return 'Dark Mode';
      case AppThemePreference.autoTime:
        return 'Auto (Time-based)';
    }
  }

  String get subtitle {
    switch (this) {
      case AppThemePreference.system:
        return 'Follows your device system theme';
      case AppThemePreference.light:
        return 'Always use crisp light appearance';
      case AppThemePreference.dark:
        return 'Always use obsidian dark appearance';
      case AppThemePreference.autoTime:
        return 'Light during the day, Dark at night';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemePreference.system:
        return Icons.brightness_auto_rounded;
      case AppThemePreference.light:
        return Icons.light_mode_rounded;
      case AppThemePreference.dark:
        return Icons.dark_mode_rounded;
      case AppThemePreference.autoTime:
        return Icons.schedule_rounded;
    }
  }
}

class PreferencesService {
  final SharedPreferences? _prefs;
  final Map<String, Object> _fallbackStorage = {};

  PreferencesService([this._prefs]);

  static const String keyThemePreference = 'app_theme_preference';
  static const String keyDayStartHour = 'theme_day_start_hour';
  static const String keyDayStartMinute = 'theme_day_start_minute';
  static const String keyNightStartHour = 'theme_night_start_hour';
  static const String keyNightStartMinute = 'theme_night_start_minute';

  static const String keyTrackSortOption = 'track_sort_option';
  static const String keyShuffleMode = 'playback_shuffle_mode';
  static const String keyRepeatMode = 'playback_repeat_mode';
  static const String keyHasScannedStorage = 'has_scanned_storage';

  // Audio Playback & Quality Keys
  static const String keyCrossfadeDuration = 'playback_crossfade_duration';
  static const String keyGaplessPlayback = 'playback_gapless_enabled';
  static const String keyAudioQuality = 'audio_streaming_quality';

  // Equalizer Keys
  static const String keyEqualizerEnabled = 'equalizer_enabled';
  static const String keyEqualizerPreset = 'equalizer_preset';
  static const String keyEqualizerGains = 'equalizer_band_gains';
  static const String keyEqualizerBassBoost = 'equalizer_bass_boost';
  static const String keyEqualizerVirtualizer = 'equalizer_virtualizer';

  /// Check whether storage scan has completed at least once
  bool hasScannedStorage() {
    return _getBool(keyHasScannedStorage) ?? false;
  }

  /// Record that storage scan has completed
  Future<bool> setHasScannedStorage(bool value) {
    return _setBool(keyHasScannedStorage, value);
  }

  /// Retrieve crossfade duration in seconds (0 = gapless / off, 1 to 10s)
  int getCrossfadeDuration() {
    return _getInt(keyCrossfadeDuration) ?? 0;
  }

  /// Set crossfade duration in seconds (0 to 10)
  Future<bool> setCrossfadeDuration(int seconds) {
    return _setInt(keyCrossfadeDuration, seconds.clamp(0, 10));
  }

  /// Retrieve whether gapless playback is enabled (default: true)
  bool getGaplessPlayback() {
    return _getBool(keyGaplessPlayback) ?? true;
  }

  /// Set gapless playback mode
  Future<bool> setGaplessPlayback(bool enabled) {
    return _setBool(keyGaplessPlayback, enabled);
  }

  /// Retrieve audio streaming quality ('320k', '256k', '160k', '96k', default: '320k')
  String getAudioQuality() {
    return _getString(keyAudioQuality) ?? '320k';
  }

  /// Store preferred audio streaming quality
  Future<bool> setAudioQuality(String quality) {
    return _setString(keyAudioQuality, quality);
  }

  /// Retrieve whether equalizer is enabled (default: false)
  bool getEqualizerEnabled() {
    return _getBool(keyEqualizerEnabled) ?? false;
  }

  /// Set equalizer enabled state
  Future<bool> setEqualizerEnabled(bool enabled) {
    return _setBool(keyEqualizerEnabled, enabled);
  }

  /// Retrieve current equalizer preset (default: 'Flat')
  String getEqualizerPreset() {
    return _getString(keyEqualizerPreset) ?? 'Flat';
  }

  /// Set current equalizer preset name
  Future<bool> setEqualizerPreset(String preset) {
    return _setString(keyEqualizerPreset, preset);
  }

  /// Retrieve 5-band equalizer gains in decibels (default: [0.0, 0.0, 0.0, 0.0, 0.0])
  List<double> getEqualizerGains() {
    final raw = _getString(keyEqualizerGains);
    if (raw == null || raw.trim().isEmpty) return const [0.0, 0.0, 0.0, 0.0, 0.0];
    try {
      final parts = raw.split(',').map((s) => double.tryParse(s.trim()) ?? 0.0).toList();
      if (parts.length == 5) return parts;
    } catch (_) {}
    return const [0.0, 0.0, 0.0, 0.0, 0.0];
  }

  List<double> getEqualizerBandGains() => getEqualizerGains();

  /// Store 5-band equalizer gains
  Future<bool> setEqualizerGains(List<double> gains) {
    final str = gains.map((g) => g.toStringAsFixed(1)).join(',');
    return _setString(keyEqualizerGains, str);
  }

  Future<bool> setEqualizerBandGains(List<double> gains) => setEqualizerGains(gains);

  /// Retrieve bass boost level (0.0 to 1.0, default: 0.0)
  double getEqualizerBassBoost() {
    return _getDouble(keyEqualizerBassBoost) ?? 0.0;
  }

  /// Set bass boost level (0.0 to 1.0)
  Future<bool> setEqualizerBassBoost(double value) {
    return _setDouble(keyEqualizerBassBoost, value.clamp(0.0, 1.0));
  }

  /// Retrieve virtualizer / surround sound level (0.0 to 1.0, default: 0.0)
  double getEqualizerVirtualizer() {
    return _getDouble(keyEqualizerVirtualizer) ?? 0.0;
  }

  /// Set virtualizer / surround sound level (0.0 to 1.0)
  Future<bool> setEqualizerVirtualizer(double value) {
    return _setDouble(keyEqualizerVirtualizer, value.clamp(0.0, 1.0));
  }

  static const int defaultDayStartHour = 6; // 06:00 AM
  static const int defaultDayStartMinute = 0;
  static const int defaultNightStartHour = 18; // 06:00 PM (18:00)
  static const int defaultNightStartMinute = 0;

  /// Retrieve stored track sort option (default: recentlyAdded)
  TrackSortOption getTrackSortOption() {
    final raw = _getString(keyTrackSortOption);
    if (raw == null) return TrackSortOption.recentlyAdded;
    return TrackSortOption.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => TrackSortOption.recentlyAdded,
    );
  }

  /// Store track sort option
  Future<bool> setTrackSortOption(TrackSortOption option) {
    return _setString(keyTrackSortOption, option.name);
  }

  /// Retrieve stored playback shuffle mode (default: false)
  bool getShuffleMode() {
    return _getBool(keyShuffleMode) ?? false;
  }

  /// Store playback shuffle mode
  Future<bool> setShuffleMode(bool isShuffle) {
    return _setBool(keyShuffleMode, isShuffle);
  }

  /// Retrieve stored playback repeat mode (default: off)
  AppRepeatMode getRepeatMode() {
    final raw = _getString(keyRepeatMode);
    if (raw == null) return AppRepeatMode.off;
    return AppRepeatMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppRepeatMode.off,
    );
  }

  /// Store playback repeat mode
  Future<bool> setRepeatMode(AppRepeatMode mode) {
    return _setString(keyRepeatMode, mode.name);
  }

  /// Retrieve stored theme preference (default: dark)
  AppThemePreference getThemePreference() {
    final raw = _getString(keyThemePreference);
    if (raw == null) return AppThemePreference.dark;
    return AppThemePreference.fromString(raw);
  }

  /// Store theme preference
  Future<bool> setThemePreference(AppThemePreference pref) {
    return _setString(keyThemePreference, pref.toPrefString());
  }

  /// Get daytime start time (default: 06:00 AM)
  TimeOfDay getDayStartTime() {
    final hour = _getInt(keyDayStartHour) ?? defaultDayStartHour;
    final minute = _getInt(keyDayStartMinute) ?? defaultDayStartMinute;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  /// Store daytime start time
  Future<void> setDayStartTime(TimeOfDay time) async {
    await _setInt(keyDayStartHour, time.hour);
    await _setInt(keyDayStartMinute, time.minute);
  }

  /// Get nighttime start time (default: 06:00 PM / 18:00)
  TimeOfDay getNightStartTime() {
    final hour = _getInt(keyNightStartHour) ?? defaultNightStartHour;
    final minute = _getInt(keyNightStartMinute) ?? defaultNightStartMinute;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  /// Store nighttime start time
  Future<void> setNightStartTime(TimeOfDay time) async {
    await _setInt(keyNightStartHour, time.hour);
    await _setInt(keyNightStartMinute, time.minute);
  }

  /// Determines whether a given time is in the daytime window.
  /// Handles schedules spanning midnight gracefully.
  bool isDayTime({DateTime? time, TimeOfDay? dayStart, TimeOfDay? nightStart}) {
    final now = time ?? DateTime.now();
    final day = dayStart ?? getDayStartTime();
    final night = nightStart ?? getNightStartTime();

    final nowMinutes = now.hour * 60 + now.minute;
    final dayMinutes = day.hour * 60 + day.minute;
    final nightMinutes = night.hour * 60 + night.minute;

    if (dayMinutes == nightMinutes) {
      // Degenerate case: if both times are identical, default 6 AM to 6 PM
      return nowMinutes >= 360 && nowMinutes < 1080;
    }

    if (dayMinutes < nightMinutes) {
      // Normal schedule: e.g. Day starts 06:00 (360) and Night starts 18:00 (1080)
      return nowMinutes >= dayMinutes && nowMinutes < nightMinutes;
    } else {
      // Cross-midnight schedule: e.g. Day starts 20:00 (1200) and Night starts 06:00 (360)
      return nowMinutes >= dayMinutes || nowMinutes < nightMinutes;
    }
  }

  /// Resolves the effective [ThemeMode] based on the preference and current time.
  ThemeMode resolveThemeMode(AppThemePreference preference, {DateTime? time}) {
    switch (preference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.autoTime:
        return isDayTime(time: time) ? ThemeMode.light : ThemeMode.dark;
    }
  }

  // --- Generic Key-Value Helpers ---

  String? _getString(String key) =>
      _prefs != null ? _prefs.getString(key) : (_fallbackStorage[key] as String?);

  Future<bool> _setString(String key, String val) async {
    _fallbackStorage[key] = val;
    if (_prefs != null) return _prefs.setString(key, val);
    return true;
  }

  int? _getInt(String key) =>
      _prefs != null ? _prefs.getInt(key) : (_fallbackStorage[key] as int?);

  Future<bool> _setInt(String key, int val) async {
    _fallbackStorage[key] = val;
    if (_prefs != null) return _prefs.setInt(key, val);
    return true;
  }

  bool? _getBool(String key) =>
      _prefs != null ? _prefs.getBool(key) : (_fallbackStorage[key] as bool?);

  Future<bool> _setBool(String key, bool val) async {
    _fallbackStorage[key] = val;
    if (_prefs != null) return _prefs.setBool(key, val);
    return true;
  }

  double? _getDouble(String key) =>
      _prefs != null ? _prefs.getDouble(key) : (_fallbackStorage[key] as double?);

  Future<bool> _setDouble(String key, double val) async {
    _fallbackStorage[key] = val;
    if (_prefs != null) return _prefs.setDouble(key, val);
    return true;
  }

  // Public generic accessors for other features
  String? getString(String key) => _getString(key);
  Future<bool> setString(String key, String val) => _setString(key, val);

  int? getInt(String key) => _getInt(key);
  Future<bool> setInt(String key, int val) => _setInt(key, val);

  bool? getBool(String key) => _getBool(key);
  Future<bool> setBool(String key, bool val) => _setBool(key, val);

  Future<bool> remove(String key) async {
    _fallbackStorage.remove(key);
    if (_prefs != null) return _prefs.remove(key);
    return true;
  }
}
