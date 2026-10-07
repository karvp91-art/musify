import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../domain/models/playlist.dart';
import '../domain/models/track.dart';
import '../domain/repositories/audio_repository.dart';
import '../presentation/providers/audio_providers.dart';

/// Metadata summary for a saved backup file on disk
class BackupFileInfo {
  final File file;
  final String fileName;
  final int fileSizeBytes;
  final DateTime modifiedAt;
  final DateTime? exportedAt;
  final int playlistCount;
  final int likedCount;

  const BackupFileInfo({
    required this.file,
    required this.fileName,
    required this.fileSizeBytes,
    required this.modifiedAt,
    this.exportedAt,
    this.playlistCount = 0,
    this.likedCount = 0,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Inspection summary shown to the user before confirming restore
class BackupPreview {
  final File file;
  final int version;
  final DateTime exportedAt;
  final int playlistCount;
  final int totalPlaylistTracks;
  final int likedCount;
  final List<String> playlistNames;
  final Map<String, dynamic> settings;

  const BackupPreview({
    required this.file,
    required this.version,
    required this.exportedAt,
    required this.playlistCount,
    required this.totalPlaylistTracks,
    required this.likedCount,
    required this.playlistNames,
    required this.settings,
  });
}

/// Outcome of a restore operation
class RestoreResult {
  final bool success;
  final int restoredPlaylists;
  final int restoredLikedSongs;
  final bool settingsRestored;
  final String? errorMessage;

  const RestoreResult({
    required this.success,
    this.restoredPlaylists = 0,
    this.restoredLikedSongs = 0,
    this.settingsRestored = false,
    this.errorMessage,
  });
}

class BackupService {
  static const int currentBackupVersion = 1;

  /// Returns the permanent public directory where backups are saved
  static Future<Directory> getBackupsDirectory() async {
    if (Platform.isAndroid) {
      // 1. Primary: Standard public Download/Musify/Backups folder
      final downloadBackups = Directory('/storage/emulated/0/Download/Musify/Backups');
      try {
        if (!downloadBackups.existsSync()) {
          await downloadBackups.create(recursive: true);
        }
        return downloadBackups;
      } catch (_) {}

      // 2. Secondary: Standard public Music/Musify/Backups folder
      final musicBackups = Directory('/storage/emulated/0/Music/Musify/Backups');
      try {
        if (!musicBackups.existsSync()) {
          await musicBackups.create(recursive: true);
        }
        return musicBackups;
      } catch (_) {}

      // 3. Fallback: External storage
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final dir = Directory(p.join(ext.path, 'Backups'));
          if (!dir.existsSync()) await dir.create(recursive: true);
          return dir;
        }
      } catch (_) {}
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Musify', 'Backups'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Exports current Playlists, Liked Songs, and Audio/Equalizer Preferences into a JSON backup file
  static Future<File> exportBackup({
    required AudioRepository repo,
    required PreferencesService prefs,
  }) async {
    // 1. Fetch current library state
    final playlists = await repo.getPlaylists();
    final likedTracks = await repo.getLikedTracks();

    // 2. Capture all preferences & audio settings
    final themePref = prefs.getThemePreference();
    final settingsMap = <String, dynamic>{
      'themePreference': themePref.toPrefString(),
      'audioQuality': prefs.getAudioQuality(),
      'crossfadeDuration': prefs.getCrossfadeDuration(),
      'gaplessPlayback': prefs.getGaplessPlayback(),
      'equalizerEnabled': prefs.getEqualizerEnabled(),
      'equalizerPreset': prefs.getEqualizerPreset(),
      'equalizerGains': prefs.getEqualizerGains(),
      'bassBoost': prefs.getEqualizerBassBoost(),
      'loudness': prefs.getEqualizerLoudness(),
      'virtualizer': prefs.getEqualizerVirtualizer(),
    };

    final totalPlaylistTracks = playlists.fold<int>(0, (sum, p) => sum + p.tracks.length);

    // 3. Construct unified JSON payload
    final now = DateTime.now();
    final backupData = {
      'version': currentBackupVersion,
      'appName': 'Musify',
      'exportedAt': now.toIso8601String(),
      'stats': {
        'playlistCount': playlists.length,
        'totalPlaylistTracks': totalPlaylistTracks,
        'likedCount': likedTracks.length,
      },
      'settings': settingsMap,
      'likedTracks': likedTracks.map((t) => t.toMap()).toList(),
      'playlists': playlists.map((p) => p.toMap()).toList(),
    };

    // 4. Save to persistent backups directory
    final backupsDir = await getBackupsDirectory();
    final timestamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    final fileName = 'musify_backup_$timestamp.json';
    final backupFile = File(p.join(backupsDir.path, fileName));

    const encoder = JsonEncoder.withIndent('  ');
    await backupFile.writeAsString(encoder.convert(backupData));

    return backupFile;
  }

  /// Lists all available Musify backup files found on the device
  static Future<List<BackupFileInfo>> listBackups() async {
    final results = <BackupFileInfo>[];
    final scannedPaths = <String>{};

    final searchDirs = <Directory>[
      await getBackupsDirectory(),
      Directory('/storage/emulated/0/Download/Musify/Backups'),
      Directory('/storage/emulated/0/Music/Musify/Backups'),
      Directory('/storage/emulated/0/Download'),
    ];

    for (final dir in searchDirs) {
      if (!dir.existsSync()) continue;

      try {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is! File) continue;

          final name = p.basename(entity.path);
          final ext = p.extension(name).toLowerCase();
          final isJsonOrMusify = ext == '.json' || ext == '.musify';
          final isMusifyNamed = name.startsWith('musify_backup_') || name.contains('musify');

          if (!isJsonOrMusify && !isMusifyNamed) continue;
          if (scannedPaths.contains(entity.path)) continue;
          scannedPaths.add(entity.path);

          try {
            // Quick peek to verify it's a valid Musify backup
            final stat = entity.statSync();
            final content = await entity.readAsString();
            final decoded = jsonDecode(content);

            if (decoded is Map<String, dynamic> &&
                (decoded['appName'] == 'Musify' || decoded.containsKey('playlists') || decoded.containsKey('likedTracks'))) {
              final stats = decoded['stats'] as Map<String, dynamic>?;
              final exportedAtStr = decoded['exportedAt'] as String?;
              final exportedAt = exportedAtStr != null ? DateTime.tryParse(exportedAtStr) : null;

              final playlistCount = stats?['playlistCount'] as int? ??
                  (decoded['playlists'] as List<dynamic>?)?.length ??
                  0;
              final likedCount = stats?['likedCount'] as int? ??
                  (decoded['likedTracks'] as List<dynamic>?)?.length ??
                  0;

              results.add(
                BackupFileInfo(
                  file: entity,
                  fileName: name,
                  fileSizeBytes: stat.size,
                  modifiedAt: stat.modified,
                  exportedAt: exportedAt,
                  playlistCount: playlistCount,
                  likedCount: likedCount,
                ),
              );
            }
          } catch (_) {
            // Ignore non-backup files
          }
        }
      } catch (_) {}
    }

    // Sort newest backups first
    results.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return results;
  }

  /// Inspects a backup file and returns an informational preview
  static Future<BackupPreview> inspectBackup(File file) async {
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    final version = data['version'] as int? ?? 1;
    final exportedAtStr = data['exportedAt'] as String? ?? '';
    final exportedAt = DateTime.tryParse(exportedAtStr) ?? file.lastModifiedSync();

    final playlistsRaw = (data['playlists'] as List<dynamic>?) ?? [];
    final likedRaw = (data['likedTracks'] as List<dynamic>?) ?? [];
    final settings = (data['settings'] as Map<String, dynamic>?) ?? {};

    final playlistNames = <String>[];
    int totalTracks = 0;

    for (final p in playlistsRaw) {
      if (p is Map<String, dynamic>) {
        playlistNames.add(p['name'] as String? ?? 'Untitled');
        final tracks = p['tracks'] as List<dynamic>?;
        totalTracks += tracks?.length ?? 0;
      }
    }

    return BackupPreview(
      file: file,
      version: version,
      exportedAt: exportedAt,
      playlistCount: playlistsRaw.length,
      totalPlaylistTracks: totalTracks,
      likedCount: likedRaw.length,
      playlistNames: playlistNames,
      settings: settings,
    );
  }

  /// Restores library state from a selected backup file
  static Future<RestoreResult> restoreBackup(
    File file, {
    required AudioRepository repo,
    required PreferencesService prefs,
    required WidgetRef ref,
    bool merge = true,
  }) async {
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      int restoredPlaylistsCount = 0;
      int restoredLikedCount = 0;
      bool settingsRestored = false;

      // 1. Restore Preferences & Equalizer Settings
      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        if (settings['themePreference'] != null) {
          final t = AppThemePreference.fromString(settings['themePreference'] as String);
          await prefs.setThemePreference(t);
          await ref.read(themePreferenceProvider.notifier).setPreference(t);
        }

        if (settings['audioQuality'] != null) {
          final q = settings['audioQuality'] as String;
          await prefs.setAudioQuality(q);
          ref.read(audioQualityProvider.notifier).setQuality(q);
        }

        if (settings['crossfadeDuration'] != null) {
          final cf = (settings['crossfadeDuration'] as num).toInt();
          await prefs.setCrossfadeDuration(cf);
          ref.read(crossfadeProvider.notifier).setDuration(cf);
        }

        if (settings['gaplessPlayback'] != null) {
          final gp = settings['gaplessPlayback'] as bool;
          await prefs.setGaplessPlayback(gp);
          ref.read(gaplessPlaybackProvider.notifier).setEnabled(gp);
        }

        if (settings['equalizerEnabled'] != null) {
          final eqEnabled = settings['equalizerEnabled'] as bool;
          await prefs.setEqualizerEnabled(eqEnabled);
          ref.read(equalizerProvider.notifier).setEnabled(eqEnabled);
        }

        if (settings['equalizerPreset'] != null) {
          final preset = settings['equalizerPreset'] as String;
          await prefs.setEqualizerPreset(preset);
          ref.read(equalizerProvider.notifier).setPreset(preset);
        }

        if (settings['equalizerGains'] != null) {
          final gainsRaw = settings['equalizerGains'] as List<dynamic>;
          final gains = gainsRaw.map((e) => (e as num).toDouble()).toList();
          await prefs.setEqualizerGains(gains);
          ref.read(equalizerProvider.notifier).setAllBands(gains);
        }

        if (settings['bassBoost'] != null) {
          final bb = (settings['bassBoost'] as num).toDouble();
          await prefs.setEqualizerBassBoost(bb);
          ref.read(equalizerProvider.notifier).setBassBoost(bb);
        }

        if (settings['loudness'] != null) {
          final l = (settings['loudness'] as num).toDouble();
          await prefs.setEqualizerLoudness(l);
          ref.read(equalizerProvider.notifier).setLoudness(l);
        }

        settingsRestored = true;
      }

      // 2. Restore Liked Songs
      final likedRaw = data['likedTracks'] as List<dynamic>?;
      if (likedRaw != null) {
        for (final item in likedRaw) {
          if (item is Map<String, dynamic>) {
            final track = Track.fromMap(item);
            final isAlreadyLiked = await repo.isTrackLiked(track.id);
            if (!isAlreadyLiked) {
              await repo.toggleLike(track);
              restoredLikedCount++;
            }
          }
        }
      }

      // 3. Restore Playlists
      final playlistsRaw = data['playlists'] as List<dynamic>?;
      if (playlistsRaw != null) {
        final existingPlaylists = await repo.getPlaylists();
        final existingByName = {for (final p in existingPlaylists) p.name.toLowerCase(): p};

        for (final item in playlistsRaw) {
          if (item is Map<String, dynamic>) {
            final playlist = Playlist.fromMap(item);
            final existing = existingByName[playlist.name.toLowerCase()];

            String targetPlaylistId;
            if (existing != null && merge) {
              // Merge mode: Add tracks to existing playlist without duplicating playlist
              targetPlaylistId = existing.id;
            } else {
              // Create new playlist with matching name and description
              final created = await repo.createPlaylist(
                playlist.name,
                description: playlist.description,
              );
              targetPlaylistId = created.id;
              restoredPlaylistsCount++;
            }

            // Populate tracks
            final currentTracksInPlaylist = await repo.getPlaylistTracks(targetPlaylistId);
            final existingTrackIds = {for (final t in currentTracksInPlaylist) t.id};

            for (final track in playlist.tracks) {
              if (!existingTrackIds.contains(track.id)) {
                await repo.addTrackToPlaylist(targetPlaylistId, track);
                existingTrackIds.add(track.id);
              }
            }
          }
        }
      }

      return RestoreResult(
        success: true,
        restoredPlaylists: restoredPlaylistsCount,
        restoredLikedSongs: restoredLikedCount,
        settingsRestored: settingsRestored,
      );
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return RestoreResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Delete a backup file
  static Future<bool> deleteBackup(File file) async {
    try {
      if (file.existsSync()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
