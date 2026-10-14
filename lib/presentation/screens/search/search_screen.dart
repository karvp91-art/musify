import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/data/sources/saavn_source_adapter.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/album/album_detail_screen.dart';
import 'package:musify/presentation/screens/artist/artist_detail_screen.dart';
import 'package:musify/presentation/screens/player/now_playing_screen.dart';
import 'package:musify/presentation/screens/stream/stream_playlist_detail_screen.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import 'package:musify/presentation/screens/stream/widgets/stream_cards.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';
import 'package:musify/presentation/providers/network_providers.dart';
import 'package:musify/presentation/widgets/download_dynamic_island.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/offline_state_view.dart';
import 'package:musify/presentation/widgets/shimmer_skeleton.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';
import 'package:musify/presentation/widgets/theme_selection_bottom_sheet.dart';

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  Timer? _historyTimer;
  SearchMultiResult _multiResult = const SearchMultiResult();
  List<Track> _searchResults = [];
  bool _isSearching = false;
  int _searchPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _selectedFilter = 'All';

  @override
  bool get wantKeepAlive => true;

  // Theme helpers
  Color _surface(bool isDark) => isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
  Color _limeText(bool isDark) => isDark ? AppColors.neonLime : AppColors.limeAccentDark;
  Color? _lastWashAccent;

  // Multi-Selection State
  bool _isSelectionMode = false;
  final Set<String> _selectedTrackIds = {};

  // Token to invalidate out-of-order responses
  int _searchToken = 0;

  // In-memory LRU search cache for instant responses
  static final Map<String, ({SearchMultiResult multi, List<Track> songs, DateTime timestamp})>
      _searchCache = {};

  final List<String> _filters = const [
    'All',
    'YouTube',
    'Songs',
    'Artists',
    'Albums',
    'Playlists',
  ];

  final List<String> _trendingSearches = const [
    'Arijit Singh',
    'Diljit Dosanjh',
    'Taylor Swift',
    'The Weeknd',
    'Punjabi Hits',
    'Lo-Fi Chill',
    'Gym Workout',
    'Bollywood Top 50',
    'Billie Eilish',
    'Karan Aujla',
    'Anirudh',
    'Atif Aslam',
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
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMoreSearchResults();
    }
  }

  Future<void> _loadMoreSearchResults() async {
    if (_isLoadingMore || !_hasMore || _isSearching) return;
    final query = _searchController.text.trim();
    if (query.isEmpty || query.length < 2) return;
    if (ref.read(isOfflineProvider)) {
      setState(() => _hasMore = false);
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _searchPage + 1;
      final saavn = ref.read(saavnAdapterProvider);
      final newTracks = await saavn.search(query, page: nextPage, limit: 25);

      if (!mounted) return;

      if (newTracks.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
      } else {
        final List<Track> updated = [..._searchResults];
        final seenKeys = updated.map((t) => '${SaavnSourceAdapter.normalizeSongTitle(t.title)}|${t.artistName.toLowerCase().trim()}').toSet();
        for (final t in newTracks) {
          final key = '${SaavnSourceAdapter.normalizeSongTitle(t.title)}|${t.artistName.toLowerCase().trim()}';
          if (seenKeys.add(key)) {
            updated.add(t);
          }
        }

        setState(() {
          _searchPage = nextPage;
          _searchResults = updated;
          _isLoadingMore = false;
          if (newTracks.length < 10) {
            _hasMore = false;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _historyTimer?.cancel();
    super.dispose();
  }

  void _performSearch(String query, {bool addToHistory = true}) async {
    _debounceTimer?.cancel();
    _historyTimer?.cancel();
    _searchPage = 1;
    _hasMore = true;
    _isLoadingMore = false;
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
      if (DateTime.now().difference(cached.timestamp) < const Duration(minutes: 3)) {
        return;
      }
    } else {
      setState(() {
        _isSearching = true;
      });
    }

    final token = ++_searchToken;

    // Fast-path: When offline, search device's downloaded & local audio library directly
    final isOffline = ref.read(isOfflineProvider);
    if (isOffline) {
      try {
        final localTracks = await ref.read(audioRepositoryProvider).searchTracks(trimmed);
        if (token != _searchToken || !mounted) return;
        setState(() {
          _multiResult = SearchMultiResult(songs: localTracks);
          _searchResults = localTracks;
          _isSearching = false;
        });
        return;
      } catch (_) {
        if (token == _searchToken && mounted) {
          setState(() => _isSearching = false);
        }
        return;
      }
    }

    try {
      final saavn = ref.read(saavnAdapterProvider);
      final router = ref.read(sourceRouterProvider);

      final multiFuture = saavn.searchMulti(trimmed).catchError((_) => const SearchMultiResult());
      final routerFuture = router.searchAll(trimmed, includeLocal: false).catchError((_) => <Track>[]);

      final results = await Future.wait([multiFuture, routerFuture]);
      final multi = results[0] as SearchMultiResult;
      final onlineTracks = results[1] as List<Track>;

      if (token != _searchToken || !mounted) return;

      // Smart deduplication across sources (prioritizing full online search tracks with complete 320k streams)
      final List<Track> combinedSongs = [...onlineTracks];
      for (final t in multi.songs) {
        final isDupe = combinedSongs.any((e) =>
            e.id == t.id ||
            (SaavnSourceAdapter.normalizeSongTitle(e.title) == SaavnSourceAdapter.normalizeSongTitle(t.title) &&
                e.artistName.toLowerCase().trim() == t.artistName.toLowerCase().trim()));
        if (!isDupe) {
          combinedSongs.add(t);
        }
      }

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

    final cacheKey = trimmed.toLowerCase();
    final cached = _searchCache[cacheKey];
    if (cached != null) {
      setState(() {
        _multiResult = cached.multi;
        _searchResults = cached.songs;
        _isSearching = false;
      });
    } else {
      setState(() {
        _isSearching = true;
      });
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(trimmed, addToHistory: false);
    });

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
    if (_selectedFilter == 'YouTube') {
      return onlineResults.where((t) => t.source == AudioSourceType.youtube).toList();
    }
    if (_selectedFilter == 'Artists' || _selectedFilter == 'Albums' || _selectedFilter == 'Playlists') {
      return onlineResults;
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
    _exitSelectionMode();
  }

  Future<void> _playSearchedTrack(Track track, {List<Track>? searchQueue}) async {
    final currentPlayingTrackId = ref.read(currentPlayingTrackIdProvider);
    final isPlaying = ref.read(isPlaybackPlayingProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    if (currentPlayingTrackId == track.id) {
      if (isPlaying) {
        audioHandler.pause();
      } else {
        audioHandler.play();
        openNowPlayingScreen(context, targetTrack: track);
      }
      return;
    }

    final currentTracks = searchQueue ?? _getCurrentVisibleTracks();
    final effectiveList = currentTracks.isNotEmpty ? currentTracks : [track];
    final startIndex = effectiveList.indexWhere(
      (t) => t.id == track.id || (t.sourceId.isNotEmpty && t.sourceId == track.sourceId),
    );

    if (startIndex != -1) {
      audioHandler.playTrackList(effectiveList, startIndex: startIndex);
    } else {
      audioHandler.playTrackList([track, ...effectiveList], startIndex: 0);
    }
    openNowPlayingScreen(context, targetTrack: track);
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
                background: circleBg,
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
              _buildMoreSelectionMenu(context, currentVisibleTracks, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoreSelectionMenu(
    BuildContext context,
    List<Track> currentVisibleTracks,
    bool isDark,
  ) {
    final circleBg =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07);
    final allSelected = currentVisibleTracks.isNotEmpty &&
        currentVisibleTracks.every((t) => _selectedTrackIds.contains(t.id));

    return Theme(
      data: Theme.of(context).copyWith(
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circleBg,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.more_vert_rounded,
            size: 42 * 0.48,
            color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E2028),
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
                  style: AppTypography.bodyMedium,
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
                  style: AppTypography.bodyMedium,
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
                  style: AppTypography.bodyMedium,
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
                  style: AppTypography.bodyMedium,
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
                  style: AppTypography.bodyMedium,
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
                  style: AppTypography.bodyMedium,
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
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCapsuleActionItem(
                  icon: Icons.playlist_play_rounded,
                  label: 'Play\nnext',
                  onTap: () => _handleBatchPlayNext(selectedTracks),
                ),
                const SizedBox(width: 14),
                _buildCapsuleActionItem(
                  icon: Icons.queue_music_rounded,
                  label: 'Add to\nqueue',
                  onTap: () => _handleBatchAddToQueue(selectedTracks),
                ),
                const SizedBox(width: 14),
                _buildCapsuleActionItem(
                  icon: Icons.playlist_add_rounded,
                  label: 'Add to\nplaylist',
                  onTap: () => _handleBatchAddToPlaylist(context, selectedTracks),
                ),
                const SizedBox(width: 14),
                _buildCapsuleActionItem(
                  icon: Icons.file_download_outlined,
                  label: 'Download',
                  onTap: () => _handleBatchDownload(selectedTracks),
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
              child: Transform.rotate(angle: -0.20, child: _buildMiniArt(displayTracks[2])),
            ),
          if (displayTracks.length >= 2)
            Positioned(
              left: 6,
              child: Transform.rotate(angle: 0.16, child: _buildMiniArt(displayTracks[1])),
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
          Icon(icon, size: 21, color: const Color(0xFF111827)),
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

  // --- Prominent Header matching HomeScreen & StreamHomeScreen ---
  Widget _buildTopHeader(ThemeData theme, bool isDark) {
    final canPop = Navigator.of(context).canPop();
    final circleBg =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Row(
        children: [
          if (canPop) ...[
            _GlassCircleButton(
              icon: Icons.chevron_left_rounded,
              size: 46,
              background: circleBg,
              iconSize: 26,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Search',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                    height: 1.1,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Discover songs, artists & playlists',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          _GlassCircleButton(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 46,
            background: circleBg,
            iconColor: isDark ? AppColors.neonLime : AppColors.neonLimeDim,
            onTap: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
            onLongPress: () {
              showThemeSelectionModal(context);
            },
          ),
        ],
      ),
    );
  }

  // --- Production-Grade Search Input Bar matching HomeScreen ---
  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    final canPop = Navigator.of(context).canPop();
    final isExpanded = _searchController.text.trim().isNotEmpty;
    final circleBg =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07);
    final iconColor =
        isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E2028);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Row(
        children: [
          if (canPop && isExpanded) ...[
            _GlassCircleButton(
              icon: Icons.chevron_left_rounded,
              size: 46,
              background: circleBg,
              iconSize: 26,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: circleBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    child: Icon(
                      Icons.search_rounded,
                      size: 21,
                      color: iconColor,
                    ),
                  ),
                  Expanded(
                    child: TextField(
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
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search songs, artists, albums, playlists',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _historyTimer?.cancel();
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.close_rounded,
                            size: 19,
                            color: iconColor,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Filter Pills matching HomeScreen ---
  Widget _buildFilterPills(
    List<String> items,
    String selectedItem,
    ValueChanged<String> onSelected,
    ThemeData theme,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Row(
        children: items.map((item) {
          final isSelected = item == selectedItem;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _GlassFilterChip(
              label: item,
              isSelected: isSelected,
              onTap: () => onSelected(item),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Search History Section ---
  Widget _buildSearchHistory(ThemeData theme, bool isDark) {
    final historyAsync = ref.watch(searchHistoryProvider);

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RECENT SEARCHES',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
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
                children: history.take(5).map((item) {
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
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
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
                                size: 16,
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
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  // --- Trending Search Topics Section ---
  Widget _buildTrendingSearchTopics(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 16,
                color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
              ),
              const SizedBox(width: 8),
              Text(
                'TRENDING SEARCHES',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trendingSearches.map((term) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _searchController.text = term;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: term.length),
                  );
                  _performSearch(term, addToHistory: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 14,
                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        term,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
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
  }

  // --- Recently Played Tracks Section (shown on empty search state) ---
  Widget _buildRecentlyPlayedSection(ThemeData theme, bool isDark) {
    final recentAsync = ref.watch(recentlyPlayedTracksStreamProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaying = ref.watch(isPlaybackPlayingProvider);

    return recentAsync.when(
      data: (recentTracks) {
        if (recentTracks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 16,
                      color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RECENTLY PLAYED',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recentTracks.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final track = recentTracks[index];
                    final isCurrent = currentPlayingTrackId == track.id;
                    return StreamSongCard(
                      track: track,
                      isCurrent: isCurrent,
                      isPlaying: isPlaying,
                      onTap: () {
                        _historyTimer?.cancel();
                        if (isCurrent) {
                          if (isPlaying) {
                            audioHandler.pause();
                          } else {
                            audioHandler.play();
                            openNowPlayingScreen(context, targetTrack: track);
                          }
                        } else {
                          audioHandler.playTrackList(recentTracks, startIndex: index);
                          openNowPlayingScreen(context, targetTrack: track);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
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
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.black : Colors.white;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = keyboardHeight > 0 ? keyboardHeight + 84.0 : 160.0;
    final visibleTracks = _getCurrentVisibleTracks();

    // Wash color: artwork of the song playing now, else the top search result
    final playingTrack = ref.watch(currentPlayingTrackProvider);
    final topSearchResult = _searchResults.firstOrNull ?? _multiResult.songs.firstOrNull;
    final washTrack = playingTrack ?? topSearchResult;

    Color? washAccent;
    if (washTrack != null) {
      final paletteAsync = ref.watch(
        trackPaletteProvider((track: washTrack, isDark: isDark)),
      );
      final palette = paletteAsync.value ??
          PaletteService.instance.getCachedPalette(washTrack, isDark: isDark);
      if (palette != null) {
        _lastWashAccent = palette.backgroundColor;
      }
      washAccent = _lastWashAccent;
    } else {
      _lastWashAccent = null;
    }
    final hasPalette = washAccent != null;
    final washColor = washAccent ?? AppColors.neonLime;
    final washStrength = hasPalette ? (isDark ? 0.75 : 0.55) : (isDark ? 0.10 : 0.16);
    final topColor = _mix(baseColor, washColor, washStrength);

    final isSearchingQuery = _searchController.text.trim().isNotEmpty;

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
        backgroundColor: baseColor,
        bottomNavigationBar: _isSelectionMode && _selectedTrackIds.isNotEmpty
            ? _buildBatchActionBar(theme, visibleTracks)
            : null,
        body: Stack(
          children: [
            // Atmospheric artwork wash that dissolves into the base background
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
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Top Bar: Selection Header, or Top Header + Search Bar
                  if (_isSelectionMode)
                    _buildSelectionHeader(theme, visibleTracks)
                  else ...[
                    if (!isSearchingQuery)
                      _buildTopHeader(theme, isDark),
                    _buildSearchBar(theme, isDark),
                  ],

                  // Filter Chips (when active search query exists and not in selection mode)
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

                  // Main Content Area
                  Expanded(
                    child: Stack(
                      children: [
                        _searchController.text.trim().length < 2
                            ? ListView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(bottom: bottomPadding),
                                children: [
                                  // Recent Searches History Section
                                  _buildSearchHistory(theme, isDark),

                                  // Trending Searches Tags
                                  _buildTrendingSearchTopics(theme, isDark),

                                  // Recently Played Section
                                  _buildRecentlyPlayedSection(theme, isDark),
                                ],
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

                        // Universal Floating MiniPlayer
                        if (!_isSelectionMode)
                          const FloatingMiniPlayer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Top-anchored Floating Download Dynamic Island
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: const DownloadDynamicIsland(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching with a different keyword',
              style: AppTypography.bodySmall.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchLoadingState(ThemeData theme, bool isDark) {
    if (_selectedFilter == 'All') {
      return const SearchMultiSkeleton();
    }
    return const TrackListSkeleton(itemCount: 8);
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
      if (ref.watch(isOfflineProvider)) {
        return OfflineStateView(
          compact: true,
          title: 'Offline Search',
          message: 'No downloaded or local tracks match "${_searchController.text.trim()}"',
          onRetry: () => _performSearch(_searchController.text.trim()),
        );
      }
      return _buildEmptyState(theme, 'No results found for "${_searchController.text.trim()}"');
    }

    return _buildTracksListView(filteredResults, theme, isDark, bottomPadding);
  }

  /// Multi-result layout: Top Hero Result, Songs, Artists, Albums, Playlists
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
        // 1. Top Hero Result
        if (topResults.isNotEmpty || artists.isNotEmpty || albums.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Top Result',
              style: AppTypography.headlineSmall.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          ...topResults.take(1).map((top) {
            final isArtist = top.isArtist;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                if (isArtist) {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => ArtistDetailScreen(
                        artistId: top.id,
                        initialName: top.title,
                        initialImageUrl: top.imageUrl,
                      ),
                    ),
                  );
                } else if (top.isAlbum) {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => AlbumDetailScreen(
                        albumId: top.id,
                        initialTitle: top.title,
                        initialArtworkUrl: top.imageUrl,
                      ),
                    ),
                  );
                } else if (top.isPlaylist) {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => StreamPlaylistDetailScreen(
                        playlistId: top.id,
                        initialTitle: top.title,
                        initialArtworkUrl: top.imageUrl,
                      ),
                    ),
                  );
                } else {
                  final saavn = ref.read(saavnAdapterProvider);
                  final normTopTitle = SaavnSourceAdapter.normalizeSongTitle(top.title);

                  // 1. Try to find the exact song in search results by ID
                  Track? targetTrack = songs.cast<Track?>().firstWhere(
                    (s) => s != null && (
                      s.sourceId == top.id ||
                      s.id == 'saavn:${top.id}' ||
                      s.id == top.id
                    ),
                    orElse: () => null,
                  );

                  // 2. Try to match by normalized title and artist
                  targetTrack ??= songs.cast<Track?>().firstWhere(
                    (s) => s != null && (
                      SaavnSourceAdapter.normalizeSongTitle(s.title) == normTopTitle &&
                      (top.description == null ||
                       top.description!.isEmpty ||
                       top.description!.toLowerCase().contains(s.artistName.toLowerCase()) ||
                       s.artistName.toLowerCase().contains(top.description!.toLowerCase()))
                    ),
                    orElse: () => null,
                  );

                  // 3. Match by normalized title
                  targetTrack ??= songs.cast<Track?>().firstWhere(
                    (s) => s != null && SaavnSourceAdapter.normalizeSongTitle(s.title) == normTopTitle,
                    orElse: () => null,
                  );

                  if (targetTrack != null) {
                    _playSearchedTrack(targetTrack, searchQueue: songs);
                  } else if (top.raw != null) {
                    final parsed = saavn.parseSongDirect(top.raw!);
                    if (parsed != null) {
                      _playSearchedTrack(parsed, searchQueue: [parsed, ...songs]);
                    } else if (songs.isNotEmpty) {
                      _playSearchedTrack(songs.first, searchQueue: songs);
                    }
                  } else if (songs.isNotEmpty) {
                    _playSearchedTrack(songs.first, searchQueue: songs);
                  }
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                ),
                child: Row(
                  children: [
                    TrackArtwork(
                      artworkUrl: top.imageUrl,
                      size: 60,
                      isCircle: isArtist,
                      borderRadius: isArtist ? null : BorderRadius.circular(14),
                      fallbackIcon: isArtist ? Icons.person_rounded : Icons.album_rounded,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  top.title,
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w800,
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
                                : (isArtist ? 'Artist' : 'Top Result'),
                            style: AppTypography.caption.copyWith(
                              fontSize: 12,
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

        // 2. Songs Section
        if (songs.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Songs',
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedFilter = 'Songs');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'See All',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...songs.take(5).map((track) {
            final isCurrent = currentPlayingTrackId == track.id;
            final isTilePlaying = isCurrent && isPlaybackPlaying;

            return TrackListTile(
              key: ValueKey('multi_search_${track.id}'),
              track: track,
              isCurrent: isCurrent,
              isPlaying: isTilePlaying,
              isYouTubeSection: track.source == AudioSourceType.youtube,
              enableSwipePlayNext: false,
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
                _playSearchedTrack(track, searchQueue: songs);
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

        // 3. Artists Section (Horizontal Row)
        if (artists.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Artists',
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedFilter = 'Artists');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'See All',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 130,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: artists.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final artist = artists[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => ArtistDetailScreen(
                          artistId: artist.id,
                          initialName: artist.title,
                          initialImageUrl: artist.imageUrl,
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 90,
                    child: Column(
                      children: [
                        TrackArtwork(
                          artworkUrl: artist.imageUrl,
                          size: 80,
                          isCircle: true,
                          fallbackIcon: Icons.person_rounded,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          artist.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // 4. Albums Section (Horizontal Row)
        if (albums.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Albums',
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedFilter = 'Albums');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'See All',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: albums.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final album = albums[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => AlbumDetailScreen(
                          albumId: album.id,
                          initialTitle: album.title,
                          initialArtist: album.music,
                          initialArtworkUrl: album.imageUrl,
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 124,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrackArtwork(
                          artworkUrl: album.imageUrl,
                          size: 124,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          album.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          album.music ?? album.year ?? 'Album',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // 5. Playlists Section
        if (playlists.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Playlists',
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedFilter = 'Playlists');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'See All',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
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
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => StreamPlaylistDetailScreen(
                      playlistId: playlist.id,
                      initialTitle: playlist.title,
                      initialSubtitle: playlist.description,
                      initialArtworkUrl: playlist.imageUrl,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                ),
                child: Row(
                  children: [
                    TrackArtwork(
                      artworkUrl: playlist.imageUrl,
                      size: 50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            playlist.description,
                            style: AppTypography.caption.copyWith(
                              fontSize: 11.5,
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
                      size: 20,
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
              CupertinoPageRoute(
                builder: (_) => ArtistDetailScreen(
                  artistId: artist.id,
                  initialName: artist.title,
                  initialImageUrl: artist.imageUrl,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                TrackArtwork(
                  artworkUrl: artist.imageUrl,
                  size: 54,
                  isCircle: true,
                  fallbackIcon: Icons.person_rounded,
                ),
                const SizedBox(width: 14),
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
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
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
                      const SizedBox(height: 2),
                      Text(
                        artist.description.isNotEmpty ? artist.description : 'Artist',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
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
              CupertinoPageRoute(
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
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                TrackArtwork(
                  artworkUrl: album.imageUrl,
                  size: 54,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        album.description.isNotEmpty
                            ? album.description
                            : (album.music != null && album.music!.isNotEmpty
                                ? '${album.music!} • Album'
                                : 'Album'),
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
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
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => StreamPlaylistDetailScreen(
                  playlistId: playlist.id,
                  initialTitle: playlist.title,
                  initialSubtitle: playlist.description,
                  initialArtworkUrl: playlist.imageUrl,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                TrackArtwork(
                  artworkUrl: playlist.imageUrl,
                  size: 54,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.title,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        playlist.description,
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
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
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  size: 16,
                  color: Color(0xFFFF3333),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'YouTube streams can be played or downloaded directly.',
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
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomPadding),
            itemExtent: _selectedFilter == 'YouTube' ? 88.0 : (_selectedFilter == 'Songs' ? 76.0 : null),
            itemCount: filteredResults.length + (_isLoadingMore ? 2 : 0),
            itemBuilder: (context, index) {
              if (index >= filteredResults.length) {
                return const TrackTileSkeleton();
              }
              final track = filteredResults[index];
              final isCurrent = currentPlayingTrackId == track.id;
              final isTilePlaying = isCurrent && isPlaybackPlaying;

              return TrackListTile(
                key: ValueKey('search_${track.id}'),
                track: track,
                isCurrent: isCurrent,
                isPlaying: isTilePlaying,
                isYouTubeSection: _selectedFilter == 'YouTube' || track.source == AudioSourceType.youtube,
                enableSwipePlayNext: false,
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
                      openNowPlayingScreen(context, targetTrack: track);
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
                  _playSearchedTrack(track, searchQueue: filteredResults);
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

/// Interactive spring-scaling circular button matching HomeScreen
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
  final VoidCallback? onLongPress;
  final Color? iconColor;
  final Color? background;
  final double size;
  final double? iconSize;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.iconColor,
    this.background,
    this.size = 46,
    this.iconSize,
  });

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.background ??
        (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2));
    final fg =
        isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onLongPress: widget.onLongPress != null
          ? () {
              HapticFeedback.heavyImpact();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: widget.iconSize ?? (widget.size * 0.48),
            color: widget.iconColor ?? fg,
          ),
        ),
      ),
    );
  }
}
