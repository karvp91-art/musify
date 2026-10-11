import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/screens/playlist/playlist_detail_screen.dart';
import 'package:musify/presentation/widgets/floating_mini_player.dart';
import 'package:musify/presentation/widgets/loading_indicators.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/services/playlist_import_service.dart';

/// Opens the Import Playlist Screen with native iOS slide navigation.
Future<void> openImportPlaylistScreen(BuildContext context) {
  HapticFeedback.selectionClick();
  return Navigator.of(context).push<void>(
    CupertinoPageRoute(
      builder: (_) => const ImportPlaylistScreen(),
    ),
  );
}

/// Circular header button matching the top app bar actions in studio_equalizer_screen.dart
class _CircleHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  const _CircleHeaderButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor =
        isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E2028);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: defaultIconColor,
        ),
      ),
    );
  }
}

class _PlatformOption {
  final String id;
  final String label;
  final IconData icon;
  final String placeholder;
  final String hint;

  const _PlatformOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.placeholder,
    required this.hint,
  });
}

const List<_PlatformOption> _platforms = [
  _PlatformOption(
    id: 'auto',
    label: 'Auto Detect',
    icon: Icons.auto_awesome_rounded,
    placeholder: 'Paste playlist link or URL...',
    hint: 'Automatically identifies Spotify, YouTube, or JioSaavn',
  ),
  _PlatformOption(
    id: 'spotify',
    label: 'Spotify',
    icon: Icons.album_rounded,
    placeholder: 'https://open.spotify.com/playlist/...',
    hint: 'Extracts full tracklists via Spotify embed engine',
  ),
  _PlatformOption(
    id: 'youtube',
    label: 'YouTube',
    icon: Icons.play_circle_fill_rounded,
    placeholder: 'https://youtube.com/playlist?list=...',
    hint: 'Converts YouTube & YouTube Music playlist links',
  ),
  _PlatformOption(
    id: 'jiosaavn',
    label: 'JioSaavn',
    icon: Icons.radio_rounded,
    placeholder: 'https://jiosaavn.com/featured/... or playlist ID',
    hint: 'Direct 320kbps JioSaavn native playlist imports',
  ),
];

class ImportPlaylistScreen extends ConsumerStatefulWidget {
  final String? initialUrl;

  const ImportPlaylistScreen({super.key, this.initialUrl});

  @override
  ConsumerState<ImportPlaylistScreen> createState() => _ImportPlaylistScreenState();
}

