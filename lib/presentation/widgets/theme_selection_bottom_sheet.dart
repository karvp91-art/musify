import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

/// Shows the floating "Appearance & Theme" selection modal sheet
/// styled to match the aesthetics of AddToPlaylistModal.
Future<void> showThemeSelectionModal(BuildContext context) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    useSafeArea: true,
    builder: (modalCtx) => Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        14 + MediaQuery.of(modalCtx).padding.bottom,
      ),
      child: const ThemeSelectionBottomSheet(),
    ),
  );
}

class ThemeSelectionBottomSheet extends ConsumerStatefulWidget {
  const ThemeSelectionBottomSheet({super.key});

  @override
  ConsumerState<ThemeSelectionBottomSheet> createState() => _ThemeSelectionBottomSheetState();
}

class _ThemeSelectionBottomSheetState extends ConsumerState<ThemeSelectionBottomSheet> {
  bool _isScheduleExpanded = false;

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime({
    required BuildContext context,
    required bool isDayStart,
    required TimeOfDay initialTime,
  }) async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (pickerCtx, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.neonLime,
                    onPrimary: Colors.black,
                    surface: Colors.black,
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.limeAccentDark,
                    onPrimary: Colors.white,
                  ),
                ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      final prefsService = ref.read(preferencesServiceProvider);
      final currentDay = prefsService.getDayStartTime();
      final currentNight = prefsService.getNightStartTime();

      if (isDayStart) {
        await ref.read(themeModeProvider.notifier).setDayNightSchedule(
              dayStart: picked,
              nightStart: currentNight,
            );
      } else {
        await ref.read(themeModeProvider.notifier).setDayNightSchedule(
              dayStart: currentDay,
              nightStart: picked,
            );
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentPreference = ref.watch(themePreferenceProvider);
    final resolvedThemeMode = ref.watch(themeModeProvider);
    final prefsService = ref.watch(preferencesServiceProvider);

    final dayStart = prefsService.getDayStartTime();
    final nightStart = prefsService.getNightStartTime();
    final isCurrentlyDay = prefsService.isDayTime();

    final cardBg = isDark ? const Color(0xFF20222B) : const Color(0xFFECEEF2);
    final dividerColor = isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB);
    final activeAccent = isDark ? AppColors.neonLime : const Color(0xFF659814);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
            blurRadius: 28,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag Handle Pill (matching AddToPlaylistModal)
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. Header Row (matching AddToPlaylistModal artwork + title layout)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222C1D) : const Color(0xFFDFEDE0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.palette_outlined,
                          color: activeAccent,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Appearance & Theme',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 17.5,
                              letterSpacing: -0.2,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _getActiveStatusText(currentPreference, isCurrentlyDay, resolvedThemeMode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Header Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Divider(
                  height: 22,
                  thickness: 1,
                  color: dividerColor,
                ),
              ),

              // 3. Theme Options List (styled matching AddToPlaylistModal's _PlaylistTile)
              ...AppThemePreference.values.map((pref) {
                final isSelected = pref == currentPreference;
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).setThemePreference(pref);
                    if (pref == AppThemePreference.autoTime) {
                      setState(() {
                        _isScheduleExpanded = true;
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    child: Row(
                      children: [
                        // Left: 44x44 rounded square icon container
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF222533) : const Color(0xFFF1F3F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            pref.icon,
                            size: 21,
                            color: isSelected
                                ? activeAccent
                                : theme.colorScheme.onSurface.withValues(alpha: 0.70),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Middle: Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    pref.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.5,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  if (pref == AppThemePreference.autoTime) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isCurrentlyDay
                                            ? Colors.amber.withValues(alpha: 0.20)
                                            : Colors.indigo.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isCurrentlyDay ? '☀️ Day' : '🌙 Night',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentlyDay
                                              ? (isDark ? Colors.amberAccent : Colors.orange.shade800)
                                              : (isDark ? Colors.lightBlueAccent : Colors.indigo),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                pref.subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12.5,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right: Circular Radio Indicator
                        _buildRadioIndicator(isSelected, isDark),
                      ],
                    ),
                  ),
                );
              }),

              // 4. Day / Night Schedule Section (when Auto is selected)
              if (currentPreference == AppThemePreference.autoTime) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Divider(
                    height: 18,
                    thickness: 1,
                    color: dividerColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E212E) : const Color(0xFFF6F7FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 17,
                                  color: activeAccent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Day / Night Schedule',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isScheduleExpanded = !_isScheduleExpanded;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  _isScheduleExpanded ? 'Hide' : 'Customize',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: activeAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Day starts at ${_formatTimeOfDay(dayStart)} (Light) • Night starts at ${_formatTimeOfDay(nightStart)} (Dark)',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        if (_isScheduleExpanded) ...[
                          const SizedBox(height: 12),
                          Divider(height: 1, color: dividerColor),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Day Time Picker Button
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickTime(
                                    context: context,
                                    isDayStart: true,
                                    initialTime: dayStart,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF282B3C) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF383D54) : const Color(0xFFDFE3EC),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.wb_sunny_rounded, size: 16, color: Colors.amber),
                                        const SizedBox(width: 6),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Day Start',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              _formatTimeOfDay(dayStart),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Night Time Picker Button
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickTime(
                                    context: context,
                                    isDayStart: false,
                                    initialTime: nightStart,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF282B3C) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF383D54) : const Color(0xFFDFE3EC),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.nightlight_round, size: 16, color: Colors.indigoAccent),
                                        const SizedBox(width: 6),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Night Start',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              _formatTimeOfDay(nightStart),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // 5. Fixed Bottom Button (matching AddToPlaylistModal's 52px high neon lime pill)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD2F843),
                      foregroundColor: const Color(0xFF111827),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Done',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the custom radio indicator matching AddToPlaylistModal
  Widget _buildRadioIndicator(bool isSelected, bool isDark) {
    final activeColor = isDark ? AppColors.neonLime : const Color(0xFF75A31E);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? activeColor
              : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
          width: isSelected ? 2.0 : 1.8,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                ),
              ),
            )
          : null,
    );
  }

  String _getActiveStatusText(
    AppThemePreference preference,
    bool isCurrentlyDay,
    ThemeMode currentThemeMode,
  ) {
    switch (preference) {
      case AppThemePreference.dark:
        return 'Active: Dark Mode (Obsidian)';
      case AppThemePreference.light:
        return 'Active: Light Mode';
      case AppThemePreference.autoTime:
        return isCurrentlyDay
            ? 'Active: Auto • Currently Daytime (Light)'
            : 'Active: Auto • Currently Nighttime (Dark)';
      case AppThemePreference.system:
        return 'Active: System Default (${currentThemeMode == ThemeMode.dark ? "Dark" : "Light"})';
    }
  }
}
