import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/presentation/screens/playlist/import_playlist_screen.dart';

/// Prominent Import Playlist banner card with neon accent styling
class ImportPlaylistBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const ImportPlaylistBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (onTap != null) {
            onTap!();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ImportPlaylistScreen(),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      AppColors.neonLime.withValues(alpha: 0.12),
                      AppColors.neonLime.withValues(alpha: 0.04),
                    ]
                  : [
                      AppColors.neonLime.withValues(alpha: 0.22),
                      AppColors.neonLime.withValues(alpha: 0.06),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.neonLime.withValues(alpha: isDark ? 0.18 : 0.30),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Accent icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.neonLime.withValues(alpha: isDark ? 0.22 : 0.35),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.playlist_add_rounded,
                  size: 24,
                  color: isDark ? AppColors.neonLime : const Color(0xFF3E8016),
                ),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import from Link',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E2028),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Spotify · YouTube · JioSaavn playlists',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? AppColors.neonLime : const Color(0xFF3E8016),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
