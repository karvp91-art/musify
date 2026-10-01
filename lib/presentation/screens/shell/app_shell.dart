import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/player/mini_player.dart';
import 'package:musify/presentation/screens/player/now_playing_screen.dart';
import 'package:musify/presentation/screens/home/home_screen.dart';
import 'package:musify/presentation/screens/search/search_screen.dart';
import 'package:musify/presentation/widgets/download_dynamic_island.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with SingleTickerProviderStateMixin {
  late final AnimationController _playerExpandController;
  late final Animation<double> _expandAnimation;
  late final Animation<Offset> _slideAnimation;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 360ms forward duration with fluid Apple Music / Material 3 deceleration curve
    _playerExpandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _expandAnimation = CurvedAnimation(
      parent: _playerExpandController,
      curve: const Cubic(0.2, 0.9, 0.22, 1.0),
      reverseCurve: Curves.easeInCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(_expandAnimation);
  }

  @override
  void dispose() {
    _playerExpandController.dispose();
    super.dispose();
  }

  void _expandPlayer() {
    _playerExpandController.forward();
  }

  void _minimizePlayer() {
    _playerExpandController.reverse();
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final currentTabIndex = ref.watch(currentTabIndexProvider);
    final activeIndex = currentTabIndex.clamp(0, _screens.length - 1);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardUp = keyboardHeight > 0;
    final isMultiSelection = ref.watch(isMultiSelectionModeProvider);

    // Pre-cache ambient blur image (64px) when track changes so NowPlaying opens instantly without decode delay
    ref.listen<Track?>(currentPlayingTrackProvider, (prev, next) {
      if (next?.artworkUrl != null && next!.artworkUrl!.trim().isNotEmpty) {
        final url = next.artworkUrl!;
        if (url.startsWith('http://') || url.startsWith('https://')) {
          precacheImage(
            CachedNetworkImageProvider(url, maxWidth: 64, maxHeight: 64),
            context,
            onError: (_, _) {},
          );
        } else {
          precacheImage(
            FileImage(File(url)),
            context,
            onError: (_, _) {},
          );
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. If keyboard is open, back button/gesture closes keyboard
        if (MediaQuery.of(context).viewInsets.bottom > 0) {
          FocusManager.instance.primaryFocus?.unfocus();
          return;
        }

        // 2. If full now playing player is open, back button minimizes player
        if (_playerExpandController.value > 0.05) {
          _minimizePlayer();
          return;
        }

        // 3. If currently on Search tab, back button returns to Home tab
        final tabIndex = ref.read(currentTabIndexProvider);
        if (tabIndex != 0) {
          ref.read(currentTabIndexProvider.notifier).setIndex(0);
          return;
        }

        // 4. If on Home tab root, double-tap back to exit safely without abrupt termination
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          AppSnackBar.show(
            context,
            message: 'Press back again to exit',
            type: AppSnackBarType.info,
            duration: const Duration(seconds: 2),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: Stack(
          children: [
            // 1. Main Body Screens with IndexedStack for instant state preservation
            IndexedStack(
              index: activeIndex,
              children: _screens,
            ),

            // 1.5. Dynamic Island Download Status Capsule
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: const DownloadDynamicIsland(),
            ),

            // 2. Docked Bottom Shell: Mini-Player & Custom Bottom Navigation Bar
            // Bottom navigation bar collapses smoothly when keyboard is open; MiniPlayer remains visible and docked above keyboard!
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: isMultiSelection ? -180 : (isKeyboardUp ? keyboardHeight : 0),
              child: AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  final isFullyExpanded = _expandAnimation.value == 1.0;
                  // Offstage and suspend tickers in bottom shell when full player is 100% open
                  return Offstage(
                    offstage: isFullyExpanded,
                    child: TickerMode(
                      enabled: !isFullyExpanded,
                      child: IgnorePointer(
                        ignoring: _expandAnimation.value > 0.05,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MiniPlayer(
                      onExpand: _expandPlayer,
                    ),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: isKeyboardUp
                            ? const SizedBox.shrink()
                            : _CustomBottomNavBar(
                                activeIndex: activeIndex,
                                onTap: (index) {
                                  HapticFeedback.selectionClick();
                                  ref.read(currentTabIndexProvider.notifier).setIndex(index);
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Expanding Full Now Playing Screen Overlay
            // Sits at the very top of the Stack, sliding up smoothly with hardware-accelerated SlideTransition.
            // Using a static pre-mounted child avoids recreating or rebuilding NowPlayingScreen on every animation frame,
            // while Offstage + TickerMode guarantee 0 GPU / 0 animation CPU while the player is collapsed.
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                final isCollapsed = _expandAnimation.value == 0.0;

                return Offstage(
                  offstage: isCollapsed,
                  child: TickerMode(
                    enabled: !isCollapsed,
                    child: IgnorePointer(
                      ignoring: isCollapsed,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: child,
                      ),
                    ),
                  ),
                );
              },
              child: RepaintBoundary(
                child: NowPlayingScreen(
                  onMinimize: _minimizePlayer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sleek modern bottom navigation bar matching the app's aesthetic
class _CustomBottomNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNavBar({
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0E13) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFECEEF2),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              _NavBarItem(
                label: 'My music',
                activeIcon: Icons.headphones_rounded,
                inactiveIcon: Icons.headphones_outlined,
                isSelected: activeIndex == 0,
                activeColor: primaryColor,
                onTap: () => onTap(0),
              ),
              _NavBarItem(
                label: 'Stream',
                activeIcon: Icons.play_circle_fill_rounded,
                inactiveIcon: Icons.play_circle_outline_rounded,
                isSelected: activeIndex == 1,
                activeColor: primaryColor,
                onTap: () => onTap(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.42)
        : const Color(0xFF7E8292);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 16 : 8,
                vertical: 2.5,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? activeColor.withValues(alpha: 0.16)
                        : AppColors.neonLime)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                size: 21,
                color: isSelected
                    ? (isDark ? activeColor : Colors.black)
                    : inactiveColor,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? activeColor : const Color(0xFF121316))
                    : inactiveColor,
                letterSpacing: -0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
