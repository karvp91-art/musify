import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/presentation/providers/audio_providers.dart';

/// Shows the floating "Appearance & Theme" selection modal sheet
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
                    surface: Color(0xFF1E212B),
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

    final cardBg = isDark ? const Color(0xFF161822) : Colors.white;
    final itemBg = isDark ? const Color(0xFF202330) : const Color(0xFFF3F4F8);
    final selectedBorderColor = isDark ? AppColors.neonLime : AppColors.limeAccentDark;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.neonLime.withValues(alpha: 0.15)
                          : AppColors.limeAccentDark.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.palette_outlined,
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
                          'Appearance & Theme',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getActiveStatusText(currentPreference, isCurrentlyDay, resolvedThemeMode),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Theme Options List
              ...AppThemePreference.values.map((pref) {
                final isSelected = pref == currentPreference;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(themeModeProvider.notifier).setThemePreference(pref);
                      if (pref == AppThemePreference.autoTime) {
                        setState(() {
                          _isScheduleExpanded = true;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                ? AppColors.neonLime.withValues(alpha: 0.08)
                                : AppColors.limeAccentDark.withValues(alpha: 0.07))
                            : itemBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? selectedBorderColor : Colors.transparent,
                          width: 1.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? AppColors.neonLime : AppColors.limeAccentDark)
                                  : (isDark ? const Color(0xFF2C3042) : Colors.white),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              pref.icon,
                              size: 19,
                              color: isSelected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      pref.displayName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    if (pref == AppThemePreference.autoTime) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isCurrentlyDay
                                              ? Colors.amber.withValues(alpha: 0.2)
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
                                const SizedBox(height: 2),
                                Text(
                                  pref.subtitle,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected
                                ? selectedBorderColor
                                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Time-based Schedule Customizer (shown when Auto is selected)
              if (currentPreference == AppThemePreference.autoTime) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E212E) : const Color(0xFFF1F3F9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3346) : const Color(0xFFE2E6F0),
                    ),
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
                                color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
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
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Day starts at ${_formatTimeOfDay(dayStart)} (Light Mode) • Night starts at ${_formatTimeOfDay(nightStart)} (Dark Mode)',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      if (_isScheduleExpanded) ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1),
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
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Colors.grey),
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
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Colors.grey),
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
              ],

              const SizedBox(height: 14),

              // Done Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? AppColors.neonLime : AppColors.limeAccentDark,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
