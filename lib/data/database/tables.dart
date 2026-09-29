import 'package:drift/drift.dart';

class LocalTracks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artistName => text()();
  TextColumn get albumTitle => text().nullable()();
  TextColumn get albumId => text().nullable()();
  TextColumn get artistId => text().nullable()();
  TextColumn get source => text()();
  TextColumn get sourceId => text()();
  IntColumn get durationMs => integer()();
  TextColumn get artworkUrl => text().nullable()();
  TextColumn get audioUrl => text()();
  TextColumn get filePath => text().nullable()();
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get codec => text().withDefault(const Constant('mp3'))();
  IntColumn get bitrate => integer().withDefault(const Constant(320))();
  BoolColumn get isLiked => boolean().withDefault(const Constant(false))();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  BoolColumn get isCollaborative => boolean().withDefault(const Constant(false))();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class PlaylistTracks extends Table {
  TextColumn get playlistId => text()();
  TextColumn get trackId => text()();
  IntColumn get position => integer()();
  DateTimeColumn get addedAt => dateTime()();
  TextColumn get addedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {playlistId, trackId};
}

class ListeningHistory extends Table {
  TextColumn get id => text()();
  TextColumn get trackId => text()();
  DateTimeColumn get playedAt => dateTime()();
  IntColumn get durationListenedMs => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
