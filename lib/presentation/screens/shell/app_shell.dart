import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/player/mini_player.dart';
import 'package:musify/presentation/screens/player/now_playing_screen.dart';
import 'package:musify/presentation/screens/home/home_screen.dart';
import 'package:musify/presentation/screens/search/search_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with SingleTickerProviderStateMixin {
  late final AnimationController _playerExpandController;
  late final Animation<double> _expandAnimation;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _playerExpandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _expandAnimation = CurvedAnimation(
      parent: _playerExpandController,
      curve: Curves.fastOutSlowIn,
    );
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
    final isKeyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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

            // 2. Docked Bottom Shell: Mini-Player & Custom Bottom Navigation Bar
            // Hidden smoothly when keyboard is open so it does not block the screen
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: isKeyboardUp ? const Offset(0, 1.2) : Offset.zero,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                child: AnimatedOpacity(
                  opacity: isKeyboardUp ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: AnimatedBuilder(
                    animation: _expandAnimation,
                    builder: (context, child) {
                      // When NowPlaying is expanding or expanded, disable touches on the bottom shell
                      return IgnorePointer(
                        ignoring: isKeyboardUp || _expandAnimation.value > 0.05,
                        child: child,
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MiniPlayer(
                          onExpand: _expandPlayer,
                        ),
                        _CustomBottomNavBar(
                          activeIndex: activeIndex,
                          onTap: (index) {
                            HapticFeedback.selectionClick();
                            ref.read(currentTabIndexProvider.notifier).setIndex(index);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Expanding Full Now Playing Screen Overlay
            // Sits at the very top of the Stack, completely covering the bottom navigation bar when expanded.
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                if (_expandAnimation.value == 0.0) {
                  return const SizedBox.shrink();
                }
                final screenHeight = MediaQuery.of(context).size.height;
                final translateY = screenHeight * (1.0 - _expandAnimation.value);

                return Transform.translate(
                  offset: Offset(0, translateY),
                  child: child,
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
          height: 56,
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
                label: 'Watch',
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
        : Colors.black.withValues(alpha: 0.45);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                size: 23,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
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
