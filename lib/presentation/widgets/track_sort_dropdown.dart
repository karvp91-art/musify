import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/domain/models/track_sort_option.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

class TrackSortDropdown extends ConsumerWidget {
  const TrackSortDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSort = ref.watch(localTrackSortOptionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final defaultBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final defaultIconColor = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);
    final isNonDefault = currentSort != TrackSortOption.recentlyAdded;

    return Theme(
      data: theme.copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? const Color(0xFF1E212B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 12,
        ),
      ),
      child: PopupMenuButton<TrackSortOption>(
        initialValue: currentSort,
        tooltip: 'Sort tracks: ${currentSort.label}',
        offset: const Offset(0, 48),
        position: PopupMenuPosition.under,
        onSelected: (TrackSortOption option) {
          HapticFeedback.selectionClick();
          ref.read(localTrackSortOptionProvider.notifier).setSortOption(option);
        },
        itemBuilder: (BuildContext context) {
          return TrackSortOption.values.map((option) {
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
          }).toList();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isNonDefault
                ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.16)
                : defaultBg,
            border: isNonDefault
                ? Border.all(color: primaryColor.withValues(alpha: 0.45), width: 1.2)
                : null,
          ),
          child: Icon(
            Icons.swap_vert_rounded,
            size: 20,
            color: isNonDefault ? primaryColor : defaultIconColor,
          ),
        ),
      ),
    );
  }
}
