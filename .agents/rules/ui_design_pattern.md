# UI Design Pattern & Approach Rule

All new and existing UI screens, modals, and modifications in this project MUST follow the design pattern and approach established in `lib/presentation/screens/settings/studio_equalizer_screen.dart`.

## Core UI Architecture Guidelines:

### 1. Top App Bar Layout
- **Back & Action Buttons**: Use 44x44 circular buttons (`_CircleHeaderButton` pattern) with `BoxShape.circle`, background `Color(0xFF20222B)` in dark mode and `Color(0xFFECEEF2)` in light mode.
- **Center Title**: Use `AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700)`.
- **Haptic Feedback**: Always call `HapticFeedback.selectionClick()` on navigation and header actions.

### 2. Open Canvas Layout & Section Structure
- **Canvas Background**: Render content directly on the scaffold background (`scaffoldBackgroundColor` in dark mode, `Colors.white` in light mode) without heavy clunky enclosing boxes.
- **Section Headers**:
  - Primary title: `AppTypography.headlineSmall.copyWith(fontSize: 18-19, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)`.
  - Subtitle: `AppTypography.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Color(0xFF8E92A0))`.
  - Action labels (e.g. "See all", "Import"): `AppTypography.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.neonLime : Color(0xFF3E8016))`.

### 3. Component & Card Styling
- **Squircle Icon Badges**: 44x44 container with `borderRadius: BorderRadius.circular(13)`, background `AppColors.neonLime.withValues(alpha: 0.18)` in dark mode and `Color(0xFFEFFCC8)` in light mode. Icon colored with `AppColors.neonLime` (dark) or `Color(0xFF3E8016)` (light).
- **Interactive Tiles**: Padding `horizontal: 4, vertical: 8` with clear title (15.5px w700) and subtitle (12-13px w500).
- **Controls & Accent Highlights**: Use `AppColors.neonLime` for active switches, sliders, checkmarks, progress bars, and selection rings.
- **Selection Pills & Filter Chips**: Height 58px squircle buttons or rounded chips (`borderRadius: BorderRadius.circular(18)` or `22`), animated container with `Duration(milliseconds: 180)` and subtle glow shadow when active.

### 4. Bottom Sheets & Modals
- **Border Radius**: Top corners `Radius.circular(24)` to `28`.
- **Drag Handle**: Center capsule 40x4 width/height, 2px radius, `Colors.white24` (dark) or `Colors.black12` (light).
- **Tile Shape**: `RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))`.
- **Selected Tile State**: Background `AppColors.neonLime.withValues(alpha: 0.22)` with `check_circle_rounded` indicator.

### 5. Floating Mini Player & Bottom Inset
- Always account for the universal `FloatingMiniPlayer()` or bottom nav bar by wrapping the screen in a `Stack`, placing `FloatingMiniPlayer()` at the bottom, and adding at least `SizedBox(height: 120-140)` at the end of the scrollable content.

### 6. Haptics
- Fire `HapticFeedback.selectionClick()` on state changes, selections, and button taps.
- Fire `HapticFeedback.lightImpact()` on drag or list tile interactions.
