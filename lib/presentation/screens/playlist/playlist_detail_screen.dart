import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/add_songs_to_playlist_modal.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';
import 'package:musify/presentation/widgets/download_dynamic_island.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/playlist_artwork.dart';
import 'package:musify/presentation/widgets/shimmer_skeleton.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/screens/player/now_playing_screen.dart';

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

/// Playlist Detail screen.
///
/// Design: the first track's artwork color washes the top of the page and
/// dissolves into the background, so the playlist cover is the one bold
/// element. Everything else is quiet:
/// - Top bar: back + 3-dot menu (search / reorder / edit / delete)
/// - Hero: centered cover, title, meta, description, owner
/// - Actions: like + download on the left, shuffle + large play on the right
/// - "Add songs" tile
/// - Track rows: artwork, title, "Artist • duration", current-track indicator
/// - Multi-selection, in-playlist search, reorder and filters are preserved
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final String title;
  final String? subtitle;
  final Playlist? playlist;
  final bool isLikedSongs;

  const PlaylistDetailScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.playlist,
    this.isLikedSongs = false,
  });

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late final TextEditingController _searchController;

  bool _isReordering = false;
  bool _isSearching = false;
  bool _downloadedOnly = false;
  String _searchFilter = '';
  List<Track>? _reorderList;

  bool _isSelectionMode = false;
  final Set<String> _selectedTrackIds = {};

  static const double _rowHeight = 72.0;

  // --- Theme helpers ---
  Color _surface(bool isDark) => isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
  Color _iconColor(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);
  Color _limeText(bool isDark) => isDark ? AppColors.neonLime : const Color(0xFF5F8F0E);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void deactivate() {
    if (_isSelectionMode) {
      ref.read(isMultiSelectionModeProvider.notifier).setMode(false);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSelectionMode(Track track) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedTrackIds.add(track.id);
    });
    ref.read(isMultiSelectionModeProvider.notifier).setMode(true);
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedTrackIds.clear();
    });
    ref.read(isMultiSelectionModeProvider.notifier).setMode(false);
  }

  // "3h 12m" / "45m"
  String _formatTotalDuration(List<Track> tracks) {
    int totalMs = 0;
    for (final t in tracks) {
      totalMs += t.durationMs;
    }
    final d = Duration(milliseconds: totalMs);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${d.inMinutes}m';
  }

  // "4:14"
  String _formatTrackDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showEditPlaylistDialog(Playlist playlist) {
    final nameController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description ?? '');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    InputDecoration deco(String hint, IconData icon) => InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: isDark ? const Color(0xFF20222B) : const Color(0xFFF3F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.neonLime, width: 2),
          ),
        );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _surface(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
          ),
        ),
        title: Text(
          'Edit playlist',
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.4,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: deco('Playlist name', Icons.queue_music_rounded),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              textCapitalization: TextCapitalization.sentences,
              decoration: deco('Description (optional)', Icons.description_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonLime,
              foregroundColor: const Color(0xFF111827),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await ref.read(audioRepositoryProvider).updatePlaylist(
                      playlist.id,
                      name: name,
                      description: descController.text.trim().isNotEmpty
                          ? descController.text.trim()
                          : null,
                    );
                ref.invalidate(playlistsStreamProvider);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              }
            },
            child: Text('Save', style: AppTypography.button.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(Playlist playlist) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Delete playlist?',
      description:
          'Are you sure you want to delete "${playlist.name}"? This action cannot be undone and your songs will remain in local music.',
      itemTitle: playlist.name,
      itemSubtitle: 'Playlist',
      itemLeading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF222533)
              : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.queue_music_rounded, size: 22, color: Color(0xFFFF4D6D)),
      ),
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      await ref.read(audioRepositoryProvider).deletePlaylist(playlist.id);
      ref.invalidate(playlistsStreamProvider);
      if (mounted) Navigator.pop(context);
    }
  }

  void _playAll(List<Track> tracks, {bool shuffle = false}) {
    if (tracks.isEmpty) return;
    HapticFeedback.mediumImpact();
    final audioHandler = ref.read(audioHandlerProvider);
    final list = shuffle ? (List<Track>.from(tracks)..shuffle()) : tracks;
    audioHandler.playTrackList(list, startIndex: 0);
    openNowPlayingScreen(context, targetTrack: list.first);
  }

  void _downloadAll(List<Track> tracks) {
    if (tracks.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'No songs available to download',
        type: AppSnackBarType.info,
      );
      return;
    }
    HapticFeedback.mediumImpact();
    final dm = ref.read(downloadManagerProvider);
    final toDownload = tracks
        .where((t) => !dm.isDownloaded(t.id) && !dm.isDownloading(t.id))
        .toList();

    if (toDownload.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'All songs in this playlist are already downloaded',
        type: AppSnackBarType.success,
        icon: Icons.download_done_rounded,
      );
      return;
    }

    for (final t in toDownload) {
      dm.downloadTrack(t);
    }
    AppSnackBar.show(
      context,
      message: 'Downloading ${toDownload.length} ${toDownload.length == 1 ? "song" : "songs"}...',
      type: AppSnackBarType.info,
      icon: Icons.file_download_outlined,
    );
  }

  void _onAddSongs(Playlist? currentPlaylist) {
    HapticFeedback.selectionClick();
    if (currentPlaylist != null) {
      showAddSongsToPlaylistModal(context, playlist: currentPlaylist);
    } else if (widget.isLikedSongs) {
      showQuickLikeTracksModal(context);
    }
  }

  // --- Multi-selection batch actions ---

  Future<void> _confirmBatchDeleteOrRemove(
    BuildContext context,
    Playlist? currentPlaylist,
    List<Track> allAvailableTracks,
  ) async {
    final selectedTracks =
        allAvailableTracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    if (selectedTracks.isEmpty) return;

    if (currentPlaylist != null) {
      final count = selectedTracks.length;
      for (final t in selectedTracks) {
        await ref.read(audioRepositoryProvider).removeTrackFromPlaylist(currentPlaylist.id, t.id);
      }
      ref.invalidate(playlistTracksProvider(currentPlaylist.id));
      _exitSelectionMode();
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Removed $count ${count == 1 ? "track" : "tracks"} from playlist',
          type: AppSnackBarType.info,
          icon: Icons.playlist_remove_rounded,
        );
      }
      return;
    }

    if (widget.isLikedSongs) {
      final repo = ref.read(audioRepositoryProvider);
      for (final t in selectedTracks) {
        await repo.toggleLike(t);
      }
      ref.invalidate(likedTracksStreamProvider);
      _exitSelectionMode();
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Removed ${selectedTracks.length} tracks from Liked Songs',
          type: AppSnackBarType.info,
          icon: Icons.favorite_border_rounded,
        );
      }
      return;
    }

    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Delete ${selectedTracks.length} ${selectedTracks.length == 1 ? "song" : "songs"}?',
      description:
          'Are you sure you want to permanently delete the selected ${selectedTracks.length} ${selectedTracks.length == 1 ? "track" : "tracks"} from your device? The audio files will be removed.',
      tracks: selectedTracks,
      confirmText: 'Delete (${selectedTracks.length})',
      cancelText: 'Cancel',
    );
    if (confirmed != true) return;

    final hasExternalStorageTrack = selectedTracks.any((t) {
      final p = t.filePath;
      return p != null && !p.toLowerCase().contains('musify') && p.isNotEmpty;
    });

    if (Platform.isAndroid && hasExternalStorageTrack) {
      var hasPermission = await Permission.manageExternalStorage.isGranted;
      if (!hasPermission) {
        final status = await Permission.manageExternalStorage.request();
        hasPermission = status.isGranted;
      }
      if (!hasPermission && context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Storage permission required to delete files from shared storage',
          type: AppSnackBarType.error,
          actionLabel: 'Settings',
          onAction: () => openAppSettings(),
        );
        return;
      }
    }

    final downloadManager = ref.read(downloadManagerProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    int deletedCount = 0;
    for (final track in selectedTracks) {
      final success = await downloadManager.deleteTrackPermanently(track);
      if (success) {
        await audioHandler.removeTrackById(track.id);
        deletedCount++;
      }
    }

    _exitSelectionMode();
    ref.invalidate(localTracksProvider);
    ref.invalidate(likedTracksStreamProvider);

    if (context.mounted && deletedCount > 0) {
      AppSnackBar.show(
        context,
        message:
            'Permanently deleted $deletedCount ${deletedCount == 1 ? "track" : "tracks"} from storage',
        type: AppSnackBarType.delete,
      );
    }
  }

  void _handleBatchDownload(List<Track> selectedTracks) {
    if (selectedTracks.isEmpty) return;
    final dm = ref.read(downloadManagerProvider);
    int count = 0;
    for (final track in selectedTracks) {
      if (!dm.isDownloaded(track.id) && !dm.isDownloading(track.id)) {
        dm.downloadTrack(track);
        count++;
      }
    }
    _exitSelectionMode();
    if (mounted) {
      AppSnackBar.show(
        context,
        message: count > 0
            ? 'Downloading $count ${count == 1 ? "song" : "songs"}...'
            : 'Selected songs are already downloaded',
        type: AppSnackBarType.info,
        icon: count > 0 ? Icons.file_download_outlined : Icons.download_done_rounded,
      );
    }
  }

  void _handleBatchAddToPlaylist(BuildContext context, List<Track> selectedTracks) {
    if (selectedTracks.isEmpty) return;
    showAddToPlaylistModal(
      context,
      ref,
      tracks: selectedTracks,
      onComplete: _exitSelectionMode,
    );
  }

  // --- Top bars ---

  Widget _buildTopBar(
    ThemeData theme,
    Playlist? currentPlaylist,
    List<Track> tracks,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final circleBg =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Row(
        children: [
          _GlassCircleButton(
            icon: Icons.arrow_back_rounded,
            size: 46,
            background: circleBg,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          if (_isReordering)
            TextButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                if (_reorderList != null && currentPlaylist != null) {
                  final newOrder = _reorderList!.map((t) => t.id).toList();
                  await ref
                      .read(audioRepositoryProvider)
                      .reorderPlaylistTracks(currentPlaylist.id, newOrder);
                  ref.invalidate(playlistTracksProvider(currentPlaylist.id));
                }
                setState(() => _isReordering = false);
              },
              child: Text(
                'Done',
                style: AppTypography.button.copyWith(
                  color: _limeText(isDark),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            )
          else
            Theme(
              data: theme.copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: _surface(isDark),
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  elevation: 10,
                ),
              ),
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: circleBg),
                  alignment: Alignment.center,
                  child: Icon(Icons.more_vert_rounded, size: 22, color: _iconColor(isDark)),
                ),
                onSelected: (val) {
                  HapticFeedback.selectionClick();
                  switch (val) {
                    case 'search':
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _searchFilter = '';
                        }
                      });
                      break;
                    case 'downloaded':
                      setState(() => _downloadedOnly = !_downloadedOnly);
                      break;
                    case 'add_songs':
                      _onAddSongs(currentPlaylist);
                      break;
                    case 'queue_all':
                      for (final t in tracks) {
                        ref.read(audioHandlerProvider).addToQueue(t);
                      }
                      AppSnackBar.show(
                        context,
                        message: 'Added ${tracks.length} songs to queue',
                        type: AppSnackBarType.info,
                        icon: Icons.queue_music_rounded,
                      );
                      break;
                    case 'add_all_playlist':
                      showAddToPlaylistModal(context, ref, tracks: tracks);
                      break;
                    case 'edit':
                      if (currentPlaylist != null) _showEditPlaylistDialog(currentPlaylist);
                      break;
                    case 'reorder':
                      setState(() {
                        _isReordering = true;
                        _reorderList = List.from(tracks);
                      });
                      break;
                    case 'delete':
                      if (currentPlaylist != null) _confirmDeletePlaylist(currentPlaylist);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (tracks.isNotEmpty)
                    PopupMenuItem(
                      value: 'search',
                      child: _menuRow(
                        Icons.search_rounded,
                        _isSearching ? 'Close search' : 'Search in playlist',
                      ),
                    ),
                  PopupMenuItem(
                    value: 'downloaded',
                    child: _menuRow(
                      _downloadedOnly ? Icons.check_box_rounded : Icons.download_done_rounded,
                      'Downloaded only',
                    ),
                  ),
                  if (currentPlaylist != null)
                    PopupMenuItem(
                      value: 'add_songs',
                      child: _menuRow(Icons.add_circle_outline_rounded, 'Add songs'),
                    ),
                  if (tracks.isNotEmpty)
                    PopupMenuItem(
                      value: 'queue_all',
                      child: _menuRow(Icons.queue_music_rounded, 'Add all to queue'),
                    ),
                  if (tracks.isNotEmpty)
                    PopupMenuItem(
                      value: 'add_all_playlist',
                      child: _menuRow(Icons.playlist_add_rounded, 'Add all to playlist'),
                    ),
                  if (currentPlaylist != null)
                    PopupMenuItem(value: 'edit', child: _menuRow(Icons.edit_outlined, 'Edit details')),
                  if (currentPlaylist != null && tracks.length > 1)
                    PopupMenuItem(
                      value: 'reorder',
                      child: _menuRow(Icons.reorder_rounded, 'Reorder tracks'),
                    ),
                  if (currentPlaylist != null) const PopupMenuDivider(height: 1),
                  if (currentPlaylist != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: _menuRow(
                        Icons.delete_outline_rounded,
                        'Delete playlist',
                        color: Colors.redAccent,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(
    ThemeData theme,
    Playlist? currentPlaylist,
    List<Track> currentVisibleTracks,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final allSelected = currentVisibleTracks.isNotEmpty &&
        currentVisibleTracks.every((t) => _selectedTrackIds.contains(t.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Row(
        children: [
          _GlassCircleButton(
            icon: Icons.close_rounded,
            size: 42,
            onTap: () {
              HapticFeedback.selectionClick();
              _exitSelectionMode();
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_selectedTrackIds.length} selected',
                style: AppTypography.headlineSmall.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GlassCircleButton(
                icon: allSelected ? Icons.check_box_rounded : Icons.checklist_rounded,
                size: 42,
                iconColor: allSelected ? _limeText(isDark) : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (allSelected) {
                      _selectedTrackIds.clear();
                    } else {
                      _selectedTrackIds.addAll(currentVisibleTracks.map((t) => t.id));
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              _GlassCircleButton(
                icon: currentPlaylist != null
                    ? Icons.playlist_remove_rounded
                    : Icons.delete_outline_rounded,
                size: 42,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _confirmBatchDeleteOrRemove(context, currentPlaylist, currentVisibleTracks);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchActionBar(
    ThemeData theme,
    Playlist? currentPlaylist,
    List<Track> currentVisibleTracks,
  ) {
    final selectedTracks =
        currentVisibleTracks.where((t) => _selectedTrackIds.contains(t.id)).toList();

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.neonLime,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonLime.withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (selectedTracks.isNotEmpty) ...[
              _buildStackedThumbnails(selectedTracks),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                '${selectedTracks.length} ${selectedTracks.length == 1 ? "song" : "songs"} selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.button.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCapsuleActionItem(
                  icon: Icons.file_download_outlined,
                  label: 'Download',
                  onTap: () => _handleBatchDownload(selectedTracks),
                ),
                const SizedBox(width: 14),
                _buildCapsuleActionItem(
                  icon: Icons.playlist_add_rounded,
                  label: 'Add to\nplaylist',
                  onTap: () => _handleBatchAddToPlaylist(context, selectedTracks),
                ),
                const SizedBox(width: 14),
                _buildCapsuleActionItem(
                  icon: currentPlaylist != null
                      ? Icons.playlist_remove_rounded
                      : Icons.delete_outline_rounded,
                  label: currentPlaylist != null ? 'Remove' : 'Delete',
                  onTap: () => _confirmBatchDeleteOrRemove(
                    context,
                    currentPlaylist,
                    currentVisibleTracks,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedThumbnails(List<Track> selectedTracks) {
    final t = selectedTracks.take(3).toList();
    return SizedBox(
      width: 50,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (t.length >= 3)
            Positioned(left: 0, child: Transform.rotate(angle: -0.20, child: _buildMiniArt(t[2]))),
          if (t.length >= 2)
            Positioned(left: 6, child: Transform.rotate(angle: 0.16, child: _buildMiniArt(t[1]))),
          Positioned(left: t.length > 1 ? 3 : 6, child: _buildMiniArt(t[0], isFront: true)),
        ],
      ),
    );
  }

  Widget _buildMiniArt(Track track, {bool isFront = false}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.black.withValues(alpha: isFront ? 0.40 : 0.20),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: TrackArtwork(
          artworkUrl: track.artworkUrl,
          seedKey: track.title,
          size: 36,
          borderRadius: BorderRadius.circular(7),
        ),
      ),
    );
  }

  Widget _buildCapsuleActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: const Color(0xFF111827)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: const Color(0xFF111827),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, String effectiveTitle) {
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: !_isSearching
          ? const SizedBox.shrink(key: ValueKey('search_collapsed'))
          : Padding(
              key: const ValueKey('search_expanded'),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _surface(isDark),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14.5,
                  ),
                  onChanged: (val) => setState(() => _searchFilter = val),
                  decoration: InputDecoration(
                    hintText: 'Search in $effectiveTitle',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    suffixIcon: _searchFilter.isNotEmpty
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchFilter = '');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
    );
  }

  // --- Hero: centered cover, then title and details ---

  Widget _buildHeader(
    ThemeData theme,
    Playlist? currentPlaylist,
    List<Track> tracks,
    String effectiveTitle,
    String? effectiveDesc,
    Color accent,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.58);
    final meta = tracks.isEmpty
        ? 'No songs yet'
        : '${tracks.length} ${tracks.length == 1 ? "song" : "songs"} • ${_formatTotalDuration(tracks)}';
    const coverSize = 208.0;
    final coverRadius = BorderRadius.circular(coverSize * 0.14);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
      child: Column(
        children: [
          // Cover with a single soft glow in the artwork's own color
          Container(
            decoration: BoxDecoration(
              borderRadius: coverRadius,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isDark ? 0.50 : 0.38),
                  blurRadius: 54,
                  spreadRadius: -2,
                  offset: const Offset(0, 22),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                  blurRadius: 24,
                  spreadRadius: -6,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: PlaylistArtwork(
              playlistId: currentPlaylist?.id,
              coverUrl: currentPlaylist?.coverUrl,
              preloadedTracks: tracks,
              isLikedSongs: widget.isLikedSongs,
              size: coverSize,
              borderRadius: coverRadius,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            effectiveTitle,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 30,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meta,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
          if (effectiveDesc != null && effectiveDesc.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              effectiveDesc.trim(),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 14.5,
                height: 1.35,
                fontWeight: FontWeight.w400,
                color: muted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF3A3D4A) : const Color(0xFF1E2028),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.person_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isLikedSongs
                    ? 'By you • Liked Songs'
                    : (currentPlaylist?.isCollaborative ?? false)
                        ? 'Collaborative • ${tracks.length} tracks'
                        : 'By you • Custom Playlist',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Like + download (left)  ·  shuffle + play (right) ---

  Widget _buildActionRow(
    ThemeData theme,
    Playlist? currentPlaylist,
    List<Track> tracks,
    bool isPlayingThisPlaylist,
    bool isPlaybackPlaying,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final nowPlaying = isPlayingThisPlaylist && isPlaybackPlaying;
    final isFav = currentPlaylist != null &&
        ref.watch(favoritePlaylistIdsProvider).contains(currentPlaylist.id);
    final hearted = widget.isLikedSongs || isFav;
    final disabled = tracks.isEmpty;
    final dm = ref.watch(downloadManagerProvider);
    final allDownloaded = tracks.isNotEmpty &&
        tracks.every((t) => dm.isDownloaded(t.id) || t.isDownloaded);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          _GlassCircleButton(
            icon: hearted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            iconColor: hearted ? const Color(0xFFFF4D6D) : null,
            size: 48,
            onTap: () async {
              if (widget.isLikedSongs) {
                AppSnackBar.show(
                  context,
                  message: 'Liked Songs is already your default favorites playlist',
                  type: AppSnackBarType.info,
                  icon: Icons.favorite_rounded,
                );
                return;
              }
              if (currentPlaylist != null) {
                HapticFeedback.selectionClick();
                final wasFav = ref.read(favoritePlaylistIdsProvider).contains(currentPlaylist.id);
                await ref
                    .read(favoritePlaylistIdsProvider.notifier)
                    .toggleFavorite(currentPlaylist.id);
                if (mounted) {
                  AppSnackBar.show(
                    context,
                    message: wasFav
                        ? 'Removed "${currentPlaylist.name}" from favorites'
                        : 'Saved "${currentPlaylist.name}" to favorites',
                    type: AppSnackBarType.info,
                    icon: wasFav ? Icons.favorite_border_rounded : Icons.favorite_rounded,
                  );
                }
              }
            },
          ),
          const SizedBox(width: 12),
          _GlassCircleButton(
            icon: allDownloaded
                ? Icons.download_done_rounded
                : Icons.download_for_offline_outlined,
            iconColor: allDownloaded ? _limeText(isDark) : null,
            size: 48,
            onTap: () => _downloadAll(tracks),
          ),
          const Spacer(),
          _GlassCircleButton(
            icon: Icons.shuffle_rounded,
            size: 52,
            onTap: disabled
                ? () {
                    AppSnackBar.show(
                      context,
                      message: 'Add songs to shuffle playback',
                      type: AppSnackBarType.info,
                    );
                  }
                : () => _playAll(tracks, shuffle: true),
          ),
          const SizedBox(width: 14),
          // Primary action: the one lime element on the page
          GestureDetector(
            onTap: disabled
                ? null
                : () {
                    if (nowPlaying) {
                      HapticFeedback.selectionClick();
                      ref.read(audioHandlerProvider).pause();
                    } else {
                      _playAll(tracks);
                    }
                  },
            child: AnimatedOpacity(
              opacity: disabled ? 0.4 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.neonLime,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonLime.withValues(alpha: 0.38),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    nowPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey(nowPlaying),
                    size: 38,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddSongsPill(ThemeData theme, Playlist? currentPlaylist) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onAddSongs(currentPlaylist),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _surface(isDark).withValues(alpha: isDark ? 0.7 : 0.8),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonLime.withValues(alpha: isDark ? 0.16 : 0.30),
                ),
                child: Icon(Icons.add_rounded, size: 24, color: _limeText(isDark)),
              ),
              const SizedBox(width: 14),
              Text(
                'Add songs',
                style: AppTypography.bodyLarge.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Track row: artwork | title + "Artist • 4:14" | trailing ---

  Widget _buildTrackRow({
    required ThemeData theme,
    required Track track,
    required bool isCurrent,
    required bool isPlaying,
    required Playlist? target,
    required VoidCallback onTap,
    Widget? trailingOverride,
    Key? key,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final isSelected = _selectedTrackIds.contains(track.id);
    final isLiked = ref.watch(likedTracksStreamProvider).value?.any((t) => t.id == track.id) ?? track.isLiked;
    final dm = ref.watch(downloadManagerProvider);
    final isDownloaded = dm.isDownloaded(track.id) || track.isDownloaded;

    Widget trailing;
    if (trailingOverride != null) {
      trailing = trailingOverride;
    } else if (_isSelectionMode) {
      trailing = Padding(
        padding: const EdgeInsets.all(10),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Icon(
            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            key: ValueKey(isSelected),
            size: 25,
            color: isSelected ? _limeText(isDark) : onSurface.withValues(alpha: 0.3),
          ),
        ),
      );
    } else {
      trailing = Theme(
        data: theme.copyWith(
          popupMenuTheme: PopupMenuThemeData(
            color: _surface(isDark),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 10,
          ),
        ),
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: Icon(Icons.more_vert_rounded, size: 22, color: onSurface.withValues(alpha: 0.6)),
          onSelected: (val) async {
            HapticFeedback.selectionClick();
            if (val == 'play_next') {
              ref.read(audioHandlerProvider).insertNextInQueue(track);
              if (mounted) {
                AppSnackBar.show(
                  context,
                  message: 'Playing "${track.title}" next',
                  type: AppSnackBarType.info,
                  icon: Icons.playlist_play_rounded,
                );
              }
            } else if (val == 'queue') {
              ref.read(audioHandlerProvider).addToQueue(track);
              if (mounted) {
                AppSnackBar.show(
                  context,
                  message: 'Added "${track.title}" to queue',
                  type: AppSnackBarType.info,
                  icon: Icons.queue_music_rounded,
                );
              }
            } else if (val == 'like') {
              final wasLiked = ref.read(likedTracksStreamProvider).value?.any((t) => t.id == track.id) ?? track.isLiked;
              await ref.read(audioRepositoryProvider).toggleLike(track);
              ref.invalidate(likedTracksStreamProvider);
              if (mounted) {
                AppSnackBar.show(
                  context,
                  message: wasLiked
                      ? 'Removed "${track.title}" from Liked Songs'
                      : 'Saved "${track.title}" to Liked Songs',
                  type: AppSnackBarType.info,
                  icon: wasLiked ? Icons.favorite_border_rounded : Icons.favorite_rounded,
                );
              }
            } else if (val == 'playlist') {
              showAddToPlaylistModal(context, ref, tracks: [track]);
            } else if (val == 'download') {
              if (isDownloaded) {
                AppSnackBar.show(
                  context,
                  message: '"${track.title}" is already downloaded',
                  type: AppSnackBarType.success,
                  icon: Icons.download_done_rounded,
                );
              } else {
                ref.read(downloadManagerProvider).downloadTrack(track);
                AppSnackBar.show(
                  context,
                  message: 'Downloading "${track.title}"...',
                  type: AppSnackBarType.info,
                  icon: Icons.file_download_outlined,
                );
              }
            } else if (val == 'select') {
              _enterSelectionMode(track);
            } else if (val == 'remove') {
              if (target != null) {
                await ref
                    .read(audioRepositoryProvider)
                    .removeTrackFromPlaylist(target.id, track.id);
                ref.invalidate(playlistTracksProvider(target.id));
                if (mounted) {
                  AppSnackBar.show(
                    context,
                    message: 'Removed "${track.title}" from playlist',
                    type: AppSnackBarType.info,
                    icon: Icons.playlist_remove_rounded,
                    actionLabel: 'Undo',
                    onAction: () async {
                      await ref
                          .read(audioRepositoryProvider)
                          .addTrackToPlaylist(target.id, track);
                      ref.invalidate(playlistTracksProvider(target.id));
                    },
                  );
                }
              } else if (widget.isLikedSongs) {
                await ref.read(audioRepositoryProvider).toggleLike(track);
                ref.invalidate(likedTracksStreamProvider);
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'play_next',
              child: _menuRow(Icons.playlist_play_rounded, 'Play next'),
            ),
            PopupMenuItem(
              value: 'queue',
              child: _menuRow(Icons.queue_music_rounded, 'Add to queue'),
            ),
            PopupMenuItem(
              value: 'like',
              child: _menuRow(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                isLiked ? 'Remove from Liked' : 'Save to Liked',
                color: isLiked ? const Color(0xFFFF4D6D) : null,
              ),
            ),
            PopupMenuItem(
              value: 'playlist',
              child: _menuRow(Icons.playlist_add_rounded, 'Add to playlist'),
            ),
            PopupMenuItem(
              value: 'download',
              child: _menuRow(
                isDownloaded ? Icons.download_done_rounded : Icons.file_download_outlined,
                isDownloaded ? 'Downloaded' : 'Download',
                color: isDownloaded ? _limeText(isDark) : null,
              ),
            ),
            PopupMenuItem(
              value: 'select',
              child: _menuRow(Icons.checklist_rounded, 'Select'),
            ),
            if (target != null || widget.isLikedSongs)
              PopupMenuItem(
                value: 'remove',
                child: _menuRow(
                  Icons.playlist_remove_rounded,
                  widget.isLikedSongs ? 'Remove from Liked' : 'Remove from playlist',
                  color: Colors.redAccent,
                ),
              ),
          ],
        ),
      );
    }

    return InkWell(
      key: key,
      onTap: onTap,
      onLongPress: _isSelectionMode ? null : () => _enterSelectionMode(track),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: _rowHeight,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? AppColors.neonLime.withValues(alpha: isDark ? 0.10 : 0.20)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TrackArtwork(
                    artworkUrl: track.artworkUrl,
                    seedKey: track.title,
                    size: 54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  if (isCurrent)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.black.withValues(alpha: 0.48),
                      ),
                      child: Icon(
                        isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                        size: 24,
                        color: AppColors.neonLime,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isCurrent ? _limeText(isDark) : onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${track.artistName} • ${_formatTrackDuration(track.durationMs)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.black : Colors.white;

    Playlist? currentPlaylist = widget.playlist;
    if (widget.playlist != null) {
      final playlists = ref.watch(playlistsStreamProvider).value;
      if (playlists != null) {
        for (final p in playlists) {
          if (p.id == widget.playlist!.id) {
            currentPlaylist = p;
            break;
          }
        }
      }
    }

    final effectiveTitle = currentPlaylist?.name ?? widget.title;
    final effectiveDesc = currentPlaylist?.description ?? widget.subtitle;

    final AsyncValue<List<Track>> tracksAsync;
    if (widget.isLikedSongs) {
      tracksAsync = ref.watch(likedTracksStreamProvider);
    } else if (widget.playlist != null) {
      tracksAsync = ref.watch(playlistTracksProvider(widget.playlist!.id));
    } else {
      tracksAsync = const AsyncData([]);
    }

    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaybackPlaying = ref.watch(isPlaybackPlayingProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    // Dynamic Accent color extracted via PaletteGenerator (coverUrl or firstTrack artwork)
    final firstTrack = tracksAsync.value?.firstOrNull;
    final paletteGenAsync = ref.watch(
      playlistPaletteGeneratorProvider((
        coverUrl: currentPlaylist?.coverUrl,
        trackArtworkUrl: firstTrack?.artworkUrl,
      )),
    );

    Color accent = isDark ? const Color(0xFF2A2D3A) : const Color(0xFFDDE1EA);
    final paletteGen = paletteGenAsync.value;
    if (paletteGen != null) {
      final Color? rawColor = isDark
          ? (paletteGen.vibrantColor?.color ??
              paletteGen.dominantColor?.color ??
              paletteGen.lightVibrantColor?.color ??
              paletteGen.darkVibrantColor?.color ??
              paletteGen.mutedColor?.color)
          : (paletteGen.lightVibrantColor?.color ??
              paletteGen.vibrantColor?.color ??
              paletteGen.dominantColor?.color ??
              paletteGen.mutedColor?.color);
      if (rawColor != null) {
        final hsl = HSLColor.fromColor(rawColor);
        accent = isDark
            ? hsl
                .withSaturation((hsl.saturation * 1.15).clamp(0.40, 0.95))
                .withLightness(hsl.lightness.clamp(0.30, 0.55))
                .toColor()
            : hsl
                .withSaturation((hsl.saturation * 1.10).clamp(0.35, 0.90))
                .withLightness(hsl.lightness.clamp(0.40, 0.65))
                .toColor();
      }
    } else if (widget.isLikedSongs) {
      accent = isDark ? const Color(0xFF2E4C20) : const Color(0xFFB4E068);
    } else if (firstTrack != null) {
      final cached = PaletteService.instance.getCachedPalette(firstTrack, isDark: isDark);
      if (cached != null) accent = cached.backgroundColor;
    }

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) _exitSelectionMode();
      },
      child: Scaffold(
        backgroundColor: baseColor,
        bottomNavigationBar: _isSelectionMode && _selectedTrackIds.isNotEmpty
            ? _buildBatchActionBar(theme, currentPlaylist, tracksAsync.value ?? [])
            : null,
        body: Stack(
          children: [
            // Artwork color wash that dissolves into the page background
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 520,
              child: IgnorePointer(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: accent),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInOutCubic,
                  builder: (context, animated, _) {
                    final top = _mix(baseColor, animated ?? accent, isDark ? 0.75 : 0.55);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.45, 1.0],
                          colors: [top, _mix(top, baseColor, 0.6), baseColor],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  tracksAsync.when(
                    loading: () => ListView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: const [
                        MediaHeaderSkeleton(),
                        TrackListSkeleton(itemCount: 8, shrinkWrap: true),
                      ],
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Couldn\'t load tracks.\n$err',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    data: (tracks) {
                      if (!_isReordering) _reorderList = List.from(tracks);

                      final baseTracks = _isReordering ? (_reorderList ?? tracks) : tracks;
                      final query = _searchFilter.trim().toLowerCase();

                      var filtered = query.isEmpty
                          ? baseTracks
                          : baseTracks.where((t) {
                              return t.title.toLowerCase().contains(query) ||
                                  t.artistName.toLowerCase().contains(query) ||
                                  (t.albumTitle?.toLowerCase().contains(query) ?? false);
                            }).toList();

                      if (_downloadedOnly) {
                        filtered = filtered.where((t) {
                          final isFromApp = t.source != AudioSourceType.local ||
                              (t.filePath != null && t.filePath!.toLowerCase().contains('musify'));
                          return t.isDownloaded && isFromApp;
                        }).toList();
                      }

                      final displayTracks = filtered;
                      final isPlayingThisPlaylist =
                          tracks.any((t) => t.id == currentPlayingTrackId);
                      final showAddSongs = !widget.isLikedSongs && currentPlaylist != null;

                      return Column(
                        children: [
                          if (_isSelectionMode)
                            _buildSelectionHeader(theme, currentPlaylist, displayTracks)
                          else ...[
                            _buildTopBar(theme, currentPlaylist, tracks),
                            _buildSearchBar(theme, effectiveTitle),
                          ],
                          Expanded(
                            child: CustomScrollView(
                              physics: const ClampingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              slivers: [
                                if (!_isSelectionMode) ...[
                                  SliverToBoxAdapter(
                                    child: _buildHeader(
                                      theme,
                                      currentPlaylist,
                                      tracks,
                                      effectiveTitle,
                                      effectiveDesc,
                                      accent,
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: _buildActionRow(
                                      theme,
                                      currentPlaylist,
                                      tracks,
                                      isPlayingThisPlaylist,
                                      isPlaybackPlaying,
                                    ),
                                  ),
                                  if (showAddSongs && !_isReordering)
                                    SliverToBoxAdapter(
                                      child: _buildAddSongsPill(theme, currentPlaylist),
                                    ),
                                ],

                                if (_isReordering)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.drag_handle_rounded,
                                              size: 16, color: _limeText(isDark)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Drag the handle on the right to reorder',
                                            style: AppTypography.caption.copyWith(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: _limeText(isDark),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                if (tracks.isEmpty)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
                                      child: Column(
                                        children: [
                                          _GlassCircleButton(
                                            icon: widget.isLikedSongs
                                                ? Icons.favorite_border_rounded
                                                : Icons.queue_music_rounded,
                                            size: 64,
                                            onTap: () => _onAddSongs(currentPlaylist),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            widget.isLikedSongs
                                                ? 'No liked songs yet'
                                                : 'This playlist is empty',
                                            style: AppTypography.headlineSmall.copyWith(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.3,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            widget.isLikedSongs
                                                ? 'Tap the heart on any song to save it here.'
                                                : 'Choose "Add songs" to start building it.',
                                            textAlign: TextAlign.center,
                                            style: AppTypography.bodySmall.copyWith(
                                              fontSize: 14,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else if (displayTracks.isEmpty)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.all(40),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.music_off_rounded,
                                            size: 46,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.3),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _searchFilter.isNotEmpty
                                                ? 'No songs match "$_searchFilter"'
                                                : 'No downloaded songs in this playlist',
                                            textAlign: TextAlign.center,
                                            style: AppTypography.bodyMedium.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else if (_isReordering && currentPlaylist != null)
                                  SliverToBoxAdapter(
                                    child: ReorderableListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      buildDefaultDragHandles: false,
                                      itemCount: displayTracks.length,
                                      // ignore: deprecated_member_use
                                      onReorder: (oldIndex, newIndex) async {
                                        setState(() {
                                          if (newIndex > oldIndex) newIndex -= 1;
                                          final item = _reorderList!.removeAt(oldIndex);
                                          _reorderList!.insert(newIndex, item);
                                        });
                                        final newOrder = _reorderList!.map((t) => t.id).toList();
                                        await ref
                                            .read(audioRepositoryProvider)
                                            .reorderPlaylistTracks(currentPlaylist!.id, newOrder);
                                      },
                                      itemBuilder: (context, idx) {
                                        final track = displayTracks[idx];
                                        return _buildTrackRow(
                                          key: ValueKey('reorder_${track.id}'),
                                          theme: theme,
                                          track: track,
                                          isCurrent: false,
                                          isPlaying: false,
                                          target: currentPlaylist,
                                          onTap: () {},
                                          trailingOverride: ReorderableDragStartListener(
                                            index: idx,
                                            child: Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Icon(
                                                Icons.drag_handle_rounded,
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                else
                                  SliverFixedExtentList(
                                    // row height + vertical margins (2 + 2)
                                    itemExtent: _rowHeight + 4,
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final track = displayTracks[index];
                                        final isCurrent = currentPlayingTrackId == track.id;

                                        return _buildTrackRow(
                                          key: ValueKey('playlist_track_${track.id}'),
                                          theme: theme,
                                          track: track,
                                          isCurrent: isCurrent,
                                          isPlaying: isPlaybackPlaying,
                                          target: currentPlaylist,
                                          onTap: () {
                                            if (_isSelectionMode) {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                if (_selectedTrackIds.contains(track.id)) {
                                                  _selectedTrackIds.remove(track.id);
                                                } else {
                                                  _selectedTrackIds.add(track.id);
                                                }
                                              });
                                            } else if (isCurrent) {
                                              HapticFeedback.selectionClick();
                                              if (!isPlaybackPlaying) audioHandler.play();
                                              openNowPlayingScreen(context, targetTrack: track);
                                            } else {
                                              audioHandler.playTrackList(displayTracks,
                                                  startIndex: index);
                                              openNowPlayingScreen(context, targetTrack: track);
                                            }
                                          },
                                        );
                                      },
                                      childCount: displayTracks.length,
                                    ),
                                  ),

                                // Space for floating mini player / bottom nav
                                SliverToBoxAdapter(
                                  child: SizedBox(height: _isSelectionMode ? 100 : 170),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  if (!_isSelectionMode) const FloatingMiniPlayer(),

                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: const DownloadDynamicIsland(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Borderless circular button used for header actions and controls.
class _GlassCircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? background;
  final double size;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.background,
    this.size = 44,
  });

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.background ?? (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2));
    final fg = isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Icon(widget.icon, size: widget.size * 0.48, color: widget.iconColor ?? fg),
        ),
      ),
    );
  }
}