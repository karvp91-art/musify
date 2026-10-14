import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/track_sort_option.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

class TrackSortDropdown extends ConsumerStatefulWidget {
  final double size;
  final Color? background;

  const TrackSortDropdown({
    super.key,
    this.size = 46,
    this.background,
  });

  @override
  ConsumerState<TrackSortDropdown> createState() => _TrackSortDropdownState();
}

class _TrackSortDropdownState extends ConsumerState<TrackSortDropdown> {
  bool _pressed = false;

  Future<void> _showSortMenu(
    BuildContext context,
    WidgetRef ref,
    TrackSortOption currentSort,
  ) async {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox? overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final Offset offset = Offset(0, button.size.height + 4);
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(offset, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero) + const Offset(0, 4),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<TrackSortOption>(
      context: context,
      position: position,
      initialValue: currentSort,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      color: isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2),
      items: TrackSortOption.values.map((option) {
        final isSelected = option == currentSort;
        return PopupMenuItem<TrackSortOption>(
          value: option,
          height: 48,
          child: Row(
            children: [
              Icon(
                option.icon,
                size: 19,
                color: isSelected
                    ? primaryColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? primaryColor
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: primaryColor,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );

    if (selected != null && context.mounted) {
      HapticFeedback.selectionClick();
      ref.read(localTrackSortOptionProvider.notifier).setSortOption(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSort = ref.watch(localTrackSortOptionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final bg = widget.background ??
        (isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2));
    final defaultIconColor =
        isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E2028);
    final isNonDefault = currentSort != TrackSortOption.recentlyAdded;

    return Tooltip(
      message: 'Sort tracks: ${currentSort.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          _showSortMenu(context, ref, currentSort);
        },
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              boxShadow: isNonDefault
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.swap_vert_rounded,
              size: widget.size * 0.48,
              color: isNonDefault ? primaryColor : defaultIconColor,
            ),
          ),
        ),
      ),
    );
  }
}
