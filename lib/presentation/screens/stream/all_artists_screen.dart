import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/artist/artist_detail_screen.dart';
import 'package:musify/presentation/widgets/download_dynamic_island.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/shimmer_skeleton.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  const _HeaderCircleButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor =
        isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: defaultIconColor,
        ),
      ),
    );
  }
}

/// Category metadata definition for Artists filtering
class _ArtistCategoryItem {
  final String id;
  final String label;
  final String icon;

  const _ArtistCategoryItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class AllArtistsScreen extends ConsumerStatefulWidget {
  const AllArtistsScreen({super.key});

  @override
  ConsumerState<AllArtistsScreen> createState() => _AllArtistsScreenState();
}

class _AllArtistsScreenState extends ConsumerState<AllArtistsScreen> {
  static const List<_ArtistCategoryItem> _categories = [
    _ArtistCategoryItem(id: 'all', label: 'All', icon: '🌟'),
    _ArtistCategoryItem(id: 'hindi', label: 'Bollywood / Hindi', icon: '🇮🇳'),
    _ArtistCategoryItem(id: 'english', label: 'English / Global', icon: '🌐'),
    _ArtistCategoryItem(id: 'japanese', label: 'Japanese / Anime', icon: '🇯🇵'),
    _ArtistCategoryItem(id: 'punjabi', label: 'Punjabi', icon: '🌾'),
    _ArtistCategoryItem(id: 'south_indian', label: 'South Indian', icon: '🌴'),
  ];

  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  // Category pagination state
  final Map<String, List<SearchArtistItem>> _categoryData = {};
  final Map<String, int> _categoryPages = {};
  final Map<String, bool> _categoryHasMore = {};
  bool _isLoadingMore = false;

