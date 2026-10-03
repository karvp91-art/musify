import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/data/repositories/local_files_scanner.dart';
import '../providers/audio_providers.dart';

/// Triggers background device scan and opens the redesigned floating modal bottom sheet
/// styled to match the aesthetics of AddToPlaylistModal.
Future<void> startScanWithProgressDialog(BuildContext context, WidgetRef ref) async {
  HapticFeedback.selectionClick();

  // If not already scanning, kick off device scanning
  final isScanning = ref.read(isScanningProvider);
  if (!isScanning) {
    _triggerDeviceScan(ref);
  }

  return showModalBottomSheet<void>(
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
      child: const ScanStorageBottomSheet(),
    ),
  );
}

/// Backward compatibility alias
Future<void> showScanStorageModal(BuildContext context, WidgetRef ref) =>
    startScanWithProgressDialog(context, ref);

/// Silently runs device storage scan in background without popping modal UI
Future<void> triggerBackgroundStorageScan(WidgetRef ref) async {
  final isScanning = ref.read(isScanningProvider);
  if (isScanning) return;

  final scanner = ref.read(localScannerProvider);
  ref.read(isScanningProvider.notifier).setScanning(true);
  try {
    await scanner.scanDeviceMusic(
      onProgress: (prog) {
        ref.read(scanProgressProvider.notifier).setProgress(prog);
      },
    );
    ref.read(preferencesServiceProvider).setHasScannedStorage(true);
    ref.read(isScanningProvider.notifier).setScanning(false);
    ref.invalidate(localTracksProvider);
  } catch (e) {
    ref.read(isScanningProvider.notifier).setScanning(false);
  }
}

Future<void> _triggerDeviceScan(WidgetRef ref) async {
  final scanner = ref.read(localScannerProvider);
  ref.read(isScanningProvider.notifier).setScanning(true);
  ref.read(scanProgressProvider.notifier).setProgress(const ScanProgress(
    filesScanned: 0,
    tracksFound: 0,
    currentDirectory: 'Starting storage scan...',
  ));

  try {
    final count = await scanner.scanDeviceMusic(
      onProgress: (prog) {
        ref.read(scanProgressProvider.notifier).setProgress(prog);
      },
    );
    ref.read(preferencesServiceProvider).setHasScannedStorage(true);
    ref.read(isScanningProvider.notifier).setScanning(false);
    ref.read(scanProgressProvider.notifier).setProgress(ScanProgress(
      filesScanned: ref.read(scanProgressProvider)?.filesScanned ?? 0,
      tracksFound: count,
      currentDirectory: 'Scan completed',
      isCompleted: true,
    ));
    ref.invalidate(localTracksProvider);
  } catch (e) {
    ref.read(isScanningProvider.notifier).setScanning(false);
    ref.read(scanProgressProvider.notifier).setProgress(ScanProgress(
      filesScanned: ref.read(scanProgressProvider)?.filesScanned ?? 0,
      tracksFound: ref.read(scanProgressProvider)?.tracksFound ?? 0,
      currentDirectory: 'Scan failed: $e',
      isCompleted: true,
    ));
  }
}

class ScanStorageBottomSheet extends ConsumerStatefulWidget {
  const ScanStorageBottomSheet({super.key});

  @override
  ConsumerState<ScanStorageBottomSheet> createState() => _ScanStorageBottomSheetState();
}

class _ScanStorageBottomSheetState extends ConsumerState<ScanStorageBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = ref.watch(scanProgressProvider);
    final isScanning = ref.watch(isScanningProvider);
    final isCompleted = progress?.isCompleted ?? false;
    final done = isCompleted && !isScanning;

    if (done && _rotationController.isAnimating) {
      _rotationController.stop();
    } else if (!done && !_rotationController.isAnimating) {
      _rotationController.repeat();
    }

    final cardBg = isDark ? Colors.black : Colors.white;
    final dividerColor = isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB);
    final activeAccent = isDark ? AppColors.neonLime : const Color(0xFF659814);

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Drag Handle Pill (matching AddToPlaylistModal)
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

            // 2. Header Row (matching 52x52 icon container + Title/Subtitle layout)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222C1D) : const Color(0xFFDFEDE0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: done
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: activeAccent,
                              size: 26,
                            )
                          : RotationTransition(
                              turns: _rotationController,
                              child: Icon(
                                Icons.refresh_rounded,
                                color: activeAccent,
                                size: 26,
                              ),
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
                          done ? 'Scan Completed' : 'Scanning Storage',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17.5,
                            letterSpacing: -0.2,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          done
                              ? 'Indexed ${progress?.tracksFound ?? 0} audio tracks'
                              : 'Indexing music & embedded artworks',
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
                  if (done)
                    IconButton(
                      tooltip: 'Rescan Storage',
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
                        size: 22,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _triggerDeviceScan(ref);
                      },
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

            // 3. Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: isDark
                      ? const Color(0xFF222533)
                      : const Color(0xFFF1F3F6),
                  valueColor: AlwaysStoppedAnimation<Color>(activeAccent),
                  value: done ? 1.0 : null,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 4. Stats Rows (Styled like AddToPlaylistModal 44x44 tiles)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222C1D) : const Color(0xFFDFEDE0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 22,
                      color: activeAccent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tracks Found',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Local audio files ready to play',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222C1D) : const Color(0xFFDFEDE0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${progress?.tracksFound ?? 0}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: activeAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222533) : const Color(0xFFF1F3F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder_open_rounded,
                      size: 22,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Files Examined',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total files crawled across storage',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222533) : const Color(0xFFF1F3F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${progress?.filesScanned ?? 0}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 5. Current Directory Pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111216) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dividerColor.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 15,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        progress?.currentDirectory ?? 'Searching device storage...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
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

            // 6. Action Button Area (matching AddToPlaylistModal 52px high pill button)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: done
                  ? SizedBox(
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
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).pop();
                          AppSnackBar.show(
                            context,
                            message:
                                'Indexed ${progress?.tracksFound ?? 0} local tracks',
                            type: AppSnackBarType.success,
                            icon: Icons.library_music_rounded,
                          );
                        },
                        child: Text(
                          'Done',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: dividerColor, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                foregroundColor: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.8),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Hide',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF222C1D)
                                    : const Color(0xFFDFEDE0),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              onPressed: null,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: activeAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Scanning...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: activeAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
