import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/track.dart';
import 'track_artwork.dart';

/// Highly polished, minimalist confirmation dialog matching the reference design.
/// Features a centered soft-pink/red badge with delete glyph, bold title,
/// centered description, optional track/item preview row, and side-by-side
/// Cancel & Lime-accented Confirm action buttons.
class AppConfirmationDialog extends StatelessWidget {
  final String title;
  final String description;
  final Track? track;
  final List<Track>? tracks;
  final String? itemTitle;
  final String? itemSubtitle;
  final Widget? itemLeading;
  final Widget? customContent;
  final String confirmText;
  final String cancelText;
  final Color? confirmColor;
  final Color? confirmTextColor;
  final IconData icon;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.description,
    this.track,
    this.tracks,
    this.itemTitle,
    this.itemSubtitle,
    this.itemLeading,
    this.customContent,
    this.confirmText = 'Delete',
    this.cancelText = 'Cancel',
    this.confirmColor,
    this.confirmTextColor,
    this.icon = Icons.delete_forever_rounded,
    this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dialogBg = isDark ? Colors.black : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final descColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final badgeCircleBg = isDark ? const Color(0xFF381A22) : const Color(0xFFFFE8EC);
    const badgeSquareBg = Color(0xFFFF4D6D);
    final cancelBtnBg = isDark ? const Color(0xFF222533) : const Color(0xFFF1F3F6);
    final cancelBtnText = isDark ? Colors.white : const Color(0xFF1E2028);
    final confirmBtnBg = confirmColor ?? AppColors.neonLime;
    final confirmBtnText = confirmTextColor ?? const Color(0xFF111827);

    // Resolve preview item if provided
    Widget? previewWidget;
    if (customContent != null) {
      previewWidget = customContent;
    } else if (track != null) {
      previewWidget = _buildTrackPreview(context, track!, isDark, titleColor, descColor);
    } else if (tracks != null && tracks!.isNotEmpty) {
      if (tracks!.length == 1) {
        previewWidget = _buildTrackPreview(context, tracks!.first, isDark, titleColor, descColor);
      } else {
        previewWidget = _buildBatchTracksPreview(context, tracks!, isDark, titleColor, descColor);
      }
    } else if (itemTitle != null) {
      previewWidget = _buildGenericItemPreview(context, isDark, titleColor, descColor);
    }

    return Dialog(
      backgroundColor: dialogBg,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Centered Top Badge
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeCircleBg,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: badgeSquareBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 2. Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: titleColor,
              ),
            ),

            const SizedBox(height: 10),

            // 3. Description
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: descColor,
              ),
            ),

            // 4. Optional Track or Item Preview
            if (previewWidget != null) ...[
              const SizedBox(height: 20),
              previewWidget,
            ],

            const SizedBox(height: 26),

            // 5. Action Buttons (Cancel + Confirm)
            Row(
              children: [
                // Cancel Button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: cancelBtnBg,
                        foregroundColor: cancelBtnText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context, false);
                        onCancel?.call();
                      },
                      child: Text(
                        cancelText,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: cancelBtnText,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Confirm Action Button (Neon Lime)
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: confirmBtnBg,
                        foregroundColor: confirmBtnText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context, true);
                        onConfirm?.call();
                      },
                      child: Text(
                        confirmText,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: confirmBtnText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackPreview(
    BuildContext context,
    Track track,
    bool isDark,
    Color titleColor,
    Color descColor,
  ) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 48,
            height: 48,
            child: TrackArtwork(
              artworkUrl: track.artworkUrl,
              seedKey: track.title,
              size: 48,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                track.artistName.isNotEmpty ? 'By ${track.artistName}' : 'Unknown Artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: descColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatchTracksPreview(
    BuildContext context,
    List<Track> tracks,
    bool isDark,
    Color titleColor,
    Color descColor,
  ) {
    final firstTrack = tracks.first;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 48,
            height: 48,
            child: TrackArtwork(
              artworkUrl: firstTrack.artworkUrl,
              seedKey: firstTrack.title,
              size: 48,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${tracks.length} tracks selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tracks.take(2).map((t) => t.title).join(', ') +
                    (tracks.length > 2 ? ' and ${tracks.length - 2} more' : ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: descColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenericItemPreview(
    BuildContext context,
    bool isDark,
    Color titleColor,
    Color descColor,
  ) {
    return Row(
      children: [
        if (itemLeading != null) ...[
          itemLeading!,
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                itemTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              if (itemSubtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  itemSubtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: descColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Helper function to display the confirmation dialog and return true if confirmed.
Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required String title,
  required String description,
  Track? track,
  List<Track>? tracks,
  String? itemTitle,
  String? itemSubtitle,
  Widget? itemLeading,
  Widget? customContent,
  String confirmText = 'Delete',
  String cancelText = 'Cancel',
  Color? confirmColor,
  Color? confirmTextColor,
  IconData icon = Icons.delete_forever_rounded,
  bool barrierDismissible = false,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogCtx) => AppConfirmationDialog(
      title: title,
      description: description,
      track: track,
      tracks: tracks,
      itemTitle: itemTitle,
      itemSubtitle: itemSubtitle,
      itemLeading: itemLeading,
      customContent: customContent,
      confirmText: confirmText,
      cancelText: cancelText,
      confirmColor: confirmColor,
      confirmTextColor: confirmTextColor,
      icon: icon,
      onConfirm: onConfirm,
      onCancel: onCancel,
    ),
  );
}
