import 'dart:io';
import 'dart:math' as math;
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

LiquidGlassSettings _resolveTabBarGlassSettings({required bool isDark}) {
  return isDark
      ? const LiquidGlassSettings(
          thickness: 30.0,
          blur: 3.0,
          chromaticAberration: 0.30,
          lightIntensity: 0.65,
          ambientStrength: 1.0,
          refractiveIndex: 1.59,
          saturation: 0.70,
          lightAngle: 0.75 * math.pi,
          glassColor: Color(0x2EFFFFFF),
          specularSharpness: GlassSpecularSharpness.sharp,
        )
      : const LiquidGlassSettings(
          thickness: 28.0,
          blur: 3.0,
          chromaticAberration: 0.25,
          lightIntensity: 0.60,
          ambientStrength: 1.0,
          refractiveIndex: 1.55,
          saturation: 0.85,
          lightAngle: 0.75 * math.pi,
          glassColor: Color(0x24FFFFFF),
          specularSharpness: GlassSpecularSharpness.medium,
        );
}

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

  Widget _buildBottomBar({
    required BuildContext context,
    required int activeIndex,
    required bool hasTrack,
    required bool isDark,
    required ThemeData theme,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = math.max(MediaQuery.paddingOf(context).bottom, 12.0);
    final dockWidth = math.min(screenWidth - 32, 335.0);

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTrack) ...[
            MiniPlayer(
              onExpand: _expandPlayer,
            ),
            const SizedBox(height: 10),
          ],
          Container(
            width: dockWidth,
            height: 64.0,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: GlassContainer(
              useOwnLayer: true,
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(5.0),
              shape: const LiquidRoundedSuperellipse(borderRadius: 32),
              settings: _resolveTabBarGlassSettings(isDark: isDark),
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
                                  style: TextStyle(
                                    fontFamily: theme.textTheme.bodyMedium?.fontFamily,
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
                                  style: TextStyle(
                                    fontFamily: theme.textTheme.bodyMedium?.fontFamily,
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
          SizedBox(height: bottomInset),
        ],
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
            child: GlassScaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: isDark ? Colors.black : Colors.white,
              bottomBar: isMultiSelection
                  ? null
                  : _buildBottomBar(
                      context: context,
                      activeIndex: activeIndex,
                      hasTrack: hasTrack,
                      isDark: isDark,
                      theme: theme,
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

