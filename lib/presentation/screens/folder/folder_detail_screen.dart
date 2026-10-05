import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/track_list_tile.dart';

/// Borderless circular action button matching AudioSettingsScreen header style
class _CircleHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  const _CircleHeaderButton({
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

class FolderDetailScreen extends ConsumerStatefulWidget {
  final MusicFolder folder;

  const FolderDetailScreen({
    super.key,
    required this.folder,
  });

  @override
  ConsumerState<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<FolderDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedTrackIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSelectionMode(Track track) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedTrackIds.add(track.id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedTrackIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentPlayingTrackId = ref.watch(currentPlayingTrackIdProvider);
    final isPlaybackPlaying = ref.watch(isPlaybackPlayingProvider);

    // Watch live folder data to stay synchronized if files are modified/deleted
    final allFolders = ref.watch(musicFoldersProvider);
    final currentFolder = allFolders.firstWhere(
      (f) => f.path == widget.folder.path,
      orElse: () => widget.folder,
    );

    final query = _searchQuery.trim().toLowerCase();
    final displayedTracks = query.isEmpty
        ? currentFolder.tracks
        : currentFolder.tracks.where((t) {
            return t.title.toLowerCase().contains(query) ||
                t.artistName.toLowerCase().contains(query) ||
                (t.albumTitle?.toLowerCase().contains(query) ?? false);
          }).toList();

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.white,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  // Top Header matching AudioSettingsScreen aesthetic
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _CircleHeaderButton(
                          icon: Icons.chevron_left_rounded,
                          iconSize: 26,
                          onTap: () {
                            if (_isSelectionMode) {
                              _exitSelectionMode();
                            } else {
                              Navigator.of(context).maybePop();
                            }
                          },
                        ),
                        const SizedBox(width: 14),

                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentFolder.name,
                                style: AppTypography.headlineSmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                currentFolder.path,
                                style: AppTypography.caption.copyWith(
                                  color: textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        if (_isSelectionMode)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedTrackIds.length == displayedTracks.length) {
                                  _selectedTrackIds.clear();
                                } else {
                                  _selectedTrackIds.addAll(displayedTracks.map((t) => t.id));
                                }
                              });
                            },
                            child: Text(
                              _selectedTrackIds.length == displayedTracks.length ? 'Deselect' : 'Select All',
                              style: AppTypography.style(
                                color: AppColors.neonLime,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          _CircleHeaderButton(
                            icon: Icons.shuffle_rounded,
                            iconSize: 20,
                            onTap: () {
                              if (displayedTracks.isNotEmpty) {
                                final shuffled = List<Track>.from(displayedTracks)..shuffle();
                                audioHandler.playTrackList(shuffled, startIndex: 0);
                              }
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Storage Summary Row (Direct on canvas matching AudioSettingsScreen)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.folder_rounded,
                            color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${currentFolder.trackCount} ${currentFolder.trackCount == 1 ? "song" : "songs"}',
                                style: AppTypography.headlineSmall.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentFolder.formattedSize.isNotEmpty
                                    ? 'Storage: ${currentFolder.formattedSize}'
                                    : currentFolder.path,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Play All Button
                        FilledButton.icon(
                          onPressed: displayedTracks.isEmpty
                              ? null
                              : () {
                                  audioHandler.playTrackList(displayedTracks, startIndex: 0);
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.neonLime,
                            foregroundColor: const Color(0xFF111827),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        ),
                      ],
                    ),
                  ),

                  // Search Filter within Folder
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: AppTypography.style(
                          color: theme.colorScheme.onSurface,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Filter songs in this folder...',
                          hintStyle: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                            fontSize: 13.5,
                          ),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? AppColors.neonLime : AppColors.limeAccentDark),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  // Track List
                  Expanded(
                    child: displayedTracks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open_rounded,
                                  size: 54,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No songs matching "$_searchQuery"'
                                      : 'No audio files found in this folder',
                                  style: AppTypography.style(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: displayedTracks.length,
                            padding: const EdgeInsets.only(top: 6, bottom: 130),
                            itemBuilder: (context, index) {
                              final track = displayedTracks[index];
                              final isCurrent = currentPlayingTrackId == track.id;
                              final isTilePlaying = isCurrent && isPlaybackPlaying;

                              return TrackListTile(
                                key: ValueKey('folder_${track.id}'),
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
                                    if (!isPlaybackPlaying) {
                                      audioHandler.play();
                                    }
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
                          ),
                  ),
                ],
              ),

              // Floating MiniPlayer visible on this screen when playback is active
              const FloatingMiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }
}
