import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'track_artwork.dart';

/// Shows the "Add Songs to Playlist" modal bottom sheet.
///
/// Allows searching through all library tracks and adding/removing them to/from
/// the specified [playlist] in real-time with instant feedback.
Future<void> showAddSongsToPlaylistModal(
  BuildContext context, {
  required Playlist playlist,
}) {
  return showModalBottomSheet<void>(
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
      child: AddSongsToPlaylistSheet(playlist: playlist),
    ),
  );
}

/// Shows a quick modal allowing user to like tracks from their library to populate Liked Songs.
Future<void> showQuickLikeTracksModal(BuildContext context) {
  return showModalBottomSheet<void>(
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
      child: const QuickLikeTracksSheet(),
    ),
  );
}

class AddSongsToPlaylistSheet extends ConsumerStatefulWidget {
  final Playlist playlist;

  const AddSongsToPlaylistSheet({super.key, required this.playlist});

  @override
  ConsumerState<AddSongsToPlaylistSheet> createState() => _AddSongsToPlaylistSheetState();
}

class _AddSongsToPlaylistSheetState extends ConsumerState<AddSongsToPlaylistSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTrackDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E2029) : const Color(0xFFF1F3F7);
    final inputBg = isDark ? const Color(0xFF262935) : const Color(0xFFE5E7EB);
    final onSurface = theme.colorScheme.onSurface;

    final allLocalTracksAsync = ref.watch(localTracksProvider);
    final playlistTracksAsync = ref.watch(playlistTracksProvider(widget.playlist.id));
    final playlistTrackIds = (playlistTracksAsync.value ?? widget.playlist.tracks)
        .map((t) => t.id)
        .toSet();

    final allTracks = allLocalTracksAsync.value ?? [];
    final query = _filter.trim().toLowerCase();
    final displayTracks = query.isEmpty
        ? allTracks
        : allTracks.where((t) {
            return t.title.toLowerCase().contains(query) ||
                t.artistName.toLowerCase().contains(query) ||
                (t.albumTitle?.toLowerCase().contains(query) ?? false);
          }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add songs',
                        style: AppTypography.headlineSmall.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'To "${widget.playlist.name}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 13,
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Done',
                    style: AppTypography.button.copyWith(
                      color: isDark ? AppColors.neonLime : const Color(0xFF5F8F0E),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _searchController,
                style: AppTypography.bodyMedium.copyWith(fontSize: 14.5, color: onSurface),
                onChanged: (v) => setState(() => _filter = v),
                decoration: InputDecoration(
                  hintText: 'Search songs in library...',
                  hintStyle: AppTypography.bodySmall.copyWith(
                    fontSize: 14,
                    color: onSurface.withValues(alpha: 0.45),
                  ),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: onSurface.withValues(alpha: 0.55)),
                  suffixIcon: _filter.isNotEmpty
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _searchController.clear();
                            setState(() => _filter = '');
                          },
                          child: Icon(Icons.close_rounded, size: 18, color: onSurface.withValues(alpha: 0.6)),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Track List
          Expanded(
            child: displayTracks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.music_off_rounded,
                            size: 42,
                            color: onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filter.isNotEmpty
                                ? 'No songs match "$_filter"'
                                : 'No songs found in local library',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: displayTracks.length,
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                    itemBuilder: (context, index) {
                      final track = displayTracks[index];
                      final isAdded = playlistTrackIds.contains(track.id);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isAdded
                              ? (isDark
                                  ? AppColors.neonLime.withValues(alpha: 0.08)
                                  : AppColors.neonLime.withValues(alpha: 0.16))
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            TrackArtwork(
                              artworkUrl: track.artworkUrl,
                              seedKey: track.title,
                              size: 46,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${track.artistName} • ${_formatTrackDuration(track.durationMs)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 12.5,
                                      color: onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                final repo = ref.read(audioRepositoryProvider);
                                if (isAdded) {
                                  await repo.removeTrackFromPlaylist(widget.playlist.id, track.id);
                                  ref.invalidate(playlistTracksProvider(widget.playlist.id));
                                  ref.invalidate(playlistsStreamProvider);
                                } else {
                                  await repo.addTrackToPlaylist(widget.playlist.id, track);
                                  ref.invalidate(playlistTracksProvider(widget.playlist.id));
                                  ref.invalidate(playlistsStreamProvider);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isAdded
                                      ? AppColors.neonLime
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.10)
                                          : Colors.black.withValues(alpha: 0.06)),
                                ),
                                child: Icon(
                                  isAdded ? Icons.check_rounded : Icons.add_rounded,
                                  size: 20,
                                  color: isAdded
                                      ? const Color(0xFF111827)
                                      : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Sheet enabling users to quickly heart tracks from library when Liked Songs is empty.
class QuickLikeTracksSheet extends ConsumerStatefulWidget {
  const QuickLikeTracksSheet({super.key});

  @override
  ConsumerState<QuickLikeTracksSheet> createState() => _QuickLikeTracksSheetState();
}

class _QuickLikeTracksSheetState extends ConsumerState<QuickLikeTracksSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTrackDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E2029) : const Color(0xFFF1F3F7);
    final inputBg = isDark ? const Color(0xFF262935) : const Color(0xFFE5E7EB);
    final onSurface = theme.colorScheme.onSurface;

    final allLocalTracksAsync = ref.watch(localTracksProvider);
    final likedTracksAsync = ref.watch(likedTracksStreamProvider);
    final likedTrackIds = (likedTracksAsync.value ?? []).map((t) => t.id).toSet();

    final allTracks = allLocalTracksAsync.value ?? [];
    final query = _filter.trim().toLowerCase();
    final displayTracks = query.isEmpty
        ? allTracks
        : allTracks.where((t) {
            return t.title.toLowerCase().contains(query) ||
                t.artistName.toLowerCase().contains(query) ||
                (t.albumTitle?.toLowerCase().contains(query) ?? false);
          }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liked Songs',
                        style: AppTypography.headlineSmall.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap the heart on any song to save it here',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 13,
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Done',
                    style: AppTypography.button.copyWith(
                      color: isDark ? AppColors.neonLime : const Color(0xFF5F8F0E),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _searchController,
                style: AppTypography.bodyMedium.copyWith(fontSize: 14.5, color: onSurface),
                onChanged: (v) => setState(() => _filter = v),
                decoration: InputDecoration(
                  hintText: 'Search songs in library...',
                  hintStyle: AppTypography.bodySmall.copyWith(
                    fontSize: 14,
                    color: onSurface.withValues(alpha: 0.45),
                  ),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: onSurface.withValues(alpha: 0.55)),
                  suffixIcon: _filter.isNotEmpty
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _searchController.clear();
                            setState(() => _filter = '');
                          },
                          child: Icon(Icons.close_rounded, size: 18, color: onSurface.withValues(alpha: 0.6)),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: displayTracks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 42,
                            color: onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filter.isNotEmpty
                                ? 'No songs match "$_filter"'
                                : 'No songs found in local library',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: displayTracks.length,
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                    itemBuilder: (context, index) {
                      final track = displayTracks[index];
                      final isLiked = likedTrackIds.contains(track.id);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isLiked
                              ? const Color(0xFFFF4D6D).withValues(alpha: isDark ? 0.10 : 0.14)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            TrackArtwork(
                              artworkUrl: track.artworkUrl,
                              seedKey: track.title,
                              size: 46,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${track.artistName} • ${_formatTrackDuration(track.durationMs)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 12.5,
                                      color: onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                await ref.read(audioRepositoryProvider).toggleLike(track);
                                ref.invalidate(likedTracksStreamProvider);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLiked
                                      ? const Color(0xFFFF4D6D).withValues(alpha: 0.16)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.10)
                                          : Colors.black.withValues(alpha: 0.06)),
                                ),
                                child: Icon(
                                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 20,
                                  color: isLiked
                                      ? const Color(0xFFFF4D6D)
                                      : (isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
