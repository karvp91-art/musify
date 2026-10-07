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
import 'package:musify/presentation/screens/stream/stream_playlist_detail_screen.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import 'package:musify/presentation/screens/stream/widgets/stream_cards.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';
import 'package:musify/presentation/providers/network_providers.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/offline_state_view.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  Timer? _historyTimer;
  SearchMultiResult _multiResult = const SearchMultiResult();
  List<Track> _searchResults = [];
  bool _isSearching = false;
  String _selectedFilter = 'All';

  @override
  bool get wantKeepAlive => true;

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
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
          Expanded(
            child: Text(
              '${_selectedTrackIds.length} selected',
              style: AppTypography.headlineSmall.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          _GlassCircleButton(
            icon: allSelected ? Icons.check_box_rounded : Icons.checklist_rounded,
            size: 40,
            iconSize: 20,
            iconColor: allSelected
                ? (isDark ? AppColors.neonLime : const Color(0xFF3B7D14))
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
            IconButton(
              icon: const Icon(Icons.playlist_play_rounded, color: Color(0xFF111827), size: 24),
              onPressed: () => _handleBatchPlayNext(selectedTracks),
              tooltip: 'Play Next',
            ),
            IconButton(
              icon: const Icon(Icons.queue_music_rounded, color: Color(0xFF111827), size: 24),
              onPressed: () => _handleBatchAddToQueue(selectedTracks),
              tooltip: 'Add to Queue',
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add_rounded, color: Color(0xFF111827), size: 24),
              onPressed: () => _handleBatchAddToPlaylist(context, selectedTracks),
              tooltip: 'Add to Playlist',
            ),
          ],
        ),
      ),
    );
  }

  // --- Production-Grade Search Input Bar with Back Button ---
  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    final canPop = Navigator.of(context).canPop();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          if (canPop) ...[
            _GlassCircleButton(
              icon: Icons.chevron_left_rounded,
              size: 44,
              iconSize: 28,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    child: Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
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
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search songs, artists, albums...',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                            size: 18,
                            color: isDark ? Colors.white60 : Colors.black54,
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

  // --- Filter Pills ---
  Widget _buildFilterPills(
    List<String> items,
    String selectedItem,
    ValueChanged<String> onSelected,
    ThemeData theme,
    bool isDark,
  ) {
    final selectedBg = AppColors.neonLime;
    final unselectedBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final unselectedTextColor =
        isDark ? Colors.white.withValues(alpha: 0.80) : const Color(0xFF4B5563);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: items.map((item) {
          final isSelected = item == selectedItem;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(item);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBg : unselectedBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 13,
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
                          }
                        } else {
                          audioHandler.playTrackList(recentTracks, startIndex: index);
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
        backgroundColor: theme.scaffoldBackgroundColor,
        bottomNavigationBar: _isSelectionMode && _selectedTrackIds.isNotEmpty
            ? _buildBatchActionBar(theme, visibleTracks)
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Bar: Selection Header or Search Input Bar
              _isSelectionMode
                  ? _buildSelectionHeader(theme, visibleTracks)
                  : _buildSearchBar(theme, isDark),

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
                            physics: const ClampingScrollPhysics(),
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
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF20222B) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 160,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 100,
                    height: 11,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF20222B) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(6),
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
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomPadding),
            itemExtent: _selectedFilter == 'YouTube' ? 88.0 : 76.0,
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

/// Borderless circular button matching HomeScreen and StreamHomeScreen style
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
    final effectiveIconColor = iconColor ??
        (isDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF1E2028));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
