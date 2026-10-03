import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';
import 'package:musify/presentation/widgets/add_to_playlist_modal.dart';
import '../providers/audio_providers.dart';

export 'add_to_playlist_modal.dart';

/// Displays a dropdown popup menu for track actions instead of a modal bottom sheet.
void showTrackDropdownMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Track track,
  Offset? tapPosition,
  BuildContext? buttonContext,
}) async {
  HapticFeedback.selectionClick();
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final primaryColor = theme.colorScheme.primary;
  final audioHandler = ref.read(audioHandlerProvider);
  final repo = ref.read(audioRepositoryProvider);
  final downloadManager = ref.read(downloadManagerProvider);
  final isDownloaded = downloadManager.isDownloaded(track.id) || track.isDownloaded;
  final isDownloading = downloadManager.isDownloading(track.id);

  final screenSize = MediaQuery.of(context).size;
  double dx = screenSize.width - 24;
  double dy = screenSize.height * 0.4;

  final targetCtx = buttonContext ?? context;
  try {
    final box = targetCtx.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final pos = box.localToGlobal(Offset.zero);
      final size = box.size;
      if (size.height < screenSize.height * 0.7) {
        dx = pos.dx + size.width;
        dy = pos.dy + size.height;
      }
    }
  } catch (_) {}

  if (tapPosition != null) {
    dx = tapPosition.dx;
    dy = tapPosition.dy;
  }

  // Clamp menu positioning so it stays elegantly on-screen
  final double menuWidth = 220;
  final double left = (dx - menuWidth).clamp(12.0, screenSize.width - menuWidth - 12);
  final double top = (dy).clamp(60.0, screenSize.height - 260);

  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      left,
      top,
      screenSize.width - left - menuWidth,
      screenSize.height - top,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
        width: 1,
      ),
    ),
    color: isDark ? Colors.black : Colors.white,
    elevation: 10,
    items: [
      PopupMenuItem(
        value: 'next',
        child: Row(
          children: [
            Icon(Icons.playlist_play_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
            const SizedBox(width: 12),
            const Text('Play Next', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'queue',
        child: Row(
          children: [
            Icon(Icons.queue_music_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
            const SizedBox(width: 12),
            const Text('Add to Queue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'playlist',
        child: Row(
          children: [
            Icon(Icons.playlist_add_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
            const SizedBox(width: 12),
            const Text('Add to Playlist', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      // Download or Delete from Device
      if (!isDownloaded && !isDownloading) ...[
        PopupMenuItem(
          value: 'download',
          child: Row(
            children: [
              Icon(Icons.download_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
              const SizedBox(width: 12),
              const Text('Download Song', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ] else if (isDownloading) ...[
        PopupMenuItem(
          value: 'cancel_download',
          child: Row(
            children: [
              Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
              const SizedBox(width: 12),
              const Text('Cancel Download', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ] else if (isDownloaded || track.source == AudioSourceType.local) ...[
        const PopupMenuItem(
          value: 'delete_device',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
              SizedBox(width: 12),
              Text('Delete from Device', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.redAccent)),
            ],
          ),
        ),
      ],
      const PopupMenuDivider(height: 1),
      PopupMenuItem(
        value: 'like',
        child: Row(
          children: [
            Icon(
              track.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 20,
              color: track.isLiked ? primaryColor : theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 12),
            Text(
              track.isLiked ? 'Remove from Liked' : 'Save to Liked',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: track.isLiked ? primaryColor : null,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  if (selected == 'next') {
    audioHandler.insertNextInQueue(track);
    if (context.mounted) {
      AppSnackBar.show(
        context,
        message: 'Playing next in queue',
        type: AppSnackBarType.info,
        icon: Icons.playlist_play_rounded,
      );
    }
  } else if (selected == 'queue') {
    audioHandler.addToQueue(track);
    if (context.mounted) {
      AppSnackBar.show(
        context,
        message: 'Added to queue',
        type: AppSnackBarType.info,
        icon: Icons.queue_music_rounded,
      );
    }
  } else if (selected == 'playlist') {
    if (context.mounted) {
      showAddToPlaylistDropdownDialog(context, ref, track);
    }
  } else if (selected == 'download') {
    downloadManager.downloadTrack(track);
  } else if (selected == 'cancel_download') {
    downloadManager.cancelDownload(track.id);
  } else if (selected == 'delete_device') {
    if (context.mounted) {
      showConfirmDeleteTrackDialog(context, ref, track);
    }
  } else if (selected == 'like') {
    repo.toggleLike(track);
  }
}

/// Modern, styled confirmation dialog to permanently delete an audio file from device storage
void showConfirmDeleteTrackDialog(BuildContext context, WidgetRef ref, Track track) async {
  final confirmed = await showAppConfirmationDialog(
    context: context,
    title: 'Delete Song?',
    description:
        'Are you sure you want to delete this track from your device? The audio file will be permanently removed.',
    track: track,
    confirmText: 'Delete',
    cancelText: 'Cancel',
  );

  if (confirmed != true) return;
  if (!context.mounted) return;

  final audioHandler = ref.read(audioHandlerProvider);
  final downloadManager = ref.read(downloadManagerProvider);

  // On Android shared external storage, check and request All Files Access if needed
  final filePath = track.filePath;
  final isInternal = filePath != null && filePath.contains('musify_downloads');
  if (Platform.isAndroid && !isInternal && filePath != null && filePath.isNotEmpty) {
    var hasPermission = await Permission.manageExternalStorage.isGranted;
    if (!hasPermission) {
      final status = await Permission.manageExternalStorage.request();
      hasPermission = status.isGranted;
    }
    if (!hasPermission && context.mounted) {
      final openSettings = await showAppConfirmationDialog(
        context: context,
        title: 'Storage Permission',
        description:
            'Android requires "All files access" permission to delete audio files directly from shared storage.\n\nPlease grant permission in App Settings.',
        confirmText: 'Open Settings',
        cancelText: 'Cancel',
        icon: Icons.folder_special_rounded,
      );
      if (openSettings == true) {
        openAppSettings();
      }
      return;
    }
  }

  final success = await downloadManager.deleteTrackPermanently(track);
  if (success) {
    await audioHandler.removeTrackById(track.id);
    if (context.mounted) {
      AppSnackBar.show(
        context,
        message: 'Permanently deleted "${track.title}" from storage',
        type: AppSnackBarType.delete,
      );
    }
  } else {
    if (context.mounted) {
      AppSnackBar.show(
        context,
        message: 'Could not delete file from device storage. Please check permissions.',
        type: AppSnackBarType.error,
        actionLabel: 'Settings',
        onAction: () => openAppSettings(),
      );
    }
  }
}

/// Backward compatibility alias — redirects to the dropdown menu to eliminate bottom sheets
void showTrackOptionsBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Track track,
}) {
  showTrackDropdownMenu(context: context, ref: ref, track: track);
}


/// Production-grade Dialog for selecting and toggling playlists (redirects to the new reference modal)
void showAddToPlaylistDropdownDialog(BuildContext context, WidgetRef ref, Track track) {
  showAddToPlaylistModal(context, ref, track: track);
}


