import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';
import 'package:musify/presentation/widgets/playlist_artwork.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';

/// An industry-standard, high-performance Playlist Detail screen aligned 1:1
/// with the Home Screen (All tab) design system:
/// - Exact icon buttons (_GlassCircleButton, 44/40 circular, borderless, AMOLED colors)
/// - Exact chips UI (pill badges with 24px radius, #20222B / #ECEEF2, #D2F843 active state)
/// - Exact tile UI (TrackListTile, 76px extent, 56x56 artwork, play button, 3-dots popup)
/// - In-playlist live search matching Home Screen search bar
/// - Multi-selection mode with floating capsule action bar
/// - Track reordering support
/// - Pure AMOLED black in dark mode
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
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;

  bool _isReordering = false;
  bool _isSearching = false;
  String _searchFilter = '';
  String _selectedFilter = 'All';
  bool _showCollapsedTitle = false;
  List<Track>? _reorderList;

  bool _isSelectionMode = false;
  final Set<String> _selectedTrackIds = {};

  final List<String> _filters = const ['All', 'Downloaded'];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final shouldShow = offset > 180;
    if (shouldShow != _showCollapsedTitle) {
      setState(() => _showCollapsedTitle = shouldShow);
    }
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

  String _formatTotalDuration(List<Track> tracks) {
    int totalMs = 0;
    for (final t in tracks) {
      totalMs += t.durationMs;
    }
    final duration = Duration(milliseconds: totalMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? "$minutes min" : ""}';
    } else {
      return '${duration.inMinutes} min';
    }
  }

  void _showEditPlaylistDialog(Playlist playlist) {
    final nameController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description ?? '');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        title: Text(
          'Edit Playlist',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 19,
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
              decoration: InputDecoration(
                hintText: 'Playlist name',
                prefixIcon: const Icon(Icons.queue_music_rounded),
                filled: true,
                fillColor: isDark ? const Color(0xFF20222B) : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.neonLime, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                prefixIcon: const Icon(Icons.description_outlined),
                filled: true,
                fillColor: isDark ? const Color(0xFF20222B) : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.neonLime, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonLime,
              foregroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(Playlist playlist) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Delete Playlist?',
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
        child: const Icon(
          Icons.queue_music_rounded,
          size: 22,
          color: Color(0xFFFF4D6D),
        ),
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

    if (shuffle) {
      final shuffled = List<Track>.from(tracks)..shuffle();
      audioHandler.playTrackList(shuffled, startIndex: 0);
    } else {
      audioHandler.playTrackList(tracks, startIndex: 0);
    }
  }

  // --- Multi-Selection Batch Actions (Aligned 1:1 with Home Screen) ---

  Future<void> _confirmBatchDeleteOrRemove(
    BuildContext context,
    Playlist? currentPlaylist,
    List<Track> allAvailableTracks,
  ) async {
    final selectedTracks = allAvailableTracks
        .where((t) => _selectedTrackIds.contains(t.id))
        .toList();

    if (selectedTracks.isEmpty) return;

    if (currentPlaylist != null) {
      // Remove from playlist
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

    // Liked Songs or local deletion
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
      title: 'Delete ${selectedTracks.length} ${selectedTracks.length == 1 ? "Song" : "Songs"}?',
      description:
          'Are you sure you want to permanently delete the selected ${selectedTracks.length} ${selectedTracks.length == 1 ? "track" : "tracks"} from your device? The audio files will be removed.',
      tracks: selectedTracks,
      confirmText: 'Delete (${selectedTracks.length})',
      cancelText: 'Cancel',
    );

    if (confirmed != true) return;

    // Check Android shared external storage permission
    final hasExternalStorageTrack = selectedTracks.any((t) {
      final p = t.filePath;
      return p != null && !p.contains('musify_downloads') && p.isNotEmpty;
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

    if (context.mounted) {
      if (deletedCount > 0) {
        AppSnackBar.show(
          context,
          message: 'Permanently deleted $deletedCount ${deletedCount == 1 ? "track" : "tracks"} from storage',
          type: AppSnackBarType.delete,
        );
      }
    }
  }

  void _handleBatchDownload(List<Track> selectedTracks) {
    if (selectedTracks.isEmpty) return;
    final downloadManager = ref.read(downloadManagerProvider);
    for (final track in selectedTracks) {
      downloadManager.downloadTrack(track);
    }
    AppSnackBar.show(
      context,
      message:
          'Starting download for ${selectedTracks.length} ${selectedTracks.length == 1 ? "song" : "songs"}',
      type: AppSnackBarType.info,
    );
    _exitSelectionMode();
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

  // --- UI Components Aligned 1:1 with Home Screen ---

  Widget _buildSelectionHeader(
    ThemeData theme,
    Playlist? currentPlaylist,
    List<Track> currentVisibleTracks,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final allSelected = currentVisibleTracks.isNotEmpty &&
        currentVisibleTracks.every((t) => _selectedTrackIds.contains(t.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          // Left: Close Button to exit Selection Mode
          _GlassCircleButton(
            icon: Icons.close_rounded,
            size: 40,
            onTap: () {
              HapticFeedback.selectionClick();
              _exitSelectionMode();
            },
          ),

          // Center: Selection Count (Centered)
          Expanded(
            child: Center(
              child: Text(
                '${_selectedTrackIds.length} selected',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          // Right: 3 Circle Buttons (Select All, Delete/Remove, More)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Select All / Toggle All
              _GlassCircleButton(
                icon: allSelected ? Icons.check_box_rounded : Icons.checklist_rounded,
                size: 40,
                iconColor: allSelected
                    ? (isDark ? AppColors.neonLime : const Color(0xFF70A314))
                    : null,
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

              // 2. Remove / Delete Action
              _GlassCircleButton(
                icon: currentPlaylist != null
                    ? Icons.playlist_remove_rounded
                    : Icons.delete_outline_rounded,
                size: 40,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _confirmBatchDeleteOrRemove(context, currentPlaylist, currentVisibleTracks);
                },
              ),
              const SizedBox(width: 8),

              // 3. More Menu (3 dots)
              _buildSelectionMoreMenuButton(context, currentVisibleTracks, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionMoreMenuButton(
    BuildContext context,
    List<Track> currentVisibleTracks,
    bool isDark,
  ) {
    final allSelected = currentVisibleTracks.isNotEmpty &&
        currentVisibleTracks.every((t) => _selectedTrackIds.contains(t.id));

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? Colors.black : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          elevation: 10,
        ),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.more_vert_rounded,
            size: 20,
            color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028),
          ),
        ),
        onSelected: (value) {
          if (value == 'toggle_all') {
            setState(() {
              if (allSelected) {
                _selectedTrackIds.clear();
              } else {
                _selectedTrackIds.addAll(currentVisibleTracks.map((t) => t.id));
              }
            });
          } else if (value == 'download') {
            final selected = currentVisibleTracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
            _handleBatchDownload(selected);
          } else if (value == 'add_playlist') {
            final selected = currentVisibleTracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
            _handleBatchAddToPlaylist(context, selected);
          } else if (value == 'cancel') {
            _exitSelectionMode();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'toggle_all',
            child: Row(
              children: [
                Icon(
                  allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 12),
                Text(allSelected ? 'Deselect All' : 'Select All'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'download',
            child: Row(
              children: [
                Icon(
                  Icons.file_download_outlined,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 12),
                const Text('Download Selected'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'add_playlist',
            child: Row(
              children: [
                Icon(
                  Icons.playlist_add_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 12),
                const Text('Add to Playlist'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'cancel',
            child: Row(
              children: [
                Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 12),
                const Text('Cancel Selection'),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.neonLime,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: Stacked Album Art Preview & Count Text
            if (selectedTracks.isNotEmpty) ...[
              _buildStackedThumbnails(selectedTracks),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                '${selectedTracks.length} ${selectedTracks.length == 1 ? "song" : "songs"} selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
            ),

            // Right: Capsule Action Items
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
                  label: 'Add to\nPlaylist',
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
    final displayTracks = selectedTracks.take(3).toList();

    return SizedBox(
      width: 50,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (displayTracks.length >= 3)
            Positioned(
              left: 0,
              child: Transform.rotate(
                angle: -0.20,
                child: _buildMiniArt(displayTracks[2]),
              ),
            ),
          if (displayTracks.length >= 2)
            Positioned(
              left: 6,
              child: Transform.rotate(
                angle: 0.16,
                child: _buildMiniArt(displayTracks[1]),
              ),
            ),
          Positioned(
            left: displayTracks.length > 1 ? 3 : 6,
            child: _buildMiniArt(displayTracks[0], isFront: true),
          ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
          Icon(
            icon,
            size: 21,
            color: const Color(0xFF111827),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // --- Search Bar (Exact Home Screen Styling) ---

  Widget _buildSearchBar(ThemeData theme, String effectiveTitle) {
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: !_isSearching
          ? const SizedBox.shrink(key: ValueKey('search_collapsed'))
          : Padding(
              key: const ValueKey('search_expanded'),
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                  onChanged: (val) {
                    setState(() {
                      _searchFilter = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search songs in $effectiveTitle...',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: theme.colorScheme.primary),
                    suffixIcon: _searchFilter.isNotEmpty
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchFilter = '';
                              });
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
    );
  }

  // --- Filter Pills (Exact Home Screen Styling) ---

  Widget _buildFilterPills(ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final selectedBg = isDark ? primaryColor : AppColors.neonLime;
    final unselectedBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final unselectedTextColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF1E2028);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _exitSelectionMode();
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBg : unselectedBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13.5,
                    color: isSelected ? Colors.black : unselectedTextColor,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Metadata Chips UI ---

  Widget _buildMetadataChips(ThemeData theme, List<Track> tracks, String totalDurationStr) {
    final isDark = theme.brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final textColor = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        // Song Count Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note_rounded, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '${tracks.length} ${tracks.length == 1 ? "song" : "songs"}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),

        // Duration Chip
        if (tracks.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: textColor.withValues(alpha: 0.65)),
                const SizedBox(width: 6),
                Text(
                  totalDurationStr,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

        // Type Tag (Favorites or Playlist)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isLikedSongs ? Icons.favorite_rounded : Icons.queue_music_rounded,
                size: 15,
                color: widget.isLikedSongs ? const Color(0xFFFF4D6D) : textColor.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 6),
              Text(
                widget.isLikedSongs ? 'Favorites' : 'Playlist',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Reactively watch playlist updates
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

    // Watch tracks reactively
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

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        bottomNavigationBar: _isSelectionMode && _selectedTrackIds.isNotEmpty
            ? _buildBatchActionBar(
                theme,
                currentPlaylist,
                tracksAsync.value ?? [],
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: tracksAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neonLime),
            ),
            error: (err, _) => Center(
              child: Text(
                'Error loading tracks: $err',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            data: (tracks) {
              if (!_isReordering) {
                _reorderList = List.from(tracks);
              }

              final baseTracks = _isReordering ? (_reorderList ?? tracks) : tracks;
              final query = _searchFilter.trim().toLowerCase();

              // Filter by search query
              var filteredTracks = query.isEmpty
                  ? baseTracks
                  : baseTracks.where((t) {
                      return t.title.toLowerCase().contains(query) ||
                          t.artistName.toLowerCase().contains(query) ||
                          (t.albumTitle?.toLowerCase().contains(query) ?? false);
                    }).toList();

              // Filter by pill (All vs Downloaded)
              if (_selectedFilter == 'Downloaded') {
                filteredTracks = filteredTracks.where((t) {
                  final isFromApp = t.source != AudioSourceType.local ||
                      (t.filePath != null && t.filePath!.contains('musify_downloads'));
                  return t.isDownloaded && isFromApp;
                }).toList();
              }

              final displayTracks = filteredTracks;
              final totalDurationStr = _formatTotalDuration(tracks);
              final isPlayingThisPlaylist = tracks.any((t) => t.id == currentPlayingTrackId);

              return Column(
                children: [
                  // Sticky Top Bar (Normal or Multi-Selection Mode)
                  if (_isSelectionMode) ...[
                    _buildSelectionHeader(theme, currentPlaylist, displayTracks),
                    _buildFilterPills(theme),
                  ] else ...[
                    // Custom App Bar Header matching Home Screen borderless circle buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                      child: Row(
                        children: [
                          // Left: Borderless Back Button
                          _GlassCircleButton(
                            icon: Icons.chevron_left_rounded,
                            size: 44,
                            onTap: () => Navigator.pop(context),
                          ),

                          // Center: Collapsible Title or Reorder prompt
                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: _showCollapsedTitle ? 1.0 : 0.0,
                              child: Text(
                                effectiveTitle,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),

                          // Right: Action Buttons
                          if (_isReordering)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
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
                              child: const Text(
                                'Done',
                                style: TextStyle(
                                  color: AppColors.neonLime,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            )
                          else ...[
                            // Search Toggle Button (matching Home Screen _GlassCircleButton)
                            if (tracks.isNotEmpty)
                              _GlassCircleButton(
                                icon: _isSearching ? Icons.close_rounded : Icons.search_rounded,
                                size: 44,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _isSearching = !_isSearching;
                                    if (!_isSearching) {
                                      _searchController.clear();
                                      _searchFilter = '';
                                    }
                                  });
                                },
                              ),

                            if (currentPlaylist != null) ...[
                              const SizedBox(width: 8),

                              // More Options Menu (borderless circular popup trigger)
                              Theme(
                                data: theme.copyWith(
                                  popupMenuTheme: PopupMenuThemeData(
                                    color: isDark ? Colors.black : Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF262A36)
                                            : const Color(0xFFE5E7EB),
                                        width: 1,
                                      ),
                                    ),
                                    elevation: 10,
                                  ),
                                ),
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? const Color(0xFF20222B)
                                          : const Color(0xFFECEEF2),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.more_horiz_rounded,
                                      size: 22,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : const Color(0xFF1E2028),
                                    ),
                                  ),
                                  onSelected: (val) {
                                    HapticFeedback.selectionClick();
                                    final target = currentPlaylist;
                                    if (val == 'edit' && target != null) {
                                      _showEditPlaylistDialog(target);
                                    } else if (val == 'reorder') {
                                      setState(() {
                                        _isReordering = true;
                                        _reorderList = List.from(tracks);
                                      });
                                    } else if (val == 'delete' && target != null) {
                                      _confirmDeletePlaylist(target);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 20),
                                          SizedBox(width: 12),
                                          Text('Edit Details',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w500, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                    if (tracks.length > 1)
                                      const PopupMenuItem(
                                        value: 'reorder',
                                        child: Row(
                                          children: [
                                            Icon(Icons.reorder_rounded, size: 20),
                                            SizedBox(width: 12),
                                            Text('Reorder Tracks',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w500, fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuDivider(height: 1),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded,
                                              size: 20, color: Colors.redAccent),
                                          SizedBox(width: 12),
                                          Text('Delete Playlist',
                                              style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    // Expandable In-Playlist Search Bar matching Home Screen exactly
                    _buildSearchBar(theme, effectiveTitle),

                    // Filter Pills (All vs Downloaded)
                    _buildFilterPills(theme),
                  ],

                  // Scrollable Body
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        // Hero Header Section (Cover art, title, metadata chips, play/shuffle)
                        if (!_isSelectionMode)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                              child: Column(
                                children: [
                                  // Playlist Artwork (Dynamic Mosaic Collage or Heart Preset)
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                                alpha: isDark ? 0.45 : 0.14),
                                            blurRadius: 28,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: PlaylistArtwork(
                                        playlistId: currentPlaylist?.id,
                                        coverUrl: currentPlaylist?.coverUrl,
                                        preloadedTracks: tracks,
                                        isLikedSongs: widget.isLikedSongs,
                                        size: 180,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Playlist Title
                                  Text(
                                    effectiveTitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),

                                  if (effectiveDesc != null &&
                                      effectiveDesc.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      effectiveDesc.trim(),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 12),

                                  // Metadata Chips Row (Song Count, Duration, Playlist Badge)
                                  _buildMetadataChips(theme, tracks, totalDurationStr),

                                  const SizedBox(height: 20),

                                  // Controls Row: Play All | Shuffle
                                  Row(
                                    children: [
                                      // Primary Play Button (High Contrast Neon Lime)
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.neonLime,
                                              foregroundColor: const Color(0xFF111827),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(24),
                                              ),
                                            ),
                                            icon: Icon(
                                              (isPlayingThisPlaylist && isPlaybackPlaying)
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              size: 24,
                                              color: const Color(0xFF111827),
                                            ),
                                            label: Text(
                                              (isPlayingThisPlaylist && isPlaybackPlaying)
                                                  ? 'Pause'
                                                  : 'Play',
                                              style: const TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF111827),
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            onPressed: tracks.isEmpty
                                                ? null
                                                : () {
                                                    if (isPlayingThisPlaylist &&
                                                        isPlaybackPlaying) {
                                                      ref
                                                          .read(audioHandlerProvider)
                                                          .pause();
                                                    } else {
                                                      _playAll(tracks);
                                                    }
                                                  },
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // Shuffle Button (Borderless circular glass action matching Home)
                                      _GlassCircleButton(
                                        icon: Icons.shuffle_rounded,
                                        size: 48,
                                        onTap: tracks.isEmpty
                                            ? () {}
                                            : () => _playAll(tracks, shuffle: true),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Reorderable Mode Banner
                        if (_isReordering)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.drag_indicator_rounded,
                                      size: 16, color: AppColors.neonLime),
                                  SizedBox(width: 6),
                                  Text(
                                    'Drag handle on the right to reorder songs',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neonLime,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Empty State
                        if (tracks.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 50, horizontal: 24),
                              child: Center(
                                child: Column(
                                  children: [
                                    _GlassCircleButton(
                                      icon: widget.isLikedSongs
                                          ? Icons.favorite_border_rounded
                                          : Icons.queue_music_rounded,
                                      size: 64,
                                      onTap: () {},
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      widget.isLikedSongs
                                          ? 'No liked tracks yet'
                                          : 'This playlist is empty',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.isLikedSongs
                                          ? 'Tap the heart icon on any song to save it to your Favorites.'
                                          : 'Tap the 3 dots on any song to add it to this playlist.',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.55),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (displayTracks.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.music_off_rounded,
                                      size: 48,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchFilter.isNotEmpty
                                          ? 'No music matching "$_searchFilter"'
                                          : 'No downloaded tracks in this playlist',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (_isReordering && currentPlaylist != null)
                          // Reorderable View with identical styling
                          SliverToBoxAdapter(
                            child: ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: displayTracks.length,
                              // ignore: deprecated_member_use
                              onReorder: (oldIndex, newIndex) async {
                                setState(() {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  final item = _reorderList!.removeAt(oldIndex);
                                  _reorderList!.insert(newIndex, item);
                                });
                                final target = currentPlaylist;
                                if (target != null) {
                                  final newOrder = _reorderList!.map((t) => t.id).toList();
                                  await ref
                                      .read(audioRepositoryProvider)
                                      .reorderPlaylistTracks(target.id, newOrder);
                                }
                              },
                              itemBuilder: (context, idx) {
                                final track = displayTracks[idx];
                                return Container(
                                  key: ValueKey('reorder_${track.id}'),
                                  height: 76,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  child: Row(
                                    children: [
                                      TrackArtwork(
                                        artworkUrl: track.artworkUrl,
                                        size: 56,
                                        borderRadius: BorderRadius.circular(14),
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
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15.5,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              track.artistName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.55),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ReorderableDragStartListener(
                                        index: idx,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.drag_handle_rounded,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          // High-Performance Fixed Extent Sliver List using TrackListTile 1:1
                          SliverFixedExtentList(
                            itemExtent: 76.0,
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final track = displayTracks[index];
                                final isCurrent = currentPlayingTrackId == track.id;
                                final isTilePlaying = isCurrent && isPlaybackPlaying;
                                final target = currentPlaylist;

                                return TrackListTile(
                                  key: ValueKey('playlist_track_${track.id}'),
                                  track: track,
                                  isCurrent: isCurrent,
                                  isPlaying: isTilePlaying,
                                  isSelectionMode: _isSelectionMode,
                                  isSelected: _selectedTrackIds.contains(track.id),
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
                                      if (isPlaybackPlaying) {
                                        audioHandler.pause();
                                      } else {
                                        audioHandler.play();
                                      }
                                    } else {
                                      audioHandler.playTrackList(displayTracks, startIndex: index);
                                    }
                                  },
                                  onLongPress: () {
                                    _enterSelectionMode(track);
                                  },
                                  onLikeToggle: () {
                                    ref.read(audioRepositoryProvider).toggleLike(track);
                                  },
                                  onRemoveFromPlaylist: target != null
                                      ? () async {
                                          await ref
                                              .read(audioRepositoryProvider)
                                              .removeTrackFromPlaylist(
                                                  target.id, track.id);
                                          ref.invalidate(
                                              playlistTracksProvider(target.id));
                                          if (context.mounted) {
                                            AppSnackBar.show(
                                              context,
                                              message:
                                                  'Removed "${track.title}" from playlist',
                                              type: AppSnackBarType.info,
                                              icon: Icons.playlist_remove_rounded,
                                              actionLabel: 'Undo',
                                              onAction: () async {
                                                await ref
                                                    .read(audioRepositoryProvider)
                                                    .addTrackToPlaylist(
                                                        target.id, track);
                                                ref.invalidate(
                                                    playlistTracksProvider(target.id));
                                              },
                                            );
                                          }
                                        }
                                      : (widget.isLikedSongs
                                          ? () async {
                                              await ref
                                                  .read(audioRepositoryProvider)
                                                  .toggleLike(track);
                                              ref.invalidate(likedTracksStreamProvider);
                                            }
                                          : null),
                                );
                              },
                              childCount: displayTracks.length,
                            ),
                          ),

                        // Bottom Padding for MiniPlayer & Floating Controls
                        SliverToBoxAdapter(
                          child: SizedBox(height: _isSelectionMode ? 100 : 160),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Borderless circular button used for header actions and controls
/// (Exact 1:1 match to Home Screen _GlassCircleButton)
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final double size;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final defaultIconColor =
        isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: defaultBg,
        ),
        child: Icon(
          icon,
          size: size * 0.48,
          color: iconColor ?? defaultIconColor,
        ),
      ),
    );
  }
}
