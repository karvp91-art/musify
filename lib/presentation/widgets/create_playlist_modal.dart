import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:musify/domain/models/playlist.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

/// Opens the subtle and solid playlist creation modal bottom sheet.
Future<Playlist?> showCreatePlaylistModal(
  BuildContext context,
  WidgetRef ref, {
  void Function(Playlist playlist)? onCreated,
}) {
  return showModalBottomSheet<Playlist>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    useSafeArea: true,
    builder: (modalContext) => _PlaylistFormBottomSheet(
      onCreated: onCreated,
    ),
  );
}

/// Opens the subtle and solid playlist editing modal bottom sheet.
Future<Playlist?> showEditPlaylistModal(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist, {
  void Function(Playlist updatedPlaylist)? onUpdated,
}) {
  return showModalBottomSheet<Playlist>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    useSafeArea: true,
    builder: (modalContext) => _PlaylistFormBottomSheet(
      initialPlaylist: playlist,
      onUpdated: onUpdated,
    ),
  );
}

class _PlaylistFormBottomSheet extends ConsumerStatefulWidget {
  final Playlist? initialPlaylist;
  final void Function(Playlist playlist)? onCreated;
  final void Function(Playlist updatedPlaylist)? onUpdated;

  const _PlaylistFormBottomSheet({
    this.initialPlaylist,
    this.onCreated,
    this.onUpdated,
  });

  @override
  ConsumerState<_PlaylistFormBottomSheet> createState() => _PlaylistFormBottomSheetState();
}

class _PlaylistFormBottomSheetState extends ConsumerState<_PlaylistFormBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialPlaylist != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialPlaylist?.name ?? '');
    _descController = TextEditingController(text: widget.initialPlaylist?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(audioRepositoryProvider);
      final desc = _descController.text.trim().isNotEmpty ? _descController.text.trim() : null;

      if (_isEditing) {
        final existing = widget.initialPlaylist!;
        await repo.updatePlaylist(
          existing.id,
          name: name,
          description: desc,
        );
        final updated = existing.copyWith(
          name: name,
          description: desc,
        );
        ref.invalidate(playlistsStreamProvider);
        if (mounted) {
          Navigator.of(context).pop(updated);
          widget.onUpdated?.call(updated);
          AppSnackBar.show(
            context,
            message: 'Updated "$name"',
            type: AppSnackBarType.success,
            icon: Icons.check_circle_rounded,
          );
        }
      } else {
        final created = await repo.createPlaylist(name, description: desc);
        ref.invalidate(playlistsStreamProvider);
        if (mounted) {
          Navigator.of(context).pop(created);
          widget.onCreated?.call(created);
          AppSnackBar.show(
            context,
            message: 'Created "$name"',
            type: AppSnackBarType.success,
            icon: Icons.playlist_add_check_rounded,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackBar.show(
          context,
          message: 'Error: $e',
          type: AppSnackBarType.error,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final isValid = _nameController.text.trim().isNotEmpty;

    return AnimatedPadding(
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        14 + viewInsets.bottom + math.max(paddingBottom, 6),
      ),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Drag Handle Pill
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. Emblem Badge & Header Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.neonLime.withValues(alpha: isDark ? 0.14 : 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.neonLime.withValues(alpha: isDark ? 0.35 : 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        _isEditing ? Icons.edit_note_rounded : Icons.queue_music_rounded,
                        color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit Playlist' : 'New Playlist',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 18.5,
                              letterSpacing: -0.3,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isEditing
                                ? 'Update title and description'
                                : 'Create an offline mix for your tracks',
                            style: AppTypography.caption.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3. Subtle & Solid Input Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E212D) : const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2B3042) : const Color(0xFFE2E6EE),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Playlist Title Field
                      TextField(
                        controller: _nameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Playlist title',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: Icon(
                            Icons.title_rounded,
                            size: 20,
                            color: isDark ? AppColors.neonLime : const Color(0xFF555B6E),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                        onSubmitted: (_) {
                          if (isValid) _submit();
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark ? const Color(0xFF2B3042) : const Color(0xFFE2E6EE),
                      ),
                      // Playlist Description Field
                      TextField(
                        controller: _descController,
                        maxLines: 2,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Description (optional)',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: Icon(
                            Icons.notes_rounded,
                            size: 20,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Action Buttons (Cancel / Confirm)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  children: [
                    // Cancel Ghost Button
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 46,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF2B3042) : const Color(0xFFE2E6EE),
                                width: 1.0,
                              ),
                            ),
                            backgroundColor: isDark ? const Color(0xFF1E212D) : const Color(0xFFF3F5F9),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Create / Save Neon Lime Action Button
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isValid
                                ? AppColors.neonLime
                                : (isDark ? const Color(0xFF222533) : const Color(0xFFE5E7EB)),
                            foregroundColor: isValid
                                ? const Color(0xFF111827)
                                : (isDark ? Colors.white38 : Colors.black38),
                            elevation: isValid ? 3 : 0,
                            shadowColor: AppColors.neonLime.withValues(alpha: 0.45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23),
                            ),
                          ),
                          onPressed: isValid && !_isSubmitting ? _submit : null,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF111827),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isEditing ? Icons.check_rounded : Icons.add_rounded,
                                      size: 18,
                                      color: isValid
                                          ? const Color(0xFF111827)
                                          : (isDark ? Colors.white38 : Colors.black38),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isEditing ? 'Save Changes' : 'Create Playlist',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                        color: isValid
                                          ? const Color(0xFF111827)
                                          : (isDark ? Colors.white38 : Colors.black38),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
