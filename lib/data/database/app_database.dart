import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [LocalTracks, Playlists, PlaylistTracks, ListeningHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndices();
        },
        beforeOpen: (details) async {
          await _createIndices();
        },
      );

  Future<void> _createIndices() async {
    await customStatement('CREATE INDEX IF NOT EXISTS idx_local_tracks_source ON local_tracks (source);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_local_tracks_is_liked ON local_tracks (is_liked);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_local_tracks_added_at ON local_tracks (added_at);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_listening_history_track_id ON listening_history (track_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist_id ON playlist_tracks (playlist_id);');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'musify.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
