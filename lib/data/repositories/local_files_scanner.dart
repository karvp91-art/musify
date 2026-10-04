import 'dart:collection';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:musify/core/utils/audio_metadata_reader.dart';
import 'package:musify/core/utils/audio_name_sanitizer.dart';
import 'package:musify/core/utils/mediastore_bridge.dart';
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

    final Set<String> visitedFilePaths = {};

    try {
      if (Platform.isAndroid) {
        final rootDir = Directory('/storage/emulated/0');
        if (await rootDir.exists()) {
          try {
            await for (final entity in rootDir.list(recursive: false, followLinks: false)) {
              if (entity is Directory) {
                final dirName = p.basename(entity.path);
                final lower = dirName.toLowerCase();
                // Skip hidden directories and system Android directory
                if (!dirName.startsWith('.') && lower != 'android') {
                  rootScanDirs.add(entity);
                }
              }
            }
          } catch (_) {}
        }

        // Always ensure standard music, ringtones, recordings, and audio folders are included
        final candidateAudioDirs = [
          Directory('/storage/emulated/0/Music'),
          Directory('/storage/emulated/0/Download'),
          Directory('/storage/emulated/0/Documents'),
          Directory('/storage/emulated/0/bluetooth'),
          Directory('/storage/emulated/0/Songs'),
          Directory('/storage/emulated/0/Ringtones'),
          Directory('/storage/emulated/0/Recordings'),
          Directory('/storage/emulated/0/Audio'),
          Directory('/storage/emulated/0/Notifications'),
          Directory('/storage/emulated/0/Alarms'),
          Directory('/storage/emulated/0/Podcasts'),
          Directory('/storage/emulated/0/Sounds'),
          Directory('/storage/emulated/0/Voice Recorder'),
          Directory('/storage/emulated/0/VoiceRecorder'),
          Directory('/storage/emulated/0/SoundRecorder'),
          Directory('/storage/emulated/0/Call Recordings'),
          Directory('/storage/emulated/0/CallRecordings'),
          Directory('/storage/emulated/0/MIUI/sound_recorder'),
          Directory('/storage/emulated/0/Samsung/Voice Recorder'),
          Directory('/storage/emulated/0/WhatsApp/Media/WhatsApp Audio'),
          Directory('/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes'),
          Directory('/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio'),
          Directory('/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes'),
        ];
        for (final dir in candidateAudioDirs) {
          if (!rootScanDirs.any((d) => d.path == dir.path)) {
            rootScanDirs.add(dir);
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

      // Shared Downloads directory
      try {
        final downloadDir = await getDownloadsDirectory();
        if (downloadDir != null) rootScanDirs.add(downloadDir);
      } catch (_) {}
    } catch (_) {}

    final List<LocalTracksCompanion> collectedTracks = [];
    int scannedFilesCounter = 0;

    // Load existing tracked file paths so we never insert a duplicate "local:..."
    // record for a song that was already downloaded from YouTube or JioSaavn
    final existingRows = await _db.select(_db.localTracks).get();
    final existingOnlinePaths = <String>{};
    final existingArtworks = <String, String>{};
    for (final row in existingRows) {
      if (row.filePath != null && row.filePath!.isNotEmpty) {
        if (row.source != AudioSourceType.local.name ||
            row.id.startsWith('youtube:') ||
            row.id.startsWith('saavn:')) {
          existingOnlinePaths.add(p.normalize(row.filePath!));
        }
      }
      if (row.artworkUrl != null && row.artworkUrl!.isNotEmpty) {
        existingArtworks[row.id] = row.artworkUrl!;
      }
    }

    // Phase 1: High-Speed Android MediaStore OS Query
    // MediaStore indexes all device music, ringtones, notifications, and voice recordings
    if (Platform.isAndroid) {
      try {
        final mediaStoreFiles = await MediaStoreBridge.getAllAudio();
        for (final msFile in mediaStoreFiles) {
          final normPath = p.normalize(msFile.filePath);
          if (visitedFilePaths.contains(normPath) || existingOnlinePaths.contains(normPath)) {
            continue;
          }
          final file = File(msFile.filePath);
          if (await file.exists()) {
            visitedFilePaths.add(normPath);
            scannedFilesCounter++;
            final track = await _parseFileToTrack(file);
            if (track != null) {
              final effectiveArtwork = (track.artworkUrl != null && track.artworkUrl!.isNotEmpty)
                  ? track.artworkUrl
                  : existingArtworks[track.id];

              collectedTracks.add(
                LocalTracksCompanion(
                  id: Value(track.id),
                  title: Value(track.title),
                  artistName: Value(track.artistName),
                  albumTitle: Value(track.albumTitle),
                  source: Value(track.source.name),
                  sourceId: Value(track.sourceId),
                  durationMs: Value(track.durationMs),
                  artworkUrl: Value(effectiveArtwork),
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
              onProgress?.call(ScanProgress(
                filesScanned: scannedFilesCounter,
                tracksFound: collectedTracks.length,
                currentDirectory: p.basename(file.parent.path),
              ));
            }
          }
        }
      } catch (_) {}
    }

    // Phase 2: Deep File System Crawl across all user storage locations
    for (final dir in rootScanDirs) {
      if (await dir.exists()) {
        await _crawlDirectorySafe(
          dir,
          visitedPaths,
          collectedTracks,
          visitedFilePaths: visitedFilePaths,
          existingOnlinePaths: existingOnlinePaths,
          existingArtworks: existingArtworks,
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

    // Second pass: Scan Musify download directories to re-index previously downloaded files
    // This ensures files survive app reinstalls (DB is wiped but files remain on disk)
    for (final dlPath in _musifyDownloadPaths) {
      final dlDir = Directory(dlPath);
      if (await dlDir.exists()) {
        await _crawlDirectorySafe(
          dlDir,
          visitedPaths,
          collectedTracks,
          visitedFilePaths: visitedFilePaths,
          existingOnlinePaths: existingOnlinePaths,
          existingArtworks: existingArtworks,
          onFileScanned: (count, path) {
            scannedFilesCounter += count;
            onProgress?.call(ScanProgress(
              filesScanned: scannedFilesCounter,
              tracksFound: collectedTracks.length,
              currentDirectory: 'Musify Downloads',
            ));
          },
          markAsDownloaded: true,
        );
      }
    }

    // Also check app-specific external storage fallback
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final musifyExtDir = Directory(p.join(extDir.path, 'Musify'));
        if (await musifyExtDir.exists()) {
          await _crawlDirectorySafe(
            musifyExtDir,
            visitedPaths,
            collectedTracks,
            visitedFilePaths: visitedFilePaths,
            existingOnlinePaths: existingOnlinePaths,
            existingArtworks: existingArtworks,
            onFileScanned: (count, path) {
              scannedFilesCounter += count;
              onProgress?.call(ScanProgress(
                filesScanned: scannedFilesCounter,
                tracksFound: collectedTracks.length,
                currentDirectory: 'Musify Downloads',
              ));
            },
            markAsDownloaded: true,
          );
        }
      }
    } catch (_) {}

    // Fast batch upsert into SQLite
    if (collectedTracks.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.localTracks, collectedTracks);
      });
    }

    // Clean up any historical duplicate local entries that share a filePath with an online/downloaded track
    try {
      await _db.customStatement(
        "DELETE FROM local_tracks WHERE source = 'local' AND file_path IN ("
        "  SELECT file_path FROM local_tracks WHERE source != 'local' AND file_path IS NOT NULL AND file_path != ''"
        ");",
      );
    } catch (_) {}

    onProgress?.call(ScanProgress(
      filesScanned: scannedFilesCounter,
      tracksFound: collectedTracks.length,
      currentDirectory: 'Complete',
      isCompleted: true,
    ));

    return collectedTracks.length;
  }

  /// Known Musify download directories to scan separately and mark as downloaded
  static const List<String> _musifyDownloadPaths = [
    '/storage/emulated/0/Music/Musify',
    '/storage/emulated/0/Download/Musify',
  ];

  /// Check if a path belongs to a Musify-managed download directory
  static bool _isMusifyDownloadPath(String path) {
    final lower = path.toLowerCase();
    for (final dlPath in _musifyDownloadPaths) {
      if (lower.startsWith(dlPath.toLowerCase())) return true;
    }
    return lower.contains('musify_downloads') || lower.contains('.musify_downloads');
  }

  /// Safe BFS crawler that inspects folder by folder so a single restricted folder does not halt traversal
  Future<void> _crawlDirectorySafe(
    Directory root,
    Set<String> visited,
    List<LocalTracksCompanion> collectedTracks, {
    void Function(int count, String currentPath)? onFileScanned,
    bool markAsDownloaded = false,
    Set<String>? existingOnlinePaths,
    Set<String>? visitedFilePaths,
    Map<String, String>? existingArtworks,
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
            final lower = entityName.toLowerCase();
            // Skip system/non-audio cache directories
            if (lower != 'android' &&
                lower != 'node_modules' &&
                lower != '.git' &&
                lower != '.cache' &&
                lower != '.thumbnails') {
              // If this is a Musify download directory, skip it during the general pass
              // (it will be scanned in a dedicated pass with markAsDownloaded=true)
              if (!markAsDownloaded && _isMusifyDownloadPath(entity.path)) {
                continue;
              }
              queue.add(entity);
            }
          } else if (entity is File) {
            // During the general scan pass, skip files inside Musify download dirs
            if (!markAsDownloaded && _isMusifyDownloadPath(currentPath)) continue;

            final normPath = p.normalize(entity.path);
            if (visitedFilePaths != null && visitedFilePaths.contains(normPath)) {
              continue;
            }
            if (existingOnlinePaths != null && existingOnlinePaths.contains(normPath)) {
              continue;
            }
            visitedFilePaths?.add(normPath);

            onFileScanned?.call(1, currentPath);
            final ext = p.extension(entity.path).toLowerCase();
            if (supportedExtensions.contains(ext)) {
              final track = await _parseFileToTrack(entity);
              if (track != null) {
                final effectiveArtwork = (track.artworkUrl != null && track.artworkUrl!.isNotEmpty)
                    ? track.artworkUrl
                    : existingArtworks?[track.id];

                collectedTracks.add(
                  LocalTracksCompanion(
                    id: Value(track.id),
                    title: Value(track.title),
                    artistName: Value(track.artistName),
                    albumTitle: Value(track.albumTitle),
                    source: Value(track.source.name),
                    sourceId: Value(track.sourceId),
                    durationMs: Value(track.durationMs),
                    artworkUrl: Value(effectiveArtwork),
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

      // ── Source 1: Embedded ID3 tags ──
      final id3 = await AudioMetadataReader.readMetadata(file);

      // ── Source 2: Android MediaStore (OS-level media scanner) ──
      final mediaStore = await MediaStoreBridge.getMetadata(file.path);

      // ── Source 3: Filename parsing ──
      final filenameParsed = AudioNameSanitizer.parseFileName(
        fileName,
        folderName: parentFolder,
      );

      // ── Cross-validate and pick the best title/artist/album ──
      String title = '';
      String artist = '';
      String? album;

      // Collect candidates from each source
      final String? id3Title = (id3?.title != null && id3!.title!.trim().isNotEmpty)
          ? AudioNameSanitizer.cleanText(id3.title!)
          : null;
      final String? id3Artist = (id3?.artist != null && !AudioNameSanitizer.isJunkArtist(id3!.artist))
          ? AudioNameSanitizer.cleanText(id3.artist!)
          : null;
      final String? id3Album = id3?.album;

      final String? msTitle = mediaStore?.title;
      final String? msArtist = (mediaStore?.artist != null && !AudioNameSanitizer.isJunkArtist(mediaStore!.artist))
          ? mediaStore.artist
          : null;
      final String? msAlbum = (mediaStore?.album != null && !AudioNameSanitizer.isJunkArtist(mediaStore!.album))
          ? mediaStore.album
          : null;

      final String fnTitle = filenameParsed.title;
      final String fnArtist = filenameParsed.artist;
      final String? fnAlbum = filenameParsed.album;

      // ── Strategy: Cross-validate ID3 against MediaStore and filename ──
      // If ID3 has both title and artist, check if they might be swapped
      // by comparing against what the filename and MediaStore say.
      if (id3Title != null && id3Artist != null) {
        // Check if ID3 title/artist are reversed compared to other sources
        final bool filenameContradicts = _metadataContradicts(
          id3Title: id3Title,
          id3Artist: id3Artist,
          otherTitle: fnTitle,
          otherArtist: fnArtist,
        );
        final bool mediaStoreContradicts = msTitle != null && msArtist != null && _metadataContradicts(
          id3Title: id3Title,
          id3Artist: id3Artist,
          otherTitle: msTitle,
          otherArtist: msArtist,
        );

        if (filenameContradicts || mediaStoreContradicts) {
          // Two sources agree the tags are wrong. Use MediaStore if available, else filename.
          if (msTitle != null && msArtist != null) {
            title = msTitle;
            artist = msArtist;
          } else {
            title = fnTitle;
            artist = fnArtist;
          }
        } else {
          // ID3 tags seem consistent with other sources, use them
          title = id3Title;
          artist = id3Artist;
        }
      } else if (id3Title != null && id3Artist == null) {
        // ID3 has title but no artist
        title = id3Title;
        // Try to get artist from MediaStore, then filename
        artist = msArtist ?? fnArtist;
      } else if (id3Title == null && id3Artist != null) {
        // ID3 has artist but no title - get title from MediaStore or filename
        artist = id3Artist;
        title = msTitle ?? fnTitle;
      } else {
        // No useful ID3 data - prefer MediaStore, fall back to filename
        if (msTitle != null && msTitle.isNotEmpty) {
          title = msTitle;
          artist = msArtist ?? fnArtist;
        } else {
          title = fnTitle;
          artist = fnArtist;
        }
      }

      // ── Resolve album ──
      album = id3Album ?? msAlbum ?? fnAlbum;

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

      // If artist is still missing, try to extract from filename
      if (artist.isEmpty || AudioNameSanitizer.isJunkArtist(artist)) {
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

      // ── Final disambiguation pass ──
      final disambiguated = AudioNameSanitizer.disambiguateTitleAndArtist(
        title: title,
        artist: artist,
        album: album,
      );
      title = disambiguated.title;
      artist = disambiguated.artist;
      album = disambiguated.album ?? album;

      // ── Extract and cache album artwork if present ──
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

      // ── Resolve duration: prefer MediaStore > ID3 > WAV estimate ──
      int durationMs = mediaStore?.durationMs ?? id3?.durationMs ?? 0;
      if (durationMs <= 0 && ext == 'wav' && stat.size > 44) {
        durationMs = (((stat.size - 44) / 176400) * 1000).round();
      }

      // If duration is unknown, estimate from file size assuming ~128kbps (16000 bytes/sec)
      if (durationMs <= 0 && stat.size > 2048) {
        durationMs = ((stat.size / 16000) * 1000).round();
      }

      // Ignore corrupted or completely empty files (< 1KB)
      if (durationMs < 0 || stat.size < 1024) {
        return null;
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

  /// Checks if one metadata source contradicts another (title/artist appear swapped).
  /// Returns true if the ID3 title matches the other's artist AND the ID3 artist matches the other's title.
  static bool _metadataContradicts({
    required String id3Title,
    required String id3Artist,
    required String otherTitle,
    required String otherArtist,
  }) {
    if (otherTitle.isEmpty || otherArtist.isEmpty ||
        otherArtist == 'Unknown Artist') {
      return false;
    }

    final id3TitleLower = id3Title.toLowerCase().trim();
    final id3ArtistLower = id3Artist.toLowerCase().trim();
    final otherTitleLower = otherTitle.toLowerCase().trim();
    final otherArtistLower = otherArtist.toLowerCase().trim();

    // Direct swap: ID3 title == other artist AND ID3 artist == other title
    if (_fuzzyMatch(id3TitleLower, otherArtistLower) &&
        _fuzzyMatch(id3ArtistLower, otherTitleLower)) {
      return true;
    }

    // Partial swap: ID3 title contains the other's artist name as a significant portion
    if (_fuzzyMatch(id3TitleLower, otherArtistLower) &&
        !_fuzzyMatch(id3TitleLower, otherTitleLower)) {
      // The ID3 title looks more like the other source's artist
      // Check via artist scoring
      final titleAsArtistScore = AudioNameSanitizer.calculateArtistScore(id3Title);
      final artistAsArtistScore = AudioNameSanitizer.calculateArtistScore(id3Artist);
      if (titleAsArtistScore > artistAsArtistScore && titleAsArtistScore >= 10) {
        return true;
      }
    }

    return false;
  }

  /// Fuzzy string matching: checks if strings are similar enough to be considered the same.
  static bool _fuzzyMatch(String a, String b) {
    if (a == b) return true;
    if (a.isEmpty || b.isEmpty) return false;

    // Normalise: remove common separators and extra spaces
    final normA = a.replaceAll(RegExp(r'[\s_\-\.]+'), ' ').trim();
    final normB = b.replaceAll(RegExp(r'[\s_\-\.]+'), ' ').trim();
    if (normA == normB) return true;

    // One contains the other
    if (normA.contains(normB) || normB.contains(normA)) return true;

    return false;
  }
}

