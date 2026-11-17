import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/services/online_artwork_enricher.dart';

/// Opens the interactive "Choose Album Artwork" bottom sheet allowing the user
/// to visually inspect high-res cover art from Apple Music, Deezer, and JioSaavn.
Future<bool?> showChooseArtworkBottomSheet(
  BuildContext context,
  WidgetRef ref,
  Track track,
) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    useSafeArea: true,
    builder: (modalCtx) => Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        14 + MediaQuery.of(modalCtx).padding.bottom,
      ),
      child: ChooseArtworkBottomSheet(track: track),
    ),
  );
}

class ChooseArtworkBottomSheet extends ConsumerStatefulWidget {
  final Track track;
  const ChooseArtworkBottomSheet({super.key, required this.track});

  @override
  ConsumerState<ChooseArtworkBottomSheet> createState() => _ChooseArtworkBottomSheetState();
}

class _ChooseArtworkBottomSheetState extends ConsumerState<ChooseArtworkBottomSheet> {
  late final TextEditingController _searchController;
  bool _isLoading = true;
  String? _errorMessage;
  List<ArtworkCandidate> _candidates = [];

  @override
  void initState() {
    super.initState();
    final cleanTitle = OnlineArtworkEnricher.cleanTitleForSearch(widget.track.title);
    final hasArtist = widget.track.artistName.trim().isNotEmpty &&
        widget.track.artistName.trim().toLowerCase() != 'unknown artist';
    final initialQuery = hasArtist ? '$cleanTitle ${widget.track.artistName}' : cleanTitle;
    _searchController = TextEditingController(text: initialQuery);

    _performSearch(initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await OnlineArtworkEnricher.searchArtworkCandidates(
        widget.track,
        customQuery: query,
      );
      if (mounted) {
        setState(() {
          _candidates = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load artwork candidates. Please check your internet connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectArtwork(ArtworkCandidate candidate) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(audioRepositoryProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    await repo.updateTrackArtwork(widget.track.id, candidate.imageUrl);

    final updatedTrack = widget.track.copyWith(artworkUrl: candidate.imageUrl);
    audioHandler.updateTrackMetadata(updatedTrack);

    if (mounted) {
      Navigator.of(context).pop(true);
      AppSnackBar.show(
        context,
        message: 'Album artwork updated for "${widget.track.title}"',
        type: AppSnackBarType.success,
        icon: Icons.check_circle_rounded,
      );
    }
  }

  Future<void> _removeArtwork() async {
    HapticFeedback.lightImpact();
    final repo = ref.read(audioRepositoryProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    await repo.updateTrackArtwork(widget.track.id, '');

    final updatedTrack = widget.track.copyWith(artworkUrl: '');
    audioHandler.updateTrackMetadata(updatedTrack);

    if (mounted) {
      Navigator.of(context).pop(true);
      AppSnackBar.show(
        context,
        message: 'Custom artwork removed',
        type: AppSnackBarType.info,
        icon: Icons.delete_outline_rounded,
      );
    }
  }

  String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final dividerColor = isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB);
    final searchInputBg = isDark ? const Color(0xFF16181F) : Colors.white;
    final activeAccent = isDark ? AppColors.neonLime : const Color(0xFF659814);
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.82;

    final hasCustomArtwork = widget.track.artworkUrl != null &&
        widget.track.artworkUrl!.isNotEmpty &&
        !TrackArtwork.isPlaceholderUrl(widget.track.artworkUrl);

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: cardBg,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Drag Handle Pill
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 2. Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Album Artwork',
                        style: AppTypography.headlineSmall.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.track.title} • ${widget.track.artistName}',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ],
            ),
          ),

          // 3. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: searchInputBg,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: dividerColor, width: 0.8),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    child: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _performSearch,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by song title or artist name...',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          fontSize: 13.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _searchController.clear();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    },
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _performSearch(_searchController.text);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: activeAccent.withValues(alpha: isDark ? 0.20 : 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Search',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: activeAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 4. Candidate Results Area
          Expanded(
            child: _isLoading
                ? _buildLoadingGrid(isDark, dividerColor)
                : _errorMessage != null
                    ? _buildErrorView(theme)
                    : _candidates.isEmpty
                        ? _buildEmptyView(theme)
                        : _buildCandidatesGrid(isDark, dividerColor, activeAccent),
          ),

          // 5. Bottom Action Bar (Remove custom artwork if present)
          if (hasCustomArtwork)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: dividerColor, width: 0.8)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _removeArtwork,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'Remove Custom Artwork',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingGrid(bool isDark, Color dividerColor) {
    final shimmerBase = isDark ? const Color(0xFF282C37) : const Color(0xFFE2E4E9);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.76,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: shimmerBase,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E212A) : const Color(0xFFD6D8DE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 12,
                width: 100,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E212A) : const Color(0xFFD6D8DE),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 70,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E212A) : const Color(0xFFD6D8DE),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_search_rounded,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 14),
            Text(
              'No artwork found',
              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting the song name or artist in the search bar above.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 44, color: Colors.amber),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Network error occurred',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => _performSearch(_searchController.text),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Retry Search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesGrid(bool isDark, Color dividerColor, Color activeAccent) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _candidates.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.74,
      ),
      itemBuilder: (context, index) {
        final candidate = _candidates[index];
        final isBestMatch = candidate.confidenceScore >= 0.80;

        Color sourceColor;
        if (candidate.source == 'Apple Music') {
          sourceColor = const Color(0xFFFC3C44);
        } else if (candidate.source == 'Deezer') {
          sourceColor = const Color(0xFFA238FF);
        } else {
          sourceColor = const Color(0xFF2BC5B4);
        }

        return InkWell(
          onTap: () => _selectArtwork(candidate),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181A22) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isBestMatch ? activeAccent.withValues(alpha: 0.7) : dividerColor,
                width: isBestMatch ? 1.5 : 0.8,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Square Artwork with Badges
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: candidate.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: isDark ? const Color(0xFF242731) : const Color(0xFFE2E4E9),
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: isDark ? const Color(0xFF242731) : const Color(0xFFE2E4E9),
                            child: const Icon(Icons.broken_image_rounded, size: 28, color: Colors.white38),
                          ),
                        ),
                      ),

                      // Top-Right: Source Badge
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sourceColor.withValues(alpha: 0.5), width: 0.8),
                          ),
                          child: Text(
                            candidate.source,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: sourceColor,
                            ),
                          ),
                        ),
                      ),

                      // Top-Left: Best Match Badge
                      if (isBestMatch)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF103B13).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.neonLime.withValues(alpha: 0.6), width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 10, color: AppColors.neonLime),
                                SizedBox(width: 3),
                                Text(
                                  'Best Match',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.neonLime,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Album / Track Title
                Text(
                  candidate.albumName.isNotEmpty ? candidate.albumName : candidate.title,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                // Artist & Duration Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        candidate.artistName,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (candidate.durationMs != null)
                      Text(
                        _formatDuration(candidate.durationMs!),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: candidate.isDurationMatch
                              ? AppColors.neonLime
                              : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
