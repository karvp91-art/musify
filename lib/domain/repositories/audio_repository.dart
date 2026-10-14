import '../models/track.dart';
import '../models/playlist.dart';

abstract class AudioRepository {
  Future<List<Track>> getLocalTracks();
  Stream<List<Track>> watchLocalTracks();
  Future<void> rescanLocalTracks();
  Future<void> saveDownloadedTrack(Track track, {required String filePath, required int fileSizeBytes});
  Future<void> removeDownloadedTrack(String trackId);
  Future<bool> deleteTrack(Track track);
  Future<void> updateTrackMetadata(String trackId, {String? title, String? artistName, String? albumTitle});
  Future<void> updateTrackArtwork(String trackId, String artworkUrl);
  Future<void> updateTrackDuration(String trackId, int durationMs);
  Future<List<Track>> getLikedTracks();
  Future<void> toggleLike(Track track);
  Future<bool> isTrackLiked(String trackId);
  Future<List<Playlist>> getPlaylists();
  Future<Playlist> createPlaylist(String name, {String? description});
  Future<void> updatePlaylist(String playlistId, {required String name, String? description});
  Future<void> deletePlaylist(String playlistId);
  Future<void> addTrackToPlaylist(String playlistId, Track track);
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId);
  Future<void> reorderPlaylistTracks(String playlistId, List<String> orderedTrackIds);
  Future<List<Track>> getPlaylistTracks(String playlistId);
  Stream<List<Track>> watchPlaylistTracks(String playlistId);
  Future<Set<String>> getPlaylistIdsForTrack(String trackId);
  Future<bool> toggleTrackInPlaylist(String playlistId, Track track);
  Future<List<Track>> searchTracks(String query);
  Stream<List<Track>> watchLikedTracks();
  Stream<List<Playlist>> watchPlaylists();
  Future<void> recordTrackPlay(Track track, {int durationListenedMs = 0, bool completed = false});
  Future<Map<String, int>> getTrackPlayCounts();
  Stream<Map<String, int>> watchTrackPlayCounts();
  Future<List<Track>> getRecentlyPlayedTracks({int limit = 20});
  Stream<List<Track>> watchRecentlyPlayedTracks({int limit = 20});
}

