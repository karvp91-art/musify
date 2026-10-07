import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/services/backup_service.dart';

/// Opens the Backup & Restore screen with authentic iOS slide navigation.
Future<void> openBackupRestoreScreen(BuildContext context) {
  HapticFeedback.selectionClick();
  return Navigator.of(context).push<void>(
    CupertinoPageRoute(
      builder: (_) => const BackupRestoreScreen(),
    ),
  );
}

/// Circular header button matching the top app bar actions of Studio Equalizer
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

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
  List<BackupFileInfo> _backups = [];
  final TextEditingController _customPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  @override
  void dispose() {
    _customPathController.dispose();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final list = await BackupService.listBackups();
      if (mounted) {
        setState(() {
          _backups = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleExport() async {
    HapticFeedback.mediumImpact();
    setState(() => _isExporting = true);

    try {
      final repo = ref.read(audioRepositoryProvider);
      final prefs = ref.read(preferencesServiceProvider);

      final backupFile = await BackupService.exportBackup(repo: repo, prefs: prefs);
      await _loadBackups();

      if (mounted) {
        setState(() => _isExporting = false);
        final fileName = backupFile.path.split(Platform.pathSeparator).last;
        AppSnackBar.show(
          context,
          message: 'Saved "$fileName" in Downloads/Musify/Backups',
          type: AppSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        AppSnackBar.show(
          context,
          message: 'Failed to create backup: $e',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Future<void> _showRestorePreviewDialog(File file) async {
    HapticFeedback.selectionClick();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeGreenColor = isDark ? AppColors.neonLime : const Color(0xFF3E8016);
    final cardBg = isDark ? const Color(0xFF181A22) : Colors.white;

    try {
      final preview = await BackupService.inspectBackup(file);
      if (!mounted) return;

      bool mergeMode = true;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.neonLime.withValues(alpha: 0.18)
                                : const Color(0xFFEFFCC8),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.settings_backup_restore_rounded,
                            color: activeGreenColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Restore Library',
                                style: AppTypography.headlineSmall.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                preview.file.path.split(Platform.pathSeparator).last,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : const Color(0xFF8E92A0),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Content breakdown card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildStatRow(
                            icon: Icons.playlist_play_rounded,
                            label: 'Playlists',
                            value: '${preview.playlistCount} (${preview.totalPlaylistTracks} tracks)',
                            isDark: isDark,
                            activeGreenColor: activeGreenColor,
                          ),
                          Divider(
                            height: 20,
                            thickness: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                          ),
                          _buildStatRow(
                            icon: Icons.favorite_rounded,
                            label: 'Liked Songs',
                            value: '${preview.likedCount} favorites',
                            isDark: isDark,
                            activeGreenColor: activeGreenColor,
                          ),
                          Divider(
                            height: 20,
                            thickness: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                          ),
                          _buildStatRow(
                            icon: Icons.tune_rounded,
                            label: 'Audio DSP & Preferences',
                            value: 'EQ Curves, Quality & Theme',
                            isDark: isDark,
                            activeGreenColor: activeGreenColor,
                          ),
                        ],
                      ),
                    ),

                    if (preview.playlistNames.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Includes: ${preview.playlistNames.take(3).join(', ')}${preview.playlistNames.length > 3 ? '...' : ''}',
                          style: AppTypography.caption.copyWith(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Merge Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Merge with Existing Library',
                                  style: AppTypography.headlineSmall.copyWith(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Preserve current playlists and append restored items',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white54 : const Color(0xFF8E92A0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: mergeMode,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.neonLime,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: isDark
                                ? const Color(0xFF2C2F3D)
                                : const Color(0xFFD6D9E0),
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setModalState(() => mergeMode = val);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.black.withValues(alpha: 0.12),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTypography.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _executeRestore(file, merge: mergeMode);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeGreenColor,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Restore Now',
                              style: AppTypography.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Invalid or corrupt backup file: $e',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color activeGreenColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTypography.style(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF374151),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.style(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: activeGreenColor,
          ),
        ),
      ],
    );
  }

  Future<void> _executeRestore(File file, {required bool merge}) async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(audioRepositoryProvider);
      final prefs = ref.read(preferencesServiceProvider);

      final result = await BackupService.restoreBackup(
        file,
        repo: repo,
        prefs: prefs,
        ref: ref,
        merge: merge,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result.success) {
          AppSnackBar.show(
            context,
            message: 'Successfully restored ${result.restoredPlaylists} playlists, '
                '${result.restoredLikedSongs} favorites & audio settings!',
            type: AppSnackBarType.success,
          );
        } else {
          AppSnackBar.show(
            context,
            message: 'Failed to restore: ${result.errorMessage}',
            type: AppSnackBarType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.show(
          context,
          message: 'Restore error: $e',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Future<void> _confirmDeleteBackup(BackupFileInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup?'),
        content: Text('Are you sure you want to permanently delete "${info.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BackupService.deleteBackup(info.file);
      await _loadBackups();
      if (mounted) {
        AppSnackBar.show(context, message: 'Backup deleted', type: AppSnackBarType.success);
      }
    }
  }

  Future<void> _handleCustomFileRestore() async {
    final rawPath = _customPathController.text.trim();
    if (rawPath.isEmpty) return;

    final file = File(rawPath);
    if (!file.existsSync()) {
      AppSnackBar.show(
        context,
        message: 'File not found at specified path',
        type: AppSnackBarType.error,
      );
      return;
    }

    await _showRestorePreviewDialog(file);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);
    final activeGreenColor = isDark ? AppColors.neonLime : const Color(0xFF3E8016);
    final iconBgColor = isDark
        ? AppColors.neonLime.withValues(alpha: 0.18)
        : const Color(0xFFEFFCC8);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top App Bar matching Studio Equalizer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _CircleHeaderButton(
                        icon: Icons.chevron_left_rounded,
                        iconSize: 26,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Backup & Restore',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      _CircleHeaderButton(
                        icon: Icons.refresh_rounded,
                        iconSize: 22,
                        onTap: _loadBackups,
                      ),
                    ],
                  ),
                ),

                // Scrollable Content (Open Canvas, Borderless, Unclosed Approach)
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // 1. CREATE BACKUP (Open Canvas)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Backup',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Export playlists, liked songs & audio preferences to a standalone JSON file.',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Save Library State Action Row (Open Canvas)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: iconBgColor,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.cloud_upload_rounded,
                                color: activeGreenColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Save Library State',
                                    style: AppTypography.headlineSmall.copyWith(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Saves to Downloads/Musify/Backups',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 12,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Create Backup Button directly on canvas
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : _handleExport,
                            icon: _isExporting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 20),
                            label: Text(
                              _isExporting ? 'Exporting...' : 'Create Backup Now',
                              style: AppTypography.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeGreenColor,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 2. AVAILABLE BACKUPS (Open Canvas)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Text(
                              'Available Backups',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: iconBgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_backups.length}',
                                style: AppTypography.style(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: activeGreenColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Backup Files List (Open Canvas)
                      if (_isLoading)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: activeGreenColor,
                            ),
                          ),
                        )
                      else if (_backups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 36,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Backups Found',
                                style: AppTypography.headlineSmall.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap "Create Backup Now" above to create your first backup archive.',
                                textAlign: TextAlign.center,
                                style: AppTypography.caption.copyWith(
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._backups.map(
                          (b) => _buildBackupTile(
                            b,
                            isDark: isDark,
                            iconBgColor: iconBgColor,
                            activeGreenColor: activeGreenColor,
                            textMuted: textMuted,
                            theme: theme,
                          ),
                        ),

                      const SizedBox(height: 28),

                      // 3. EXTERNAL RESTORE (Open Canvas)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'External Restore',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Import from external download or shared .json / .musify file',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Open Canvas Path Input
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customPathController,
                                style: AppTypography.style(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: '/storage/emulated/0/...',
                                  hintStyle: AppTypography.caption.copyWith(
                                    fontSize: 12,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 13,
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF20222B)
                                      : const Color(0xFFECEEF2),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _handleCustomFileRestore,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF20222B)
                                    : const Color(0xFFECEEF2),
                                foregroundColor: theme.colorScheme.onSurface,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 13,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Open',
                                style: AppTypography.style(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Clearance for floating mini player
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),

            // Universal Floating Mini Player
            const FloatingMiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupTile(
    BackupFileInfo info, {
    required bool isDark,
    required Color iconBgColor,
    required Color activeGreenColor,
    required Color textMuted,
    required ThemeData theme,
  }) {
    final dateStr = info.exportedAt != null
        ? '${info.exportedAt!.year}-${info.exportedAt!.month.toString().padLeft(2, '0')}-${info.exportedAt!.day.toString().padLeft(2, '0')} ${info.exportedAt!.hour.toString().padLeft(2, '0')}:${info.exportedAt!.minute.toString().padLeft(2, '0')}'
        : '${info.modifiedAt.year}-${info.modifiedAt.month.toString().padLeft(2, '0')}-${info.modifiedAt.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.description_rounded,
              size: 22,
              color: activeGreenColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.fileName,
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr • ${info.formattedSize}',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (info.playlistCount > 0)
                      _buildMiniBadge(
                        '${info.playlistCount} Playlists',
                        isDark: isDark,
                        activeGreenColor: activeGreenColor,
                      ),
                    if (info.playlistCount > 0 && info.likedCount > 0)
                      const SizedBox(width: 6),
                    if (info.likedCount > 0)
                      _buildMiniBadge(
                        '${info.likedCount} Liked',
                        isDark: isDark,
                        activeGreenColor: activeGreenColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Delete circular button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              _confirmDeleteBackup(info);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Restore button
          ElevatedButton(
            onPressed: () => _showRestorePreviewDialog(info.file),
            style: ElevatedButton.styleFrom(
              backgroundColor: activeGreenColor,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Restore',
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(
    String text, {
    required bool isDark,
    required Color activeGreenColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neonLime.withValues(alpha: 0.16)
            : const Color(0xFFEFFCC8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTypography.style(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: activeGreenColor,
        ),
      ),
    );
  }
}
