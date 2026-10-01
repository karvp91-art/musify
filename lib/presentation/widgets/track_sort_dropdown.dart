import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/domain/models/track_sort_option.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

class TrackSortDropdown extends ConsumerWidget {
  const TrackSortDropdown({super.key});

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
      color: isDark ? Colors.black : Colors.white,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSort = ref.watch(localTrackSortOptionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final defaultIconColor =
        isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1E2028);
    final isNonDefault = currentSort != TrackSortOption.recentlyAdded;

    final glassSettings = isDark
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
            glassColor: Color(0x3DFFFFFF),
            specularSharpness: GlassSpecularSharpness.medium,
          );

    return Tooltip(
      message: 'Sort tracks: ${currentSort.label}',
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            _showSortMenu(context, ref, currentSort);
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (isNonDefault)
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
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
              shape: const LiquidRoundedSuperellipse(borderRadius: 22),
              settings: glassSettings,
              child: Center(
                child: Icon(
                  Icons.swap_vert_rounded,
                  size: 21,
                  color: isNonDefault ? primaryColor : defaultIconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
