import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/domain/models/lyrics.dart';
import 'package:musify/domain/models/playback_state.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/seek_bar.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/track_menu_bottom_sheet.dart';
import 'package:musify/presentation/widgets/loading_indicators.dart';
import 'package:musify/presentation/screens/settings/studio_equalizer_screen.dart';

bool _isNowPlayingRouteOpen = false;

// ─────────────────────────────────────────────────────────────────────────────
// Motion language
//
// Every animation on this screen shares ONE easing family and a small set of
// durations, so nothing feels like it belongs to a different "speed".
// ─────────────────────────────────────────────────────────────────────────────

/// Fast start, long soft landing (Material 3 "emphasized decelerate").
const Curve _kEmph = Cubic(0.05, 0.7, 0.1, 1.0);

/// Duration for small state changes (toggles, play state, scale).
const Duration _kState = Duration(milliseconds: 360);

/// Duration for press feedback.
const Duration _kPress = Duration(milliseconds: 120);

/// Global helper to push NowPlayingScreen seamlessly from any screen
Future<void> openNowPlayingScreen(BuildContext context, {Track? targetTrack}) async {
  if (_isNowPlayingRouteOpen || !context.mounted) return;
  _isNowPlayingRouteOpen = true;
  HapticFeedback.selectionClick();
  FocusManager.instance.primaryFocus?.unfocus();
  SystemChannels.textInput.invokeMethod('TextInput.hide');

  // Pre-cache artwork and warm up palette extraction ahead of push to
  // eliminate first-frame jank. Capped short so opening never feels delayed.
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final trackToWarm = targetTrack ?? container.read(currentPlayingTrackProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (trackToWarm != null) {
      await Future.wait([
        TrackArtwork.precacheArtwork(context, trackToWarm.artworkUrl),
        container.read(trackPaletteProvider((track: trackToWarm, isDark: isDark)).future),
      ]).timeout(const Duration(milliseconds: 140), onTimeout: () => []);
    }
  } catch (_) {}

  if (!context.mounted) {
    _isNowPlayingRouteOpen = false;
    return;
  }

  await WidgetsBinding.instance.endOfFrame;

  if (!context.mounted) {
    _isNowPlayingRouteOpen = false;
    return;
  }

  await Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder(
      opaque: true,
      fullscreenDialog: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return NowPlayingScreen(
          initialTrack: targetTrack,
          onMinimize: () => Navigator.of(context).pop(),
          expandAnimation: animation,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // The same curve is applied in both directions: it decelerates on the
        // way in and naturally accelerates away on the way out.
        final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
            .chain(CurveTween(curve: _kEmph));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 360),
    ),
  );
  _isNowPlayingRouteOpen = false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared design tokens
// ─────────────────────────────────────────────────────────────────────────────

const Color _kBaseDark = Color(0xFF0C0D12);
const Color _kBaseLight = Color(0xFFF7F8FA);
const Color _kLikeRed = Color(0xFFFF5A5F);

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

/// Readable primary text color for the current brightness.
Color _ink(bool isDark) => isDark ? Colors.white : const Color(0xFF14161C);

/// Secondary text color (artist names, captions).
Color _inkSoft(bool isDark) =>
    isDark ? Colors.white.withValues(alpha: 0.58) : Colors.black.withValues(alpha: 0.52);

/// Accent used for "on" states of toggles; high contrast in both modes.
Color _toggleAccent(bool isDark) =>
    isDark ? AppColors.neonLime : const Color(0xFF0D9488);

// ─────────────────────────────────────────────────────────────────────────────
// Animation helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Staggered entrance: fades + slides (and optionally scales) its child in
/// during the [begin]..[end] window of a shared [animation] (0..1).
///
/// The widget tree shape never changes while animating or after completing,
/// so child state (scroll controllers, tickers) is never torn down mid-intro.
class _Reveal extends StatefulWidget {
  final Animation<double> animation;
  final double begin;
  final double end;
  final Offset offset;
  final double scaleFrom;
  final Widget child;

  const _Reveal({
    required this.animation,
    required this.begin,
    required this.end,
    required this.child,
    this.offset = const Offset(0, 18),
    this.scaleFrom = 1.0,
  });

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  late CurvedAnimation _curved;

  CurvedAnimation _make() => CurvedAnimation(
        parent: widget.animation,
        curve: Interval(widget.begin, widget.end, curve: _kEmph),
      );

  @override
  void initState() {
    super.initState();
    _curved = _make();
  }

  @override
  void didUpdateWidget(covariant _Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.begin != widget.begin ||
        oldWidget.end != widget.end) {
      _curved.dispose();
      _curved = _make();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: AnimatedBuilder(
        animation: _curved,
        child: RepaintBoundary(child: widget.child),
        builder: (context, child) {
          final t = _curved.value;
          Widget result = child!;
          if (widget.scaleFrom != 1.0) {
            result = Transform.scale(
              scale: widget.scaleFrom + (1.0 - widget.scaleFrom) * t,
              child: result,
            );
          }
          return Transform.translate(
            offset: widget.offset * (1.0 - t),
            child: result,
          );
        },
      ),
    );
  }
}

/// Tiny animated equalizer glyph. Dances while audio is playing, rests low
/// while paused. Driven by one controller + a repaint-only painter.
class _EqBars extends ConsumerStatefulWidget {
  final double size;
  final Color color;
  final int bars;

  const _EqBars({this.size = 16, required this.color, this.bars = 4});

