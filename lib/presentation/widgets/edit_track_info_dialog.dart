import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/track.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

/// Shows a modal dialog for manually editing track metadata (title, artist, album).
Future<bool?> showEditTrackInfoDialog(BuildContext context, WidgetRef ref, Track track) async {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _EditTrackInfoDialog(track: track),
  );
}

class _EditTrackInfoDialog extends ConsumerStatefulWidget {
  final Track track;
  const _EditTrackInfoDialog({required this.track});

  @override
  ConsumerState<_EditTrackInfoDialog> createState() => _EditTrackInfoDialogState();
}

class _EditTrackInfoDialogState extends ConsumerState<_EditTrackInfoDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _artistController = TextEditingController(text: widget.track.artistName);
    _albumController = TextEditingController(text: widget.track.albumTitle ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    final album = _albumController.text.trim();

    if (title.isEmpty) {
      AppSnackBar.show(context, message: 'Title cannot be empty', type: AppSnackBarType.error);
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(audioRepositoryProvider);
      await repo.updateTrackMetadata(
        widget.track.id,
        title: title != widget.track.title ? title : null,
        artistName: artist != widget.track.artistName ? artist : null,
        albumTitle: album != (widget.track.albumTitle ?? '') ? album : null,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
        AppSnackBar.show(
          context,
          message: 'Track info updated',
          type: AppSnackBarType.success,
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.show(context, message: 'Failed to update: $e', type: AppSnackBarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.edit_note_rounded, color: primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Edit Track Info',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(Icons.close_rounded, size: 22, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title field
            _buildField(
              label: 'Title',
              controller: _titleController,
              icon: Icons.music_note_rounded,
              theme: theme,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Artist field
            _buildField(
              label: 'Artist',
              controller: _artistController,
              icon: Icons.person_rounded,
              theme: theme,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Album field
            _buildField(
              label: 'Album',
              controller: _albumController,
              icon: Icons.album_rounded,
              theme: theme,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
