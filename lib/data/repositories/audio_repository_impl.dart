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

  @override
  Future<List<Track>> getLocalTracks() async {
    final query = _db.select(_db.localTracks)
      ..where((tbl) => tbl.source.equals(AudioSourceType.local.name))
      ..orderBy([(t) => OrderingTerm.asc(t.title)]);
    final rows = await query.get();
    return rows.map(_toDomainTrack).toList();
  }

  @override
  Future<void> rescanLocalTracks() async {
    // Local device scan logic is coordinated with file scanner
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
    return rows.map((p) => Playlist(
      id: p.id,
      name: p.name,
      description: p.description,
      coverUrl: p.coverUrl,
      isCollaborative: p.isCollaborative,
      isDownloaded: p.isDownloaded,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    )).toList();
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
    final query = _db.select(_db.playlists)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map((rows) => rows.map((p) => Playlist(
      id: p.id,
      name: p.name,
      description: p.description,
      coverUrl: p.coverUrl,
      isCollaborative: p.isCollaborative,
      isDownloaded: p.isDownloaded,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    )).toList());
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
}
