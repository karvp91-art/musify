import 'dart:io';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'collapsing_large_title_header.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/scan_progress_dialog.dart';
import 'package:musify/presentation/widgets/track_sort_dropdown.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/playlist_artwork.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import 'package:musify/presentation/widgets/create_playlist_modal.dart';
import 'package:musify/presentation/widgets/shimmer_skeleton.dart';
import 'package:musify/presentation/screens/settings/audio_settings_screen.dart';
import 'package:musify/presentation/screens/player/now_playing_screen.dart';
import 'package:musify/presentation/screens/playlist/import_playlist_screen.dart';
import 'package:musify/services/online_artwork_enricher.dart';
import '../playlist/playlist_detail_screen.dart';
import '../folder/folder_detail_screen.dart';

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

// --- Shared theme helpers (same values as PlaylistDetailScreen) ---
Color _surfaceFor(bool isDark) => isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
Color _limeTextFor(bool isDark) => isDark ? AppColors.neonLime : AppColors.limeAccentDark;
Color _limeTintFor(bool isDark) => isDark ? const Color(0xFF1B2616) : const Color(0xFFE8F8DC);
Color _iconColorFor(bool isDark) =>
    isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);

/// One popup menu look for every 3-dot menu on the page.
ThemeData _popupTheme(ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  return theme.copyWith(
    popupMenuTheme: PopupMenuThemeData(
      color: _surfaceFor(isDark),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB)),
      ),
      elevation: 10,
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Home (My music).
///
/// Follows the PlaylistDetailScreen pattern:
/// - Top bar: title + search / sort / 3-dot menu (select, scan, settings)
/// - Filter chips: tonal surface, lime tint when selected (solid lime is
///   reserved for the primary Play button and the batch bar)
/// - Action row: select + download-all on the left, shuffle + large play right
/// - Track rows: artwork, title, "Artist • duration", now-playing overlay,
///   3-dot menu per row, check circle in selection mode
/// - Selection mode: header with close / count / select all / delete, and the
///   floating lime batch bar (download, add to playlist, delete)
class _HomeScreenState extends ConsumerState<HomeScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  static const double _expandedTop = 134;  // spacious large title area matching Personalise style
  static const double _collapsedTop = 56;  // compact bar
  static const double _chipsHeight = 54;   // 4 + 42 + 8 (matches your chip row)
  static const double _searchFullHeight = 60;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isSearchExpanded = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedTrackIds = {};

  final List<String> _filters = const ['All', 'Audio', 'Playlists', 'Folders', 'Liked Songs', 'Downloaded'];

  // Filters that show a flat list of tracks
  static const Set<String> _trackFilters = {'All', 'Audio', 'Liked Songs', 'Downloaded'};

  static const double _rowHeight = 72.0;
  Color? _lastWashAccent;

  @override
  bool get wantKeepAlive => true;

  // --- Theme helpers ---
  Color _surface(bool isDark) => _surfaceFor(isDark);
  Color _limeText(bool isDark) => _limeTextFor(isDark);
  Color _limeTint(bool isDark) => _limeTintFor(isDark);
  Color _iconColor(bool isDark) => _iconColorFor(isDark);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Auto-scan storage silently in background if device was scanned at least once
      final prefs = ref.read(preferencesServiceProvider);
      if (prefs.hasScannedStorage()) {
        triggerBackgroundStorageScan(ref);
      }
      // Silently fetch online artwork for local songs missing cover art
      OnlineArtworkEnricher.triggerBackgroundEnrichment(ref);
    });
  }

  // --- Selection mode ---

  void _enterSelectionMode(Track track) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedTrackIds.add(track.id);
    });
    ref.read(isMultiSelectionModeProvider.notifier).setMode(true);
  }

  /// Enter selection mode from the menu / action row, with nothing selected yet.
  void _startSelection() {
    HapticFeedback.heavyImpact();
    setState(() => _isSelectionMode = true);
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
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollEndNotification && n.depth == 0 && _scrollController.hasClients) {
      const d = _expandedTop - _collapsedTop;
      final o = _scrollController.offset;
      if (o > 0 && o < d) {
        final target = o < d / 2 ? 0.0 : d;
        Future.microtask(() {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              target,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
    return false;
  }

  // --- Formatting ---

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

  String _songsMeta(List<Track> tracks) {
    if (tracks.isEmpty) return 'No songs yet';
    return '${tracks.length} ${tracks.length == 1 ? "song" : "songs"} • ${_formatTotalDuration(tracks)}';
  }

  // --- Modal helpers ---

  void _showNewPlaylistDialog(BuildContext context, WidgetRef ref) {
    showCreatePlaylistModal(context, ref);
  }

  void _showEditPlaylistDialog(BuildContext context, WidgetRef ref, Playlist playlist) {
    showEditPlaylistModal(context, ref, playlist);
  }

  void _confirmDeletePlaylist(BuildContext context, WidgetRef ref, Playlist playlist) async {
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

  // --- Playback / bulk actions ---

  void _playAll(List<Track> tracks, {bool shuffle = false}) {
    if (tracks.isEmpty) return;
    HapticFeedback.mediumImpact();
    final list = shuffle ? (List<Track>.from(tracks)..shuffle()) : tracks;
    ref.read(audioHandlerProvider).playTrackList(list, startIndex: 0);
    openNowPlayingScreen(context, targetTrack: list.first);
  }

  Future<void> _confirmBatchDelete(
    BuildContext context,
    WidgetRef ref,
    List<Track> allAvailableTracks,
  ) async {
    final selectedTracks =
        allAvailableTracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    await _confirmDeleteTracks(context, ref, selectedTracks);
  }

  /// Permanently deletes the given tracks from the device (batch or single row).
  Future<void> _confirmDeleteTracks(
    BuildContext context,
    WidgetRef ref,
    List<Track> selectedTracks,
  ) async {
    if (selectedTracks.isEmpty) return;

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

    // Check Android shared external storage permission
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

    if (_isSelectionMode) _exitSelectionMode();

    ref.invalidate(localTracksProvider);
    ref.invalidate(trackPlayCountsProvider);
    ref.invalidate(likedTracksStreamProvider);

    if (context.mounted) {
      if (deletedCount > 0) {
        AppSnackBar.show(
          context,
          message:
              'Permanently deleted $deletedCount ${deletedCount == 1 ? "track" : "tracks"} from storage',
          type: AppSnackBarType.delete,
        );
      } else {
        AppSnackBar.show(
          context,
          message: 'Couldn\'t delete files from storage. Check permissions and try again.',
          type: AppSnackBarType.error,
        );
      }
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

  // --- Selection header (close · count · select all · delete) ---

  Widget _buildSelectionHeader(ThemeData theme, List<Track> currentVisibleTracks) {
    final isDark = theme.brightness == Brightness.dark;
    final circleBg =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07);
    final allSelected = currentVisibleTracks.isNotEmpty &&
        currentVisibleTracks.every((t) => _selectedTrackIds.contains(t.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Row(
        children: [
          _GlassCircleButton(
            icon: Icons.close_rounded,
            size: 42,
            background: circleBg,
            onTap: _exitSelectionMode,
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
                background: circleBg,
                iconColor: allSelected ? _limeText(isDark) : null,
                onTap: () {
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
                icon: Icons.delete_outline_rounded,
                size: 42,
                background: circleBg,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _confirmBatchDelete(context, ref, currentVisibleTracks);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Bottom floating action bar for selection mode ---

  Widget _buildBatchActionBar(ThemeData theme, List<Track> currentVisibleTracks) {
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
                  icon: Icons.playlist_add_rounded,
                  label: 'Add to\nplaylist',
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

  // --- Top bar: title + search / sort / 3-dot menu ---

  Widget _buildCollapsingTopRow(
    ThemeData theme,
    String subtitle,
    List<Track> visibleTracks,
    double t, // 0 = expanded, 1 = collapsed
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final circleBg =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07);
    final searchActive = _isSearchExpanded;
    final btn = lerpDouble(46, 40, t)!;

    // Action buttons area width: 3 buttons of width `btn` + two 8px gaps
    final actionsWidth = (btn * 3) + 16;
    // When collapsed, title stops before the action buttons. When expanded, title has full width.
    final titleRightPadding = lerpDouble(18, actionsWidth + 24, t)!;
    // Title glides up smoothly over the expanded travel
    final titleTop = lerpDouble(54, 7, t)!;

    return Stack(
      children: [
        // Top action buttons row (Search, Sort, More) pinned at top right
        Positioned(
          top: 6,
          right: 18,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GlassCircleButton(
                icon: searchActive ? Icons.close_rounded : Icons.search_rounded,
                iconColor: searchActive ? _limeText(isDark) : null,
                size: btn,
                background: circleBg,
                onTap: () {
                  if (searchActive) {
                    _searchFocusNode.unfocus();
                    FocusScope.of(context).unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();
                    SystemChannels.textInput.invokeMethod('TextInput.hide');
                    setState(() {
                      _isSearchExpanded = false;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  } else {
                    setState(() => _isSearchExpanded = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _isSearchExpanded) _searchFocusNode.requestFocus();
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              TrackSortDropdown(size: btn, background: circleBg),
              const SizedBox(width: 8),
              _buildMoreMenu(theme, circleBg, visibleTracks, size: btn),
            ],
          ),
        ),

        // Large title & subtitle block (Personalise hero style when expanded, compact bar when collapsed)
        Positioned(
          top: titleTop,
          left: 18,
          right: titleRightPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My music',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headlineLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: lerpDouble(34, 21, t),
                  height: 1.1,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: lerpDouble(-1.0, -0.4, t),
                ),
              ),
              // Subtitle fades out cleanly during scroll
              ClipRect(
                child: Align(
                  alignment: Alignment.topLeft,
                  heightFactor: (1.0 - t * 1.5).clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: (1.0 - t * 2.2).clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoreMenu(
    ThemeData theme,
    Color circleBg,
    List<Track> visibleTracks, {
    double size = 46,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final canSelect = _trackFilters.contains(_selectedFilter) && visibleTracks.isNotEmpty;

    return Theme(
      data: _popupTheme(theme),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: circleBg),
          alignment: Alignment.center,
          child: Icon(Icons.more_vert_rounded, size: 22, color: _iconColor(isDark)),
        ),
        onSelected: (val) async {
          HapticFeedback.selectionClick();
          switch (val) {
            case 'select':
              _startSelection();
              break;
            case 'scan':
              await startScanWithProgressDialog(context, ref);
              break;
            case 'settings':
              openAudioSettingsScreen(context);
              break;
          }
        },
        itemBuilder: (context) => [
          if (canSelect)
            PopupMenuItem(value: 'select', child: _menuRow(Icons.checklist_rounded, 'Select songs')),
          PopupMenuItem(
            value: 'scan',
            child: _menuRow(Icons.refresh_rounded, 'Scan device storage'),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem(
            value: 'settings',
            child: _menuRow(ref.read(themePreferenceProvider).icon, 'Audio & theme settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final circleBg =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07);
    final iconColor =
        isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E2028);

    return ExcludeFocus(
      excluding: !_isSearchExpanded,
      child: IgnorePointer(
        ignoring: !_isSearchExpanded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: Container(
            height: 48,
            decoration: BoxDecoration(color: circleBg, borderRadius: BorderRadius.circular(24)),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: false,
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: 14.5,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search songs, artists, albums',
                hintStyle: AppTypography.bodySmall.copyWith(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: iconColor,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.close_rounded,
                            size: 19,
                            color: iconColor,
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
      ),
    );
  }

  Widget _buildCollapsingHeader({
    required ThemeData theme,
    required String subtitle,
    required List<Track> visibleTracks,
    required double topInset,
    required Color topColor,
    required Color collapsedColor,
    required Color dividerColor,
  }) {
    final showSearch = _isSearchExpanded && !_isSelectionMode;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: showSearch ? _searchFullHeight : 0.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, searchH, _) => SliverPersistentHeader(
        pinned: true,
        delegate: CollapsingLargeTitleDelegate(
          topInset: topInset,
          // In selection mode the bar stays fixed (no large title)
          expandedTopHeight: _isSelectionMode ? 58 : _expandedTop,
          collapsedTopHeight: _isSelectionMode ? 58 : _collapsedTop,
          topRowBuilder: (ctx, t) => _isSelectionMode
              ? _buildSelectionHeader(theme, visibleTracks)
              : _buildCollapsingTopRow(theme, subtitle, visibleTracks, t),
          searchBar: _buildSearchBar(theme),
          searchHeight: searchH,
          searchFullHeight: _searchFullHeight,
          bottom: _buildFilterPills(theme),
          bottomHeight: _chipsHeight,
          topColor: topColor,
          collapsedColor: collapsedColor,
          dividerColor: dividerColor,
        ),
      ),
    );
  }

  // --- Filter chips: borderless translucent glass matching top bar & selection header ---

  Widget _buildFilterPills(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _GlassFilterChip(
              label: filter,
              isSelected: isSelected,
              onTap: () {
                _exitSelectionMode();
                setState(() => _selectedFilter = filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Shared building blocks ---

  Widget _emptyState(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 56, 40, 24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _surface(isDark)),
              child: Icon(
                icon,
                size: 64 * 0.48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 14,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _tonalPill(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final fg = filled ? const Color(0xFF111827) : _limeText(isDark);
    return Material(
      color: filled ? AppColors.neonLime : _limeTint(isDark),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Action row: select (left) · shuffle + play (right) ---

  // ignore: unused_element
  Widget _buildActionRow(
    ThemeData theme,
    List<Track> tracks,
    bool isPlayingThisList,
    bool isPlaybackPlaying,
  ) {
    final nowPlaying = isPlayingThisList && isPlaybackPlaying;
    final disabled = tracks.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        children: [
          _GlassCircleButton(
            icon: Icons.checklist_rounded,
            size: 48,
            onTap: disabled ? () {} : _startSelection,
          ),
          const Spacer(),
          _GlassCircleButton(
            icon: Icons.shuffle_rounded,
            size: 52,
            onTap: disabled
                ? () {
                    AppSnackBar.show(
                      context,
                      message: 'No songs to shuffle',
                      type: AppSnackBarType.info,
                    );
                  }
                : () => _playAll(tracks, shuffle: true),
          ),
          const SizedBox(width: 14),
          // Primary action: the one solid lime element on the page
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
                width: 50,
                height: 50,
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

  // --- Track row: artwork | title + "Artist • 4:14" | trailing ---

  Widget _buildTrackRow({
    required ThemeData theme,
    required Track track,
    required bool isCurrent,
    required bool isPlaying,
    required Set<String>? likedIds,
    required bool isLikedList,
    required VoidCallback onTap,
    Key? key,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final isSelected = _selectedTrackIds.contains(track.id);
    final isLiked = likedIds?.contains(track.id) ?? track.isLiked;

    Widget trailing;
    if (_isSelectionMode) {
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
        data: _popupTheme(theme),
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
            } else if (val == 'like' || val == 'remove_liked') {
              final wasLiked = isLiked;
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
            } else if (val == 'select') {
              _enterSelectionMode(track);
            } else if (val == 'delete') {
              await _confirmDeleteTracks(context, ref, [track]);
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
              value: 'select',
              child: _menuRow(Icons.checklist_rounded, 'Select'),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'delete',
              child: _menuRow(
                Icons.delete_outline_rounded,
                'Delete from device',
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

  /// Action row + track list, shared by All, Audio, Liked Songs and Downloaded.
  Widget _buildTrackSection(
    ThemeData theme,
    List<Track> tracks,
    String keyPrefix,
    String? currentPlayingTrackId,
    bool isPlaybackPlaying, {
    bool isLikedList = false,
  }) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final likedAsync = ref.watch(likedTracksStreamProvider);
    // One Set lookup per row instead of scanning the liked list for every row
    final likedIds = likedAsync.value?.map((t) => t.id).toSet();
    // final isPlayingThisList = tracks.any((t) => t.id == currentPlayingTrackId);

    return SliverMainAxisGroup(
      slivers: [
        // if (!_isSelectionMode)
        //   SliverToBoxAdapter(
        //     child: _buildActionRow(theme, tracks, isPlayingThisList, isPlaybackPlaying),
        //   ),
        SliverFixedExtentList(
          // row height + vertical margins (2 + 2)
          itemExtent: _rowHeight + 4,
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final track = tracks[index];
              final isCurrent = currentPlayingTrackId == track.id;

              return _buildTrackRow(
                key: ValueKey('${keyPrefix}_${track.id}'),
                theme: theme,
                track: track,
                isCurrent: isCurrent,
                isPlaying: isCurrent && isPlaybackPlaying,
                likedIds: likedIds,
                isLikedList: isLikedList,
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
                    audioHandler.playTrackList(tracks, startIndex: index);
                    openNowPlayingScreen(context, targetTrack: track);
                  }
                },
              );
            },
            childCount: tracks.length,
            addAutomaticKeepAlives: false,
          ),
        ),
      ],
    );
  }

  Widget _errorSliver(ThemeData theme, String message) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }

  // --- Views for the different category filters ---

  Widget _buildPlaylistsView(ThemeData theme) {
    final playlistsAsync = ref.watch(playlistsStreamProvider);

    return playlistsAsync.when(
      data: (playlists) {
        final header = SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    playlists.length == 1 ? '1 playlist' : '${playlists.length} playlists',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                _tonalPill(
                  theme,
                  icon: Icons.link_rounded,
                  label: 'Import',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ImportPlaylistScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _tonalPill(
                  theme,
                  icon: Icons.add_rounded,
                  label: 'Create',
                  filled: true,
                  onTap: () => _showNewPlaylistDialog(context, ref),
                ),
              ],
            ),
          ),
        );

        if (playlists.isEmpty) {
          return SliverMainAxisGroup(
            slivers: [
              header,
              _emptyState(
                theme,
                icon: Icons.queue_music_rounded,
                title: 'No playlists yet',
                message: 'Create your first playlist to organize your songs.',
              ),
            ],
          );
        }

        return SliverMainAxisGroup(
          slivers: [
            header,
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final p = playlists[index];
                  return _HomePlaylistItem(
                    key: ValueKey('playlist_${p.id}'),
                    playlist: p,
                    onTap: () => _openPlaylistTracks(context, ref, p),
                    onEdit: () => _showEditPlaylistDialog(context, ref, p),
                    onDelete: () => _confirmDeletePlaylist(context, ref, p),
                  );
                },
                childCount: playlists.length,
              ),
            ),
          ],
        );
      },
      loading: () => TrackListSkeleton.sliver(itemCount: 6),
      error: (e, _) => _errorSliver(theme, 'Couldn\'t load playlists.\n$e'),
    );
  }

  Widget _buildLikedSongsView(
    ThemeData theme,
    List<Track> displayedTracks,
    AsyncValue<List<Track>> likedAsync,
    String? currentPlayingTrackId,
    bool isPlaybackPlaying,
  ) {
    return likedAsync.when(
      data: (_) {
        if (displayedTracks.isEmpty) {
          return _emptyState(
            theme,
            icon: Icons.favorite_border_rounded,
            title: _searchQuery.isNotEmpty
                ? 'No liked songs match "$_searchQuery"'
                : 'No liked songs yet',
            message: _searchQuery.isNotEmpty
                ? 'Try a different search.'
                : 'Tap the heart on any song to save it here.',
          );
        }
        return _buildTrackSection(
          theme,
          displayedTracks,
          'liked',
          currentPlayingTrackId,
          isPlaybackPlaying,
          isLikedList: true,
        );
      },
      loading: () => TrackListSkeleton.sliver(itemCount: 8),
      error: (e, _) => _errorSliver(theme, 'Couldn\'t load liked songs.\n$e'),
    );
  }

  Widget _buildDownloadedView(
    ThemeData theme,
    List<Track> displayedTracks,
    String? currentPlayingTrackId,
    bool isPlaybackPlaying,
  ) {
    if (displayedTracks.isEmpty) {
      return _emptyState(
        theme,
        icon: Icons.download_for_offline_rounded,
        title: _searchQuery.isNotEmpty
            ? 'No downloads match "$_searchQuery"'
            : 'No downloaded songs yet',
        message: _searchQuery.isNotEmpty
            ? 'Try a different search.'
            : 'Songs you download from search results will appear here for offline playback.',
        action: _searchQuery.isEmpty
            ? _tonalPill(
                theme,
                icon: Icons.stream_rounded,
                label: 'Explore stream',
                onTap: () => ref.read(currentTabIndexProvider.notifier).setIndex(0),
              )
            : null,
      );
    }

    return _buildTrackSection(theme, displayedTracks, 'dl', currentPlayingTrackId, isPlaybackPlaying);
  }

  Widget _buildFoldersView(ThemeData theme) {
    final folders = ref.watch(musicFoldersProvider);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;

    final query = _searchQuery.trim().toLowerCase();
    final displayedFolders = query.isEmpty
        ? folders
        : folders.where((f) {
            return f.name.toLowerCase().contains(query) || f.path.toLowerCase().contains(query);
          }).toList();

    if (displayedFolders.isEmpty) {
      return _emptyState(
        theme,
        icon: Icons.folder_off_rounded,
        title: _searchQuery.isNotEmpty ? 'No folders match "$_searchQuery"' : 'No audio folders found',
        message: 'Scan your device storage to find audio folders automatically.',
      );
    }

    final allTracks = displayedFolders.expand((f) => f.tracks).toList();
    final totalSongs = displayedFolders.fold<int>(0, (sum, f) => sum + f.trackCount);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${displayedFolders.length} ${displayedFolders.length == 1 ? "folder" : "folders"} • $totalSongs songs',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                _tonalPill(
                  theme,
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle all',
                  onTap: () => _playAll(allTracks, shuffle: true),
                ),
              ],
            ),
          ),
        ),
        SliverFixedExtentList(
          itemExtent: _rowHeight + 4,
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final folder = displayedFolders[index];
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => FolderDetailScreen(folder: folder)),
                  );
                },
                child: Container(
                  height: _rowHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: _surface(isDark),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.folder_rounded, color: _limeText(isDark), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folder.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyLarge.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${folder.trackCount} ${folder.trackCount == 1 ? "song" : "songs"} • ${folder.path}',
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
                      if (folder.formattedSize.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _limeTint(isDark),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            folder.formattedSize,
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _limeText(isDark),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: onSurface.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: displayedFolders.length,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.black : Colors.white;
    final sortedTracksAsync = ref.watch(sortedLocalTracksProvider);
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaybackPlaying = ref.watch(isPlaybackPlayingProvider);

    final localTracks = sortedTracksAsync.value ?? [];
    final musicTracks = localTracks.where((t) => !t.isAudioClip).toList();
    final audioClipTracks = localTracks.where((t) => t.isAudioClip).toList();
    final query = _searchQuery.trim().toLowerCase();

    final likedTracksAsync = ref.watch(likedTracksStreamProvider);

    List<Track> baseFilterTracks;
    if (_selectedFilter == 'Audio') {
      baseFilterTracks = audioClipTracks;
    } else if (_selectedFilter == 'Downloaded') {
      baseFilterTracks = localTracks.where((t) {
        final isFromApp = t.source != AudioSourceType.local ||
            (t.filePath != null && t.filePath!.toLowerCase().contains('musify'));
        return t.isDownloaded && isFromApp;
      }).toList();
    } else if (_selectedFilter == 'Liked Songs') {
      baseFilterTracks = likedTracksAsync.value ?? [];
    } else {
      // 'All' tab: full music tracks only, excluding ringtones, recordings, and short audio snippets
      baseFilterTracks = musicTracks;
    }

    final displayedTracks = query.isEmpty
        ? baseFilterTracks
        : baseFilterTracks.where((t) {
            return t.title.toLowerCase().contains(query) ||
                t.artistName.toLowerCase().contains(query) ||
                (t.albumTitle?.toLowerCase().contains(query) ?? false);
          }).toList();

    final List<Track> currentVisibleTracks = displayedTracks;

    // Header subtitle follows the current list: "128 songs • 8h 12m"
    final String subtitle;
    if (_trackFilters.contains(_selectedFilter)) {
      subtitle = (_selectedFilter == 'All' && query.isEmpty)
          ? '${_songsMeta(displayedTracks)} on this device'
          : _songsMeta(displayedTracks);
    } else {
      subtitle = '${_songsMeta(musicTracks)} on this device';
    }

    // Soft wash from the artwork of whatever is playing (neutral lime tint otherwise)
    final playingTrack = ref.watch(currentPlayingTrackProvider);
    Color? washAccent;
    if (playingTrack != null) {
      final paletteAsync = ref.watch(
        trackPaletteProvider((track: playingTrack, isDark: isDark)),
      );
      final palette = paletteAsync.value ??
          PaletteService.instance.getCachedPalette(playingTrack, isDark: isDark);
      if (palette != null) {
        _lastWashAccent = palette.backgroundColor;
      }
      washAccent = _lastWashAccent;
    } else {
      _lastWashAccent = null;
    }
    final hasPalette = washAccent != null;
    final washColor = washAccent ?? AppColors.neonLime;
    // Same strength and falloff as PlaylistDetailScreen so both pages match
    final washStrength = hasPalette ? (isDark ? 0.75 : 0.55) : (isDark ? 0.10 : 0.16);
    final topColor = _mix(baseColor, washColor, washStrength);

    final topInset = MediaQuery.paddingOf(context).top;
    // Matches the wash gradient colour at the height where the bar collapses (~140px out of 520px)
    final collapsedHeaderColor = _mix(topColor, baseColor, 0.36);
    const dividerColor = Colors.transparent;

    // Position RefreshIndicator cleanly below the pinned header chips when pulled down from top
    final headerTopOffset = topInset +
        (_isSelectionMode ? 58.0 : _expandedTop) +
        (_isSearchExpanded ? _searchFullHeight : 0.0) +
        _chipsHeight;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        backgroundColor: baseColor,
        bottomNavigationBar: _isSelectionMode && _selectedTrackIds.isNotEmpty
            ? _buildBatchActionBar(theme, currentVisibleTracks)
            : null,
        body: Stack(
          children: [
            // Color wash that dissolves into the page background
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 520,
              child: IgnorePointer(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: topColor),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInOutCubic,
                  builder: (context, animatedTop, _) {
                    final top = animatedTop ?? topColor;
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
            RefreshIndicator(
              edgeOffset: headerTopOffset,
              displacement: 28.0,
              color: AppColors.neonLime,
              backgroundColor: isDark ? const Color(0xFF1E2028) : Colors.white,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await triggerBackgroundStorageScan(ref);
                OnlineArtworkEnricher.triggerBackgroundEnrichment(ref);
                ref.invalidate(localTracksProvider);
                ref.invalidate(trackPlayCountsProvider);
                ref.invalidate(likedTracksStreamProvider);
                ref.invalidate(playlistsStreamProvider);
                try {
                  await ref.read(localTracksProvider.future);
                } catch (_) {}
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    _buildCollapsingHeader(
                      theme: theme,
                      subtitle: subtitle,
                      visibleTracks: currentVisibleTracks,
                      topInset: topInset,
                      topColor: topColor,
                      collapsedColor: collapsedHeaderColor,
                      dividerColor: dividerColor,
                    ),

                    sortedTracksAsync.when(
                      data: (_) {
                        if (_selectedFilter == 'Playlists') return _buildPlaylistsView(theme);
                        if (_selectedFilter == 'Folders') return _buildFoldersView(theme);
                        if (_selectedFilter == 'Liked Songs') {
                          return _buildLikedSongsView(
                            theme,
                            displayedTracks,
                            likedTracksAsync,
                            currentPlayingTrackId,
                            isPlaybackPlaying,
                          );
                        }
                        if (_selectedFilter == 'Downloaded') {
                          return _buildDownloadedView(
                            theme,
                            displayedTracks,
                            currentPlayingTrackId,
                            isPlaybackPlaying,
                          );
                        }
                        if (displayedTracks.isEmpty) {
                          return _emptyState(
                            theme,
                            icon: _selectedFilter == 'Audio'
                                ? Icons.mic_none_rounded
                                : Icons.music_off_rounded,
                            title: _searchQuery.isNotEmpty
                                ? 'No results for "$_searchQuery"'
                                : (_selectedFilter == 'Audio'
                                    ? 'No recordings or ringtones'
                                    : 'No songs on this device'),
                            message: _searchQuery.isNotEmpty
                                ? 'Try a different search.'
                                : (_selectedFilter == 'Audio'
                                    ? 'Voice notes, recordings and ringtones will show up here.'
                                    : 'Scan your storage to find the music you already have.'),
                            action: _searchQuery.isEmpty && _selectedFilter != 'Audio'
                                ? _tonalPill(
                                    theme,
                                    icon: Icons.refresh_rounded,
                                    label: 'Scan device storage',
                                    onTap: () async {
                                      await startScanWithProgressDialog(context, ref);
                                    },
                                  )
                                : null,
                          );
                        }
                        return _buildTrackSection(
                          theme,
                          displayedTracks,
                          'track',
                          currentPlayingTrackId,
                          isPlaybackPlaying,
                        );
                      },
                      loading: () => TrackListSkeleton.sliver(itemCount: 10),
                      error: (err, _) => _errorSliver(theme, 'Couldn\'t load your music.\n$err'),
                    ),

                    SliverToBoxAdapter(child: SizedBox(height: _isSelectionMode ? 100 : 170)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Borderless circular/pill glass filter chip matching top bar & selection header actions.
class _GlassFilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GlassFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_GlassFilterChip> createState() => _GlassFilterChipState();
}

class _GlassFilterChipState extends State<_GlassFilterChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circleBg =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07);
    final fg = isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isSelected ? AppColors.neonLime : circleBg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.neonLime.withValues(alpha: isDark ? 0.35 : 0.24),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13.5,
              letterSpacing: -0.2,
              fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
              color: widget.isSelected ? const Color(0xFF111827) : fg,
            ),
          ),
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
    this.size = 46,
  });

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.background ?? _surfaceFor(isDark);
    final fg = isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: widget.size * 0.48, color: widget.iconColor ?? fg),
        ),
      ),
    );
  }
}

/// Playlist row for the Playlists tab. Same geometry as the track rows:
/// 72px row, 54px artwork, 14px radius, same margins and typography.
class _HomePlaylistItem extends ConsumerWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HomePlaylistItem({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final tracksAsync = ref.watch(playlistTracksProvider(playlist.id));
    final tracks = tracksAsync.value ?? playlist.tracks;
    final audioHandler = ref.read(audioHandlerProvider);

    final songCountStr = '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}';
    final hasDesc = playlist.description != null && playlist.description!.trim().isNotEmpty;
    final subtitleText =
        hasDesc ? '$songCountStr • ${playlist.description!.trim()}' : songCountStr;

    void playPlaylist() {
      if (tracks.isNotEmpty) {
        audioHandler.playTrackList(tracks, startIndex: 0);
        openNowPlayingScreen(context, targetTrack: tracks.first);
      } else {
        AppSnackBar.show(
          context,
          message: 'This playlist has no songs to play',
          type: AppSnackBarType.info,
        );
      }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
        child: Row(
          children: [
            PlaylistArtwork(
              playlistId: playlist.id,
              coverUrl: playlist.coverUrl,
              preloadedTracks: tracks,
              size: 54,
              borderRadius: BorderRadius.circular(14),
              hasShadow: false,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitleText,
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
            const SizedBox(width: 6),
            _GlassCircleButton(
              icon: Icons.play_arrow_rounded,
              size: 38,
              iconColor: _iconColorFor(isDark),
              onTap: playPlaylist,
            ),
            Theme(
              data: _popupTheme(theme),
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 22,
                  color: onSurface.withValues(alpha: 0.6),
                ),
                onSelected: (value) {
                  HapticFeedback.selectionClick();
                  if (value == 'play') {
                    playPlaylist();
                  } else if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'play', child: _menuRow(Icons.play_arrow_rounded, 'Play')),
                  PopupMenuItem(value: 'edit', child: _menuRow(Icons.edit_outlined, 'Edit details')),
                  const PopupMenuDivider(height: 1),
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
      ),
    );
  }
}