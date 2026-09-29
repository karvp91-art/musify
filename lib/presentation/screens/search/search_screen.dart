import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/constants/app_constants.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/compact_card.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';
import 'package:musify/presentation/widgets/track_menu_bottom_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<Track> _searchResults = [];
  bool _isSearching = false;
  String _selectedFilter = 'All';
  String _selectedGenre = 'Trending';

  final List<String> _filters = const ['All', 'Songs', 'Artists', 'Albums'];

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

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _performSearch(String query, {bool addToHistory = true}) async {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    if (addToHistory) {
      ref.read(searchHistoryProvider.notifier).addQuery(trimmed);
    }

    setState(() {
      _isSearching = true;
    });

    final saavn = ref.read(saavnAdapterProvider);
    final results = await saavn.search(trimmed);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(AppConstants.debounceSearchDuration, () {
      _performSearch(query, addToHistory: false);
    });
  }

  List<Track> _getFilteredResults() {
    if (_selectedFilter == 'All' || _selectedFilter == 'Songs') {
      return _searchResults;
    }
    if (_selectedFilter == 'Artists') {
      return _searchResults;
    }
    if (_selectedFilter == 'Albums') {
      return _searchResults.where((t) => t.albumTitle != null).toList();
    }
    return _searchResults;
  }

  // --- Top Bar matching HomeScreen ---
  Widget _buildTopHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Borderless Search Icon Button
          _GlassCircleButton(
            icon: Icons.search_rounded,
            onTap: () {
              if (_searchController.text.isNotEmpty) {
                HapticFeedback.lightImpact();
                _searchController.clear();
                _performSearch('', addToHistory: false);
              }
            },
          ),

          // Center: Title "Search & Explore"
          Text(
            'Search & Explore',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),

          // Right: Refresh Online Tracks Button (Borderless)
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

  // --- Search Input Bar matching HomeScreen borderless capsule design ---
  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
          borderRadius: BorderRadius.circular(23),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (query) => _performSearch(query, addToHistory: true),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E2028),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search songs, artists, genres...',
            hintStyle: TextStyle(
              fontSize: 13.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('', addToHistory: false);
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
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
    final unselectedBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final unselectedTextColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF1E2028);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                  color: isSelected ? primaryColor : unselectedBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  item,
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

  // --- Search History Section (replaces popular searches) ---
  Widget _buildSearchHistory(ThemeData theme, bool isDark) {
    final historyAsync = ref.watch(searchHistoryProvider);

    return historyAsync.when(
      data: (history) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  if (history.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showClearHistoryDialog(context);
                      },
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 36,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No recent searches',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Searches you perform will appear here',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: history.map((item) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _searchController.text = item;
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
                                style: TextStyle(
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
      loading: () => const SizedBox(height: 40),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1C24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Search History?'),
        content: const Text('This will remove all recent searches from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(searchHistoryProvider.notifier).clearAll();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaybackPlaying = ref.watch(isPlaybackPlayingProvider);

    // Watch JioSaavn 320kbps tracks for selected genre
    final saavnAsync = _selectedGenre == 'Trending'
        ? ref.watch(saavnTrendingTracksProvider)
        : ref.watch(saavnGenreTracksProvider(_selectedGenre.toLowerCase()));

    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final filteredResults = _getFilteredResults();

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = keyboardHeight > 0 ? keyboardHeight + 20.0 : 160.0;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Header: (🔍) Search & Explore (⟳)
            _buildTopHeader(theme),

            // Search Input Bar (borderless capsule design)
            _buildSearchBar(theme, isDark),

            // Filter Chips (when active search results exist)
            if (_searchResults.isNotEmpty)
              _buildFilterPills(
                _filters,
                _selectedFilter,
                (val) => setState(() => _selectedFilter = val),
                theme,
                isDark,
              ),

            // Results / Suggestions / Trending High-Fidelity
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchController.text.isEmpty
                      ? RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(saavnTrendingTracksProvider);
                            ref.invalidate(saavnGenreTracksProvider);
                          },
                          child: ListView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.only(bottom: bottomPadding),
                            children: [
                              // JioSaavn Discovery Header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
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
                                            style: TextStyle(
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
                                          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      itemCount: saavnTracks.length,
                                      itemBuilder: (context, index) {
                                        final track = saavnTracks[index];
                                        return CompactCard(
                                          title: track.title,
                                          subtitle: track.artistName,
                                          imageUrl: track.artworkUrl,
                                          onTap: () {
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

                              const SizedBox(height: 28),

                              // Recent Searches History Section
                              _buildSearchHistory(theme, isDark),
                            ],
                          ),
                        )
                      : filteredResults.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sentiment_dissatisfied_rounded,
                                      size: 48,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No results found for "${_searchController.text}"',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Try another artist, genre, or keyword',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
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
                                  onTap: () {
                                    ref.read(searchHistoryProvider.notifier).addQuery(_searchController.text.trim().isNotEmpty ? _searchController.text.trim() : track.title);
                                    audioHandler.playTrackList(filteredResults, startIndex: index);
                                  },
                                  onLikeToggle: () {
                                    ref.read(audioRepositoryProvider).toggleLike(track);
                                  },
                                  onMoreOptions: () {
                                    showTrackOptionsBottomSheet(
                                      context: context,
                                      ref: ref,
                                      track: track,
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Borderless circular button matching HomeScreen header action style
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final buttonBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonBg,
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor,
        ),
      ),
    );
  }
}