  // Search pagination state
  List<SearchArtistItem>? _onlineSearchResults;
  int _searchPage = 1;
  bool _isOnlineSearching = false;
  bool _isLoadingMoreSearch = false;
  bool _hasMoreSearch = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 350) {
      _loadMore();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _onlineSearchResults = null;
        _searchPage = 1;
        _hasMoreSearch = true;
      });
      if (query.length >= 2) {
        _performOnlineSearchDebounced(query);
      }
    }
  }

  void _performOnlineSearchDebounced(String query) async {
    setState(() => _isOnlineSearching = true);
    try {
      final saavn = ref.read(saavnAdapterProvider);
      final results = await Future.wait([
        saavn.searchArtists(query),
        saavn.searchMulti(query),
      ]);
      final searchArtists = results[0] as List<SearchArtistItem>;
      final multi = results[1] as SearchMultiResult;

      final combined = <SearchArtistItem>[...searchArtists];
      final seenIds = combined.map((e) => e.id).toSet();
      for (final a in multi.artists) {
        if (seenIds.add(a.id)) {
          combined.add(a);
        }
      }
      for (final top in multi.topResults) {
        if (top.isArtist && seenIds.add(top.id)) {
          combined.insert(0, SearchArtistItem(
            id: top.id,
            title: top.title,
            imageUrl: top.imageUrl,
            description: top.description ?? 'Artist',
          ));
        }
      }

      if (mounted && _searchQuery == query) {
        setState(() {
          _onlineSearchResults = combined;
          _isOnlineSearching = false;
        });
      }
    } catch (_) {
      if (mounted && _searchQuery == query) {
        setState(() => _isOnlineSearching = false);
      }
    }
  }

  void _loadMore() async {
    if (_searchQuery.isNotEmpty) {
      if (_isOnlineSearching || _isLoadingMoreSearch || !_hasMoreSearch) return;
      setState(() => _isLoadingMoreSearch = true);
      try {
        final nextPage = _searchPage + 1;
        final saavn = ref.read(saavnAdapterProvider);
        final newResults = await saavn.searchArtists(_searchQuery, page: nextPage, limit: 25);
        if (!mounted) return;
        if (newResults.isEmpty) {
          setState(() {
            _hasMoreSearch = false;
            _isLoadingMoreSearch = false;
          });
        } else {
          final existing = _onlineSearchResults ?? [];
          final seenIds = existing.map((e) => e.id).toSet();
          final appended = <SearchArtistItem>[...existing];
          for (final a in newResults) {
            if (seenIds.add(a.id)) {
              appended.add(a);
            }
          }
          setState(() {
            _onlineSearchResults = appended;
            _searchPage = nextPage;
            _isLoadingMoreSearch = false;
            if (newResults.length < 10) {
              _hasMoreSearch = false;
            }
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingMoreSearch = false);
      }
    } else {
      final hasMore = _categoryHasMore[_selectedCategory] ?? true;
      if (_isLoadingMore || !hasMore) return;

      setState(() => _isLoadingMore = true);
      try {
        final currentPage = _categoryPages[_selectedCategory] ?? 1;
        final nextPage = currentPage + 1;
        final streamRepo = ref.read(streamContentRepositoryProvider);
        final newItems = await streamRepo.getArtistsByCategory(_selectedCategory, page: nextPage);
        if (!mounted) return;
        if (newItems.isEmpty) {
          setState(() {
            _categoryHasMore[_selectedCategory] = false;
            _isLoadingMore = false;
          });
        } else {
          final existing = _categoryData[_selectedCategory] ?? [];
          final seenIds = existing.map((e) => e.id).toSet();
          final appended = <SearchArtistItem>[...existing];
          for (final a in newItems) {
            if (seenIds.add(a.id)) {
              appended.add(a);
            }
          }
          setState(() {
            _categoryData[_selectedCategory] = appended;
            _categoryPages[_selectedCategory] = nextPage;
            _isLoadingMore = false;
            if (newItems.length < 6) {
              _categoryHasMore[_selectedCategory] = false;
            }
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final artistsAsync = ref.watch(streamArtistsByCategoryProvider(_selectedCategory));

    final activeGreenColor = isDark ? AppColors.neonLime : const Color(0xFF3E8016);
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top App Bar matching studio_equalizer_screen.dart
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _HeaderCircleButton(
                          icon: Icons.chevron_left_rounded,
                          iconSize: 26,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Explore Artists',
                              style: AppTypography.headlineSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        _HeaderCircleButton(
                          icon: Icons.refresh_rounded,
                          iconSize: 20,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.invalidate(streamArtistsByCategoryProvider(_selectedCategory));
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Open Canvas Header Section (matching studio_equalizer_screen.dart)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Featured Artists',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_categoryData[_selectedCategory]?.length ?? 0}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: activeGreenColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Discover voices across cultures & languages',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Bar Field (Pill Shape matching home_screen.dart & studio_equalizer_screen.dart)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search artist by name...',
                                hintStyle: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _searchController.clear();
                              },
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Horizontal Filter Chips Bar (matching studio_equalizer_screen.dart & home_screen.dart)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        for (int i = 0; i < _categories.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final cat = _categories[i];
                              final isSelected = _selectedCategory == cat.id;
                              final selectedBg = isDark ? AppColors.neonLime : AppColors.limeAccentDark;
                              final unselectedBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
                              final unselectedTextColor = isDark
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : const Color(0xFF1E2028);

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (!isSelected) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedCategory = cat.id;
                                    });
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? selectedBg : unselectedBg,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        cat.icon,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        cat.label,
                                        style: AppTypography.bodySmall.copyWith(
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected
                                              ? (isDark ? Colors.black : Colors.white)
                                              : unselectedTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 14),
                ),

                // Main Artists Grid
                artistsAsync.when(
                  loading: () => SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.74,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 18,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildArtistSkeleton(),
                        childCount: 12,
                      ),
                    ),
                  ),
                  error: (err, stack) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load artists catalog',
                            style: AppTypography.bodyMedium.copyWith(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => ref.refresh(
                              streamArtistsByCategoryProvider(_selectedCategory),
                            ),
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (artists) {
                    if (_categoryData[_selectedCategory] == null) {
                      _categoryData[_selectedCategory] = List.from(artists);
                      _categoryPages[_selectedCategory] = 1;
                      _categoryHasMore[_selectedCategory] = true;
                    }
                    final currentCategoryArtists = _categoryData[_selectedCategory] ?? artists;

                    // Filter artists by search query
                    List<SearchArtistItem> displayedArtists = currentCategoryArtists;
                    if (_searchQuery.isNotEmpty) {
                      final lowerQuery = _searchQuery.toLowerCase();
                      displayedArtists = currentCategoryArtists
                          .where((a) => a.title.toLowerCase().contains(lowerQuery))
                          .toList();

                      // If online search returned extra matching artists, merge them cleanly
                      if (_onlineSearchResults != null && _onlineSearchResults!.isNotEmpty) {
                        final seenIds = displayedArtists.map((e) => e.id).toSet();
                        for (final extra in _onlineSearchResults!) {
                          if (seenIds.add(extra.id)) {
                            displayedArtists.add(extra);
                          }
                        }
                      }
                    }

                    if (displayedArtists.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 54,
                                color: isDark ? Colors.white38 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No artists available in this category'
                                    : 'No artists found matching "$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                              if (_isOnlineSearching) ...[
                                const SizedBox(height: 16),
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.74,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 18,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final artist = displayedArtists[index];
                            return _ArtistGridItem(
                              artist: artist,
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
                            );
                          },
                          childCount: displayedArtists.length,
                        ),
                      ),
                    );
                  },
                ),

                if (_isLoadingMore || _isLoadingMoreSearch)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? AppColors.neonLime : const Color(0xFF3B7D14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Spacing at bottom for floating dock and mini player
                const SliverToBoxAdapter(
                  child: SizedBox(height: 140),
                ),
              ],
            ),

            // Floating Mini Player Platter
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingMiniPlayer(),
            ),

            // Floating Dynamic Island Capsule
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

  Widget _buildArtistSkeleton() {
    return Column(
      children: const [
        ShimmerBox.circle(size: 86),
        SizedBox(height: 8),
        ShimmerBox(width: 70, height: 12, borderRadius: 6),
        SizedBox(height: 4),
        ShimmerBox(width: 44, height: 10, borderRadius: 5),
      ],
    );
  }
}

class _ArtistGridItem extends StatelessWidget {
  final SearchArtistItem artist;
  final VoidCallback onTap;

  const _ArtistGridItem({
    required this.artist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Avatar with subtle ambient depth - fully borderless
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: TrackArtwork(
                artworkUrl: artist.imageUrl,
                size: 86,
                cacheDimension: 260,
                borderRadius: BorderRadius.circular(43),
                isCircle: true,
                fallbackIcon: Icons.person_rounded,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Artist Name
          Text(
            artist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          // Description / Artist tag
          Text(
            artist.description.isNotEmpty ? artist.description : 'Artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              color: isDark ? Colors.white54 : const Color(0xFF8E92A0),
            ),
          ),
        ],
      ),
    );
  }
}