class _ImportPlaylistScreenState extends ConsumerState<ImportPlaylistScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  late final TextEditingController _playlistNameController;

  String _selectedPlatform = 'auto';
  bool _isExtracting = false;
  bool _isResolving = false;
  bool _isSaving = false;
  String? _errorMessage;

  ExternalPlaylistResult? _playlistResult;
  int _matchedCount = 0;
  int _totalCount = 0;
  String _currentResolvingTrack = '';

  @override
  void initState() {
    super.initState();
    _playlistNameController = TextEditingController();
    _urlController.addListener(_onUrlChanged);

    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      _updatePlatformFromUrl(widget.initialUrl!);
    }
  }

  void _onUrlChanged() {
    if (!mounted) return;
    final text = _urlController.text.trim();
    if (text.isNotEmpty && _selectedPlatform == 'auto') {
      _updatePlatformFromUrl(text);
    }
    setState(() {});
  }

  void _updatePlatformFromUrl(String url) {
    final detected = PlaylistImportService.detectPlatform(url);
    if (detected != 'unknown' && detected != _selectedPlatform) {
      setState(() {
        _selectedPlatform = detected;
      });
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _urlFocusNode.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() {
        _urlController.text = text;
        _errorMessage = null;
      });
      _updatePlatformFromUrl(text);
      AppSnackBar.show(
        context,
        message: 'Link pasted from clipboard',
        type: AppSnackBarType.info,
        icon: Icons.content_paste_rounded,
      );
    }
  }

  void _showMoreMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.content_paste_rounded),
                  title: Text(
                    'Paste from Clipboard',
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop();
                    _pasteFromClipboard();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.clear_all_rounded),
                  title: Text(
                    'Clear Input & Reset',
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop();
                    setState(() {
                      _urlController.clear();
                      _errorMessage = null;
                      _playlistResult = null;
                      _matchedCount = 0;
                      _totalCount = 0;
                      _selectedPlatform = 'auto';
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: Text(
                    'Supported Link Formats',
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Spotify playlists, YouTube playlists/mixes, JioSaavn URLs & IDs',
                    style: AppTypography.caption.copyWith(color: isDark ? Colors.white54 : Colors.black54),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _analyzeAndExtract() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please paste a playlist URL or ID.');
      return;
    }

    _urlFocusNode.unfocus();
    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _playlistResult = null;
      _matchedCount = 0;
      _totalCount = 0;
    });

    HapticFeedback.mediumImpact();

    try {
      final importer = ref.read(playlistImportServiceProvider);

      // Extract tracks from external source
      final result = await importer.extractPlaylistFromUrl(url);

      if (!mounted) return;
      setState(() {
        _playlistResult = result;
        _playlistNameController.text = result.title;
        _isExtracting = false;
        _isResolving = true;
        _totalCount = result.tracks.length;
        _matchedCount = 0;
        _selectedPlatform = result.platform;
      });

      // Stream matching against native catalogs (JioSaavn 320k first, YouTube fallback)
      await for (final progress in importer.resolveTracksStream(result.tracks)) {
        if (!mounted) return;
        setState(() {
          _matchedCount = progress.current;
          _currentResolvingTrack = progress.item.title;
        });
      }

      if (!mounted) return;
      setState(() {
        _isResolving = false;
      });

      AppSnackBar.show(
        context,
        message: 'Loaded ${result.tracks.length} tracks from ${result.platform.toUpperCase()}',
        type: AppSnackBarType.success,
        icon: Icons.check_circle_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _isResolving = false;
        _errorMessage = e is FormatException ? e.message : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _savePlaylist() async {
    if (_playlistResult == null || _isSaving) return;

    final selectedItems = _playlistResult!.tracks.where((t) => t.isSelected && t.resolvedTrack != null).toList();
    if (selectedItems.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Please select at least one matched song to create playlist.',
        type: AppSnackBarType.warning,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    final name = _playlistNameController.text.trim();
    if (name.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Please give your playlist a name.',
        type: AppSnackBarType.warning,
        icon: Icons.title_rounded,
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final importer = ref.read(playlistImportServiceProvider);
      final tracks = selectedItems.map((e) => e.resolvedTrack!).toList();

      final createdPlaylist = await importer.saveAsInAppPlaylist(
        name: name,
        description: 'Imported from ${_playlistResult!.platform.toUpperCase()}',
        tracks: tracks,
      );

      ref.invalidate(playlistsStreamProvider);

      if (!mounted) return;
      setState(() => _isSaving = false);

      AppSnackBar.show(
        context,
        message: 'Created "$name" with ${tracks.length} songs',
        type: AppSnackBarType.success,
        icon: Icons.playlist_add_check_rounded,
      );

      // Navigate directly into the newly created playlist
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (_) => PlaylistDetailScreen(
            title: createdPlaylist.name,
            subtitle: createdPlaylist.description,
            playlist: createdPlaylist,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackBar.show(
        context,
        message: 'Failed to create playlist: $e',
        type: AppSnackBarType.error,
        icon: Icons.error_outline_rounded,
      );
    }
  }

  void _toggleSelectAll(bool selectAll) {
    HapticFeedback.selectionClick();
    if (_playlistResult == null) return;
    setState(() {
      for (final track in _playlistResult!.tracks) {
        if (track.resolvedTrack != null) {
          track.isSelected = selectAll;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);
    final activeGreenColor = isDark ? AppColors.neonLime : const Color(0xFF3E8016);
    final cardBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);

    final selectedCount = _playlistResult?.tracks.where((t) => t.isSelected && t.resolvedTrack != null).length ?? 0;
    final totalMatched = _playlistResult?.tracks.where((t) => t.resolvedTrack != null).length ?? 0;

    final currentOption = _platforms.firstWhere(
      (p) => p.id == _selectedPlatform,
      orElse: () => _platforms.first,
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top App Bar matching studio_equalizer_screen.dart
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _CircleHeaderButton(
                        icon: Icons.chevron_left_rounded,
                        iconSize: 26,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Import Playlist',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      _CircleHeaderButton(
                        icon: Icons.more_vert_rounded,
                        iconSize: 22,
                        onTap: () => _showMoreMenu(context),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content sitting directly on open canvas
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // 1. Open Canvas Header & Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Import External Playlist',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Convert Spotify, YouTube & JioSaavn playlists into in-app playlists',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // 2. Platforms Selection Row (Exact Studio Equalizer Presets Row Pattern)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Text(
                              'Platforms',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Auto-detects link',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: activeGreenColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Horizontal Platform Squircle Row (58x58 with 18px radius)
                      SizedBox(
                        height: 94,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          itemCount: _platforms.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final platform = _platforms[index];
                            final isSelected = _selectedPlatform == platform.id;

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedPlatform = platform.id;
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.neonLime
                                          : (isDark
                                              ? const Color(0xFF20222B)
                                              : const Color(0xFFF3F4F6)),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      platform.icon,
                                      size: 26,
                                      color: isSelected
                                          ? Colors.black
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF1E2028)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    platform.label,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 3. Link Input Section Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Playlist Link or ID',
                              style: AppTypography.headlineSmall.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentOption.hint,
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Input Box Card (styled after _CircleHeaderButton & _AudioEffectCard)
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            // Squircle icon badge (44x44, radius 13)
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.neonLime.withValues(alpha: 0.18)
                                    : const Color(0xFFEFFCC8),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.link_rounded,
                                size: 22,
                                color: activeGreenColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _urlController,
                                focusNode: _urlFocusNode,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: currentOption.placeholder,
                                  hintStyle: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _analyzeAndExtract(),
                              ),
                            ),
                            if (_urlController.text.isNotEmpty)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _urlController.clear();
                                  setState(() => _errorMessage = null);
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? Colors.white12 : Colors.black12,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              )
                            else
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _pasteFromClipboard,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.neonLime.withValues(alpha: 0.18)
                                        : const Color(0xFFEFFCC8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'PASTE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: activeGreenColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Validation Error Message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.redAccent,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // 4. Primary "Fetch & Match Songs" Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.neonLime,
                            foregroundColor: const Color(0xFF111827),
                            elevation: 3,
                            shadowColor: AppColors.neonLime.withValues(alpha: 0.45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          onPressed: _isExtracting || _isResolving ? null : _analyzeAndExtract,
                          child: _isExtracting
                              ? const PulseDotsIndicator(
                                  size: 8,
                                  spacing: 5,
                                  color: Color(0xFF111827),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.cloud_download_rounded,
                                      size: 20,
                                      color: Color(0xFF111827),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Fetch & Match Songs',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      // 5. Resolving Progress Card
                      if (_isResolving) ...[
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Resolving Audio Streams',
                                    style: AppTypography.headlineSmall.copyWith(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$_matchedCount / $_totalCount',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: activeGreenColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _totalCount > 0 ? _matchedCount / _totalCount : null,
                                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                  valueColor: AlwaysStoppedAnimation<Color>(activeGreenColor),
                                  minHeight: 6,
                                ),
                              ),
                              if (_currentResolvingTrack.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Matching: $_currentResolvingTrack',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // 6. Extracted Playlist Preview & Tracks
                      if (_playlistResult != null) ...[
                        const SizedBox(height: 28),

                        // Section Header: Playlist Info
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Playlist Details',
                                style: AppTypography.headlineSmall.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Edit playlist name and preview matched songs',
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Playlist Meta Card (Open Canvas Card matching studio equalizer)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              // Squircle emblem badge (44x44, radius 13)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: _playlistResult!.artworkUrl != null
                                      ? TrackArtwork(
                                          artworkUrl: _playlistResult!.artworkUrl,
                                          size: 48,
                                          borderRadius: BorderRadius.circular(13),
                                        )
                                      : Container(
                                          color: isDark
                                              ? AppColors.neonLime.withValues(alpha: 0.18)
                                              : const Color(0xFFEFFCC8),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.queue_music_rounded,
                                            size: 24,
                                            color: activeGreenColor,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _playlistNameController,
                                      style: AppTypography.headlineSmall.copyWith(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: 'Playlist name',
                                        hintStyle: TextStyle(
                                          color: textMuted,
                                          fontSize: 16.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: activeGreenColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _playlistResult!.platform.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: activeGreenColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$totalMatched of ${_playlistResult!.tracks.length} matched',
                                          style: AppTypography.caption.copyWith(
                                            fontSize: 11.5,
                                            color: textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Section Header: Matched Tracks
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Text(
                                'Matched Songs ($selectedCount)',
                                style: AppTypography.headlineSmall.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _toggleSelectAll(selectedCount < totalMatched),
                                child: Text(
                                  selectedCount < totalMatched ? 'Select All' : 'Deselect All',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: activeGreenColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Track Items sitting on open canvas following _AudioEffectCard pattern
                        ...List.generate(_playlistResult!.tracks.length, (index) {
                          final item = _playlistResult!.tracks[index];
                          final isMatched = item.resolvedTrack != null;

                          return _TrackImportRow(
                            item: item,
                            isDark: isDark,
                            onToggle: isMatched
                                ? () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      item.isSelected = !item.isSelected;
                                    });
                                  }
                                : null,
                          );
                        }),

                        const SizedBox(height: 24),

                        // Create In-App Playlist Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (selectedCount == 0 || _isSaving)
                                  ? (isDark ? const Color(0xFF262933) : const Color(0xFFE2E4E9))
                                  : AppColors.neonLime,
                              foregroundColor: const Color(0xFF111827),
                              elevation: selectedCount > 0 ? 3 : 0,
                              shadowColor: AppColors.neonLime.withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: (selectedCount == 0 || _isSaving) ? null : _savePlaylist,
                            child: _isSaving
                                ? const PulseDotsIndicator(
                                    size: 8,
                                    spacing: 5,
                                    color: Color(0xFF111827),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.playlist_add_check_rounded,
                                        size: 22,
                                        color: Color(0xFF111827),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Create Musify Playlist ($selectedCount tracks)',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],

                      // Bottom padding for mini-player
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),

            // Universal Floating Mini Player
            const FloatingMiniPlayer(),
          ],
        ),
      ),
    );
  }
}

/// Track Item row on open canvas following the _AudioEffectCard pattern of studio_equalizer_screen.dart
class _TrackImportRow extends StatelessWidget {
  final ExternalTrackItem item;
  final bool isDark;
  final VoidCallback? onToggle;

  const _TrackImportRow({
    required this.item,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);
    final isMatched = item.resolvedTrack != null;

    final iconBg = isDark
        ? AppColors.neonLime.withValues(alpha: 0.18)
        : const Color(0xFFEFFCC8);
    final activeGreenColor = isDark ? AppColors.neonLime : const Color(0xFF3E8016);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          // Squircle Artwork or Icon Badge (44x44, radius 13)
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 44,
              height: 44,
              child: item.artworkUrl != null || item.resolvedTrack?.artworkUrl != null
                  ? TrackArtwork(
                      artworkUrl: item.resolvedTrack?.artworkUrl ?? item.artworkUrl,
                      size: 44,
                      borderRadius: BorderRadius.circular(13),
                    )
                  : Container(
                      color: iconBg,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 22,
                        color: activeGreenColor,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 14),

          // Title & Subtitle matching _AudioEffectCard
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.resolvedTrack?.title ?? item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: isMatched
                        ? theme.colorScheme.onSurface
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.resolvedTrack?.artistName ?? item.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ),
                    if (isMatched) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: item.resolvedTrack?.source == AudioSourceType.saavn
                              ? const Color(0xFF2BC5B4).withValues(alpha: 0.18)
                              : const Color(0xFFFF0000).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.resolvedTrack?.source == AudioSourceType.saavn
                              ? '320k Studio'
                              : 'YouTube',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: item.resolvedTrack?.source == AudioSourceType.saavn
                                ? const Color(0xFF2BC5B4)
                                : const Color(0xFFFF0000),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Trailing Switch toggle matching studio_equalizer_screen.dart
          if (isMatched)
            Switch(
              value: item.isSelected,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.neonLime,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: isDark
                  ? const Color(0xFF2C2F3D)
                  : const Color(0xFFD6D9E0),
              trackOutlineColor:
                  WidgetStateProperty.all(Colors.transparent),
              onChanged: (_) {
                HapticFeedback.selectionClick();
                onToggle?.call();
              },
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'No Match',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent.shade100,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
