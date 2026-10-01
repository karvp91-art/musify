import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/data/repositories/local_files_scanner.dart';
import '../providers/audio_providers.dart';

Future<void> startScanWithProgressDialog(BuildContext context, WidgetRef ref) async {
  final scanner = ref.read(localScannerProvider);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final primaryColor = Theme.of(context).colorScheme.primary;

  ref.read(isScanningProvider.notifier).setScanning(true);
  ref.read(scanProgressProvider.notifier).setProgress(const ScanProgress(
    filesScanned: 0,
    tracksFound: 0,
    currentDirectory: 'Starting storage scan...',
  ));

  bool isDone = false;
  int finalCount = 0;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      return Consumer(
        builder: (context, ref, child) {
          final progress = ref.watch(scanProgressProvider);
          final done = progress?.isCompleted ?? isDone;

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF16181F) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          done ? Icons.check_circle_rounded : Icons.search_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              done ? 'Scan Completed' : 'Scanning Storage',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              done
                                  ? 'Indexed $finalCount audio tracks'
                                  : 'Indexing music & embedded artworks',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : Colors.black.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      value: done ? 1.0 : null,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatChip(
                        label: 'Tracks Found',
                        value: '${progress?.tracksFound ?? 0}',
                        icon: Icons.music_note_rounded,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      _StatChip(
                        label: 'Files Checked',
                        value: '${progress?.filesScanned ?? 0}',
                        icon: Icons.folder_open_rounded,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Current Directory
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E212B)
                          : const Color(0xFFF1F3F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_rounded,
                          size: 15,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            progress?.currentDirectory ?? 'Searching...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (done) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        },
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );

  try {
    final count = await scanner.scanDeviceMusic(
      onProgress: (prog) {
        ref.read(scanProgressProvider.notifier).setProgress(prog);
      },
    );
    finalCount = count;
    isDone = true;
    ref.read(isScanningProvider.notifier).setScanning(false);
    ref.read(scanProgressProvider.notifier).setProgress(ScanProgress(
      filesScanned: ref.read(scanProgressProvider)?.filesScanned ?? 0,
      tracksFound: count,
      currentDirectory: 'Done',
      isCompleted: true,
    ));
    ref.invalidate(localTracksProvider);
  } catch (e) {
    ref.read(isScanningProvider.notifier).setScanning(false);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
      AppSnackBar.show(
        context,
        message: 'Scan error: $e',
        type: AppSnackBarType.error,
      );
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final Color primaryColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E212B) : const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
