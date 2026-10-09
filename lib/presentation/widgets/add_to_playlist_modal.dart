import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/loading_indicators.dart';
import 'playlist_artwork.dart';
import 'track_artwork.dart';
import 'create_playlist_modal.dart';

/// Shows the redesigned "Add to Playlist" popup modal placed at the bottom
/// with margins from edges and circular corners on all sides (matching reference UI)
Future<bool?> showAddToPlaylistModal(
  BuildContext context,
  WidgetRef ref, {
  Track? track,
  List<Track>? tracks,
  VoidCallback? onComplete,
}) {
  final allTracks = tracks ?? (track != null ? [track] : <Track>[]);
  if (allTracks.isEmpty) return Future.value(false);

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    useSafeArea: true,
    builder: (modalContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        14 + MediaQuery.of(modalContext).padding.bottom,
      ),
      child: AddToPlaylistBottomSheet(
        tracks: allTracks,
        onComplete: onComplete,
      ),
    ),
  );
}

/// Backward compatibility alias for single track invocation
void showAddToPlaylistDropdownDialog(
  BuildContext context,
  WidgetRef ref,
  Track track,
) {
  showAddToPlaylistModal(context, ref, track: track);
}

class AddToPlaylistBottomSheet extends ConsumerStatefulWidget {
  final List<Track> tracks;
  final VoidCallback? onComplete;

  const AddToPlaylistBottomSheet({
    super.key,
    required this.tracks,
    this.onComplete,
  });

  @override
  ConsumerState<AddToPlaylistBottomSheet> createState() => _AddToPlaylistBottomSheetState();
}

class _AddToPlaylistBottomSheetState extends ConsumerState<AddToPlaylistBottomSheet> {
  static const String _favoritesId = '__favorites_preset__';
  String? _selectedPlaylistId;
  bool _isProcessing = false;

  void _showCreatePlaylistDialog(BuildContext parentContext) {
    showCreatePlaylistModal(
      parentContext,
      ref,
      onCreated: (newPlaylist) {
        if (mounted) {
          setState(() {
            _selectedPlaylistId = newPlaylist.id;
          });
        }
      },
    );
  }

