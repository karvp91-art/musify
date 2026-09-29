import 'dart:collection';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:musify/core/utils/audio_metadata_reader.dart';
import 'package:musify/core/utils/audio_name_sanitizer.dart';
import 'package:musify/domain/models/track.dart';
import '../database/app_database.dart';
import 'sample_audio_generator.dart';

class ScanProgress {
  final int filesScanned;
  final int tracksFound;
  final String currentDirectory;
  final bool isCompleted;

  const ScanProgress({
    required this.filesScanned,
    required this.tracksFound,
    required this.currentDirectory,
    this.isCompleted = false,
  });
}

class LocalFilesScanner {
  final AppDatabase _db;
  Directory? _cachedArtworksDir;

  LocalFilesScanner(this._db);

  static const List<String> supportedExtensions = [
    '.mp3',
    '.m4a',
    '.flac',
    '.wav',
    '.ogg',
    '.aac',
    '.opus',
    '.wma',
    '.webm',
    '.m4b',
    '.m4p',
    '.aiff',
    '.3gp',
    '.amr',
  ];

  static const Map<String, String> demoArtworkUrls = {
    'Ambient Sunrise': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
    'Velvet Chill': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
    'Midnight Study': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
  };

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) return true;

      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }

  /// Generates demo audio tracks locally and inserts them into the database for immediate testing
  Future<int> seedSampleMusic() async {
    final demoFiles = await SampleAudioGenerator.generateDemoSuite();
    int added = 0;
    for (final file in demoFiles) {
      final track = await _parseFileToTrack(file);
      if (track != null) {
        String? artwork;
        for (final entry in demoArtworkUrls.entries) {
          if (track.title.contains(entry.key)) {
            artwork = entry.value;
            break;
          }
        }

        await _db.into(_db.localTracks).insert(
          LocalTracksCompanion(
            id: Value(track.id),
            title: Value(track.title),
            artistName: Value(track.artistName),
            albumTitle: Value('Musify Originals'),
            source: Value(track.source.name),
            sourceId: Value(track.sourceId),
            durationMs: Value(track.durationMs),
            artworkUrl: Value(artwork),
            audioUrl: Value(track.audioUrl),
            filePath: Value(track.filePath),
            fileSizeBytes: Value(track.fileSizeBytes),
            codec: Value(track.codec),
            bitrate: Value(track.bitrate),
            isLiked: Value(false),
            isDownloaded: Value(true),
            addedAt: Value(track.addedAt),
          ),
          mode: InsertMode.insertOrReplace,
        );
        added++;
      }
    }
    return added;
  }

  /// Thorough, resilient device scanner that crawls all storage locations without aborting on permission errors
  Future<int> scanDeviceMusic({void Function(ScanProgress progress)? onProgress}) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission && (Platform.isAndroid || Platform.isIOS)) {
      onProgress?.call(const ScanProgress(
        filesScanned: 0,
        tracksFound: 0,
        currentDirectory: 'Permission denied',
        isCompleted: true,
      ));
      return 0;
    }

    final Set<String> visitedPaths = {};
    final List<Directory> rootScanDirs = [];

    onProgress?.call(const ScanProgress(
      filesScanned: 0,
      tracksFound: 0,
      currentDirectory: 'Preparing directories...',
    ));

    try {
      if (Platform.isAndroid) {
        final rootDir = Directory('/storage/emulated/0');
        if (await rootDir.exists()) {
          try {
            await for (final entity in rootDir.list(recursive: false, followLinks: false)) {
              if (entity is Directory) {
                final dirName = p.basename(entity.path);
                // Skip hidden directories and system Android directory
                if (!dirName.startsWith('.') && dirName != 'Android') {
                  rootScanDirs.add(entity);
                }
              }
            }
          } catch (_) {
            // Fallback: standard user directories
            rootScanDirs.addAll([
              Directory('/storage/emulated/0/Music'),
              Directory('/storage/emulated/0/Download'),
              Directory('/storage/emulated/0/Audio'),
              Directory('/storage/emulated/0/Documents'),
              Directory('/storage/emulated/0/Podcasts'),
              Directory('/storage/emulated/0/Recordings'),
              Directory('/storage/emulated/0/bluetooth'),
              Directory('/storage/emulated/0/Media'),
              Directory('/storage/emulated/0/Songs'),
            ]);
          }
        }

        // Scan external SD card mounts if present
        final storageRoot = Directory('/storage');
        if (await storageRoot.exists()) {
          try {
            await for (final entity in storageRoot.list(recursive: false, followLinks: false)) {
              if (entity is Directory) {
                final dirName = p.basename(entity.path);
                if (dirName != 'emulated' && dirName != 'self' && !dirName.startsWith('.')) {
                  rootScanDirs.add(entity);
                }
              }
            }
          } catch (_) {}
        }
      }

      // Application Documents & Downloads directories
      final docDir = await getApplicationDocumentsDirectory();
      rootScanDirs.add(docDir);

      try {
        final downloadDir = await getDownloadsDirectory();
        if (downloadDir != null) rootScanDirs.add(downloadDir);
      } catch (_) {}
    } catch (_) {}

    final List<LocalTracksCompanion> collectedTracks = [];
    int scannedFilesCounter = 0;

    for (final dir in rootScanDirs) {
      if (await dir.exists()) {
        await _crawlDirectorySafe(
          dir,
          visitedPaths,
          collectedTracks,
          onFileScanned: (count, path) {
            scannedFilesCounter += count;
            onProgress?.call(ScanProgress(
              filesScanned: scannedFilesCounter,
              tracksFound: collectedTracks.length,
              currentDirectory: p.basename(path),
            ));
          },
        );
      }
    }

    // Fast batch upsert into SQLite
    if (collectedTracks.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.localTracks, collectedTracks);
      });
    }

    onProgress?.call(ScanProgress(
      filesScanned: scannedFilesCounter,
      tracksFound: collectedTracks.length,
      currentDirectory: 'Complete',
      isCompleted: true,
    ));

    return collectedTracks.length;
  }

  /// Safe BFS crawler that inspects folder by folder so a single restricted folder does not halt traversal
  Future<void> _crawlDirectorySafe(
    Directory root,
    Set<String> visited,
    List<LocalTracksCompanion> collectedTracks, {
    void Function(int count, String currentPath)? onFileScanned,
  }) async {
    final queue = Queue<Directory>()..add(root);

    while (queue.isNotEmpty) {
      final currentDir = queue.removeFirst();
      final currentPath = currentDir.path;

      if (visited.contains(currentPath)) continue;
      visited.add(currentPath);

      try {
        await for (final entity in currentDir.list(recursive: false, followLinks: false)) {
          final entityName = p.basename(entity.path);
          if (entityName.startsWith('.')) continue; // Skip hidden files/dirs

          if (entity is Directory) {
            // Skip heavy non-audio/system directories
            if (entityName != 'Android' &&
                entityName != 'node_modules' &&
                entityName != '.git' &&
                entityName != '.cache' &&
                entityName != '.thumbnails') {
              queue.add(entity);
            }
          } else if (entity is File) {
            onFileScanned?.call(1, currentPath);
            final ext = p.extension(entity.path).toLowerCase();
            if (supportedExtensions.contains(ext)) {
              final track = await _parseFileToTrack(entity);
              if (track != null) {
                collectedTracks.add(
                  LocalTracksCompanion(
                    id: Value(track.id),
                    title: Value(track.title),
                    artistName: Value(track.artistName),
                    albumTitle: Value(track.albumTitle),
                    source: Value(track.source.name),
                    sourceId: Value(track.sourceId),
                    durationMs: Value(track.durationMs),
                    artworkUrl: Value(track.artworkUrl),
                    audioUrl: Value(track.audioUrl),
                    filePath: Value(track.filePath),
                    fileSizeBytes: Value(track.fileSizeBytes),
                    codec: Value(track.codec),
                    bitrate: Value(track.bitrate),
                    isLiked: Value(track.isLiked),
                    isDownloaded: Value(true),
                    addedAt: Value(track.addedAt),
                  ),
                );
              }
            }
          }
        }
      } catch (_) {
        // Individual folder permission denial handled safely without failing the whole scan
      }
    }
  }

  Future<Track?> _parseFileToTrack(File file) async {
    try {
      final fileName = p.basenameWithoutExtension(file.path);
      final parentFolder = p.basename(file.parent.path);
      final stat = await file.stat();

      // 1. Try reading embedded ID3 tags
      final id3 = await AudioMetadataReader.readMetadata(file);

      String title = '';
      String artist = '';
      String? album = id3?.album;

      if (id3?.artist != null && !AudioNameSanitizer.isJunkArtist(id3!.artist)) {
        artist = AudioNameSanitizer.cleanText(id3.artist!);
      }
      if (id3?.title != null && id3!.title!.trim().isNotEmpty) {
        title = AudioNameSanitizer.cleanText(id3.title!);
      }

      // If ID3 title contains separators (e.g. YouTube full video title dumped into ID3 title)
      // and artist is empty or junk, parse the combined title
      if (title.isNotEmpty && AudioNameSanitizer.hasSeparator(title) && (artist.isEmpty || AudioNameSanitizer.isJunkArtist(artist))) {
        final parsedFromTitle = AudioNameSanitizer.parseFileName(
          title,
          folderName: parentFolder,
          fallbackAlbum: album,
        );
        title = parsedFromTitle.title;
        artist = parsedFromTitle.artist;
        if (parsedFromTitle.album != null && (album == null || album.isEmpty || album == 'Local Audio')) {
          album = parsedFromTitle.album;
        }
      }

      // 2. If ID3 title is missing or generic, parse from filename
      if (title.isEmpty) {
        final parsed = AudioNameSanitizer.parseFileName(
          fileName,
          folderName: parentFolder,
          fallbackArtist: artist.isNotEmpty ? artist : null,
          fallbackAlbum: album,
        );
        title = parsed.title;
        if (artist.isEmpty || AudioNameSanitizer.isJunkArtist(artist)) {
          artist = parsed.artist;
        }
        if (parsed.album != null && (album == null || album.isEmpty || album == 'Local Audio')) {
          album = parsed.album;
        }
      } else if (artist.isEmpty || AudioNameSanitizer.isJunkArtist(artist)) {
        final parsed = AudioNameSanitizer.parseFileName(
          fileName,
          folderName: parentFolder,
          fallbackAlbum: album,
        );
        if (parsed.artist != 'Unknown Artist') {
          artist = parsed.artist;
        } else {
          artist = 'Unknown Artist';
        }
        if (parsed.album != null && (album == null || album.isEmpty || album == 'Local Audio')) {
          album = parsed.album;
        }
      }

      // 3. Disambiguate title and artist (fixes swapped tags and separates movie/album)
      final disambiguated = AudioNameSanitizer.disambiguateTitleAndArtist(
        title: title,
        artist: artist,
        album: album,
      );
      title = disambiguated.title;
      artist = disambiguated.artist;
      album = disambiguated.album ?? album;

      // 3. Extract and cache album artwork if present
      String? artworkPath;
      if (id3?.artworkBytes != null && id3!.artworkBytes!.isNotEmpty) {
        try {
          if (_cachedArtworksDir == null) {
            final docDir = await getApplicationDocumentsDirectory();
            final artDir = Directory(p.join(docDir.path, 'artworks'));
            if (!await artDir.exists()) {
              await artDir.create(recursive: true);
            }
            _cachedArtworksDir = artDir;
          }
          final artDir = _cachedArtworksDir!;
          final hash = file.path.hashCode.abs().toString();
          final artFile = File(p.join(artDir.path, '$hash.jpg'));
          if (!await artFile.exists()) {
            await artFile.writeAsBytes(id3.artworkBytes!);
          }
          artworkPath = artFile.path;
        } catch (_) {}
      }

      artworkPath ??= await AudioMetadataReader.findFolderArtwork(file);

      final ext = p.extension(file.path).replaceAll('.', '').toLowerCase();

      // Estimate / calculate duration for standard audio
      int durationMs = id3?.durationMs ?? 0;
      if (durationMs <= 0 && ext == 'wav' && stat.size > 44) {
        durationMs = (((stat.size - 44) / 176400) * 1000).round();
      }

      return Track(
        id: 'local:${file.path}',
        title: title,
        artistName: artist,
        albumTitle: album ?? 'Local Audio',
        source: AudioSourceType.local,
        sourceId: file.path,
        durationMs: durationMs,
        artworkUrl: artworkPath,
        audioUrl: file.path,
        filePath: file.path,
        fileSizeBytes: stat.size,
        codec: ext,
        bitrate: 320,
        isLiked: false,
        isDownloaded: true,
        addedAt: stat.modified,
      );
    } catch (_) {
      return null;
    }
  }
}
