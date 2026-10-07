import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:musify/core/utils/audio_name_sanitizer.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/repositories/audio_repository.dart';
import '../database/app_database.dart' hide Playlist;

class AudioRepositoryImpl implements AudioRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  AudioRepositoryImpl(this._db);

  Track _toDomainTrack(LocalTrack item) {
    var title = item.title;
    var artist = item.artistName;
    var album = item.albumTitle;

    if (item.source == AudioSourceType.local.name) {
      if (AudioNameSanitizer.isBitrateOrQuality(title) || AudioNameSanitizer.isJunkTitle(title)) {
        // Automatically recover original title from filePath if it was corrupted to a bitrate (e.g. "256k")
        if (item.filePath != null && item.filePath!.isNotEmpty) {
          final fileName = p.basenameWithoutExtension(item.filePath!);
          final parent = p.basename(p.dirname(item.filePath!));
          final parsed = AudioNameSanitizer.parseFileName(fileName, folderName: parent);
          title = parsed.title;
          if (artist == 'Unknown Artist' ||
              AudioNameSanitizer.isJunkArtist(artist) ||
              AudioNameSanitizer.isBitrateOrQuality(artist)) {
            artist = parsed.artist;
          }
        }
      }

      final disambiguated = AudioNameSanitizer.disambiguateTitleAndArtist(
        title: title,
        artist: artist,
        album: album,
      );
      title = disambiguated.title;
      artist = disambiguated.artist;
      album = disambiguated.album ?? album;

      if (title != item.title || artist != item.artistName) {
        // Correct the stored database record asynchronously
        _db.update(_db.localTracks)
          ..where((tbl) => tbl.id.equals(item.id))
          ..write(LocalTracksCompanion(
            title: Value(title),
            artistName: Value(artist),
            albumTitle: Value(album),
          ));
      }
    }

    return Track(
      id: item.id,
      title: title,
      artistName: artist,
      albumTitle: album,
      albumId: item.albumId,
      artistId: item.artistId,
      source: AudioSourceType.values.firstWhere(
        (e) => e.name == item.source,
        orElse: () => AudioSourceType.local,
      ),
      sourceId: item.sourceId,
      durationMs: item.durationMs,
      artworkUrl: item.artworkUrl,
      audioUrl: item.audioUrl,
      filePath: item.filePath,
      fileSizeBytes: item.fileSizeBytes,
      codec: item.codec,
      bitrate: item.bitrate,
      isLiked: item.isLiked,
      isDownloaded: item.isDownloaded,
      addedAt: item.addedAt,
    );
  }

  LocalTracksCompanion _toCompanion(Track track) {
    return LocalTracksCompanion(
      id: Value(track.id),
      title: Value(track.title),
      artistName: Value(track.artistName),
      albumTitle: Value(track.albumTitle),
      albumId: Value(track.albumId),
      artistId: Value(track.artistId),
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
      isDownloaded: Value(track.isDownloaded),
      addedAt: Value(track.addedAt),
    );
  }

  bool _cleanedUpBogusTracks = false;
  Future<void> _cleanCorruptedDownloadArtifacts() async {
    if (_cleanedUpBogusTracks) return;
    _cleanedUpBogusTracks = true;
    try {
      await (_db.delete(_db.localTracks)
            ..where((tbl) =>
                tbl.title.equals('musify downloads') |
                (tbl.source.equals('local') & tbl.filePath.like('%musify_downloads%'))))
          .go();
      // Remove any duplicate local track pointing to a file path owned by an online/downloaded track
      await _db.customStatement(
        "DELETE FROM local_tracks WHERE source = 'local' AND file_path IN ("
        "  SELECT file_path FROM local_tracks WHERE source != 'local' AND file_path IS NOT NULL AND file_path != ''"
        ");",
      );
    } catch (_) {}
  }

  String _normalizeFilePath(String path) {
    var norm = p.normalize(path).replaceAll(r'\', '/');
    if (norm.startsWith('/sdcard/')) {
      norm = '/storage/emulated/0/${norm.substring(8)}';
    }
    return norm.toLowerCase();
  }

  List<Track> _deduplicateTracks(List<Track> tracks) {
    final seenPaths = <String, Track>{};
    final seenSignatures = <String, Track>{};
    final unique = <Track>[];

    for (final t in tracks) {
      final normPath = t.filePath != null && t.filePath!.isNotEmpty
          ? _normalizeFilePath(t.filePath!)
          : '';
      final sig = '${t.title.trim().toLowerCase()}_${(t.durationMs / 1000).round()}';

      Track? existing;
      if (normPath.isNotEmpty && seenPaths.containsKey(normPath)) {
        existing = seenPaths[normPath];
      } else if (sig.isNotEmpty && t.durationMs > 5000 && seenSignatures.containsKey(sig)) {
        existing = seenSignatures[sig];
      }

      if (existing == null) {
        if (normPath.isNotEmpty) seenPaths[normPath] = t;
        if (sig.isNotEmpty) seenSignatures[sig] = t;
        unique.add(t);
      } else {
        // If an entry is already present, prefer the richer online track (e.g. YouTube/JioSaavn with artwork & artist)
        final idx = unique.indexOf(existing);
        if (existing.source == AudioSourceType.local && t.source != AudioSourceType.local) {
          if (idx != -1) unique[idx] = t;
          if (normPath.isNotEmpty) seenPaths[normPath] = t;
          if (sig.isNotEmpty) seenSignatures[sig] = t;
        } else if (existing.artistName == 'Unknown Artist' && t.artistName != 'Unknown Artist') {
          if (idx != -1) unique[idx] = t;
          if (normPath.isNotEmpty) seenPaths[normPath] = t;
          if (sig.isNotEmpty) seenSignatures[sig] = t;
        }
      }
    }
    return unique;
  }

  @override
  Future<List<Track>> getLocalTracks() async {
    await _cleanCorruptedDownloadArtifacts();
    final query = _db.select(_db.localTracks)
      ..where((tbl) =>
          (tbl.source.equals(AudioSourceType.local.name) | tbl.isDownloaded.equals(true)) &
          tbl.title.isNotValue('musify downloads'))
      ..orderBy([(t) => OrderingTerm.asc(t.title)]);
    final rows = await query.get();
    final tracks = rows
        .map(_toDomainTrack)
        .where((t) => !(t.source == AudioSourceType.local && (t.filePath?.contains('musify_downloads') ?? false)))
        .toList();
    return _deduplicateTracks(tracks);
  }

  @override
  Stream<List<Track>> watchLocalTracks() {
    _cleanCorruptedDownloadArtifacts();
    final query = _db.select(_db.localTracks)
      ..where((tbl) =>
          (tbl.source.equals(AudioSourceType.local.name) | tbl.isDownloaded.equals(true)) &
          tbl.title.isNotValue('musify downloads'))
      ..orderBy([(t) => OrderingTerm.asc(t.title)]);
    return query.watch().map((rows) {
      final tracks = rows
          .map(_toDomainTrack)
          .where((t) => !(t.source == AudioSourceType.local && (t.filePath?.contains('musify_downloads') ?? false)))
          .toList();
      return _deduplicateTracks(tracks);
    });
  }

  @override
  Future<void> rescanLocalTracks() async {
    // Local device scan logic is coordinated with file scanner
  }

  @override
  Future<void> saveDownloadedTrack(Track track, {required String filePath, required int fileSizeBytes}) async {
    final updated = track.copyWith(
      filePath: filePath,
      fileSizeBytes: fileSizeBytes,
      isDownloaded: true,
      addedAt: DateTime.now(),
    );
    // Delete any duplicate local file entry that points to this exact physical file
    try {
      await (_db.delete(_db.localTracks)
            ..where((tbl) => tbl.filePath.equals(filePath) & tbl.id.isNotValue(updated.id)))
          .go();
    } catch (_) {}
    await _db.into(_db.localTracks).insert(
      _toCompanion(updated),
      mode: InsertMode.insertOrReplace,
    );
  }

  @override
  Future<void> removeDownloadedTrack(String trackId) async {
    final row = await (_db.select(_db.localTracks)..where((tbl) => tbl.id.equals(trackId))).getSingleOrNull();
    if (row != null) {
      if (row.filePath != null && row.filePath!.isNotEmpty) {
        final file = File(row.filePath!);
        if (file.existsSync()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
      final inPlaylists = await (_db.select(_db.playlistTracks)..where((tbl) => tbl.trackId.equals(trackId))).get();
      if (row.source == AudioSourceType.local.name || (!row.isLiked && inPlaylists.isEmpty)) {
        await (_db.delete(_db.localTracks)..where((tbl) => tbl.id.equals(trackId))).go();
      } else {
        await (_db.update(_db.localTracks)..where((tbl) => tbl.id.equals(trackId))).write(
          const LocalTracksCompanion(
            isDownloaded: Value(false),
            filePath: Value(null),
          ),
        );
      }
    }
  }

  @override
  Future<bool> deleteTrack(Track track) async {
    bool fileDeleted = true;
    if (track.filePath != null && track.filePath!.isNotEmpty) {
      final file = File(track.filePath!);
      if (file.existsSync()) {
        try {
          await file.delete();
          if (file.existsSync()) {
            fileDeleted = false;
          }
        } catch (_) {
          fileDeleted = false;
        }
      }
    }

    if (fileDeleted) {
      await (_db.delete(_db.playlistTracks)..where((tbl) => tbl.trackId.equals(track.id))).go();
      await (_db.delete(_db.listeningHistory)..where((tbl) => tbl.trackId.equals(track.id))).go();
      await (_db.delete(_db.localTracks)..where((tbl) => tbl.id.equals(track.id))).go();
      return true;
    }
    return false;
  }

  @override
  Future<void> updateTrackMetadata(String trackId, {String? title, String? artistName, String? albumTitle}) async {
    final updates = <String, Value>{};
    if (title != null) updates['title'] = Value(title);
    if (artistName != null) updates['artistName'] = Value(artistName);
    if (albumTitle != null) updates['albumTitle'] = Value(albumTitle);

    if (updates.isEmpty) return;

    await (_db.update(_db.localTracks)..where((tbl) => tbl.id.equals(trackId))).write(
      LocalTracksCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        artistName: artistName != null ? Value(artistName) : const Value.absent(),
        albumTitle: albumTitle != null ? Value(albumTitle) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> updateTrackArtwork(String trackId, String artworkUrl) async {
    await (_db.update(_db.localTracks)..where((tbl) => tbl.id.equals(trackId))).write(
      LocalTracksCompanion(
        artworkUrl: Value(artworkUrl),
      ),
    );
  }

  @override
  Future<List<Track>> getLikedTracks() async {
    final query = _db.select(_db.localTracks)
      ..where((tbl) => tbl.isLiked.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]);
    final rows = await query.get();
    return rows.map(_toDomainTrack).toList();
  }

  @override
  Future<void> toggleLike(Track track) async {
    final existing = await (_db.select(_db.localTracks)..where((tbl) => tbl.id.equals(track.id))).getSingleOrNull();
    final newLiked = !(existing?.isLiked ?? track.isLiked);

    if (existing != null) {
      await (_db.update(_db.localTracks)..where((tbl) => tbl.id.equals(track.id))).write(
        LocalTracksCompanion(isLiked: Value(newLiked)),
      );
    } else {
      await _db.into(_db.localTracks).insert(
        _toCompanion(track.copyWith(isLiked: newLiked)),
        mode: InsertMode.insertOrReplace,
      );
    }
  }

  @override
  Future<bool> isTrackLiked(String trackId) async {
    final track = await (_db.select(_db.localTracks)..where((tbl) => tbl.id.equals(trackId))).getSingleOrNull();
    return track?.isLiked ?? false;
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    final rows = await (_db.select(_db.playlists)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
    final playlists = <Playlist>[];
    for (final p in rows) {
      final tracks = await getPlaylistTracks(p.id);
      playlists.add(Playlist(
        id: p.id,
        name: p.name,
        description: p.description,
        coverUrl: p.coverUrl,
        isCollaborative: p.isCollaborative,
        isDownloaded: p.isDownloaded,
        tracks: tracks,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      ));
    }
    return playlists;
  }

  @override
  Future<Playlist> createPlaylist(String name, {String? description}) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final entry = PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await _db.into(_db.playlists).insert(entry);
    return Playlist(
      id: id,
      name: name,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> updatePlaylist(String playlistId, {required String name, String? description}) async {
    await (_db.update(_db.playlists)..where((tbl) => tbl.id.equals(playlistId))).write(
      PlaylistsCompanion(
        name: Value(name),
        description: Value(description),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await (_db.delete(_db.playlistTracks)..where((tbl) => tbl.playlistId.equals(playlistId))).go();
    await (_db.delete(_db.playlists)..where((tbl) => tbl.id.equals(playlistId))).go();
  }

  @override
  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    // Ensure track exists in localTracks table
    await _db.into(_db.localTracks).insert(
      _toCompanion(track),
      mode: InsertMode.insertOrReplace,
    );

    // Get max position
    final tracksInPlaylist = await (_db.select(_db.playlistTracks)
      ..where((tbl) => tbl.playlistId.equals(playlistId))).get();
    final nextPosition = tracksInPlaylist.length;

    await _db.into(_db.playlistTracks).insert(
      PlaylistTracksCompanion(
        playlistId: Value(playlistId),
        trackId: Value(track.id),
        position: Value(nextPosition),
        addedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );

    // Update playlist updatedAt
    await (_db.update(_db.playlists)..where((tbl) => tbl.id.equals(playlistId))).write(
      PlaylistsCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await (_db.delete(_db.playlistTracks)
      ..where((tbl) => tbl.playlistId.equals(playlistId) & tbl.trackId.equals(trackId))).go();

    await (_db.update(_db.playlists)..where((tbl) => tbl.id.equals(playlistId))).write(
      PlaylistsCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> reorderPlaylistTracks(String playlistId, List<String> orderedTrackIds) async {
    await _db.transaction(() async {
      for (int i = 0; i < orderedTrackIds.length; i++) {
        await (_db.update(_db.playlistTracks)
              ..where((tbl) => tbl.playlistId.equals(playlistId) & tbl.trackId.equals(orderedTrackIds[i])))
            .write(PlaylistTracksCompanion(position: Value(i)));
      }
      await (_db.update(_db.playlists)..where((tbl) => tbl.id.equals(playlistId))).write(
        PlaylistsCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    final query = _db.select(_db.playlistTracks).join([
      innerJoin(_db.localTracks, _db.localTracks.id.equalsExp(_db.playlistTracks.trackId)),
    ])
      ..where(_db.playlistTracks.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(_db.playlistTracks.position)]);

    final rows = await query.get();
    return rows.map((row) {
      final localTrack = row.readTable(_db.localTracks);
      return _toDomainTrack(localTrack);
    }).toList();
  }

  @override
  Stream<List<Track>> watchPlaylistTracks(String playlistId) {
    final query = _db.select(_db.playlistTracks).join([
      innerJoin(_db.localTracks, _db.localTracks.id.equalsExp(_db.playlistTracks.trackId)),
    ])
      ..where(_db.playlistTracks.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(_db.playlistTracks.position)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final localTrack = row.readTable(_db.localTracks);
        return _toDomainTrack(localTrack);
      }).toList();
    });
  }

  @override
  Future<Set<String>> getPlaylistIdsForTrack(String trackId) async {
    final rows = await (_db.select(_db.playlistTracks)
      ..where((tbl) => tbl.trackId.equals(trackId))).get();
    return rows.map((r) => r.playlistId).toSet();
  }

  @override
  Future<bool> toggleTrackInPlaylist(String playlistId, Track track) async {
    final existing = await (_db.select(_db.playlistTracks)
      ..where((tbl) => tbl.playlistId.equals(playlistId) & tbl.trackId.equals(track.id))).getSingleOrNull();

    if (existing != null) {
      await removeTrackFromPlaylist(playlistId, track.id);
      return false; // Removed
    } else {
      await addTrackToPlaylist(playlistId, track);
      return true; // Added
    }
  }

  @override
  Future<List<Track>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];
    final searchPattern = '%$query%';
    final rows = await (_db.select(_db.localTracks)
      ..where((tbl) => tbl.title.like(searchPattern) | tbl.artistName.like(searchPattern) | tbl.albumTitle.like(searchPattern))
      ..limit(50)).get();
    return rows.map(_toDomainTrack).toList();
  }

  @override
  Stream<List<Track>> watchLikedTracks() {
    final query = _db.select(_db.localTracks)
      ..where((tbl) => tbl.isLiked.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]);
    return query.watch().map((rows) => rows.map(_toDomainTrack).toList());
  }

  @override
  Stream<List<Playlist>> watchPlaylists() {
    final query = _db.select(_db.playlists).join([
      leftOuterJoin(_db.playlistTracks, _db.playlistTracks.playlistId.equalsExp(_db.playlists.id)),
    ])..orderBy([OrderingTerm.desc(_db.playlists.updatedAt)]);

    return query.watch().asyncMap((_) async {
      return getPlaylists();
    });
  }

  @override
  Future<void> recordTrackPlay(Track track, {int durationListenedMs = 0, bool completed = false}) async {
    await _db.into(_db.localTracks).insert(
      _toCompanion(track),
      mode: InsertMode.insertOrReplace,
    );

    await _db.into(_db.listeningHistory).insert(
      ListeningHistoryCompanion(
        id: Value(_uuid.v4()),
        trackId: Value(track.id),
        playedAt: Value(DateTime.now()),
        durationListenedMs: Value(durationListenedMs),
        completed: Value(completed),
      ),
    );
  }

  @override
  Future<Map<String, int>> getTrackPlayCounts() async {
    final countCol = _db.listeningHistory.id.count();
    final query = _db.selectOnly(_db.listeningHistory)
      ..addColumns([_db.listeningHistory.trackId, countCol])
      ..groupBy([_db.listeningHistory.trackId]);

    final rows = await query.get();
    final Map<String, int> counts = {};
    for (final row in rows) {
      final trackId = row.read(_db.listeningHistory.trackId);
      final count = row.read(countCol);
      if (trackId != null && count != null) {
        counts[trackId] = count;
      }
    }
    return counts;
  }

  @override
  Stream<Map<String, int>> watchTrackPlayCounts() {
    final countCol = _db.listeningHistory.id.count();
    final query = _db.selectOnly(_db.listeningHistory)
      ..addColumns([_db.listeningHistory.trackId, countCol])
      ..groupBy([_db.listeningHistory.trackId]);

    return query.watch().map((rows) {
      final Map<String, int> counts = {};
      for (final row in rows) {
        final trackId = row.read(_db.listeningHistory.trackId);
        final count = row.read(countCol);
        if (trackId != null && count != null) {
          counts[trackId] = count;
        }
      }
      return counts;
    });
  }

  @override
  Future<List<Track>> getRecentlyPlayedTracks({int limit = 20}) async {
    final query = _db.select(_db.listeningHistory).join([
      innerJoin(_db.localTracks, _db.localTracks.id.equalsExp(_db.listeningHistory.trackId)),
    ])
      ..orderBy([OrderingTerm.desc(_db.listeningHistory.playedAt)])
      ..limit(limit * 2);

    final rows = await query.get();
    final seen = <String>{};
    final tracks = <Track>[];
    for (final row in rows) {
      final trackData = row.readTable(_db.localTracks);
      if (seen.add(trackData.id)) {
        tracks.add(_toDomainTrack(trackData));
        if (tracks.length >= limit) break;
      }
    }
    return tracks;
  }

  @override
  Stream<List<Track>> watchRecentlyPlayedTracks({int limit = 20}) {
    final query = _db.select(_db.listeningHistory).join([
      innerJoin(_db.localTracks, _db.localTracks.id.equalsExp(_db.listeningHistory.trackId)),
    ])
      ..orderBy([OrderingTerm.desc(_db.listeningHistory.playedAt)])
      ..limit(limit * 2);

    return query.watch().map((rows) {
      final seen = <String>{};
      final tracks = <Track>[];
      for (final row in rows) {
        final trackData = row.readTable(_db.localTracks);
        if (seen.add(trackData.id)) {
          tracks.add(_toDomainTrack(trackData));
          if (tracks.length >= limit) break;
        }
      }
      return tracks;
    });
  }
}