  @override
  ConsumerState<_EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends ConsumerState<_EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _playing = ref.read(isPlaybackPlayingProvider);
    if (_playing) _c.repeat();
    ref.listenManual<bool>(isPlaybackPlayingProvider, (_, next) {
      if (next == _playing) return;
      _playing = next;
      if (next) {
        _c.repeat();
      } else {
        _c.stop();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _EqPainter(
          animation: _c,
          playing: _playing,
          color: widget.color,
          bars: widget.bars,
        ),
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  final Animation<double> animation;
  final bool playing;
  final Color color;
  final int bars;

  _EqPainter({
    required this.animation,
    required this.playing,
    required this.color,
    required this.bars,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final gap = size.width * 0.14;
    final barW = (size.width - gap * (bars - 1)) / bars;
    for (var i = 0; i < bars; i++) {
      final double f;
      if (playing) {
        // Integer frequencies keep the loop seamless.
        final wave = math.sin(2 * math.pi * animation.value * (i % 3 + 1) + i * 1.7);
        f = 0.28 + 0.72 * (0.5 + 0.5 * wave);
      } else {
        f = 0.26;
      }
      final h = size.height * f;
      final x = i * (barW + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barW, h),
          Radius.circular(barW / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EqPainter old) =>
      old.playing != playing || old.color != color || old.bars != bars;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

enum _Sheet { none, queue, lyrics }

class NowPlayingScreen extends ConsumerStatefulWidget {
  final VoidCallback onMinimize;
  final Animation<double>? expandAnimation;
  final Track? initialTrack;

  const NowPlayingScreen({
    super.key,
    required this.onMinimize,
    this.expandAnimation,
    this.initialTrack,
  });

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with TickerProviderStateMixin {
  _Sheet _sheet = _Sheet.none;
  bool _settled = false;
  Animation<double>? _effectiveAnimation;
  MiniPlayerPalette? _cachedPalette;

  /// Drives the staggered entrance of every block on the main view.
  /// Starts together with the route slide so the two read as one motion.
  late final AnimationController _intro;

  /// ONE controller drives everything that happens when a sheet (queue or
  /// lyrics) opens/closes: main view recedes, sheet rises, background calms.
  late final AnimationController _sheetCtrl;
  late final CurvedAnimation _sheetAnim;
  late final Animation<double> _mainFade;
  late final Animation<double> _mainScale;
  late final Animation<double> _sheetFade;
  late final Animation<Offset> _sheetSlide;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _sheetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 340),
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && mounted && _sheet != _Sheet.none) {
          setState(() => _sheet = _Sheet.none);
        }
      });
    // One curve both ways: decelerates on open, and on close it starts slow
    // and speeds away, which reads as a natural dismissal.
    _sheetAnim = CurvedAnimation(parent: _sheetCtrl, curve: _kEmph);
    _mainFade = _sheetAnim
        .drive(CurveTween(curve: const Interval(0.0, 0.55, curve: Curves.easeIn)))
        .drive(Tween<double>(begin: 1.0, end: 0.0));
    _mainScale = _sheetAnim.drive(Tween<double>(begin: 1.0, end: 0.95));
    _sheetFade = _sheetAnim
        .drive(CurveTween(curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
    _sheetSlide = _sheetAnim.drive(
      Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupAnimationListener();
  }

  @override
  void didUpdateWidget(covariant NowPlayingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandAnimation != oldWidget.expandAnimation) {
      _cleanupAnimationListener();
      _setupAnimationListener();
    }
  }

  void _setupAnimationListener() {
    final anim = widget.expandAnimation ?? ModalRoute.of(context)?.animation;
    if (anim == _effectiveAnimation) return;
    _cleanupAnimationListener();
    _effectiveAnimation = anim;
    if (anim != null) {
      anim.addStatusListener(_handleRouteStatus);
      if (anim.status == AnimationStatus.completed) {
        _settled = true;
        _intro.value = 1.0;
      } else {
        _settled = false;
        if (anim.status == AnimationStatus.forward && _intro.status == AnimationStatus.dismissed) {
          _intro.forward(from: 0.0);
        }
      }
    } else {
      _settled = true;
      _intro.value = 1.0;
    }
  }

  void _cleanupAnimationListener() {
    _effectiveAnimation?.removeStatusListener(_handleRouteStatus);
    _effectiveAnimation = null;
  }

  void _handleRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      // Entrance choreography begins WITH the slide, not after it.
      if (_intro.status == AnimationStatus.dismissed) _intro.forward(from: 0.0);
    } else if (status == AnimationStatus.completed) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (mounted) {
        setState(() => _settled = true);
        if (_intro.status == AnimationStatus.dismissed) _intro.forward(from: 0.0);
      }
    }
    // On reverse we deliberately change nothing: the content slides away
    // intact together with the route instead of vanishing first.
  }

  void _openSheet(_Sheet sheet) {
    if (_sheet == sheet && _sheetCtrl.status != AnimationStatus.reverse) return;
    setState(() => _sheet = sheet);
    _sheetCtrl.forward();
  }

  void _closeSheet() {
    if (_sheet == _Sheet.none) return;
    _sheetCtrl.reverse();
  }

  @override
  void dispose() {
    _cleanupAnimationListener();
    _sheetAnim.dispose();
    _sheetCtrl.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveTrack = ref.watch(currentPlayingTrackProvider);
    final track = liveTrack ?? widget.initialTrack;
    final audioHandler = ref.read(audioHandlerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (track == null) {
      return Scaffold(
        backgroundColor: isDark ? _kBaseDark : _kBaseLight,
        body: Center(
          child: Text(
            'Nothing is playing',
            style: AppTypography.style(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final paletteAsync = ref.watch(
      trackPaletteProvider((track: track, isDark: isDark)),
    );

    final palette = paletteAsync.value ??
        PaletteService.instance.getCachedPalette(track, isDark: isDark) ??
        _cachedPalette ??
        MiniPlayerPalette.fallback(
          isDark: isDark,
          seed: track.id.isNotEmpty ? track.id : track.title,
        );

    _cachedPalette = palette;
    final accent = palette.backgroundColor;

    final mainView = KeyedSubtree(
      key: const ValueKey('main_player_view'),
      child: _buildMainPlayerView(track, audioHandler, theme, palette),
    );

    Widget? sheetView;
    switch (_sheet) {
      case _Sheet.queue:
        sheetView = KeyedSubtree(
          key: const ValueKey('queue_view'),
          child: _buildQueueView(audioHandler, theme, accent),
        );
      case _Sheet.lyrics:
        sheetView = KeyedSubtree(
          key: const ValueKey('full_lyrics_view'),
          child: _buildFullLyricsView(track, audioHandler, theme, accent),
        );
      case _Sheet.none:
        sheetView = null;
    }

    return PopScope(
      canPop: _sheet == _Sheet.none,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeSheet();
      },
      child: Scaffold(
        backgroundColor: isDark ? _kBaseDark : _kBaseLight,
        body: Stack(
          children: [
            Positioned.fill(
              child: _AmbientPaletteBackground(
                backgroundColor: palette.backgroundColor,
                isDark: isDark,
                settled: _settled,
                calm: _sheetAnim,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // Main player: recedes (fade + tiny scale) as a sheet rises,
                  // all on the same controller as the sheet itself.
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _sheetAnim,
                      child: mainView,
                      builder: (context, child) {
                        final covered = _sheetAnim.value >= 1.0;
                        return TickerMode(
                          enabled: !covered,
                          child: Offstage(
                            offstage: covered,
                            child: IgnorePointer(
                              ignoring: _sheet != _Sheet.none,
                              child: FadeTransition(
                                opacity: _mainFade,
                                child: ScaleTransition(
                                  scale: _mainScale,
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (sheetView != null)
                    Positioned.fill(
                      child: FadeTransition(
                        opacity: _sheetFade,
                        child: SlideTransition(
                          position: _sheetSlide,
                          child: RepaintBoundary(child: sheetView),
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

  // ───────────────────────────── Main player ─────────────────────────────
  //
  // Layout: everything sits directly on the shared atmospheric background.
  // No wells, capsules or cards: just artwork, type and controls.
  //
  //   top bar → artwork → title / like → lyrics → seek → controls
  //
  // Entrance: one 900ms controller, staggered, started WITH the route slide.

  Widget _buildMainPlayerView(
    Track track,
    dynamic audioHandler,
    ThemeData theme,
    MiniPlayerPalette palette,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final accent = palette.backgroundColor;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
          HapticFeedback.lightImpact();
          widget.onMinimize();
        }
      },
      child: Column(
        children: [
          _Reveal(
            animation: _intro,
            begin: 0.0,
            end: 0.40,
            offset: const Offset(0, -10),
            child: _NowPlayingTopBar(
              track: track,
              palette: palette,
              onBack: () {
                HapticFeedback.lightImpact();
                widget.onMinimize();
              },
            ),
          ),

          // Artwork takes all the space the other blocks leave over.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxByWidth = math.min(constraints.maxWidth - 40, 400.0);
                final maxByHeight = math.max(0.0, constraints.maxHeight - 12);
                final artSize = math.min(maxByWidth, maxByHeight).toDouble();
                return Align(
                  alignment: const Alignment(0, 0.35),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _Reveal(
                      animation: _intro,
                      begin: 0.0,
                      end: 0.62,
                      offset: const Offset(0, 24),
                      scaleFrom: 0.9,
                      child: _SquircleArtworkHero(
                        track: track,
                        artSize: artSize,
                        accent: accent,
                        audioHandler: audioHandler,
                        settled: _settled,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
            child: Column(
              children: [
                const SizedBox(height: 14),

                // Title + artist (left), like (right)
                _Reveal(
                  animation: _intro,
                  begin: 0.18,
                  end: 0.62,
                  offset: const Offset(0, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.9,
                                height: 1.12,
                                color: _ink(isDark),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.15,
                                color: _inkSoft(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _InlineLikeButton(track: track),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Live lyrics: open text on the background, no container.
                _Reveal(
                  animation: _intro,
                  begin: 0.28,
                  end: 0.70,
                  offset: const Offset(0, 12),
                  child: _settled
                      ? _SlidingLyricsWidget(
                          audioHandler: audioHandler,
                          primaryColor: accent,
                          onExpand: () {
                            HapticFeedback.lightImpact();
                            _openSheet(_Sheet.lyrics);
                          },
                        )
                      // Same footprint as the real widget, so swapping is a
                      // pure cross-fade inside it with zero layout shift.
                      : const SizedBox(height: _SlidingLyricsWidgetState._viewHeight),
                ),

                const SizedBox(height: 8),

                _Reveal(
                  animation: _intro,
                  begin: 0.36,
                  end: 0.78,
                  offset: const Offset(0, 12),
                  child: const _IsolatedPlayerSeekBar(),
                ),

                const SizedBox(height: 4),

                _Reveal(
                  animation: _intro,
                  begin: 0.42,
                  end: 0.90,
                  offset: const Offset(0, 14),
                  child: _PlaybackControlsRow(
                    audioHandler: audioHandler,
                    isQueueOpen: _sheet == _Sheet.queue,
                    onToggleQueue: () {
                      HapticFeedback.selectionClick();
                      if (_sheet == _Sheet.queue) {
                        _closeSheet();
                      } else {
                        _openSheet(_Sheet.queue);
                      }
                    },
                  ),
                ),

                SizedBox(height: math.max(bottomInset, 16) + 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── Queue ─────────────────────────────

  Widget _buildQueueView(
    dynamic audioHandler,
    ThemeData theme,
    Color accent,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final toggle = _toggleAccent(isDark);
    final base = isDark ? _kBaseDark : _kBaseLight;

    return _SheetBody(
      child: Consumer(
        builder: (context, ref, _) {
          final queue = ref.watch(playerStateStreamProvider.select((s) => s.value?.queue ?? const []));
          final currentIndex = ref.watch(playerStateStreamProvider.select((s) => s.value?.currentIndex ?? -1));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
                    HapticFeedback.lightImpact();
                    _closeSheet();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 10, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Up next',
                              style: AppTypography.style(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: _ink(isDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              queue.length == 1 ? '1 song' : '${queue.length} songs',
                              style: AppTypography.style(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _inkSoft(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Plain text action: no pill, no fill.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          audioHandler.clearQueue();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Text(
                            'Clear',
                            style: AppTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: toggle,
                            ),
                          ),
                        ),
                      ),
                      _GhostIconButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        iconSize: 28,
                        onTap: _closeSheet,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _FadeEdges(
                  fraction: 0.03,
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: queue.length,
                    proxyDecorator: (child, index, animation) => AnimatedBuilder(
                      animation: animation,
                      child: child,
                      builder: (context, child) {
                        final t = Curves.easeOut.transform(animation.value);
                        return Transform.scale(
                          scale: 1.0 + 0.025 * t,
                          child: Material(
                            color: base.withValues(alpha: 0.88 * t),
                            child: child,
                          ),
                        );
                      },
                    ),
                    onReorderItem: (oldIdx, newIdx) {
                      HapticFeedback.selectionClick();
                      audioHandler.reorderQueue(oldIdx, newIdx);
                    },
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      final isCurrent = index == currentIndex;

                      final row = ListTile(
                        contentPadding: const EdgeInsets.only(left: 20, right: 6),
                        leading: SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              TrackArtwork(
                                artworkUrl: item.artworkUrl,
                                seedKey: item.id.isNotEmpty ? item.id : item.title,
                                size: 52,
                                borderRadius: BorderRadius.circular(12),
                                ambientGlow: false,
                                cacheDimension: 156,
                              ),
                              if (isCurrent)
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.black.withValues(alpha: 0.45),
                                  ),
                                  child: const Center(
                                    child: _EqBars(size: 20, color: Colors.white, bars: 4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 15,
                            letterSpacing: -0.2,
                            fontWeight: FontWeight.w700,
                            color: isCurrent ? toggle : _ink(isDark),
                          ),
                        ),
                        subtitle: Text(
                          item.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 13,
                            color: _inkSoft(isDark),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                audioHandler.removeQueueItemAt(index);
                              },
                              child: SizedBox(
                                width: 36,
                                height: 44,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: _inkSoft(isDark).withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: SizedBox(
                                width: 40,
                                height: 44,
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 22,
                                  color: _inkSoft(isDark).withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          audioHandler.playTrackAtIndex(index);
                        },
                      );

                      // First rows glide in with the sheet itself (same
                      // controller, so it can never fall out of step). Rows
                      // further down are static, and scrolling never replays.
                      final Widget content = index < 8
                          ? _Reveal(
                              animation: _sheetAnim,
                              begin: 0.15 + index * 0.04,
                              end: math.min(1.0, 0.15 + index * 0.04 + 0.55),
                              offset: const Offset(0, 16),
                              child: row,
                            )
                          : row;

                      return Padding(
                        key: ValueKey('queue_${item.id}_$index'),
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: content,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ───────────────────────────── Full lyrics ─────────────────────────────

  Widget _buildFullLyricsView(
    Track track,
    dynamic audioHandler,
    ThemeData theme,
    Color accent,
  ) {
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);
    final isDark = theme.brightness == Brightness.dark;

    return _SheetBody(
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
                HapticFeedback.lightImpact();
                _closeSheet();
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
              child: Row(
                children: [
                  _GhostIconButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    iconSize: 28,
                    onTap: _closeSheet,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: _ink(isDark),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 12.5,
                              color: _inkSoft(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LikeButton(track: track),
                      Builder(
                        builder: (btnCtx) => _GhostIconButton(
                          icon: Icons.more_vert_rounded,
                          iconSize: 22,
                          onTap: () {
                            showTrackDropdownMenu(
                              context: context,
                              buttonContext: btnCtx,
                              ref: ref,
                              track: track,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Full synced lyrics body
          Expanded(
            child: lyricsAsync.when(
              data: (Lyrics? lyrics) {
                if (lyrics == null || lyrics.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lyrics_outlined,
                            size: 44,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.30),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No lyrics for this song',
                            style: AppTypography.style(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _ink(isDark),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'We couldn\'t find lyrics for "${track.title}".',
                            textAlign: TextAlign.center,
                            style: AppTypography.style(
                              fontSize: 13,
                              color: _inkSoft(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return _FullLyricsScrollView(
                  lyrics: lyrics,
                  audioHandler: audioHandler,
                  primaryColor: accent,
                );
              },
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulseDotsIndicator(
                      size: 7.0,
                      spacing: 5.0,
                      color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Loading lyrics...',
                      style: AppTypography.style(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: _inkSoft(isDark).withValues(alpha: 0.65),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Lyrics failed to load',
                  style: AppTypography.style(
                    fontSize: 13,
                    color: theme.colorScheme.error.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ),

          // Compact persistent player controls
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _IsolatedPlayerSeekBar(),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GhostIconButton(
                      icon: Icons.skip_previous_rounded,
                      size: 52,
                      iconSize: 32,
                      onTap: () => audioHandler.skipToPrevious(),
                    ),
                    const SizedBox(width: 14),
                    _PlayPauseButton(
                      size: 56,
                      iconSize: 30,
                      audioHandler: audioHandler,
                    ),
                    const SizedBox(width: 14),
                    _GhostIconButton(
                      icon: Icons.skip_next_rounded,
                      size: 52,
                      iconSize: 32,
                      onTap: () => audioHandler.skipToNext(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet body (queue / lyrics). Deliberately NOT a card: no fill, no rounded
// top, no shadow. The content floats on the same atmospheric background.
// ─────────────────────────────────────────────────────────────────────────────

class _SheetBody extends StatelessWidget {
  final Widget child;

  const _SheetBody({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 6,
        bottom: MediaQuery.paddingOf(context).bottom,
      ),
      child: child,
    );
  }
}

/// Softly fades the top and bottom edges of a scrolling child to transparent.
class _FadeEdges extends StatelessWidget {
  final Widget child;
  final double fraction;

  const _FadeEdges({required this.child, this.fraction = 0.12});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0.0, fraction, 1.0 - fraction, 1.0],
      ).createShader(rect),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons & header
// ─────────────────────────────────────────────────────────────────────────────

/// Borderless icon button: no circle, no fill. Soft press response.
class _GhostIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;

  const _GhostIconButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 24,
    this.iconColor,
  });

  @override
  State<_GhostIconButton> createState() => _GhostIconButtonState();
}

class _GhostIconButtonState extends State<_GhostIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.iconColor ?? _ink(isDark).withValues(alpha: 0.9);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: _kPress,
        curve: _kEmph,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.6 : 1.0,
          duration: _kPress,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: Icon(widget.icon, size: widget.iconSize, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat icon button for prev / next in the controls row
class _PlainIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PlainIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PlainIconButton> createState() => _PlainIconButtonState();
}

class _PlainIconButtonState extends State<_PlainIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.84 : 1.0,
        duration: _kPress,
        curve: _kEmph,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.7 : 1.0,
          duration: _kPress,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              widget.icon,
              size: 38,
              color: _ink(isDark),
            ),
          ),
        ),
      ),
    );
  }
}

/// Top bar: minimize arrow, live "Now playing" label, and plain icon actions.
/// Nothing sits inside a pill or circle.
class _NowPlayingTopBar extends ConsumerWidget {
  final Track track;
  final MiniPlayerPalette palette;
  final VoidCallback onBack;

  const _NowPlayingTopBar({
    required this.track,
    required this.palette,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttonIconColor = palette.iconColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          // Fixed-width side slots keep the title perfectly centered
          SizedBox(
            width: 96,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _GhostIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                size: 44,
                iconSize: 30,
                iconColor: buttonIconColor,
                onTap: onBack,
              ),
            ),
          ),

          // Centered status: equalizer glyph + label, no capsule
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EqBars(size: 13, color: palette.titleColor.withValues(alpha: 0.9), bars: 3),
                  const SizedBox(width: 8),
                  Text(
                    'Now playing',
                    style: AppTypography.style(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: palette.titleColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(
            width: 96,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final isEqEnabled = ref.watch(equalizerProvider.select((e) => e.isEnabled));
                      final target = isEqEnabled
                          ? (palette.isLight ? const Color(0xFF0D9488) : AppColors.neonLime)
                          : buttonIconColor.withValues(alpha: 0.85);
                      // Color glides instead of snapping when EQ toggles.
                      return TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: target),
                        duration: _kState,
                        curve: _kEmph,
                        builder: (context, color, _) => _GhostIconButton(
                          icon: Icons.tune_rounded,
                          size: 44,
                          iconSize: 21,
                          iconColor: color ?? target,
                          onTap: () => openStudioEqualizerScreen(context),
                        ),
                      );
                    },
                  ),
                  Builder(
                    builder: (btnCtx) => _GhostIconButton(
                      icon: Icons.more_vert_rounded,
                      size: 44,
                      iconSize: 21,
                      iconColor: buttonIconColor,
                      onTap: () {
                        showTrackDropdownMenu(
                          context: context,
                          buttonContext: btnCtx,
                          ref: ref,
                          track: track,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Heart button used in the full lyrics header (no circle).
class _LikeButton extends ConsumerWidget {
  final Track track;

  const _LikeButton({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(
      currentPlayingTrackProvider.select((t) => t?.id == track.id ? (t?.isLiked ?? false) : track.isLiked),
    );

    return _GhostIconButton(
      icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      iconColor: isLiked ? _kLikeRed : null,
      iconSize: 22,
      onTap: () {
        ref.read(audioRepositoryProvider).toggleLike(track);
      },
    );
  }
}

/// Heart at the right of the title row. A bare icon with a generous tap
/// target; liking pops the heart with a short springy scale.
class _InlineLikeButton extends ConsumerWidget {
  final Track track;

  const _InlineLikeButton({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLiked = ref.watch(
      currentPlayingTrackProvider.select(
        (t) => t?.id == track.id ? (t?.isLiked ?? false) : track.isLiked,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isLiked) {
          HapticFeedback.selectionClick();
        } else {
          HapticFeedback.mediumImpact();
        }
        ref.read(audioRepositoryProvider).toggleLike(track);
      },
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Icon(
            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 27,
            color: isLiked ? _kLikeRed : _ink(isDark).withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Artwork hero
// ─────────────────────────────────────────────────────────────────────────────

/// The artwork floats gently and its colored glow breathes in the same
/// rhythm (one controller drives both) while music plays. Only cheap
/// compositing layers animate; the artwork itself is never repainted.
class _SquircleArtworkHero extends ConsumerStatefulWidget {
  final Track track;
  final double artSize;
  final Color accent;
  final dynamic audioHandler;
  final bool settled;

  const _SquircleArtworkHero({
    required this.track,
    required this.artSize,
    required this.accent,
    required this.audioHandler,
    this.settled = true,
  });

  @override
  ConsumerState<_SquircleArtworkHero> createState() => _SquircleArtworkHeroState();
}

class _SquircleArtworkHeroState extends ConsumerState<_SquircleArtworkHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;
  late final CurvedAnimation _curve;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowFade;

  static const Duration _rest = Duration(milliseconds: 520);

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
    _curve = CurvedAnimation(parent: _float, curve: Curves.easeInOutSine);
    _glowScale = Tween<double>(begin: 0.95, end: 1.06).animate(_curve);
    _glowFade = Tween<double>(begin: 0.70, end: 1.0).animate(_curve);

    if (widget.settled && ref.read(isPlaybackPlayingProvider)) _float.repeat(reverse: true);
    ref.listenManual<bool>(isPlaybackPlayingProvider, (_, playing) {
      if (widget.settled) {
        if (playing) {
          _float.repeat(reverse: true);
        } else {
          // Settle back to rest in step with the paused scale-down.
          _float.animateTo(0, duration: _rest, curve: _kEmph);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _SquircleArtworkHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settled != oldWidget.settled) {
      if (widget.settled && ref.read(isPlaybackPlayingProvider)) {
        if (!_float.isAnimating) _float.repeat(reverse: true);
      } else if (!widget.settled) {
        _float.stop();
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final artSize = widget.artSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheDim = (artSize * pixelRatio).round().clamp(100, 900);
    final radius = BorderRadius.circular(artSize * 0.075);
    final isPlaying = ref.watch(isPlaybackPlayingProvider);
    final trackKey = track.id.isNotEmpty ? track.id : track.title;

    final artwork = RepaintBoundary(
      child: Container(
        width: artSize,
        height: artSize,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            // Contact shadow: tight and dark, anchors the artwork
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
              blurRadius: 10,
              spreadRadius: -2,
              offset: const Offset(0, 5),
            ),
            // Ambient shadow: wide and soft, gives lift
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.16),
              blurRadius: 28,
              spreadRadius: -6,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TrackArtwork(
                artworkUrl: track.artworkUrl,
                seedKey: trackKey,
                size: artSize,
                borderRadius: radius,
                ambientGlow: false,
                cacheDimension: cacheDim,
              ),
              // Soft top-left sheen, like light catching a glossy sleeve
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.center,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.10 : 0.14),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Breathing glow in the artwork's own color, rendered via fast GPU RadialGradient
    final glowColor = widget.accent.withValues(alpha: isDark ? 0.48 : 0.36);
    final glow = Positioned(
      top: 8,
      bottom: -20,
      left: -22,
      right: -22,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _glowFade,
          child: ScaleTransition(
            scale: _glowScale,
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      glowColor,
                      glowColor.withValues(alpha: glowColor.a * 0.40),
                      glowColor.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity;
        if (v == null) return;
        if (v < -250) {
          HapticFeedback.lightImpact();
          widget.audioHandler.skipToNext();
        } else if (v > 250) {
          HapticFeedback.lightImpact();
          widget.audioHandler.skipToPrevious();
        }
      },
      // Full size while playing, gently receded while paused.
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.88,
        duration: _rest,
        curve: _kEmph,
        child: AnimatedBuilder(
          animation: _curve,
          child: SizedBox(
            width: artSize,
            height: artSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [glow, Positioned.fill(child: artwork)],
            ),
          ),
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -7 * _curve.value),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Playback controls
// ─────────────────────────────────────────────────────────────────────────────

class _PlaybackControlsRow extends StatelessWidget {
  final dynamic audioHandler;
  final bool isQueueOpen;
  final VoidCallback onToggleQueue;

  const _PlaybackControlsRow({
    required this.audioHandler,
    required this.isQueueOpen,
    required this.onToggleQueue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeToggleColor = _toggleAccent(isDark);
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.50)
        : const Color(0xFF8A8E9C);

    Widget toggleSlot({required Widget icon, required bool active}) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            icon,
            Positioned(
              bottom: 5,
              child: AnimatedScale(
                scale: active ? 1.0 : 0.0,
                duration: _kState,
                curve: _kEmph,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeToggleColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. Shuffle / repeat toggle
        Consumer(
          builder: (context, ref, _) {
            final isShuffle = ref.watch(playerStateStreamProvider.select((s) => s.value?.isShuffleEnabled ?? false));
            final repeatMode = ref.watch(playerStateStreamProvider.select((s) => s.value?.repeatMode ?? AppRepeatMode.off));

            final IconData modeIcon;
            final String modeLabel;
            final bool isActive;

            if (isShuffle) {
              modeIcon = Icons.shuffle_rounded;
              modeLabel = 'Shuffle';
              isActive = true;
            } else if (repeatMode == AppRepeatMode.one) {
              modeIcon = Icons.repeat_one_rounded;
              modeLabel = 'Repeat one';
              isActive = true;
            } else if (repeatMode == AppRepeatMode.all) {
              modeIcon = Icons.repeat_rounded;
              modeLabel = 'Repeat all';
              isActive = true;
            } else {
              modeIcon = Icons.shuffle_rounded;
              modeLabel = 'Shuffle off';
              isActive = false;
            }

            return Tooltip(
              message: modeLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  audioHandler.cyclePlaybackMode();
                },
                child: toggleSlot(
                  active: isActive,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: _kEmph,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: TweenAnimationBuilder<Color?>(
                      key: ValueKey(modeIcon),
                      tween: ColorTween(end: isActive ? activeToggleColor : inactiveColor),
                      duration: _kState,
                      builder: (context, color, _) => Icon(
                        modeIcon,
                        size: 23,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // 2. Previous
        _PlainIconButton(
          icon: Icons.skip_previous_rounded,
          onTap: () => audioHandler.skipToPrevious(),
        ),

        // 3. Large play / pause
        _PlayPauseButton(
          size: 74,
          iconSize: 40,
          audioHandler: audioHandler,
        ),

        // 4. Next
        _PlainIconButton(
          icon: Icons.skip_next_rounded,
          onTap: () => audioHandler.skipToNext(),
        ),

        // 5. Queue toggle
        Tooltip(
          message: 'Queue',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleQueue,
            child: toggleSlot(
              active: isQueueOpen,
              icon: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: isQueueOpen ? activeToggleColor : inactiveColor),
                duration: _kState,
                builder: (context, color, _) => Icon(
                  isQueueOpen ? Icons.queue_music_rounded : Icons.queue_music_outlined,
                  size: 23,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Play / pause button in the neon lime accent. The glyph morphs between
/// play and pause, and the button gives a soft press response.
class _PlayPauseButton extends ConsumerStatefulWidget {
  final double size;
  final double iconSize;
  final dynamic audioHandler;

  const _PlayPauseButton({
    required this.size,
    required this.iconSize,
    required this.audioHandler,
  });

  @override
  ConsumerState<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends ConsumerState<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morph;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    final playing = ref.read(isPlaybackPlayingProvider);
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: playing ? 1.0 : 0.0,
    );
    ref.listenManual<bool>(isPlaybackPlayingProvider, (_, next) {
      if (next) {
        _morph.forward();
      } else {
        _morph.reverse();
      }
    });
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = ref.watch(isPlaybackPlayingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const buttonColor = AppColors.neonLime;
    final highlight = _mix(buttonColor, Colors.white, 0.30);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        if (isPlaying) {
          widget.audioHandler.pause();
        } else {
          widget.audioHandler.play();
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _kEmph,
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [highlight, buttonColor],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: buttonColor.withValues(alpha: isDark ? 0.35 : 0.25),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: _morph.drive(CurveTween(curve: _kEmph)),
            size: widget.iconSize,
            color: const Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lyrics
// ─────────────────────────────────────────────────────────────────────────────

/// Live 3-line sliding lyrics, set directly on the background (no container).
/// Tap (or swipe up) to open the full lyrics sheet.
///
/// All lines share one font size and weight; emphasis comes only from scale
/// and color, so the active line moves without ever re-laying out text.
class _SlidingLyricsWidget extends ConsumerStatefulWidget {
  final dynamic audioHandler;
  final Color primaryColor;
  final VoidCallback onExpand;

  const _SlidingLyricsWidget({
    required this.audioHandler,
    required this.primaryColor,
    required this.onExpand,
  });

  @override
  ConsumerState<_SlidingLyricsWidget> createState() => _SlidingLyricsWidgetState();
}

class _SlidingLyricsWidgetState extends ConsumerState<_SlidingLyricsWidget> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  static const double _lineExtent = 32.0;
  static const double _viewHeight = 96.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveIndex(int index, {bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final targetOffset = (index * _lineExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 460),
        curve: _kEmph,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  Widget _buildUnavailable(bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onExpand();
      },
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 16,
              color: _inkSoft(isDark).withValues(alpha: 0.50),
            ),
            const SizedBox(width: 8),
            Text(
              'Lyrics unavailable',
              style: AppTypography.style(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: _inkSoft(isDark).withValues(alpha: 0.55),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);

    ref.listen<String?>(currentPlayingTrackIdProvider, (previous, next) {
      if (previous != next) {
        _lastActiveIndex = -1;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }
    });

    final Widget body = lyricsAsync.when(
      data: (Lyrics? lyrics) {
        if (lyrics == null || lyrics.isEmpty) {
          return KeyedSubtree(
            key: const ValueKey('unavailable'),
            child: _buildUnavailable(isDark),
          );
        }

        // Selector with O(log n) binary search
        final int activeIndex = ref.watch(
          playerStateStreamProvider.select((s) {
            final pos = s.value?.position ?? Duration.zero;
            if (lyrics.isSynced) {
              return lyrics.findCurrentLineIndex(pos);
            } else {
              final dur = s.value?.duration ?? Duration.zero;
              if (dur.inMilliseconds > 0 && lyrics.lines.isNotEmpty) {
                final progress = pos.inMilliseconds / dur.inMilliseconds;
                return (progress * lyrics.lines.length).floor().clamp(0, lyrics.lines.length - 1);
              }
              return 0;
            }
          }),
        );

        if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
          final isJump = (_lastActiveIndex == -1) || ((activeIndex - _lastActiveIndex).abs() > 2);
          _lastActiveIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToActiveIndex(activeIndex, animate: !isJump);
          });
        }

        const verticalListPadding = (_viewHeight - _lineExtent) / 2;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onExpand();
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -150) {
              HapticFeedback.lightImpact();
              widget.onExpand();
            }
          },
          child: _FadeEdges(
            fraction: 0.28,
            child: ListView.builder(
              controller: _scrollController,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: verticalListPadding),
              itemExtent: _lineExtent,
              itemCount: lyrics.lines.length,
              itemBuilder: (context, index) {
                final line = lyrics.lines[index];
                final isActive = index == activeIndex;

                return Center(
                  child: AnimatedScale(
                    scale: isActive ? 1.0 : 0.9,
                    duration: _kState,
                    curve: _kEmph,
                    child: AnimatedDefaultTextStyle(
                      duration: _kState,
                      curve: _kEmph,
                      // Only color animates here, so this is repaint-only.
                      style: AppTypography.style(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? _ink(isDark)
                            : _inkSoft(isDark).withValues(alpha: 0.40),
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                      child: Text(
                        line.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PulseDotsIndicator(
              size: 5.5,
              spacing: 4.0,
              color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
            ),
            const SizedBox(width: 9),
            Text(
              'Loading lyrics...',
              style: AppTypography.style(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _inkSoft(isDark).withValues(alpha: 0.65),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
      error: (_, _) => _buildUnavailable(isDark),
    );

    return SizedBox(
      width: double.infinity,
      height: _viewHeight,
      child: body,
    );
  }
}

/// Full synchronized lyrics scroll view. The active line is emphasised by
/// scale and color only: no highlight box behind it.
class _FullLyricsScrollView extends ConsumerStatefulWidget {
  final Lyrics lyrics;
  final dynamic audioHandler;
  final Color primaryColor;

  const _FullLyricsScrollView({
    required this.lyrics,
    required this.audioHandler,
    required this.primaryColor,
  });

  @override
  ConsumerState<_FullLyricsScrollView> createState() => _FullLyricsScrollViewState();
}

class _FullLyricsScrollViewState extends ConsumerState<_FullLyricsScrollView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollTimer;

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (_userIsScrolling) return;
    final key = _lineKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.35,
        duration: animate ? const Duration(milliseconds: 520) : Duration.zero,
        curve: _kEmph,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final toggle = _toggleAccent(isDark);

    // Selector with O(log n) binary search
    final int activeIndex = ref.watch(
      playerStateStreamProvider.select((s) {
        final pos = s.value?.position ?? Duration.zero;
        if (widget.lyrics.isSynced) {
          return widget.lyrics.findCurrentLineIndex(pos);
        } else {
          final dur = s.value?.duration ?? Duration.zero;
          if (dur.inMilliseconds > 0 && widget.lyrics.lines.isNotEmpty) {
            final progress = pos.inMilliseconds / dur.inMilliseconds;
            return (progress * widget.lyrics.lines.length).floor().clamp(0, widget.lyrics.lines.length - 1);
          }
          return 0;
        }
      }),
    );

    if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
      final isJump = (_lastActiveIndex == -1);
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(activeIndex, animate: !isJump);
      });
    }

    final dimColor = isDark
        ? Colors.white.withValues(alpha: 0.34)
        : Colors.black.withValues(alpha: 0.36);

    return Stack(
      children: [
        _FadeEdges(
          fraction: 0.06,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction != ScrollDirection.idle) {
                _userScrollTimer?.cancel();
                if (!_userIsScrolling) setState(() => _userIsScrolling = true);
              } else {
                _userScrollTimer?.cancel();
                _userScrollTimer = Timer(const Duration(milliseconds: 3500), () {
                  if (mounted) {
                    setState(() => _userIsScrolling = false);
                    _scrollToIndex(activeIndex);
                  }
                });
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 72),
              itemCount: widget.lyrics.lines.length,
              itemBuilder: (context, index) {
                final line = widget.lyrics.lines[index];
                final isActive = index == activeIndex;
                _lineKeys[index] ??= GlobalKey();

                return GestureDetector(
                  key: _lineKeys[index],
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (line.timestamp != Duration.zero) {
                      widget.audioHandler.seek(line.timestamp);
                    }
                    _userIsScrolling = false;
                    _userScrollTimer?.cancel();
                    _scrollToIndex(index);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: AnimatedScale(
                      scale: isActive ? 1.0 : 0.92,
                      alignment: Alignment.centerLeft,
                      duration: _kState,
                      curve: _kEmph,
                      child: AnimatedDefaultTextStyle(
                        duration: _kState,
                        curve: _kEmph,
                        // Constant size/weight: only color changes, so lines
                        // never reflow while the highlight moves.
                        style: AppTypography.style(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isActive ? _ink(isDark) : dimColor,
                          height: 1.3,
                          letterSpacing: -0.4,
                        ),
                        child: Text(
                          line.text,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // "Back to current line": plain text action, no pill or border.
        Positioned(
          bottom: 14,
          left: 0,
          right: 0,
          child: Center(
            child: IgnorePointer(
              ignoring: !_userIsScrolling,
              child: AnimatedSlide(
                offset: _userIsScrolling ? Offset.zero : const Offset(0, 0.5),
                duration: _kState,
                curve: _kEmph,
                child: AnimatedOpacity(
                  opacity: _userIsScrolling ? 1 : 0,
                  duration: _kState,
                  curve: _kEmph,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _userIsScrolling = false);
                      _userScrollTimer?.cancel();
                      _scrollToIndex(activeIndex);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_rounded, size: 16, color: toggle),
                          const SizedBox(width: 6),
                          Text(
                            'Back to current line',
                            style: AppTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: toggle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seek bar (ORIGINAL, unchanged)
// ─────────────────────────────────────────────────────────────────────────────

/// Isolated High-Performance Seek Bar Consumer
class _IsolatedPlayerSeekBar extends ConsumerWidget {
  const _IsolatedPlayerSeekBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerStateStreamProvider.select((s) => s.value?.position ?? Duration.zero));
    final duration = ref.watch(playerStateStreamProvider.select((s) => s.value?.duration ?? Duration.zero));
    final audioHandler = ref.read(audioHandlerProvider);

    return CustomSeekBar(
      position: position,
      duration: duration,
      onSeek: (pos) => audioHandler.seek(pos),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background
// ─────────────────────────────────────────────────────────────────────────────

/// Atmospheric palette background shared by the player and both sheets.
///
/// The artwork color is strongest at the top and dissolves into the neutral
/// base before the title. When a sheet opens, [calm] (the sheet's own
/// animation) drains the tint and fades the drifting blobs, so sheet text
/// always sits on a quiet, predictable surface, in perfect step with the
/// sheet motion.
///
/// Two soft blobs slowly orbit behind the artwork while music plays. Heavy
/// layers are only mounted once [settled], and they fade in rather than pop.
class _AmbientPaletteBackground extends ConsumerStatefulWidget {
  final Color backgroundColor;
  final bool isDark;
  final bool settled;
  final Animation<double> calm;

  const _AmbientPaletteBackground({
    required this.backgroundColor,
    required this.isDark,
    required this.calm,
    this.settled = true,
  });

  @override
  ConsumerState<_AmbientPaletteBackground> createState() => _AmbientPaletteBackgroundState();
}

class _AmbientPaletteBackgroundState extends ConsumerState<_AmbientPaletteBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(vsync: this, duration: const Duration(seconds: 18));
    if (widget.settled && ref.read(isPlaybackPlayingProvider)) _drift.repeat();
    ref.listenManual<bool>(isPlaybackPlayingProvider, (_, playing) {
      if (widget.settled) {
        if (playing) {
          _drift.repeat();
        } else {
          _drift.stop();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AmbientPaletteBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settled != oldWidget.settled) {
      if (widget.settled && ref.read(isPlaybackPlayingProvider)) {
        if (!_drift.isAnimating) _drift.repeat();
      } else if (!widget.settled) {
        _drift.stop();
      }
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final baseColor = isDark ? _kBaseDark : _kBaseLight;
    final backgroundColor = widget.backgroundColor;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: widget.calm,
        builder: (context, _) {
          final calm = widget.calm.value.clamp(0.0, 1.0);
          final tinted = _mix(backgroundColor, baseColor, 0.72 * calm);

          final staticBase = DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.36, 0.64, 0.88],
                colors: [
                  tinted,
                  _mix(tinted, baseColor, 0.42),
                  _mix(tinted, baseColor, 0.84),
                  baseColor,
                ],
              ),
            ),
          );

          if (!widget.settled) {
            return staticBase;
          }

          // Analogous companion color for the second blob
          final hsl = HSLColor.fromColor(backgroundColor);
          final companion = hsl.withHue((hsl.hue + 38) % 360).toColor();
          final blobA = _mix(backgroundColor, Colors.white, isDark ? 0.18 : 0.30)
              .withValues(alpha: isDark ? 0.34 : 0.40);
          final blobB = companion.withValues(alpha: isDark ? 0.26 : 0.30);

          final blobAWidget = RepaintBoundary(
            child: SizedBox(
              width: 500,
              height: 500,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [blobA, blobA.withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),
          );

          final blobBWidget = RepaintBoundary(
            child: SizedBox(
              width: 440,
              height: 440,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [blobB, blobB.withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),
          );

          final living = Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _drift,
                builder: (context, _) {
                  final a = _drift.value * 2 * math.pi;
                  final dxA = 100.0 * math.sin(a);
                  final dyA = -150.0 + 35.0 * math.cos(a);
                  final dxB = -110.0 * math.cos(a);
                  final dyB = -40.0 + 45.0 * math.sin(a);
                  return Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(dxA, dyA),
                        child: blobAWidget,
                      ),
                      Transform.translate(
                        offset: Offset(dxB, dyB),
                        child: blobBWidget,
                      ),
                    ],
                  );
                },
              ),
              // Soft bloom behind the artwork
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 0.85,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.06 : 0.18),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              staticBase,
              // Fades in once on mount, and out as a sheet calms the page.
              Opacity(
                opacity: 1.0 - calm,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  builder: (context, v, child) => Opacity(opacity: v, child: child),
                  child: living,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}