  Future<void> _commitAddToPlaylist(List<Playlist> customPlaylists) async {
    if (_isProcessing) return;
    if (_selectedPlaylistId == null) {
      AppSnackBar.show(
        context,
        message: 'Please select a playlist',
        type: AppSnackBarType.info,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });
    HapticFeedback.mediumImpact();

    final repo = ref.read(audioRepositoryProvider);

    if (_selectedPlaylistId == _favoritesId) {
      // Add to Favorites / Liked Songs
      for (final t in widget.tracks) {
        if (!t.isLiked) {
          await repo.toggleLike(t);
        }
      }
      ref.invalidate(likedTracksStreamProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        AppSnackBar.show(
          context,
          message: widget.tracks.length == 1
              ? 'Added "${widget.tracks.first.title}" to Favorites'
              : 'Added ${widget.tracks.length} songs to Favorites',
          type: AppSnackBarType.success,
          icon: Icons.favorite_rounded,
        );
        widget.onComplete?.call();
      }
    } else {
      // Add to custom playlist
      Playlist? target;
      for (final pl in customPlaylists) {
        if (pl.id == _selectedPlaylistId) {
          target = pl;
          break;
        }
      }

      for (final t in widget.tracks) {
        await repo.addTrackToPlaylist(_selectedPlaylistId!, t);
      }
      ref.invalidate(playlistTracksProvider(_selectedPlaylistId!));
      ref.invalidate(playlistsStreamProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        final playlistName = target?.name ?? 'Playlist';
        AppSnackBar.show(
          context,
          message: widget.tracks.length == 1
              ? 'Added to "$playlistName"'
              : 'Added ${widget.tracks.length} songs to "$playlistName"',
          type: AppSnackBarType.success,
          icon: Icons.playlist_add_check_rounded,
        );
        widget.onComplete?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final likedTracksAsync = ref.watch(likedTracksStreamProvider);
    final likedCount = likedTracksAsync.value?.length ?? 0;

    final singleTrack = widget.tracks.length == 1 ? widget.tracks.first : null;
    final customPlaylists = playlistsAsync.value ?? [];

    // Pre-select first custom playlist if none selected yet, or favorites if custom playlists empty
    if (_selectedPlaylistId == null) {
      if (customPlaylists.isNotEmpty) {
        _selectedPlaylistId = customPlaylists.first.id;
      } else {
        _selectedPlaylistId = _favoritesId;
      }
    }

    final dividerColor = isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
            blurRadius: 28,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Drag Handle Pill
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 2. Track Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  _buildHeaderArtwork(singleTrack, isDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add to Playlist',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17.5,
                            letterSpacing: -0.2,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          singleTrack != null
                              ? singleTrack.title
                              : '${widget.tracks.length} songs selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Divider 1
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Divider(
                height: 22,
                thickness: 1,
                color: dividerColor,
              ),
            ),

            // 3. "New Playlist" Action Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => _showCreatePlaylistDialog(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2818) : const Color(0xFFF1F6EC),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: (isDark ? AppColors.neonLime : const Color(0xFF86B92C))
                                .withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          color: isDark ? AppColors.neonLime : const Color(0xFF659814),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'New Playlist',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isDark ? AppColors.neonLime : const Color(0xFF5D890E),
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Divider 2
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Divider(
                height: 22,
                thickness: 1,
                color: dividerColor,
              ),
            ),

            // 4. Playlists List
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.44,
              ),
              child: playlistsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: PulseDotsIndicator(size: 8, spacing: 5),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Error: $err')),
                ),
                data: (playlists) {
                  final totalItems = 1 + playlists.length;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: totalItems,
                    padding: const EdgeInsets.only(bottom: 6),
                    itemBuilder: (ctx, index) {
                      if (index == 0) {
                        // Favorites Row with Red Heartbeat Outline
                        final isSelected = _selectedPlaylistId == _favoritesId;
                        return _FavoritesTile(
                          likedCount: likedCount,
                          isSelected: isSelected,
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedPlaylistId = _favoritesId;
                            });
                          },
                        );
                      }

                      final pl = playlists[index - 1];
                      final isSelected = _selectedPlaylistId == pl.id;

                      return _PlaylistTile(
                        playlist: pl,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedPlaylistId = pl.id;
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // 5. Fixed Bottom Button: "Add to Playlist"
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD2F843),
                    foregroundColor: const Color(0xFF111827),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: _isProcessing ? null : () => _commitAddToPlaylist(customPlaylists),
                  child: _isProcessing
                      ? const PulseDotsIndicator(
                          size: 7,
                          spacing: 4,
                          color: Color(0xFF111827),
                        )
                      : Text(
                          'Add to Playlist',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                            letterSpacing: -0.1,
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

  /// Builds the 52x52 track artwork or sage vinyl turntable disc matching the screenshot
  Widget _buildHeaderArtwork(Track? singleTrack, bool isDark) {
    if (singleTrack?.artworkUrl != null && singleTrack!.artworkUrl!.trim().isNotEmpty) {
      return TrackArtwork(
        artworkUrl: singleTrack.artworkUrl,
        size: 52,
        borderRadius: BorderRadius.circular(14),
      );
    }

    if (widget.tracks.isNotEmpty &&
        widget.tracks.first.artworkUrl != null &&
        widget.tracks.first.artworkUrl!.trim().isNotEmpty) {
      return TrackArtwork(
        artworkUrl: widget.tracks.first.artworkUrl,
        size: 52,
        borderRadius: BorderRadius.circular(14),
      );
    }

    // Reference screenshot non-image artwork: Pale sage container with centered olive vinyl disc & hole
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222C1D) : const Color(0xFFDFEDE0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDark ? AppColors.neonLime : const Color(0xFF759D24),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 7.5,
              height: 7.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222C1D) : const Color(0xFFDFEDE0),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Favorites tile displaying real-time liked count and red heartbeat ECG icon
class _FavoritesTile extends StatelessWidget {
  final int likedCount;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FavoritesTile({
    required this.likedCount,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF141517),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(22, 22),
                  painter: _HeartbeatPainter(color: const Color(0xFFE11D48)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Favorites',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$likedCount ${likedCount == 1 ? "song" : "songs"}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            _buildRadioIndicator(isSelected, isDark),
          ],
        ),
      ),
    );
  }
}

