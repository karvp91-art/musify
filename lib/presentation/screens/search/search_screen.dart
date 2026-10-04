import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/album/album_detail_screen.dart';
import 'package:musify/presentation/screens/artist/artist_detail_screen.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import 'package:musify/presentation/widgets/compact_card.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  Timer? _historyTimer;
  SearchMultiResult _multiResult = const SearchMultiResult();
  List<Track> _searchResults = [];
  bool _isSearching = false;
  String _selectedFilter = 'All';
  String _selectedGenre = 'Trending';

  // Multi-Selection State
  bool _isSelectionMode = false;
  final Set<String> _selectedTrackIds = {};

  // Production-grade search token to invalidate out-of-order responses
  int _searchToken = 0;

  // In-memory LRU search cache for instantaneous keystroke/backspace responses
  static final Map<String, ({SearchMultiResult multi, List<Track> songs, DateTime timestamp})> _searchCache = {};

  final List<String> _filters = const ['All', 'YouTube', 'Songs', 'Artists', 'Albums', 'Playlists'];

  final List<String> _genres = const [
    'Trending',
    'Bollywood',
    'Pop',
    'Lo-Fi',
    'Punjabi',
    'Indie',
    'EDM',
    'Acoustic',
    'Rock',
  ];

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

  List<Track> _getCurrentVisibleTracks() {
    if (_selectedFilter == 'All') {
      return _searchResults.isNotEmpty ? _searchResults : _multiResult.songs;
    }
    return _getFilteredResults();
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
    if (_isSelectionMode) {
      ref.read(isMultiSelectionModeProvider.notifier).setMode(false);
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _historyTimer?.cancel();
    super.dispose();
  }

  void _performSearch(String query, {bool addToHistory = true}) async {
    _debounceTimer?.cancel();
    _historyTimer?.cancel();
    final trimmed = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      setState(() {
        _multiResult = const SearchMultiResult();
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    if (addToHistory) {
      ref.read(searchHistoryProvider.notifier).addQuery(trimmed);
    }

    final cacheKey = trimmed.toLowerCase();
    final cached = _searchCache[cacheKey];

    // If cached in memory, show immediately with zero UI delay
    if (cached != null) {
      setState(() {
        _multiResult = cached.multi;
        _searchResults = cached.songs;
        _isSearching = false;
      });
      // If cached less than 3 minutes ago, no need to re-fetch
      if (DateTime.now().difference(cached.timestamp) < const Duration(minutes: 3)) {
        return;
      }
    } else {
      setState(() {
        _isSearching = true;
      });
    }

    final token = ++_searchToken;

    try {
      final saavn = ref.read(saavnAdapterProvider);
      final router = ref.read(sourceRouterProvider);

      // Parallel execution for lowest possible latency across JioSaavn and other audio sources
      final multiFuture = saavn.searchMulti(trimmed).catchError((_) => const SearchMultiResult());
      final routerFuture = router.searchAll(trimmed, includeLocal: false).catchError((_) => <Track>[]);

      final results = await Future.wait([multiFuture, routerFuture]);
      final multi = results[0] as SearchMultiResult;
      final onlineTracks = results[1] as List<Track>;

      // Stale response check: If user typed something else while request was in-flight, discard
      if (token != _searchToken || !mounted) return;

      // Smart deduplication across sources
      final List<Track> combinedSongs = [...multi.songs];
      for (final t in onlineTracks) {
        final isDupe = combinedSongs.any((e) =>
            e.id == t.id ||
            (e.title.toLowerCase().trim() == t.title.toLowerCase().trim() &&
                e.artistName.toLowerCase().trim() == t.artistName.toLowerCase().trim()));
        if (!isDupe) {
          combinedSongs.add(t);
        }
      }

      // Store in LRU cache
      if (_searchCache.length >= 60) {
        _searchCache.remove(_searchCache.keys.first);
      }
      _searchCache[cacheKey] = (
        multi: multi,
        songs: combinedSongs,
        timestamp: DateTime.now(),
      );

      setState(() {
        _multiResult = multi;
        _searchResults = combinedSongs;
        _isSearching = false;
      });
    } catch (_) {
      if (token == _searchToken && mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _historyTimer?.cancel();
    final trimmed = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      if (_searchResults.isNotEmpty || _multiResult.isNotEmpty || _isSearching) {
        setState(() {
          _searchResults = [];
          _multiResult = const SearchMultiResult();
          _isSearching = false;
        });
      }
      return;
    }

    // Do NOT trigger automatic network search on a single character (e.g. 'a')
    if (trimmed.length < 2) {
      if (_searchResults.isNotEmpty || _multiResult.isNotEmpty || _isSearching) {
        setState(() {
          _searchResults = [];
          _multiResult = const SearchMultiResult();
          _isSearching = false;
        });
      }
      return;
    }

    // Instant cache lookup on keystroke for queries >= 2 chars
    final cacheKey = trimmed.toLowerCase();
    final cached = _searchCache[cacheKey];
    if (cached != null) {
      setState(() {
        _multiResult = cached.multi;
        _searchResults = cached.songs;
        _isSearching = false;
      });
    } else {
      // Mark as searching right away on typing so UI shows loading instead of premature "No results found"
      setState(() {
        _isSearching = true;
      });
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(trimmed, addToHistory: false);
    });

    // Auto-record to recent search history after 1.5s pause when query has substantial length
    if (trimmed.length >= 3) {
      _historyTimer = Timer(const Duration(milliseconds: 1500), () {
        ref.read(searchHistoryProvider.notifier).addQuery(trimmed);
      });
    }
  }

  List<Track> _getFilteredResults() {
    final onlineResults = _searchResults.where((t) => t.source != AudioSourceType.local).toList();
    if (_selectedFilter == 'All' || _selectedFilter == 'Songs') {
      return onlineResults;
    }
    if (_selectedFilter == 'JioSaavn') {
      return onlineResults.where((t) => t.source == AudioSourceType.saavn).toList();
    }
    if (_selectedFilter == 'YouTube') {
      return onlineResults.where((t) => t.source == AudioSourceType.youtube).toList();
    }
    if (_selectedFilter == 'Artists') {
      return onlineResults;
    }
    if (_selectedFilter == 'Albums') {
      return onlineResults.where((t) => t.albumTitle != null).toList();
    }
    return onlineResults;
  }

  void _handleBatchPlayNext(List<Track> selectedTracks) {
    if (selectedTracks.isEmpty) return;
    HapticFeedback.mediumImpact();
    final audioHandler = ref.read(audioHandlerProvider);
    for (final track in selectedTracks.reversed) {
      audioHandler.insertNextInQueue(track);
    }
    showSnackBar(
      context,
      'Playing next: ${selectedTracks.length} ${selectedTracks.length == 1 ? "track" : "tracks"}',
      type: AppSnackBarType.success,
    );
    _exitSelectionMode();
  }

  void _handleBatchAddToQueue(List<Track> selectedTracks) {
    if (selectedTracks.isEmpty) return;
    HapticFeedback.mediumImpact();
    final audioHandler = ref.read(audioHandlerProvider);
    for (final track in selectedTracks) {
      audioHandler.addToQueue(track);
    }
    showSnackBar(
      context,
      'Added ${selectedTracks.length} ${selectedTracks.length == 1 ? "track" : "tracks"} to queue',
      type: AppSnackBarType.success,
    );
    _exitSelectionMode();
  }

  void _handleBatchDownload(List<Track> selectedTracks) {
    if (selectedTracks.isEmpty) return;
    HapticFeedback.mediumImpact();
    final manager = ref.read(downloadManagerProvider);
    for (final track in selectedTracks) {
      manager.downloadTrack(track);
    }
    showSnackBar(
      context,
      'Downloading ${selectedTracks.length} ${selectedTracks.length == 1 ? "track" : "tracks"}',
      type: AppSnackBarType.success,
    );
    _exitSelectionMode();
  }

  void _handleBatchAddToPlaylist(BuildContext context, List<Track> selectedTracks) {
    if (selectedTracks.isEmpty) return;
    HapticFeedback.mediumImpact();
    showAddToPlaylistModal(
      context,
      ref,
      track: selectedTracks.first,
      tracks: selectedTracks,
    );
    _exitSelectionMode();
  }

  Widget _buildSelectionHeader(ThemeData theme, List<Track> currentVisibleTracks) {
    final isDark = theme.brightness == Brightness.dark;
    final allSelected = currentVisibleTracks.isNotEmpty &&
        currentVisibleTracks.every((t) => _selectedTrackIds.contains(t.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: [
          // Close button to exit selection mode
          _GlassCircleButton(
            icon: Icons.close_rounded,
            size: 40,
            iconSize: 20,
            onTap: () {
              HapticFeedback.selectionClick();
              _exitSelectionMode();
            },
          ),
          const SizedBox(width: 12),

          // Count text
          Expanded(
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

          // Select All / Deselect All
          _GlassCircleButton(
            icon: allSelected ? Icons.check_box_rounded : Icons.checklist_rounded,
            size: 40,
            iconSize: 20,
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

          // More Options popup menu
          _buildMoreSelectionMenu(context, currentVisibleTracks, isDark),
        ],
      ),
    );
  }

  Widget _buildMoreSelectionMenu(
    BuildContext context,
    List<Track> currentVisibleTracks,
    bool isDark,
  ) {
    final allSelected = currentVisibleTracks.isNotEmpty &&
        currentVisibleTracks.every((t) => _selectedTrackIds.contains(t.id));

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
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
          final selected = currentVisibleTracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
          if (value == 'toggle_all') {
            setState(() {
              if (allSelected) {
                _selectedTrackIds.clear();
              } else {
                _selectedTrackIds.addAll(currentVisibleTracks.map((t) => t.id));
              }
            });
          } else if (value == 'play_next') {
            _handleBatchPlayNext(selected);
          } else if (value == 'add_queue') {
            _handleBatchAddToQueue(selected);
          } else if (value == 'download') {
            _handleBatchDownload(selected);
          } else if (value == 'add_playlist') {
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
                Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: AppTypography.style(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'play_next',
            child: Row(
              children: [
                Icon(
                  Icons.playlist_play_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 12),
                Text(
                  'Play Next',
                  style: AppTypography.style(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'add_queue',
            child: Row(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 12),
                Text(
                  'Add to Queue',
                  style: AppTypography.style(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'download',
            child: Row(
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 12),
                Text(
                  'Download Selected',
                  style: AppTypography.style(fontSize: 14, fontWeight: FontWeight.w500),
                ),
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
                Text(
                  'Add to Playlist',
                  style: AppTypography.style(fontSize: 14, fontWeight: FontWeight.w500),
                ),
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
                Text(
                  'Cancel Selection',
                  style: AppTypography.style(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCapsuleActionItem(
                  icon: Icons.playlist_play_rounded,
                  label: 'Play\nNext',
                  onTap: () => _handleBatchPlayNext(selectedTracks),
                ),
                const SizedBox(width: 14),
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
            style: AppTypography.style(
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

  Widget _buildSearchLoadingState(ThemeData theme, bool isDark) {
    final primaryColor = theme.colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.neonLime : primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Searching high-fidelity catalog...',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Querying songs, artists, albums & playlists',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Top Bar matching HomeScreen (with centered title) ---
  Widget _buildTopHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 8),
      child: Row(
        children: [
          // Left balance spacer (matches the 44px width of the right button)
          const SizedBox(width: 44),

          // Center: Title "Search & Explore"
          Expanded(
            child: Text(
              'Search & Explore',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Right: Refresh Online Tracks Button (Borderless 44px)
          _GlassCircleButton(
            icon: _isSearching ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              if (_searchController.text.isNotEmpty) {
                _performSearch(_searchController.text, addToHistory: true);
              } else {
                ref.invalidate(saavnTrendingTracksProvider);
                ref.invalidate(saavnGenreTracksProvider);
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Search Input Bar matching Screenshot 1 capsule design: [<] [Query] [X] [Mic] ---
  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Padding(
      key: const ValueKey('search_bar_padding_wrapper'),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            // Left search icon (constant, stable, never steals focus)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.search_rounded,
                size: 22,
                color: theme.colorScheme.primary,
              ),
            ),

            // Search text field
            Expanded(
              child: TextField(
                key: const ValueKey('search_screen_text_field'),
                focusNode: _searchFocusNode,
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (query) {
                  _historyTimer?.cancel();
                  if (query.trim().isNotEmpty) {
                    _performSearch(query, addToHistory: true);
                  }
                },
                style: AppTypography.style(
                  color: isDark ? Colors.white : const Color(0xFF1E2028),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  hintStyle: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Clear 'X' button (only rebuilds itself via ValueListenableBuilder, never unmounts TextField)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                if (value.text.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () {
                    _historyTimer?.cancel();
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                );
              },
            ),

            // Mic Icon (Screenshot 1)
            IconButton(
              icon: Icon(
                Icons.mic_rounded,
                size: 22,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                showSnackBar(
                  context,
                  'Voice search active. Speak or type artist / album name.',
                  type: AppSnackBarType.info,
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  // --- Filter Pills matching HomeScreen borderless animated capsule pills ---
  Widget _buildFilterPills(
    List<String> items,
    String selectedItem,
    ValueChanged<String> onSelected,
    ThemeData theme,
    bool isDark,
  ) {
    final primaryColor = theme.colorScheme.primary;
    final selectedBg = isDark ? primaryColor : AppColors.neonLime;
    final unselectedBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final unselectedTextColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF1E2028);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: items.map((item) {
          final isSelected = item == selectedItem;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(item);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBg : unselectedBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  item,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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

  // --- Search History Section (Recent Searches) ---
  Widget _buildSearchHistory(ThemeData theme, bool isDark) {
    final historyAsync = ref.watch(searchHistoryProvider);

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: RECENT SEARCHES & Clear all
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RECENT SEARCHES',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showClearHistoryDialog(context);
                    },
                    child: Text(
                      'Clear all',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Column(
                children: history.take(6).map((item) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _historyTimer?.cancel();
                      _searchController.text = item;
                      _searchController.selection = TextSelection.fromPosition(
                        TextPosition(offset: item.length),
                      );
                      _performSearch(item, addToHistory: true);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item,
                              style: AppTypography.style(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E2028),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(searchHistoryProvider.notifier).removeQuery(item);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 17,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _showClearHistoryDialog(BuildContext context) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Clear Search History?',
      description: 'Are you sure you want to remove all recent searches from your history?',
      confirmText: 'Clear',
      cancelText: 'Cancel',
      icon: Icons.history_rounded,
    );

    if (confirmed == true) {
      ref.read(searchHistoryProvider.notifier).clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioHandler = ref.watch(audioHandlerProvider);

    // Watch JioSaavn 320kbps tracks for selected genre
    final saavnAsync = _selectedGenre == 'Trending'
        ? ref.watch(saavnTrendingTracksProvider)
        : ref.watch(saavnGenreTracksProvider(_selectedGenre.toLowerCase()));

    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = keyboardHeight > 0 ? keyboardHeight + 84.0 : 160.0;

    final visibleTracks = _getCurrentVisibleTracks();

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: isDark ? Colors.black : Colors.white,
        bottomNavigationBar: _isSelectionMode && _selectedTrackIds.isNotEmpty
            ? _buildBatchActionBar(theme, visibleTracks)
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Bar: Selection Header when in selection mode, else standard top header
              _isSelectionMode
                  ? _buildSelectionHeader(theme, visibleTracks)
                  : _buildTopHeader(theme),

              // Search Input Bar (only shown when not in selection mode)
              if (!_isSelectionMode)
                _buildSearchBar(theme, isDark),

              // Filter Chips (when active search results exist and not in selection mode)
              if (!_isSelectionMode &&
                  _searchController.text.trim().length >= 2 &&
                  (_searchResults.isNotEmpty || _multiResult.isNotEmpty))
                _buildFilterPills(
                  _filters,
                  _selectedFilter,
                  (val) => setState(() => _selectedFilter = val),
                  theme,
                  isDark,
                ),

            // Results / Suggestions / Trending High-Fidelity
            Expanded(
              child: Stack(
                children: [
                  _searchController.text.trim().length < 2
                      ? RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(saavnTrendingTracksProvider);
                            ref.invalidate(saavnGenreTracksProvider);
                          },
                          child: ListView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.only(bottom: bottomPadding),
                            children: [
                              // Recent Searches History Section (prominently at the top)
                              _buildSearchHistory(theme, isDark),

                              // JioSaavn Discovery Header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Trending High-Fidelity',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '320kbps Direct Stream',
                                          style: AppTypography.caption.copyWith(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.graphic_eq_rounded,
                                            size: 14,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '320 KBPS',
                                            style: AppTypography.style(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: primaryColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Genre Pills (matching HomeScreen animated capsule pills)
                              _buildFilterPills(
                                _genres,
                                _selectedGenre,
                                (val) => setState(() => _selectedGenre = val),
                                theme,
                                isDark,
                              ),
                              const SizedBox(height: 12),

                              // JioSaavn Tracks Horizontal Carousel
                              SizedBox(
                                height: 200,
                                child: saavnAsync.when(
                                  data: (saavnTracks) {
                                    if (saavnTracks.isEmpty) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.wifi_off_rounded,
                                                size: 20,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Offline or no tracks found for $_selectedGenre',
                                                style: theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    return ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      itemCount: saavnTracks.length,
                                      itemBuilder: (context, index) {
                                        final track = saavnTracks[index];
                                        return CompactCard(
                                          title: track.title,
                                          subtitle: track.artistName,
                                          imageUrl: track.artworkUrl,
                                          onTap: () {
                                            _historyTimer?.cancel();
                                            ref.read(searchHistoryProvider.notifier).addQuery(track.title);
                                            audioHandler.playTrackList(saavnTracks, startIndex: index);
                                          },
                                        );
                                      },
                                    );
                                  },
                                  loading: () => const Center(
                                    child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    ),
                                  ),
                                  error: (err, _) => Center(
                                    child: Text(
                                      'Unable to reach online catalog',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        )
                      : _buildActiveSearchResults(theme, isDark, bottomPadding),
                  if (_isSearching)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        backgroundColor: Colors.transparent,
                        color: AppColors.neonLime,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search terms or filter',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSearchResults(ThemeData theme, bool isDark, double bottomPadding) {
    final isActivelySearching = _isSearching || (_debounceTimer?.isActive ?? false);

    if (_selectedFilter == 'All') {
      if (_multiResult.isNotEmpty) {
        return _buildMultiResultView(theme, isDark, bottomPadding);
      }
      if (isActivelySearching) {
        return _buildSearchLoadingState(theme, isDark);
      }
      return _buildEmptyState(theme, 'No results found for "${_searchController.text.trim()}"');
    } else if (_selectedFilter == 'Artists') {
      if (_multiResult.artists.isNotEmpty) {
        return _buildArtistsListView(theme, isDark, bottomPadding);
      }
      if (isActivelySearching) {
        return _buildSearchLoadingState(theme, isDark);
      }
      return _buildEmptyState(theme, 'No artists found for "${_searchController.text.trim()}"');
    } else if (_selectedFilter == 'Albums') {
      if (_multiResult.albums.isNotEmpty) {
        return _buildAlbumsListView(theme, isDark, bottomPadding);
      }
      if (isActivelySearching) {
        return _buildSearchLoadingState(theme, isDark);
      }
      return _buildEmptyState(theme, 'No albums found for "${_searchController.text.trim()}"');
    } else if (_selectedFilter == 'Playlists') {
      if (_multiResult.playlists.isNotEmpty) {
        return _buildPlaylistsListView(theme, isDark, bottomPadding);
      }
      if (isActivelySearching) {
        return _buildSearchLoadingState(theme, isDark);
      }
      return _buildEmptyState(theme, 'No playlists found for "${_searchController.text.trim()}"');
    }

    final filteredResults = _getFilteredResults();
    if (filteredResults.isEmpty && _multiResult.isEmpty) {
      if (isActivelySearching) {
        return _buildSearchLoadingState(theme, isDark);
      }
      return _buildEmptyState(theme, 'No results found for "${_searchController.text.trim()}"');
    }

    return _buildTracksListView(filteredResults, theme, isDark, bottomPadding);
  }

  /// Multi-result layout: Top Result, Playlists, and Songs with full artist & album navigation
  Widget _buildMultiResultView(ThemeData theme, bool isDark, double bottomPadding) {
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaybackPlaying = ref.watch(isPlaybackPlayingProvider);
    final topResults = _multiResult.topResults;
    final playlists = _multiResult.playlists;
    final songs = _searchResults.isNotEmpty ? _searchResults : _multiResult.songs;
    final albums = _multiResult.albums;
    final artists = _multiResult.artists;

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPadding),
      children: [
        // 1. Top Result Section
        if (topResults.isNotEmpty || artists.isNotEmpty || albums.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Top Result',
              style: AppTypography.style(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E2028),
              ),
            ),
          ),

          // Primary Top Result item
          ...topResults.take(1).map((top) {
            final isArtist = top.isArtist;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                if (isArtist) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ArtistDetailScreen(
                        artistId: top.id,
                        initialName: top.title,
                        initialImageUrl: top.imageUrl,
                      ),
                    ),
                  );
                } else if (top.isAlbum) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AlbumDetailScreen(
                        albumId: top.id,
                        initialTitle: top.title,
                        initialArtworkUrl: top.imageUrl,
                      ),
                    ),
                  );
                } else if (songs.isNotEmpty) {
                  ref.read(audioHandlerProvider).playTrackList(songs, startIndex: 0);
                }
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
              child: Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.scaffoldBackgroundColor,
                ),
                child: Row(
                  children: [
                    TrackArtwork(
                      artworkUrl: top.imageUrl,
                      size: 54,
                      isCircle: isArtist,
                      borderRadius: isArtist ? null : BorderRadius.circular(14),
                      fallbackIcon: isArtist ? Icons.person_rounded : Icons.album_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  top.title,
                                  style: AppTypography.style(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E2028),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isArtist) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: Colors.blueAccent,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            top.description?.isNotEmpty == true
                                ? top.description!
                                : (isArtist ? 'Artist' : 'Top Hit'),
                            style: AppTypography.caption.copyWith(
                              fontSize: 12.5,
                              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Secondary artist item under Top Result if available
          ...artists.take(1).where((a) => topResults.isEmpty || a.id != topResults.first.id).map((artist) {
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArtistDetailScreen(
                      artistId: artist.id,
                      initialName: artist.title,
                      initialImageUrl: artist.imageUrl,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
              child: Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.scaffoldBackgroundColor,
                ),
                child: Row(
                  children: [
                    TrackArtwork(
                      artworkUrl: artist.imageUrl,
                      size: 54,
                      isCircle: true,
                      fallbackIcon: Icons.person_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  artist.title,
                                  style: AppTypography.style(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E2028),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: Colors.blueAccent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            artist.description.isNotEmpty ? artist.description : 'Artist',
                            style: AppTypography.caption.copyWith(
                              fontSize: 12.5,
                              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        // 2. Playlists Section
        if (playlists.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Playlists',
                  style: AppTypography.style(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E2028),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedFilter = 'Playlists');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...playlists.take(3).map((playlist) {
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _searchController.text = playlist.title;
                _performSearch(playlist.title, addToHistory: true);
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
              child: Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.scaffoldBackgroundColor,
                ),
                child: Row(
                  children: [
                    TrackArtwork(
                      artworkUrl: playlist.imageUrl,
                      size: 54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            style: AppTypography.style(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E2028),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            playlist.description,
                            style: AppTypography.caption.copyWith(
                              fontSize: 12.5,
                              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        // 3. Songs Section
        if (songs.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Songs',
                  style: AppTypography.style(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E2028),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedFilter = 'Songs');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...songs.take(6).map((track) {
            final isCurrent = currentPlayingTrackId == track.id;
            final isTilePlaying = isCurrent && isPlaybackPlaying;

            return TrackListTile(
              key: ValueKey('multi_search_${track.id}'),
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
                      if (_selectedTrackIds.isEmpty) {
                        _exitSelectionMode();
                      }
                    } else {
                      _selectedTrackIds.add(track.id);
                    }
                  });
                  return;
                }
                HapticFeedback.selectionClick();
                final query = _searchController.text.trim();
                if (query.isNotEmpty) {
                  ref.read(searchHistoryProvider.notifier).addQuery(query);
                }
                ref.read(audioHandlerProvider).playTrackList(songs, startIndex: songs.indexOf(track));
              },
              onLongPress: () {
                _enterSelectionMode(track);
              },
              onLikeToggle: () {
                ref.read(audioRepositoryProvider).toggleLike(track);
              },
            );
          }),
        ],

        // 4. Albums Section
        if (albums.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Albums',
              style: AppTypography.style(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E2028),
              ),
            ),
          ),
          ...albums.take(3).map((album) {
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AlbumDetailScreen(
                      albumId: album.id,
                      initialTitle: album.title,
                      initialArtist: album.music,
                      initialArtworkUrl: album.imageUrl,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
              child: Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.scaffoldBackgroundColor,
                ),
                child: Row(
                  children: [
                    TrackArtwork(
                      artworkUrl: album.imageUrl,
                      size: 54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            style: AppTypography.style(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E2028),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            album.description.isNotEmpty
                                ? album.description
                                : (album.music != null && album.music!.isNotEmpty
                                    ? '${album.music!} • Album'
                                    : 'Album'),
                            style: AppTypography.caption.copyWith(
                              fontSize: 12.5,
                              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  /// Full Artists Tab
  Widget _buildArtistsListView(ThemeData theme, bool isDark, double bottomPadding) {
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPadding, top: 4),
      itemCount: _multiResult.artists.length,
      itemBuilder: (context, index) {
        final artist = _multiResult.artists[index];
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArtistDetailScreen(
                  artistId: artist.id,
                  initialName: artist.title,
                  initialImageUrl: artist.imageUrl,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.scaffoldBackgroundColor,
            ),
            child: Row(
              children: [
                TrackArtwork(
                  artworkUrl: artist.imageUrl,
                  size: 54,
                  isCircle: true,
                  fallbackIcon: Icons.person_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              artist.title,
                              style: AppTypography.style(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E2028),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: Colors.blueAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artist.description.isNotEmpty ? artist.description : 'Artist',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.5,
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Full Albums Tab
  Widget _buildAlbumsListView(ThemeData theme, bool isDark, double bottomPadding) {
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPadding, top: 4),
      itemCount: _multiResult.albums.length,
      itemBuilder: (context, index) {
        final album = _multiResult.albums[index];
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AlbumDetailScreen(
                  albumId: album.id,
                  initialTitle: album.title,
                  initialArtist: album.music,
                  initialArtworkUrl: album.imageUrl,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.scaffoldBackgroundColor,
            ),
            child: Row(
              children: [
                TrackArtwork(
                  artworkUrl: album.imageUrl,
                  size: 54,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title,
                        style: AppTypography.style(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E2028),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        album.description.isNotEmpty
                            ? album.description
                            : (album.music != null && album.music!.isNotEmpty
                                ? '${album.music!} • Album'
                                : 'Album'),
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.5,
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Full Playlists Tab
  Widget _buildPlaylistsListView(ThemeData theme, bool isDark, double bottomPadding) {
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPadding, top: 4),
      itemCount: _multiResult.playlists.length,
      itemBuilder: (context, index) {
        final playlist = _multiResult.playlists[index];
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _searchController.text = playlist.title;
            _performSearch(playlist.title, addToHistory: true);
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.scaffoldBackgroundColor,
            ),
            child: Row(
              children: [
                TrackArtwork(
                  artworkUrl: playlist.imageUrl,
                  size: 54,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.title,
                        style: AppTypography.style(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E2028),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        playlist.description,
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.5,
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Songs & YouTube Tracks List
  Widget _buildTracksListView(
    List<Track> filteredResults,
    ThemeData theme,
    bool isDark,
    double bottomPadding,
  ) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaybackPlaying = ref.watch(isPlaybackPlayingProvider);

    return Column(
      children: [
        if (_selectedFilter == 'YouTube')
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1414) : const Color(0xFFFFF4F4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF0000).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFFFF3333),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'YouTube tracks will be saved directly into your permanent music folder.',
                    style: AppTypography.caption.copyWith(
                      color: isDark ? Colors.white70 : const Color(0xFF551111),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomPadding),
            itemExtent: 76.0,
            itemCount: filteredResults.length,
            itemBuilder: (context, index) {
              final track = filteredResults[index];
              final isCurrent = currentPlayingTrackId == track.id;
              final isTilePlaying = isCurrent && isPlaybackPlaying;

              return TrackListTile(
                key: ValueKey('search_${track.id}'),
                track: track,
                isCurrent: isCurrent,
                isPlaying: isTilePlaying,
                isYouTubeSection: _selectedFilter == 'YouTube',
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedTrackIds.contains(track.id),
                onTap: () {
                  if (_isSelectionMode) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (_selectedTrackIds.contains(track.id)) {
                        _selectedTrackIds.remove(track.id);
                        if (_selectedTrackIds.isEmpty) {
                          _exitSelectionMode();
                        }
                      } else {
                        _selectedTrackIds.add(track.id);
                      }
                    });
                    return;
                  }
                  if (isCurrent) {
                    HapticFeedback.selectionClick();
                    if (!isPlaybackPlaying) {
                      audioHandler.play();
                    }
                    return;
                  }
                  _historyTimer?.cancel();
                  final query = _searchController.text.trim();
                  if (query.isNotEmpty) {
                    ref.read(searchHistoryProvider.notifier).addQuery(query);
                  } else {
                    ref.read(searchHistoryProvider.notifier).addQuery(track.title);
                  }
                  audioHandler.playTrackList(filteredResults, startIndex: index);
                },
                onLongPress: () {
                  _enterSelectionMode(track);
                },
                onLikeToggle: () {
                  ref.read(audioRepositoryProvider).toggleLike(track);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Borderless circular button matching HomeScreen header action style
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 20,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final buttonBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final effectiveIconColor = iconColor ?? (isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonBg,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: effectiveIconColor,
        ),
      ),
    );
  }
}
