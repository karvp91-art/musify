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
import 'package:musify/presentation/widgets/loading_indicators.dart';
import 'package:musify/services/ringtone_service.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:musify/data/database/app_database.dart';

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

  // Waveform heights & Real Waveform State
  late List<double> _waveformHeights;
  bool _isRealWaveform = false;

  // Fade In & Fade Out State (in seconds)
  int _fadeInSec = 0; // 0 (Off), 1s, 2s, 3s
  int _fadeOutSec = 0; // 0 (Off), 1s, 2s, 3s

  // Interactive Waveform Drag States
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;
  bool _isDraggingWindow = false;
  double _dragWindowInitialStart = 0.0;
  double _dragWindowInitialEnd = 0.0;

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
    _waveformHeights = List.generate(60, (index) {
      final base = sin(index / 8.0).abs() * 0.6 + 0.3;
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

        // 2. Extract REAL audio waveform amplitudes from audio file
        try {
          final realAmplitudes = await RingtoneService.extractWaveform(_workingFilePath!, samples: 60);
          if (realAmplitudes != null && realAmplitudes.isNotEmpty && mounted) {
            setState(() {
              _waveformHeights = realAmplitudes;
              _isRealWaveform = true;
            });
          }
        } catch (_) {}

        _positionSub = _player.positionStream.listen((pos) {
          if (!mounted) return;
          final currentMs = pos.inMilliseconds.toDouble();
          setState(() => _currentPlaybackMs = currentMs);

          // Real-time volume fading curve during loop playback preview
          if (_isPlaying) {
            double targetVol = 1.0;
            if (_fadeInSec > 0 && currentMs < _startMs + (_fadeInSec * 1000)) {
              final elapsed = currentMs - _startMs;
              targetVol = (elapsed / (_fadeInSec * 1000)).clamp(0.05, 1.0);
            }
            if (_fadeOutSec > 0 && currentMs > _endMs - (_fadeOutSec * 1000)) {
              final remaining = _endMs - currentMs;
              final fadeVol = (remaining / (_fadeOutSec * 1000)).clamp(0.05, 1.0);
              targetVol = min(targetVol, fadeVol);
            }
            _player.setVolume(targetVol);
          }

          // If reached end of trimmed zone, loop back to start
          if (currentMs >= _endMs) {
            if (_fadeInSec > 0) {
              _player.setVolume(0.05);
            }
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
      if (_fadeInSec > 0) {
        await _player.setVolume(0.05);
      } else {
        await _player.setVolume(1.0);
      }
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
      fadeInMs: _fadeInSec * 1000,
      fadeOutMs: _fadeOutSec * 1000,
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
        await RingtoneService.scanFile(trimmedPath);
        final fileName = File(trimmedPath).path.split(Platform.isWindows ? '\\' : '/').last;
        final exactDurationMs = (_endMs - _startMs).toInt();

        // Immediately insert or update in localTracks with exact duration so it never displays an inaccurate estimate
        try {
          final db = ref.read(databaseProvider);
          final fileStat = await File(trimmedPath).stat();
          await db.into(db.localTracks).insert(
            LocalTracksCompanion(
              id: Value('local:$trimmedPath'),
              title: Value('${widget.track.title} (Clip)'),
              artistName: Value(widget.track.artistName),
              albumTitle: const Value('Musify'),
              source: Value(AudioSourceType.local.name),
              sourceId: Value(trimmedPath),
              durationMs: Value(exactDurationMs),
              artworkUrl: Value(widget.track.artworkUrl),
              audioUrl: Value(trimmedPath),
              filePath: Value(trimmedPath),
              fileSizeBytes: Value(fileStat.size),
              codec: Value(trimmedPath.endsWith('.m4a') ? 'm4a' : 'mp3'),
              bitrate: const Value(320),
              isLiked: const Value(false),
              isDownloaded: const Value(true),
              addedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
        } catch (_) {}

        showSnackBar(
          context,
          'Saved to Music/Musify: $fileName',
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
                          const LyricsLoadingWave(height: 38),
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

                        // High-Fidelity Waveform Display with Interactive Draggable Trim Handles
                        Container(
                          height: 124,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          color: Colors.transparent,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final totalWidth = constraints.maxWidth;
                              final startFrac = (_startMs / _totalDurationMs).clamp(0.0, 1.0);
                              final endFrac = (_endMs / _totalDurationMs).clamp(0.0, 1.0);
                              final playFrac = (_currentPlaybackMs / _totalDurationMs).clamp(0.0, 1.0);

                              final startX = totalWidth * startFrac;
                              final endX = totalWidth * endFrac;
                              final selectionWidth = max(6.0, endX - startX);

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Real audio waveform / synthetic badge in top right
                                  Positioned(
                                    top: 0,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _isRealWaveform
                                            ? AppColors.neonLime.withValues(alpha: 0.15)
                                            : (isDark ? Colors.white10 : Colors.black12),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: _isRealWaveform
                                              ? AppColors.neonLime.withValues(alpha: 0.35)
                                              : Colors.transparent,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isRealWaveform ? Icons.graphic_eq_rounded : Icons.waves_rounded,
                                            size: 11,
                                            color: _isRealWaveform ? AppColors.neonLime : textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isRealWaveform ? 'Real Audio Waveform' : 'Analyzing Wave...',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: _isRealWaveform ? AppColors.neonLime : textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Background Tap-to-seek waveform bars
                                  Positioned(
                                    top: 22,
                                    left: 0,
                                    right: 0,
                                    height: 74,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapUp: (details) {
                                        final tapFrac = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
                                        final seekMs = tapFrac * _totalDurationMs;
                                        _player.seek(Duration(milliseconds: seekMs.toInt()));
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: _waveformHeights.asMap().entries.map((entry) {
                                          final idx = entry.key;
                                          final hFrac = entry.value;
                                          final barFrac = idx / (_waveformHeights.length - 1);
                                          final isInsideTrim = barFrac >= startFrac && barFrac <= endFrac;

                                          return Container(
                                            width: 3.5,
                                            height: 68 * hFrac,
                                            decoration: BoxDecoration(
                                              color: isInsideTrim
                                                  ? AppColors.neonLime
                                                  : (isDark ? const Color(0xFF282C38) : const Color(0xFFD1D5DB)),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),

                                  // Highlighted active trim box with slide window gesture
                                  Positioned(
                                    left: startX,
                                    width: selectionWidth,
                                    top: 22,
                                    height: 74,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onHorizontalDragStart: (details) {
                                        _dragWindowInitialStart = _startMs;
                                        _dragWindowInitialEnd = _endMs;
                                        setState(() => _isDraggingWindow = true);
                                      },
                                      onHorizontalDragUpdate: (details) {
                                        final deltaMs = (details.primaryDelta! / totalWidth) * _totalDurationMs;
                                        final windowDuration = _dragWindowInitialEnd - _dragWindowInitialStart;
                                        final maxStart = max(0.0, _totalDurationMs - windowDuration);
                                        final newStart = (_startMs + deltaMs).clamp(0.0, maxStart);
                                        final newEnd = (newStart + windowDuration).clamp(0.0, _totalDurationMs);
                                        setState(() {
                                          _startMs = newStart;
                                          _endMs = newEnd;
                                        });
                                      },
                                      onHorizontalDragEnd: (_) {
                                        setState(() => _isDraggingWindow = false);
                                        if (_isPlaying) {
                                          _player.seek(Duration(milliseconds: _startMs.toInt()));
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _isDraggingWindow
                                              ? AppColors.neonLime.withValues(alpha: 0.32)
                                              : AppColors.neonLime.withValues(alpha: 0.18),
                                          border: Border.symmetric(
                                            horizontal: BorderSide(
                                              color: AppColors.neonLime.withValues(alpha: _isDraggingWindow ? 0.7 : 0.3),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: _isDraggingWindow
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF111827).withValues(alpha: 0.85),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  'Sliding ${((_endMs - _startMs) / 1000).toStringAsFixed(1)}s',
                                                  style: const TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.neonLime,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),

                                  // Playhead needle
                                  if (_isPlaying)
                                    Positioned(
                                      left: (totalWidth * playFrac - 1).clamp(0.0, totalWidth - 2.5),
                                      top: 22,
                                      height: 74,
                                      child: IgnorePointer(
                                        child: Container(
                                          width: 2.5,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(1),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withValues(alpha: 0.9),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Left Draggable Trim Handle
                                  Positioned(
                                    left: (startX - 16).clamp(-14.0, totalWidth - 20),
                                    top: 0,
                                    bottom: 0,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onHorizontalDragStart: (_) {
                                        HapticFeedback.selectionClick();
                                        setState(() => _isDraggingStart = true);
                                      },
                                      onHorizontalDragUpdate: (details) {
                                        final deltaMs = (details.primaryDelta! / totalWidth) * _totalDurationMs;
                                        final newStart = (_startMs + deltaMs).clamp(0.0, _endMs - 1000.0);
                                        setState(() => _startMs = newStart);
                                      },
                                      onHorizontalDragEnd: (_) {
                                        HapticFeedback.lightImpact();
                                        setState(() => _isDraggingStart = false);
                                        if (_isPlaying) {
                                          _player.seek(Duration(milliseconds: _startMs.toInt()));
                                        }
                                      },
                                      child: _WaveformTrimHandle(
                                        isStart: true,
                                        isDragging: _isDraggingStart,
                                        timeLabel: _formatTime(_startMs),
                                        isDark: isDark,
                                      ),
                                    ),
                                  ),

                                  // Right Draggable Trim Handle
                                  Positioned(
                                    left: (endX - 16).clamp(0.0, totalWidth + 14),
                                    top: 0,
                                    bottom: 0,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onHorizontalDragStart: (_) {
                                        HapticFeedback.selectionClick();
                                        setState(() => _isDraggingEnd = true);
                                      },
                                      onHorizontalDragUpdate: (details) {
                                        final deltaMs = (details.primaryDelta! / totalWidth) * _totalDurationMs;
                                        final newEnd = (_endMs + deltaMs).clamp(_startMs + 1000.0, _totalDurationMs);
                                        setState(() => _endMs = newEnd);
                                      },
                                      onHorizontalDragEnd: (_) {
                                        HapticFeedback.lightImpact();
                                        setState(() => _isDraggingEnd = false);
                                      },
                                      child: _WaveformTrimHandle(
                                        isStart: false,
                                        isDragging: _isDraggingEnd,
                                        timeLabel: _formatTime(_endMs),
                                        isDark: isDark,
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

                        // 4. Fade Transitions (Fade-In & Fade-Out)
                        _FadeTransitionControls(
                          fadeInSec: _fadeInSec,
                          fadeOutSec: _fadeOutSec,
                          onFadeInChanged: (val) {
                            setState(() => _fadeInSec = val);
                          },
                          onFadeOutChanged: (val) {
                            setState(() => _fadeOutSec = val);
                          },
                          isDark: isDark,
                        ),

                        const SizedBox(height: 26),

                        // 5. Apply Audio Actions (Clean, borderless studio action tiles)
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
                    ? const PulseDotsIndicator(
                        size: 5,
                        spacing: 3,
                        color: Color(0xFF111827),
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

/// Interactive draggable trim handle with grip pill and floating timestamp tooltip
class _WaveformTrimHandle extends StatelessWidget {
  final bool isStart;
  final bool isDragging;
  final String timeLabel;
  final bool isDark;

  const _WaveformTrimHandle({
    required this.isStart,
    required this.isDragging,
    required this.timeLabel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32, // Large hit-test footprint for easy touch manipulation
      child: Column(
        children: [
          // Floating timestamp badge
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: isDragging ? 1.0 : 0.85,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isDragging
                    ? AppColors.neonLime
                    : (isDark ? const Color(0xFF20222B) : const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isDragging
                    ? [
                        BoxShadow(
                          color: AppColors.neonLime.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: isDragging
                      ? const Color(0xFF111827)
                      : (isDark ? Colors.white : const Color(0xFF1F2937)),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Vertical guide line & Grab Handle Pill
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vertical trim needle line
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: AppColors.neonLime,
                    borderRadius: BorderRadius.circular(1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonLime.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                // Center Grip Pill with chevron indicator
                AnimatedScale(
                  scale: isDragging ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 22,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.neonLime,
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: AppColors.neonLime.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isStart ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                      size: 18,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade-In and Fade-Out selector controls with real-time preview feedback
class _FadeTransitionControls extends StatelessWidget {
  final int fadeInSec;
  final int fadeOutSec;
  final ValueChanged<int> onFadeInChanged;
  final ValueChanged<int> onFadeOutChanged;
  final bool isDark;

  const _FadeTransitionControls({
    required this.fadeInSec,
    required this.fadeOutSec,
    required this.onFadeInChanged,
    required this.onFadeOutChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? Colors.white54 : const Color(0xFF8E92A0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FADE TRANSITIONS',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              if (fadeInSec > 0 || fadeOutSec > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.neonLime.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Active preview',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.neonLime : const Color(0xFF3E8016),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16181F) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Fade In Row
              Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 18,
                    color: fadeInSec > 0 ? AppColors.neonLime : textMuted,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      'Fade In',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [0, 1, 2, 3].map((sec) {
                        final isSelected = fadeInSec == sec;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _FadePill(
                            label: sec == 0 ? 'Off' : '${sec}s',
                            isSelected: isSelected,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onFadeInChanged(sec);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF262833) : const Color(0xFFE5E7EB),
              ),
              const SizedBox(height: 12),
              // Fade Out Row
              Row(
                children: [
                  Icon(
                    Icons.trending_down_rounded,
                    size: 18,
                    color: fadeOutSec > 0 ? AppColors.neonLime : textMuted,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      'Fade Out',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [0, 1, 2, 3].map((sec) {
                        final isSelected = fadeOutSec == sec;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _FadePill(
                            label: sec == 0 ? 'Off' : '${sec}s',
                            isSelected: isSelected,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onFadeOutChanged(sec);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FadePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FadePill({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.neonLime
              : (isDark ? const Color(0xFF222530) : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.neonLime.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF111827)
                : (isDark ? Colors.white70 : const Color(0xFF374151)),
          ),
        ),
      ),
    );
  }
}