/// Custom playlist tile with real-time reactive song count from playlistTracksProvider
class _PlaylistTile extends ConsumerWidget {
  final Playlist playlist;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PlaylistTile({
    required this.playlist,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Watch playlist tracks directly to guarantee instantaneous, reactive song count updates
    final tracksAsync = ref.watch(playlistTracksProvider(playlist.id));
    final count = tracksAsync.value?.length ?? playlist.tracks.length;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        child: Row(
          children: [
            _buildPlaylistCover(playlist, isDark),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count ${count == 1 ? "song" : "songs"}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            _buildRadioIndicator(isSelected, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCover(Playlist pl, bool isDark) {
    if (pl.coverUrl != null && pl.coverUrl!.trim().isNotEmpty) {
      return PlaylistArtwork(
        playlistId: pl.id,
        coverUrl: pl.coverUrl,
        size: 44,
        borderRadius: BorderRadius.circular(12),
        hasShadow: false,
      );
    }

    final lowerName = pl.name.toLowerCase();

    if (pl.tracks.isEmpty) {
      if (lowerName.contains('chill') || lowerName.contains('vibe')) {
        return _buildCuratedTile(
          colors: const [Color(0xFFFF7E5F), Color(0xFFFEB47B)],
          icon: Icons.wb_sunny_rounded,
        );
      } else if (lowerName.contains('workout') || lowerName.contains('gym')) {
        return _buildCuratedTile(
          colors: const [Color(0xFF232526), Color(0xFF414345)],
          icon: Icons.fitness_center_rounded,
        );
      } else if (lowerName.contains('party') || lowerName.contains('mix') || lowerName.contains('dance')) {
        return _buildCuratedTile(
          colors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          icon: Icons.celebration_rounded,
        );
      } else if (lowerName.contains('night') || lowerName.contains('sleep') || lowerName.contains('late')) {
        return _buildCuratedTile(
          colors: const [Color(0xFF0F2027), Color(0xFF203A43)],
          icon: Icons.bedtime_rounded,
        );
      }
    }

    return PlaylistArtwork(
      playlistId: pl.id,
      coverUrl: pl.coverUrl,
      size: 44,
      borderRadius: BorderRadius.circular(12),
      hasShadow: false,
    );
  }

  Widget _buildCuratedTile({required List<Color> colors, required IconData icon}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

Widget _buildRadioIndicator(bool isSelected, bool isDark) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: isSelected
            ? const Color(0xFF75A31E)
            : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
        width: isSelected ? 2.0 : 1.8,
      ),
    ),
    child: isSelected
        ? Center(
            child: Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF75A31E),
              ),
            ),
          )
        : null,
  );
}

/// Custom painter for the red heartbeat outline heart in Favorites tile matching the reference
class _HeartbeatPainter extends CustomPainter {
  final Color color;

  const _HeartbeatPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Heart outline path
    final heartPath = Path();
    heartPath.moveTo(w * 0.5, h * 0.83);
    // Left lobe
    heartPath.cubicTo(w * 0.12, h * 0.58, w * 0.05, h * 0.28, w * 0.26, h * 0.16);
    heartPath.cubicTo(w * 0.40, h * 0.09, w * 0.48, h * 0.22, w * 0.5, h * 0.30);
    // Right lobe
    heartPath.cubicTo(w * 0.52, h * 0.22, w * 0.60, h * 0.09, w * 0.74, h * 0.16);
    heartPath.cubicTo(w * 0.95, h * 0.28, w * 0.88, h * 0.58, w * 0.5, h * 0.83);

    canvas.drawPath(heartPath, paint);

    // Heartbeat pulse ECG line across the middle
    final ecgPath = Path();
    ecgPath.moveTo(w * 0.16, h * 0.49);
    ecgPath.lineTo(w * 0.36, h * 0.49);
    ecgPath.lineTo(w * 0.43, h * 0.38);
    ecgPath.lineTo(w * 0.50, h * 0.63);
    ecgPath.lineTo(w * 0.57, h * 0.41);
    ecgPath.lineTo(w * 0.63, h * 0.49);
    ecgPath.lineTo(w * 0.84, h * 0.49);

    canvas.drawPath(ecgPath, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}