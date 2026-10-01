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
import 'package:musify/presentation/widgets/track_list_tile.dart';
import 'package:musify/presentation/widgets/scan_progress_dialog.dart';
import 'package:musify/presentation/widgets/track_sort_dropdown.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/playlist_artwork.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import 'package:musify/presentation/widgets/theme_selection_bottom_sheet.dart';
import '../playlist/playlist_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isSearchExpanded = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedTrackIds = {};

  final List<String> _filters = const ['All', 'Playlists', 'Liked Songs', 'Downloaded'];

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
  

  // --- Modal Helpers ---

  void _showMoreMenu(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themePref = ref.read(themePreferenceProvider);

    final screenSize = MediaQuery.of(context).size;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        screenSize.width - 240,
        75,
        16,
        screenSize.height - 75,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: isDark ? const Color(0xFF1E212B) : Colors.white,
      elevation: 10,
      items: [
        PopupMenuItem(
          value: 'scan',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
              const SizedBox(width: 12),
              const Text('Scan Storage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'theme',
          child: Row(
            children: [
              Icon(
                themePref.icon,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 12),
              Text(
                'Theme: ${themePref.displayName.replaceAll(" Mode", "")}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected == 'scan') {
      if (context.mounted) await startScanWithProgressDialog(context, ref);
    } else if (selected == 'theme') {
      if (context.mounted) await showThemeSelectionModal(context);
    }
  }

  void _showNewPlaylistDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1C28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'New Playlist',
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
                fillColor: isDark ? const Color(0xFF222533) : const Color(0xFFF3F4F6),
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
                fillColor: isDark ? const Color(0xFF222533) : const Color(0xFFF3F4F6),
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
              style: theme.textTheme.labelLarge?.copyWith(
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
                final repo = ref.read(audioRepositoryProvider);
                await repo.createPlaylist(
                  name,
                  description: descController.text.trim().isNotEmpty
                      ? descController.text.trim()
                      : null,
                );
                ref.invalidate(playlistsStreamProvider);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (context.mounted) {
                  AppSnackBar.show(
                    context,
                    message: 'Created "$name"',
                    type: AppSnackBarType.success,
                    icon: Icons.playlist_add_check_rounded,
                  );
                }
              }
            },
            child: Text(
              'Create',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPlaylistDialog(BuildContext context, WidgetRef ref, Playlist playlist) {
    final nameController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description ?? '');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1C28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                fillColor: isDark ? const Color(0xFF222533) : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.neonLime, width: 2)),
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
                fillColor: isDark ? const Color(0xFF222533) : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.neonLime, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: theme.textTheme.labelLarge?.copyWith(
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
                final repo = ref.read(audioRepositoryProvider);
                await repo.updatePlaylist(
                  playlist.id,
                  name: name,
                  description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                );
                ref.invalidate(playlistsStreamProvider);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              }
            },
            child: Text(
              'Save',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(BuildContext context, WidgetRef ref, Playlist playlist) async {
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
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Deleted "${playlist.name}"',
          type: AppSnackBarType.info,
          icon: Icons.delete_outline_rounded,
        );
      }
    }
  }

  void _openPlaylistTracks(BuildContext context, WidgetRef ref, Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          title: playlist.name,
          subtitle: playlist.description,
          playlist: playlist,
        ),
      ),
    );
  }

  Future<void> _confirmBatchDelete(
    BuildContext context,
    WidgetRef ref,
    List<Track> allAvailableTracks,
  ) async {
    final selectedTracks = allAvailableTracks
        .where((t) => _selectedTrackIds.contains(t.id))
        .toList();

    if (selectedTracks.isEmpty) return;

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
    ref.invalidate(trackPlayCountsProvider);
    ref.invalidate(likedTracksStreamProvider);

    if (context.mounted) {
      if (deletedCount > 0) {
        AppSnackBar.show(
          context,
          message: 'Permanently deleted $deletedCount ${deletedCount == 1 ? "track" : "tracks"} from storage',
          type: AppSnackBarType.delete,
        );
      } else {
        AppSnackBar.show(
          context,
          message: 'Could not delete files from storage. Please check permissions.',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Widget _buildSelectionHeader(ThemeData theme, List<Track> currentVisibleTracks) {
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

          // Right: 3 Circle Buttons (Select All / Edit, Delete, More)
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

              // 2. Delete Action
              _GlassCircleButton(
                icon: Icons.delete_outline_rounded,
                size: 40,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _confirmBatchDelete(context, ref, currentVisibleTracks);
                },
              ),
              const SizedBox(width: 8),

              // 3. More Menu (3 dots)
              _buildMoreMenuButton(context, currentVisibleTracks, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoreMenuButton(
    BuildContext context,
    List<Track> currentVisibleTracks,
    bool isDark,
  ) {
    final allSelected = currentVisibleTracks.isNotEmpty &&
        currentVisibleTracks.every((t) => _selectedTrackIds.contains(t.id));

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? const Color(0xFF1E212B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  // --- Bottom Floating Action Bar for Selection Mode ---

  Widget _buildBatchActionBar(ThemeData theme, List<Track> currentVisibleTracks) {
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

            // Right: 3 Action Items (Download, Add to Playlist, Delete)
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
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  onTap: () => _confirmBatchDelete(context, ref, currentVisibleTracks),
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

  // --- Header & Filters ---

  Widget _buildTopHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 11, 8),
      child: Row(
        children: [
          // Left: Borderless Search Toggle
          _GlassCircleButton(
            icon: _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
            onTap: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),

          // Center: "My Music" Title (centered in the middle between search and sorting icons)
          Expanded(
            child: Text(
              'My Music',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Dedicated Sorting Dropdown in AppBar
          const TrackSortDropdown(),

          const SizedBox(width: 8),

          // Right: Borderless More Button
          _GlassCircleButton(
            icon: Icons.more_horiz_rounded,
            onTap: () => _showMoreMenu(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: !_isSearchExpanded
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
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists, albums...',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: theme.colorScheme.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
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

  // --- Views for Different Category Filters ---

  Widget _buildPlaylistsView(ThemeData theme) {
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final isDark = theme.brightness == Brightness.dark;

    return playlistsAsync.when(
      data: (playlists) {
        return SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Playlists (${playlists.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'Create',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                      ),
                    ),
                    onPressed: () => _showNewPlaylistDialog(context, ref),
                  ),
                ],
              ),
            ),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No playlists yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create your first playlist to organize your songs.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...playlists.map((p) => _HomePlaylistItem(
                playlist: p,
                onTap: () => _openPlaylistTracks(context, ref, p),
                onEdit: () => _showEditPlaylistDialog(context, ref, p),
                onDelete: () => _confirmDeletePlaylist(context, ref, p),
              )),
          ]),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildLikedSongsView(ThemeData theme, String? currentPlayingTrackId, bool isPlaybackPlaying) {
    final likedTracksAsync = ref.watch(likedTracksStreamProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    return likedTracksAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No liked songs yet. Heart songs to add them here!',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ),
            ),
          );
        }

        return SliverFixedExtentList(
          itemExtent: 76.0,
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final track = tracks[index];
              final isCurrent = currentPlayingTrackId == track.id;
              final isTilePlaying = isCurrent && isPlaybackPlaying;
              return TrackListTile(
                key: ValueKey('liked_${track.id}'),
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
                  } else {
                    audioHandler.playTrackList(tracks, startIndex: index);
                  }
                },
                onLongPress: () {
                  _enterSelectionMode(track);
                },
                onLikeToggle: () {
                  ref.read(audioRepositoryProvider).toggleLike(track);
                },
              );
            },
            childCount: tracks.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70)))),
    );
  }

  Widget _buildDownloadedView(
    ThemeData theme,
    String? currentPlayingTrackId,
    bool isPlaybackPlaying,
    List<Track> allLocalTracks,
  ) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final downloadedTracks = allLocalTracks.where((t) {
      final isFromApp = t.source != AudioSourceType.local ||
          (t.filePath != null && t.filePath!.contains('musify_downloads'));
      return t.isDownloaded && isFromApp;
    }).toList();

    final query = _searchQuery.trim().toLowerCase();
    final displayedTracks = query.isEmpty
        ? downloadedTracks
        : downloadedTracks.where((t) {
            return t.title.toLowerCase().contains(query) ||
                t.artistName.toLowerCase().contains(query) ||
                (t.albumTitle?.toLowerCase().contains(query) ?? false);
          }).toList();

    if (displayedTracks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.download_for_offline_rounded,
                  size: 52,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 14),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No downloaded songs matching "$_searchQuery"'
                      : 'No downloaded songs yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Try another search query'
                      : 'Songs you download from search results will appear here for offline playback.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (_searchQuery.isEmpty) ...[
                  const SizedBox(height: 18),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Search & Download'),
                    onPressed: () {
                      ref.read(currentTabIndexProvider.notifier).setIndex(1);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverFixedExtentList(
      itemExtent: 76.0,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = displayedTracks[index];
          final isCurrent = currentPlayingTrackId == track.id;
          final isTilePlaying = isCurrent && isPlaybackPlaying;

          return TrackListTile(
            key: ValueKey('dl_${track.id}'),
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
              } else {
                audioHandler.playTrackList(displayedTracks, startIndex: index);
              }
            },
            onLongPress: () {
              _enterSelectionMode(track);
            },
            onLikeToggle: () {
              ref.read(audioRepositoryProvider).toggleLike(track);
            },
          );
        },
        childCount: displayedTracks.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sortedTracksAsync = ref.watch(sortedLocalTracksProvider);
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaybackPlaying = ref.watch(isPlaybackPlayingProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    final localTracks = sortedTracksAsync.value ?? [];
    final query = _searchQuery.trim().toLowerCase();
    final displayedTracks = query.isEmpty
        ? localTracks
        : localTracks.where((t) {
            return t.title.toLowerCase().contains(query) ||
                t.artistName.toLowerCase().contains(query) ||
                (t.albumTitle?.toLowerCase().contains(query) ?? false);
          }).toList();

    List<Track> currentVisibleTracks = displayedTracks;
    if (_selectedFilter == 'Downloaded') {
      final downloadedTracks = localTracks.where((t) {
        final isFromApp = t.source != AudioSourceType.local ||
            (t.filePath != null && t.filePath!.contains('musify_downloads'));
        return t.isDownloaded && isFromApp;
      }).toList();
      currentVisibleTracks = query.isEmpty
          ? downloadedTracks
          : downloadedTracks.where((t) {
              return t.title.toLowerCase().contains(query) ||
                  t.artistName.toLowerCase().contains(query) ||
                  (t.albumTitle?.toLowerCase().contains(query) ?? false);
            }).toList();
    } else if (_selectedFilter == 'Liked Songs') {
      final likedTracksAsync = ref.watch(likedTracksStreamProvider);
      final likedTracks = likedTracksAsync.value ?? [];
      currentVisibleTracks = query.isEmpty
          ? likedTracks
          : likedTracks.where((t) {
              return t.title.toLowerCase().contains(query) ||
                  t.artistName.toLowerCase().contains(query) ||
                  (t.albumTitle?.toLowerCase().contains(query) ?? false);
            }).toList();
    }

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
            ? _buildBatchActionBar(theme, currentVisibleTracks)
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Pinned Sticky Top Header or Batch Selection Header
              if (_isSelectionMode) ...[
                _buildSelectionHeader(theme, currentVisibleTracks),
                _buildFilterPills(theme),
              ] else ...[
                _buildTopHeader(theme),
                _buildSearchBar(theme),
                _buildFilterPills(theme),
              ],
              const SizedBox(height: 4),

              // Scrollable Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(localTracksProvider);
                    ref.invalidate(trackPlayCountsProvider);
                    ref.invalidate(likedTracksStreamProvider);
                    ref.invalidate(playlistsStreamProvider);
                  },
                  child: sortedTracksAsync.when(
                    data: (localTracks) {
                      final query = _searchQuery.trim().toLowerCase();
                      final displayedTracks = query.isEmpty
                          ? localTracks
                          : localTracks.where((t) {
                              return t.title.toLowerCase().contains(query) ||
                                  t.artistName.toLowerCase().contains(query) ||
                                  (t.albumTitle?.toLowerCase().contains(query) ?? false);
                            }).toList();

                      return CustomScrollView(
                        physics: const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          // View Switcher based on Selected Filter
                          if (_selectedFilter == 'Playlists')
                            _buildPlaylistsView(theme)
                          else if (_selectedFilter == 'Liked Songs')
                            _buildLikedSongsView(theme, currentPlayingTrackId, isPlaybackPlaying)
                          else if (_selectedFilter == 'Downloaded')
                            _buildDownloadedView(theme, currentPlayingTrackId, isPlaybackPlaying, localTracks)
                          else if (displayedTracks.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.music_off_rounded,
                                      size: 48,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No music matching "$_searchQuery"'
                                          : 'No offline audio tracks found',
                                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                                    ),
                                    if (_searchQuery.isEmpty) ...[
                                      const SizedBox(height: 14),
                                      FilledButton.tonalIcon(
                                        icon: const Icon(Icons.refresh_rounded, size: 18),
                                        label: const Text('Scan Device Storage'),
                                        onPressed: () async {
                                          await startScanWithProgressDialog(context, ref);
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          // High-Performance Fixed Extent Sliver List for 60/120 FPS scrolling
                          SliverFixedExtentList(
                            itemExtent: 76.0,
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final track = displayedTracks[index];
                                final isCurrent = currentPlayingTrackId == track.id;
                                final isTilePlaying = isCurrent && isPlaybackPlaying;

                                return TrackListTile(
                                  key: ValueKey('track_${track.id}'),
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
                                    } else {
                                      audioHandler.playTrackList(displayedTracks, startIndex: index);
                                    }
                                  },
                                  onLongPress: () {
                                    _enterSelectionMode(track);
                                  },
                                  onLikeToggle: () {
                                    ref.read(audioRepositoryProvider).toggleLike(track);
                                  },
                                );
                              },
                              childCount: displayedTracks.length,
                            ),
                          ),

                        // Bottom Padding for MiniPlayer & Bottom Shell
                        SliverToBoxAdapter(
                          child: SizedBox(height: _isSelectionMode ? 100 : 160),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(
                      'Failed to load music: $err',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

/// Borderless circular button used for header actions
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
    final defaultIconColor = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);

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

/// A dedicated playlist item widget for the Home Screen Playlists tab
/// formatted with identical typography, artwork dimensions, row height,
/// and styling to TrackListTile on the Home Screen (All).
class _HomePlaylistItem extends ConsumerWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HomePlaylistItem({
    required this.playlist,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tracksAsync = ref.watch(playlistTracksProvider(playlist.id));
    final tracks = tracksAsync.value ?? playlist.tracks;
    final audioHandler = ref.read(audioHandlerProvider);

    final songCountStr = '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}';
    final hasDesc = playlist.description != null && playlist.description!.trim().isNotEmpty;
    final subtitleText = hasDesc ? '$songCountStr • ${playlist.description!.trim()}' : songCountStr;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
      highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // Rounded Square Artwork (matching TrackListTile exactly: size 56, radius 14)
            PlaylistArtwork(
              playlistId: playlist.id,
              coverUrl: playlist.coverUrl,
              preloadedTracks: tracks,
              size: 56,
              borderRadius: BorderRadius.circular(14),
              hasShadow: false,
            ),
            const SizedBox(width: 14),

            // Title & Subtitle (identical typography, font family, size and layout to TrackListTile)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Trailing: Borderless Circular Play Action Button (matching TrackListTile)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (tracks.isNotEmpty) {
                  audioHandler.playTrackList(tracks, startIndex: 0);
                } else {
                  AppSnackBar.show(
                    context,
                    message: 'Playlist has no songs to play',
                    type: AppSnackBarType.info,
                  );
                }
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028),
                ),
              ),
            ),

            const SizedBox(width: 2),

            // Trailing 3-Dot Dropdown Menu Button — matching TrackListTile
            Theme(
              data: theme.copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: isDark ? const Color(0xFF1E212B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 10,
                ),
              ),
              child: PopupMenuButton<String>(
                offset: const Offset(0, 4),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                onSelected: (value) async {
                  HapticFeedback.selectionClick();
                  if (value == 'play') {
                    if (tracks.isNotEmpty) {
                      audioHandler.playTrackList(tracks, startIndex: 0);
                    } else {
                      AppSnackBar.show(
                        context,
                        message: 'Playlist has no songs to play',
                        type: AppSnackBarType.info,
                      );
                    }
                  } else if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'play',
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
                        const SizedBox(width: 12),
                        Text('Play', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 14)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 19, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
                        const SizedBox(width: 12),
                        Text('Edit Details', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 14)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Text('Delete Playlist', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.w500, fontSize: 14)),
                      ],
                    ),
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


