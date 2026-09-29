import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track_sort_option.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';
import 'package:musify/presentation/widgets/track_menu_bottom_sheet.dart';
import 'package:musify/presentation/widgets/scan_progress_dialog.dart';
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

  final List<String> _filters = const ['All', 'Playlists', 'Liked Songs', 'Downloaded'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  

  // --- Modal Helpers ---

  void _showMoreMenu(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final currentSort = ref.read(localTrackSortOptionProvider);
    final isDark = theme.brightness == Brightness.dark;

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
          value: 'sort',
          child: Row(
            children: [
              Icon(Icons.sort_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
              const SizedBox(width: 12),
              Text('Sort (${currentSort.label})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
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
          value: 'demo',
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
              const SizedBox(width: 12),
              const Text('Load Demo Tracks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'theme',
          child: Row(
            children: [
              Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 12),
              Text(isDark ? 'Light Mode' : 'Dark Mode', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );

    if (selected == 'sort') {
      if (context.mounted) _showSortDialog(context, ref);
    } else if (selected == 'scan') {
      if (context.mounted) await startScanWithProgressDialog(context, ref);
    } else if (selected == 'demo') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating demo tracks...')),
        );
        final count = await ref.read(localScannerProvider).seedSampleMusic();
        ref.invalidate(localTracksProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded $count demo tracks!')),
          );
        }
      }
    } else if (selected == 'theme') {
      ref.read(themeModeProvider.notifier).toggleTheme();
    }
  }

  void _showSortDialog(BuildContext context, WidgetRef ref) {
    final currentSort = ref.read(localTrackSortOptionProvider);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Sort Tracks By'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        children: TrackSortOption.values.map((option) {
          final isSelected = option == currentSort;
          return SimpleDialogOption(
            onPressed: () {
              ref.read(localTrackSortOptionProvider.notifier).setSortOption(option);
              Navigator.pop(dialogCtx);
            },
            child: Row(
              children: [
                Icon(
                  option.icon,
                  size: 20,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 20),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showNewPlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final repo = ref.read(audioRepositoryProvider);
                await repo.createPlaylist(name);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
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

  // --- Header & Filters ---

  Widget _buildTopHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

          // Center: "My Music" Title
          Text(
            'My Music',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),

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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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
    final unselectedBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final unselectedTextColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF1E2028);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : unselectedBg,
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

    return playlistsAsync.when(
      data: (playlists) {
        return SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Playlists (${playlists.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create'),
                    onPressed: () => _showNewPlaylistDialog(context, ref),
                  ),
                ],
              ),
            ),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('No playlists yet. Tap "Create" to make one!', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)))),
              )
            else
              ...playlists.map((p) {
                final isDark = theme.brightness == Brightness.dark;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.queue_music_rounded, color: theme.colorScheme.primary, size: 26),
                  ),
                  title: Text(p.name, style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                  subtitle: Text(p.description ?? 'Playlist', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'delete') {
                        ref.read(audioRepositoryProvider).deletePlaylist(p.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'delete', child: Text('Delete Playlist')),
                    ],
                  ),
                  onTap: () => _openPlaylistTracks(context, ref, p),
                );
              }),
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
                onTap: () {
                  audioHandler.playTrackList(tracks, startIndex: index);
                },
                onLikeToggle: () {
                  ref.read(audioRepositoryProvider).toggleLike(track);
                },
                onMoreOptions: () {
                  showTrackDropdownMenu(
                    context: context,
                    ref: ref,
                    track: track,
                  );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sortedTracksAsync = ref.watch(sortedLocalTracksProvider);
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaybackPlaying = ref.watch(isPlaybackPlayingProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Pinned Sticky Top Header, Search Bar, and Filter Pills
            _buildTopHeader(theme),
            _buildSearchBar(theme),
            _buildFilterPills(theme),
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
                                  onTap: () {
                                    audioHandler.playTrackList(displayedTracks, startIndex: index);
                                  },
                                  onLikeToggle: () {
                                    ref.read(audioRepositoryProvider).toggleLike(track);
                                  },
                                  onMoreOptions: () {
                                    showTrackDropdownMenu(
                                      context: context,
                                      ref: ref,
                                      track: track,
                                    );
                                  },
                                );
                              },
                              childCount: displayedTracks.length,
                            ),
                          ),

                        // Bottom Padding for MiniPlayer & Bottom Shell
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 160),
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
    );
  }
}

/// Borderless circular button used for header actions
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


