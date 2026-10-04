import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';
import 'package:musify/presentation/widgets/track_artwork.dart';
import 'package:musify/presentation/widgets/app_confirmation_dialog.dart';
import 'package:musify/services/ringtone_service.dart';

class RingtoneEditorScreen extends ConsumerStatefulWidget {
  final Track track;
  final String? localFilePath;

  const RingtoneEditorScreen({
    super.key,
    required this.track,
    this.localFilePath,
  });

  @override
  ConsumerState<RingtoneEditorScreen> createState() => _RingtoneEditorScreenState();
}

class _RingtoneEditorScreenState extends ConsumerState<RingtoneEditorScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _workingFilePath;
  bool _isLoadingFile = true;
  double _downloadProgress = 0.0;
  bool _isProcessingAction = false;

  // Trimming bounds in milliseconds
  double _totalDurationMs = 180000.0; // default 3 min fallback
  double _startMs = 0.0;
  double _endMs = 30000.0; // default 30s ringtone
  double _currentPlaybackMs = 0.0;
  bool _isPlaying = false;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;

  // Waveform heights
  late final List<double> _waveformHeights;

  @override
  void initState() {
    super.initState();
    ref.read(audioHandlerProvider).pause();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioHandlerProvider).pause();
    });
    _generateWaveform();
    _prepareAudioFile();
  }

  void _generateWaveform() {
    final random = Random(widget.track.title.hashCode ^ widget.track.artistName.hashCode);
    _waveformHeights = List.generate(48, (index) {
      final base = sin(index / 7.0).abs() * 0.6 + 0.3;
      final noise = (random.nextDouble() - 0.5) * 0.3;
      return (base + noise).clamp(0.2, 1.0);
    });
  }

  void _prepareAudioFile() async {
    setState(() => _isLoadingFile = true);

    try {
      // 1. Check if passed or track has direct local file path
      if (widget.localFilePath != null && File(widget.localFilePath!).existsSync()) {
        _workingFilePath = widget.localFilePath;
      } else if (widget.track.filePath != null && File(widget.track.filePath!).existsSync()) {
        _workingFilePath = widget.track.filePath;
      } else if (widget.track.audioUrl.isNotEmpty && widget.track.audioUrl.startsWith('/')) {
        _workingFilePath = widget.track.audioUrl;
      } else {
        // Download remote track audio to temp file for trimming
        final dir = await getTemporaryDirectory();
        final tempFile = File('${dir.path}/ringtone_temp_${widget.track.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.mp3');

        if (!tempFile.existsSync() || tempFile.lengthSync() < 1000) {
          final dio = Dio();
          await dio.download(
            widget.track.audioUrl,
            tempFile.path,
            onReceiveProgress: (received, total) {
              if (total > 0 && mounted) {
                setState(() => _downloadProgress = received / total);
              }
            },
          );
        }
        _workingFilePath = tempFile.path;
      }

      // Initialize player with file
      if (_workingFilePath != null) {
        await _player.setFilePath(_workingFilePath!);
        final duration = _player.duration;
        if (duration != null && duration.inMilliseconds > 0) {
          _totalDurationMs = duration.inMilliseconds.toDouble();
          _endMs = min(_totalDurationMs, 30000.0);
        }

        _positionSub = _player.positionStream.listen((pos) {
          if (!mounted) return;
          final currentMs = pos.inMilliseconds.toDouble();
          setState(() => _currentPlaybackMs = currentMs);

          // If reached end of trimmed zone, loop back to start
          if (currentMs >= _endMs) {
            _player.seek(Duration(milliseconds: _startMs.toInt()));
          }
        });

        _playerStateSub = _player.playerStateStream.listen((state) {
          if (!mounted) return;
          setState(() => _isPlaying = state.playing);
        });
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Unable to load audio file for ringtone editing',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFile = false);
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _togglePreviewPlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      HapticFeedback.selectionClick();
      ref.read(audioHandlerProvider).pause();
      await _player.seek(Duration(milliseconds: _startMs.toInt()));
      await _player.play();
    }
  }

  void _nudgeStart(double deltaMs) {
    HapticFeedback.selectionClick();
    setState(() {
      _startMs = (_startMs + deltaMs).clamp(0.0, _endMs - 1000.0);
    });
    if (_isPlaying) {
      _player.seek(Duration(milliseconds: _startMs.toInt()));
    }
  }

  void _nudgeEnd(double deltaMs) {
    HapticFeedback.selectionClick();
    setState(() {
      _endMs = (_endMs + deltaMs).clamp(_startMs + 1000.0, _totalDurationMs);
    });
  }

  String _formatTime(double ms) {
    final totalSec = (ms / 1000).floor();
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;
    final fraction = ((ms % 1000) / 100).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$fraction';
  }

  Future<String?> _trimAudioFile() async {
    if (_workingFilePath == null) return null;

    final outputPath = await RingtoneService.getSuggestedOutputPath(
      widget.track.title,
      extension: _workingFilePath!.endsWith('.m4a') ? 'm4a' : 'mp3',
    );

    return await RingtoneService.trimAudio(
      inputPath: _workingFilePath!,
      outputPath: outputPath,
      startMs: _startMs.toInt(),
      endMs: _endMs.toInt(),
    );
  }

  void _handleSetRingtone(RingtoneType type) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    HapticFeedback.mediumImpact();

    // Pause preview playback
    if (_isPlaying) {
      await _player.pause();
    }

    try {
      final trimmedPath = await _trimAudioFile();
      if (trimmedPath == null) {
        if (mounted) {
          showSnackBar(context, 'Failed to trim ringtone segment', type: AppSnackBarType.error);
        }
        return;
      }

      final result = await RingtoneService.setRingtone(
        filePath: trimmedPath,
        title: '${widget.track.title} Ringtone',
        type: type,
      );

      if (result['needPermission'] == true) {
        if (mounted) {
          final confirm = await showAppConfirmationDialog(
            context: context,
            title: 'Permission Required',
            description: 'Android requires "Modify System Settings" permission to set phone ringtones. Tap Open Settings to grant it.',
            confirmText: 'Open Settings',
            cancelText: 'Cancel',
            icon: Icons.settings_suggest_rounded,
          );
          if (confirm == true) {
            await RingtoneService.openWriteSettings();
          }
        }
      } else if (result['success'] == true) {
        if (mounted) {
          showSnackBar(
            context,
            'Successfully set as ${type.label}!',
            type: AppSnackBarType.success,
          );
        }
      } else {
        if (mounted) {
          showSnackBar(context, 'Could not set ringtone: ${result['error'] ?? 'Unknown error'}', type: AppSnackBarType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error processing ringtone: $e', type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  void _handleSaveFile() async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    HapticFeedback.mediumImpact();

    try {
      final trimmedPath = await _trimAudioFile();
      if (trimmedPath != null && mounted) {
        showSnackBar(
          context,
          'Saved to: ${File(trimmedPath).path}',
          type: AppSnackBarType.success,
        );
      } else if (mounted) {
        showSnackBar(context, 'Failed to save trimmed audio file', type: AppSnackBarType.error);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error saving ringtone: $e', type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);
    final durationSec = (_endMs - _startMs) / 1000.0;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with _CircleHeaderButton
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
                        'Ringtone Studio',
                        style: AppTypography.headlineSmall.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  _CircleHeaderButton(
                    icon: Icons.save_alt_rounded,
                    iconSize: 22,
                    onTap: _handleSaveFile,
                  ),
                ],
              ),
            ),

            // Main Body Content
            Expanded(
              child: _isLoadingFile
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _downloadProgress > 0
                                ? 'Preparing audio: ${(_downloadProgress * 100).toInt()}%'
                                : 'Loading audio stream...',
                            style: AppTypography.bodySmall.copyWith(color: textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        // 1. Hero Track Overview (Clean, open, borderless)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: TrackArtwork(
                                  artworkUrl: widget.track.artworkUrl,
                                  size: 52,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.track.title,
                                      style: AppTypography.style(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.track.artistName,
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 12.5,
                                        color: textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.neonLime.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '320 KBPS',
                                  style: AppTypography.style(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.neonLime : const Color(0xFF436900),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 2. Waveform Trimmer Section Header (Open, no closed bordered container)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Waveform Trimmer',
                                    style: AppTypography.headlineSmall.copyWith(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Select audio loop boundaries',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.neonLime,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${durationSec.toStringAsFixed(1)}s Ringtone',
                                  style: AppTypography.style(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // High-Fidelity Waveform Display (Open, borderless canvas)
                        Container(
                          height: 104,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          color: Colors.transparent,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final totalWidth = constraints.maxWidth;
                              final startFrac = (_startMs / _totalDurationMs).clamp(0.0, 1.0);
                              final endFrac = (_endMs / _totalDurationMs).clamp(0.0, 1.0);
                              final playFrac = (_currentPlaybackMs / _totalDurationMs).clamp(0.0, 1.0);

                              return Stack(
                                children: [
                                  // Waveform dynamic bars (Neon Lime inside active trim)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: _waveformHeights.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final hFrac = entry.value;
                                      final barFrac = idx / (_waveformHeights.length - 1);
                                      final isInsideTrim = barFrac >= startFrac && barFrac <= endFrac;

                                      return Container(
                                        width: 3.5,
                                        height: 72 * hFrac,
                                        decoration: BoxDecoration(
                                          color: isInsideTrim
                                              ? AppColors.neonLime
                                              : (isDark ? const Color(0xFF282C38) : const Color(0xFFD1D5DB)),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      );
                                    }).toList(),
                                  ),

                                  // Highlighted active trim box in Neon Lime
                                  Positioned(
                                    left: totalWidth * startFrac,
                                    width: max(4.0, totalWidth * (endFrac - startFrac)),
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.neonLime.withValues(alpha: 0.22),
                                        border: const Border.symmetric(
                                          vertical: BorderSide(
                                            color: AppColors.neonLime,
                                            width: 2.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Playhead needle
                                  if (_isPlaying)
                                    Positioned(
                                      left: totalWidth * playFrac,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 2.5,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Start Slider & Separated Nudges (Zero horizontal overflow)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Start Position',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                  Text(
                                    _formatTime(_startMs),
                                    style: AppTypography.style(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.neonLime : const Color(0xFF436900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              GlassSlider(
                                value: _startMs.clamp(0.0, max(0.0, _endMs - 1000.0)),
                                min: 0.0,
                                max: max(1000.0, _endMs - 1000.0),
                                activeColor: AppColors.neonLime,
                                thumbColor: AppColors.neonLime,
                                inactiveColor: isDark ? const Color(0xFF282B38) : const Color(0xFFE5E7EB),
                                glowColor: AppColors.neonLime.withValues(alpha: 0.5),
                                glowRadius: 2.0,
                                trackHeight: 4.5,
                                thumbRadius: 9.5,
                                useOwnLayer: true,
                                onChangeStart: (_) => HapticFeedback.selectionClick(),
                                onChanged: (val) {
                                  setState(() => _startMs = val);
                                  if (_isPlaying) {
                                    _player.seek(Duration(milliseconds: val.toInt()));
                                  }
                                },
                              ),
                              const SizedBox(height: 4),
                              // Start Nudge row (fits easily without overflowing)
                              Row(
                                children: [
                                  Text(
                                    'Adjust Start: ',
                                    style: AppTypography.caption.copyWith(fontSize: 11, color: textMuted),
                                  ),
                                  const SizedBox(width: 4),
                                  _NudgeButton(label: '-1s', isDark: isDark, onTap: () => _nudgeStart(-1000)),
                                  const SizedBox(width: 4),
                                  _NudgeButton(label: '-0.1s', isDark: isDark, onTap: () => _nudgeStart(-100)),
                                  const SizedBox(width: 4),
                                  _NudgeButton(label: '+0.1s', isDark: isDark, onTap: () => _nudgeStart(100)),
                                  const SizedBox(width: 4),
                                  _NudgeButton(label: '+1s', isDark: isDark, onTap: () => _nudgeStart(1000)),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // End Slider & Separated Nudges (Zero horizontal overflow)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'End Position',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                  Text(
                                    _formatTime(_endMs),
                                    style: AppTypography.style(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.neonLime : const Color(0xFF436900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              GlassSlider(
                                value: _endMs.clamp(min(_totalDurationMs, _startMs + 1000.0), _totalDurationMs),
                                min: min(_totalDurationMs, _startMs + 1000.0),
                                max: _totalDurationMs,
                                activeColor: AppColors.neonLime,
                                thumbColor: AppColors.neonLime,
                                inactiveColor: isDark ? const Color(0xFF282B38) : const Color(0xFFE5E7EB),
                                glowColor: AppColors.neonLime.withValues(alpha: 0.5),
                                glowRadius: 2.0,
                                trackHeight: 4.5,
                                thumbRadius: 9.5,
                                useOwnLayer: true,
                                onChangeStart: (_) => HapticFeedback.selectionClick(),
                                onChanged: (val) {
                                  setState(() => _endMs = val);
                                },
                              ),
                              const SizedBox(height: 4),
                              // End Nudge row (fits easily without overflowing)
                              Row(
                                children: [
                                  Text(
                                    'Adjust End:   ',
                                    style: AppTypography.caption.copyWith(fontSize: 11, color: textMuted),
                                  ),
                                  const SizedBox(width: 4),
                                  _NudgeButton(label: '-1s', isDark: isDark, onTap: () => _nudgeEnd(-1000)),
                                  const SizedBox(width: 4),
                                  _NudgeButton(label: '-0.1s', isDark: isDark, onTap: () => _nudgeEnd(-100)),
                                  const SizedBox(width: 4),
                                  _NudgeButton(label: '+0.1s', isDark: isDark, onTap: () => _nudgeEnd(100)),
                                  const SizedBox(width: 4),
                                  _NudgeButton(label: '+1s', isDark: isDark, onTap: () => _nudgeEnd(1000)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Center Studio Preview Play Button
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _togglePreviewPlay,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.neonLime,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.neonLime.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    size: 36,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isPlaying ? 'Playing Preview Loop' : 'Tap to Preview Loop',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 26),

                        // 3. Loop Presets Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Loop Presets',
                            style: AppTypography.headlineSmall.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Horizontal Presets Row (Sleek capsule pills)
                        SizedBox(
                          height: 42,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            children: [
                              _PresetDurationItem(
                                label: '15s',
                                sublabel: 'Notify',
                                icon: Icons.notifications_active_rounded,
                                isSelected: (durationSec - 15.0).abs() < 0.8,
                                isDark: isDark,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _endMs = min(_startMs + 15000.0, _totalDurationMs);
                                  });
                                },
                              ),
                              const SizedBox(width: 12),
                              _PresetDurationItem(
                                label: '30s',
                                sublabel: 'Standard',
                                icon: Icons.phone_in_talk_rounded,
                                isSelected: (durationSec - 30.0).abs() < 0.8,
                                isDark: isDark,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _endMs = min(_startMs + 30000.0, _totalDurationMs);
                                  });
                                },
                              ),
                              const SizedBox(width: 12),
                              _PresetDurationItem(
                                label: '45s',
                                sublabel: 'Extended',
                                icon: Icons.ring_volume_rounded,
                                isSelected: (durationSec - 45.0).abs() < 0.8,
                                isDark: isDark,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _endMs = min(_startMs + 45000.0, _totalDurationMs);
                                  });
                                },
                              ),
                              const SizedBox(width: 12),
                              _PresetDurationItem(
                                label: '60s',
                                sublabel: 'Alarm',
                                icon: Icons.alarm_rounded,
                                isSelected: (durationSec - 60.0).abs() < 0.8,
                                isDark: isDark,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _endMs = min(_startMs + 60000.0, _totalDurationMs);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 26),

                        // 4. Apply Audio Actions (Clean, borderless studio action tiles)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'APPLY AUDIO',
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: textMuted,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _StudioActionCard(
                          icon: Icons.phone_in_talk_rounded,
                          title: 'Set as Phone Ringtone',
                          subtitle: 'Default incoming calls for SIM 1 & 2',
                          actionLabel: 'Apply',
                          isLoading: _isProcessingAction,
                          isDark: isDark,
                          onTap: () => _handleSetRingtone(RingtoneType.ringtone),
                        ),
                        _StudioActionCard(
                          icon: Icons.notifications_active_rounded,
                          title: 'Set as Notification Sound',
                          subtitle: 'System alerts, messages and chats',
                          actionLabel: 'Apply',
                          isLoading: _isProcessingAction,
                          isDark: isDark,
                          onTap: () => _handleSetRingtone(RingtoneType.notification),
                        ),
                        _StudioActionCard(
                          icon: Icons.alarm_rounded,
                          title: 'Set as Alarm Tone',
                          subtitle: 'Wake up to this audio segment',
                          actionLabel: 'Apply',
                          isLoading: _isProcessingAction,
                          isDark: isDark,
                          onTap: () => _handleSetRingtone(RingtoneType.alarm),
                        ),
                        _StudioActionCard(
                          icon: Icons.file_download_outlined,
                          title: 'Save Trimmed Clip',
                          subtitle: 'Export high-quality file to storage',
                          actionLabel: 'Save',
                          isLoading: _isProcessingAction,
                          isDark: isDark,
                          onTap: _handleSaveFile,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular header button matching StudioEqualizerScreen
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

/// Refined micro nudge chip
class _NudgeButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _NudgeButton({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E202B) : const Color(0xFFECEEF2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTypography.style(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.neonLime : const Color(0xFF436900),
          ),
        ),
      ),
    );
  }
}

/// Preset duration item inspired by horizontal presets in StudioEqualizerScreen (Sleek capsule pill)
class _PresetDurationItem extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PresetDurationItem({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.neonLime
              : (isDark ? const Color(0xFF1E202B) : const Color(0xFFECEEF2)),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF111827)
                  : (isDark ? Colors.white70 : const Color(0xFF1E2028)),
            ),
            const SizedBox(width: 7),
            Text(
              '$label • $sublabel',
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF111827)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Open, borderless studio action tile sitting directly on the scaffold background
class _StudioActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onTap;

  const _StudioActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.isLoading,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);
    final iconBg = isDark
        ? AppColors.neonLime.withValues(alpha: 0.16)
        : AppColors.neonLime.withValues(alpha: 0.22);
    final iconColor = isDark ? AppColors.neonLime : const Color(0xFF3E8016);

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            // Squircle icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 22,
                color: iconColor,
              ),
            ),

            const SizedBox(width: 14),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.headlineSmall.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 12,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Apply / Save Button (Sleek capsule button)
            GestureDetector(
              onTap: isLoading ? null : onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.neonLime,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF111827),
                        ),
                      )
                    : Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
