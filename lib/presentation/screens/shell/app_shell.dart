import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
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
    final currentTrack = ref.watch(currentPlayingTrackProvider);
    final hasTrack = currentTrack != null;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
      child: Stack(
        children: [
          // 1. Native iOS 26 Liquid Glass Navigation Layer with GlassScaffold & GlassTabBar.bottom
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
            child: GlassScaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: isDark ? Colors.black : Colors.white,
              bottomBar: isMultiSelection
                  ? null
                  : Material(
                      type: MaterialType.transparency,
                      child: GlassTabBar.bottom(
                        tabs: const [
                          GlassTab(
                            icon: Icon(Icons.headphones_outlined),
                            activeIcon: Icon(Icons.headphones_rounded),
                            label: 'My music',
                            glowColor: AppColors.neonLime,
                          ),
                          GlassTab(
                            icon: Icon(Icons.play_circle_outline_rounded),
                            activeIcon: Icon(Icons.play_circle_fill_rounded),
                            label: 'Stream',
                            glowColor: AppColors.neonLime,
                          ),
                        ],
                        selectedIndex: activeIndex,
                        onTabSelected: (index) {
                          HapticFeedback.selectionClick();
                          ref.read(currentTabIndexProvider.notifier).setIndex(index);
                        },
                        indicatorColor: AppColors.neonLime,
                        selectedIconColor: const Color(0xFF111827),
                        selectedLabelColor: const Color(0xFF111827),
                        unselectedIconColor: isDark
                            ? Colors.white.withValues(alpha: 0.65)
                            : const Color(0xFF555B6E),
                        unselectedLabelColor: isDark
                            ? Colors.white.withValues(alpha: 0.65)
                            : const Color(0xFF555B6E),
                        selectedLabelStyle: TextStyle(
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                          letterSpacing: -0.2,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                          letterSpacing: -0.2,
                        ),
                        bottomAccessory: MiniPlayer(
                          onExpand: _expandPlayer,
                        ),
                        bottomAccessoryEnabled: hasTrack,
                        bottomAccessoryHeight: 80,
                      ),
                    ),
              body: Stack(
                children: [
                  // 1. Main Body Screens with IndexedStack for instant state preservation
                  IndexedStack(
                    index: activeIndex,
                    children: _screens,
                  ),

                  // 2. Dynamic Island Download Status Capsule
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 0,
                    right: 0,
                    child: const DownloadDynamicIsland(),
                  ),
                ],
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
    );
  }
}

