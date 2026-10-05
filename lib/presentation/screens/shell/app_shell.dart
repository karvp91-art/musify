import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/player/mini_player.dart';
import 'package:musify/presentation/screens/player/now_playing_screen.dart';
import 'package:musify/presentation/screens/search/search_screen.dart';
import 'package:musify/presentation/widgets/download_dynamic_island.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import '../home/home_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with SingleTickerProviderStateMixin {
  late final AnimationController _playerExpandController;
  late final Animation<double> _expandAnimation;
  late final Animation<Offset> _slideAnimation;
  late final PageController _pageController;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: ref.read(currentTabIndexProvider).clamp(0, _screens.length - 1),
    );
    // 320ms forward duration with fluid Apple Music / Material 3 deceleration curve
    _playerExpandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final current = ref.read(currentPlayingTrackProvider);
        if (current?.artworkUrl != null) {
          TrackArtwork.precacheArtwork(context, current!.artworkUrl);
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  Widget _buildDock({
    required BuildContext context,
    required int activeIndex,
    required bool isDark,
    required ThemeData theme,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = math.max(MediaQuery.paddingOf(context).bottom, 10.0);
    final dockWidth = math.min(screenWidth - 32, 335.0);

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          width: dockWidth,
          height: 64.0,
          padding: const EdgeInsets.all(5.0),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xE614161C)
                : const Color(0xF2FFFFFF),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
                children: [
                  // Clean standard Ease-In-Out Slide Indicator
                  AnimatedAlign(
                    alignment: activeIndex == 0 ? Alignment.centerLeft : Alignment.centerRight,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.neonLime,
                          borderRadius: BorderRadius.circular(27.0),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonLime.withValues(alpha: isDark ? 0.35 : 0.45),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tab Buttons Row
                  Row(
                    children: [
                      // Tab 0: My Music
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(currentTabIndexProvider.notifier).setIndex(0);
                          },
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  activeIndex == 0
                                      ? Icons.headphones_rounded
                                      : Icons.headphones_outlined,
                                  size: 20,
                                  color: activeIndex == 0
                                      ? const Color(0xFF111827)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.65)
                                          : const Color(0xFF555B6E)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'My music',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 12.5,
                                    fontWeight: activeIndex == 0
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    decoration: TextDecoration.none,
                                    letterSpacing: -0.2,
                                    color: activeIndex == 0
                                        ? const Color(0xFF111827)
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.65)
                                            : const Color(0xFF555B6E)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Tab 1: Stream
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(currentTabIndexProvider.notifier).setIndex(1);
                          },
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  activeIndex == 1
                                      ? Icons.play_circle_fill_rounded
                                      : Icons.play_circle_outline_rounded,
                                  size: 20,
                                  color: activeIndex == 1
                                      ? const Color(0xFF111827)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.65)
                                          : const Color(0xFF555B6E)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Stream',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 12.5,
                                    fontWeight: activeIndex == 1
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    decoration: TextDecoration.none,
                                    letterSpacing: -0.2,
                                    color: activeIndex == 1
                                        ? const Color(0xFF111827)
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.65)
                                            : const Color(0xFF555B6E)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTabIndex = ref.watch(currentTabIndexProvider);
    final activeIndex = currentTabIndex.clamp(0, _screens.length - 1);
    final currentTrack = ref.watch(currentPlayingTrackProvider);
    final hasTrack = currentTrack != null;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMultiSelection = ref.watch(isMultiSelectionModeProvider);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    // Smoothly animate PageView when currentTabIndex changes programmatically (e.g. via tab taps or back button)
    ref.listen<int>(currentTabIndexProvider, (prev, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.animateToPage(
          next.clamp(0, _screens.length - 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        );
      }
    });

    // Pre-cache high-res player artwork (480px) when track changes so NowPlaying opens with 0ms decode latency
    ref.listen<Track?>(currentPlayingTrackProvider, (prev, next) {
      if (next?.artworkUrl != null && next!.artworkUrl!.trim().isNotEmpty) {
        TrackArtwork.precacheArtwork(context, next.artworkUrl);
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
      child: Stack(
        children: [
          // 1. Native iOS 26 Liquid Glass Navigation Layer with GlassScaffold
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              final isFullyExpanded = _expandAnimation.value == 1.0;
              // Offstage and suspend tickers in background navigation layer when full player is 100% open
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
            child: RepaintBoundary(
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                backgroundColor: isDark ? Colors.black : Colors.white,
                body: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    children: [
                      // 1. Main Body Screens with PageView for smooth horizontal swipe gestures
                      PageView(
                        controller: _pageController,
                        physics: const ClampingScrollPhysics(),
                        onPageChanged: (index) {
                          if (ref.read(currentTabIndexProvider) != index) {
                            HapticFeedback.selectionClick();
                            ref.read(currentTabIndexProvider.notifier).setIndex(index);
                          }
                        },
                        children: _screens,
                      ),

                      // 2. Dynamic Island Download Status Capsule
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 0,
                        right: 0,
                        child: const DownloadDynamicIsland(),
                      ),

                      // 3. Floating Navigation Dock (Anchored at screen bottom, covered naturally when keyboard opens)
                      if (!isMultiSelection)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _buildDock(
                              context: context,
                              activeIndex: activeIndex,
                              isDark: isDark,
                              theme: theme,
                            ),
                          ),
                        ),

                      // 4. Floating MiniPlayer (Floats above dock when closed, and floats above keyboard when typing)
                      if (!isMultiSelection && hasTrack)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          left: 0,
                          right: 0,
                          bottom: keyboardHeight > 0
                              ? keyboardHeight + 6.0
                              : 64.0 + math.max(MediaQuery.paddingOf(context).bottom, 10.0) + 3.0,
                          child: Material(
                            type: MaterialType.transparency,
                            child: MiniPlayer(
                              onExpand: _expandPlayer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Expanding Full Now Playing Screen Overlay
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
                      transformHitTests: false,
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
                expandAnimation: _expandAnimation,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

