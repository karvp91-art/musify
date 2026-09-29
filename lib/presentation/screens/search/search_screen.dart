import 'dart:async';
import 'package:flutter/material.dart';
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

  final List<String> _popularTags = const [
    'Arijit Singh',
    'Bollywood',
    'Lo-Fi',
    'Pop',
    'Punjabi',
    'Anirudh',
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

  void _performSearch(String query) async {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
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
      _performSearch(query);
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
    final filteredResults = _getFilteredResults();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          'Search & Explore',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Input Bar (matching reference borderless capsule design)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                borderRadius: BorderRadius.circular(23),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: _performSearch,
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, genres...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: theme.colorScheme.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),

          // Filter Chips (when active search results exist)
          if (_searchResults.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = filter == _selectedFilter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),

          // Results / Status / Suggestions / Trending High-Fidelity
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
                          padding: const EdgeInsets.only(bottom: 160),
                          children: [
                            // JioSaavn Discovery Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Trending High-Fidelity',
                                        style: theme.textTheme.headlineSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '320kbps Direct Stream',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.graphic_eq_rounded,
                                          size: 13,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '320 KBPS',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Genre Pills
                            SizedBox(
                              height: 40,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _genres.length,
                                itemBuilder: (context, index) {
                                  final genre = _genres[index];
                                  final isSelected = genre == _selectedGenre;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(genre),
                                      selected: isSelected,
                                      showCheckmark: false,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedGenre = genre;
                                          });
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),

                            // JioSaavn Tracks Carousel
                            SizedBox(
                              height: 200,
                              child: saavnAsync.when(
                                data: (saavnTracks) {
                                  if (saavnTracks.isEmpty) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: saavnTracks.length,
                                    itemBuilder: (context, index) {
                                      final track = saavnTracks[index];
                                      return CompactCard(
                                        title: track.title,
                                        subtitle: track.artistName,
                                        imageUrl: track.artworkUrl,
                                        onTap: () {
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

                            // Popular Searches Section
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'POPULAR SEARCHES & ARTISTS',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _popularTags.map((tag) {
                                      return ActionChip(
                                        label: Text(tag),
                                        avatar: const Icon(Icons.music_note, size: 16),
                                        onPressed: () {
                                          _searchController.text = tag;
                                          _performSearch(tag);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
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
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Try another artist, genre, or keyword',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 160),
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
    );
  }
}
