import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/providers/network_providers.dart';
import 'package:musify/presentation/widgets/loading_indicators.dart';

/// Production-grade reusable offline empty/error state view.
/// Shows rich visual feedback, clear recovery messaging, and one-tap navigation to downloaded/local music.
class OfflineStateView extends ConsumerStatefulWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;
  final bool showMyMusicButton;

  const OfflineStateView({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.compact = false,
    this.showMyMusicButton = true,
  });

  @override
  ConsumerState<OfflineStateView> createState() => _OfflineStateViewState();
}

class _OfflineStateViewState extends ConsumerState<OfflineStateView> {
  bool _isChecking = false;

  Future<void> _handleRetry() async {
    if (_isChecking) return;
    HapticFeedback.mediumImpact();
    setState(() => _isChecking = true);

    final service = ref.read(networkServiceProvider);
    final reachable = await service.checkInternetReachability();

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (reachable) {
      widget.onRetry?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveTitle = widget.title ?? "No Internet Connection";
    final effectiveMessage = widget.message ??
        "Connect to WiFi or mobile data to explore online streaming, charts, and new releases.";

    if (widget.compact) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1A16) : const Color(0xFFFAF5ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.amber.withValues(alpha: isDark ? 0.25 : 0.4),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.15),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 20,
                color: Colors.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    effectiveTitle,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Showing offline & downloaded songs',
                    style: AppTypography.caption.copyWith(
                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onRetry != null)
              GestureDetector(
                onTap: _handleRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A231C) : const Color(0xFFF1E4D0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _isChecking
                      ? const PulseDotsIndicator(
                          size: 5,
                          spacing: 3,
                          color: Colors.amber,
                        )
                      : Text(
                          'Retry',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                          ),
                        ),
                ),
              ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Aura Icon with soft amber glow
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: isDark ? 0.20 : 0.10),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF241D15) : const Color(0xFFFBF1E2),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 28,
                  color: Colors.amber,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              effectiveTitle,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              effectiveMessage,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13.5,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                // Primary: Go to My Music (Downloads)
                if (widget.showMyMusicButton)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonLime,
                      foregroundColor: const Color(0xFF111827),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    icon: const Icon(Icons.headphones_rounded, size: 18, color: Color(0xFF111827)),
                    label: const Text(
                      'Go to My Music',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(currentTabIndexProvider.notifier).setIndex(1);
                    },
                  ),

                // Secondary: Retry Connection
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF2E323F) : const Color(0xFFD1D5DB),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  icon: _isChecking
                      ? PulseDotsIndicator(
                          size: 5,
                          spacing: 3,
                          color: theme.colorScheme.primary,
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _isChecking ? 'Checking...' : 'Retry',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  onPressed: _isChecking ? null : _handleRetry,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
