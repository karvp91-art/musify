import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/providers/network_providers.dart';
import 'package:musify/services/network_service.dart';

/// Production-grade animated floating capsule banner that displays offline/online network transitions.
/// Designed with liquid-glass aesthetics, non-intrusive height, and quick navigation to local music.
class OfflineDynamicBanner extends ConsumerStatefulWidget {
  const OfflineDynamicBanner({super.key});

  @override
  ConsumerState<OfflineDynamicBanner> createState() => _OfflineDynamicBannerState();
}

class _OfflineDynamicBannerState extends ConsumerState<OfflineDynamicBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  bool _showBanner = false;
  bool _isBackOnline = false;
  Timer? _backOnlineDismissTimer;
  NetworkStatus? _previousStatus;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _backOnlineDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _handleNetworkChange(NetworkStatus next) {
    if (_previousStatus == null) {
      _previousStatus = next;
      if (next == NetworkStatus.offline) {
        setState(() {
          _showBanner = true;
          _isBackOnline = false;
        });
        _animController.forward();
      }
      return;
    }

    if (_previousStatus == NetworkStatus.offline && next == NetworkStatus.online) {
      // Transitioned: Offline -> Online (Show Back Online brief badge)
      _backOnlineDismissTimer?.cancel();
      setState(() {
        _showBanner = true;
        _isBackOnline = true;
      });
      _animController.forward();
      HapticFeedback.lightImpact();

      _backOnlineDismissTimer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted) {
          _animController.reverse().then((_) {
            if (mounted) {
              setState(() => _showBanner = false);
            }
          });
        }
      });
    } else if (next == NetworkStatus.offline) {
      // Transitioned: Online -> Offline
      _backOnlineDismissTimer?.cancel();
      setState(() {
        _showBanner = true;
        _isBackOnline = false;
      });
      _animController.forward();
      HapticFeedback.mediumImpact();
    } else if (next == NetworkStatus.online && !_isBackOnline) {
      _animController.reverse().then((_) {
        if (mounted) {
          setState(() => _showBanner = false);
        }
      });
    }

    _previousStatus = next;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NetworkStatus>(networkStatusProvider, (prev, next) {
      _handleNetworkChange(next);
    });

    if (!_showBanner && _animController.isDismissed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: topPadding + 6,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                constraints: const BoxConstraints(maxWidth: 420, minHeight: 46),
                decoration: BoxDecoration(
                  color: _isBackOnline
                      ? (isDark ? const Color(0xE610261A) : const Color(0xF2EAF8EF))
                      : (isDark ? const Color(0xE6201B14) : const Color(0xF2FDF4E7)),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isBackOnline
                        ? AppColors.neonLime.withValues(alpha: isDark ? 0.4 : 0.6)
                        : Colors.amber.withValues(alpha: isDark ? 0.35 : 0.5),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Status glowing dot & icon
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isBackOnline
                            ? AppColors.neonLime.withValues(alpha: 0.2)
                            : Colors.amber.withValues(alpha: 0.2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _isBackOnline
                            ? Icons.wifi_rounded
                            : Icons.wifi_off_rounded,
                        size: 15,
                        color: _isBackOnline
                            ? (isDark ? AppColors.neonLime : const Color(0xFF287D3C))
                            : (isDark ? Colors.amberAccent : const Color(0xFFB45309)),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Status Message Text
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isBackOnline ? 'Back Online' : "You're Offline",
                            style: AppTypography.caption.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _isBackOnline
                                  ? (isDark ? Colors.white : const Color(0xFF1E3A24))
                                  : (isDark ? Colors.white : const Color(0xFF452205)),
                            ),
                          ),
                          Text(
                            _isBackOnline
                                ? 'Connection restored'
                                : 'Showing downloaded & local library',
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Quick Switch to My Music Action
                    if (!_isBackOnline) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(currentTabIndexProvider.notifier).setIndex(1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E2419) : const Color(0xFFF1E1CB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'My Music',
                            style: AppTypography.caption.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Dismiss close button
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _animController.reverse().then((_) {
                          if (mounted) {
                            setState(() => _showBanner = false);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
