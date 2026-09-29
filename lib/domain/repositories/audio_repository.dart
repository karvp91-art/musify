import '../models/track.dart';
import '../models/playlist.dart';

abstract class AudioRepository {
  Future<List<Track>> getLocalTracks();
  Future<void> rescanLocalTracks();
  Future<List<Track>> getLikedTracks();
  Future<void> toggleLike(Track track);
  Future<bool> isTrackLiked(String trackId);
  Future<List<Playlist>> getPlaylists();
  Future<Playlist> createPlaylist(String name, {String? description});
  Future<void> deletePlaylist(String playlistId);
  Future<void> addTrackToPlaylist(String playlistId, Track track);
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId);
  Future<List<Track>> getPlaylistTracks(String playlistId);
  Future<List<Track>> searchTracks(String query);
  Stream<List<Track>> watchLikedTracks();
  Stream<List<Playlist>> watchPlaylists();
  Future<void> recordTrackPlay(Track track, {int durationListenedMs = 0, bool completed = false});
  Future<Map<String, int>> getTrackPlayCounts();
  Stream<Map<String, int>> watchTrackPlayCounts();
}
