# App Typography Rule

All text rendering in the app MUST adhere to `AppTypography` defined in `lib/core/theme/app_typography.dart`.

## Guidelines:
1. Always use `AppTypography` (which uses GoogleFonts Plus Jakarta Sans) for font styling instead of ad-hoc or default `TextStyle` without font family.
2. Available predefined styles:
   - `AppTypography.headlineLarge`: 28px, w800
   - `AppTypography.headlineSmall`: 20px, w700
   - `AppTypography.bodyLarge`: 16px, w600
   - `AppTypography.bodySmall`: 13.5px, w500
   - `AppTypography.caption`: 12px, w500
   - `AppTypography.button`: 14px, w700
3. For custom styles, always use the factory helper:
   ```dart
   AppTypography.style(
     fontSize: ...,
     fontWeight: ...,
     color: ...,
     letterSpacing: ...,
     height: ...,
   )
   ```
4. Never introduce hardcoded non-Plus Jakarta Sans typography or raw unstyled text.
