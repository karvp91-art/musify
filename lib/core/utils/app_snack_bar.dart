import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toastification/toastification.dart';
import 'package:musify/core/theme/app_colors.dart';
import 'package:musify/core/theme/app_typography.dart';

enum AppSnackBarType {
  success,
  delete,
  info,
  error,
  warning,
}

typedef SnackType = AppSnackBarType;

/// Global snackbar / toast helper matching my-local-fe design system
void showSnackBar(
  BuildContext context,
  String message, {
  AppSnackBarType type = AppSnackBarType.info,
}) {
  AppSnackBar.show(context, message: message, type: type);
}

class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarType type = AppSnackBarType.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Automatically clean up the message
    final cleanedMessage = message
        .replaceFirst('Exception: ', '')
        .replaceAll(RegExp(r'[\[\]]'), '');

    final IconData defaultIcon = switch (type) {
      AppSnackBarType.success => Icons.check_circle_rounded,
      AppSnackBarType.delete => Icons.delete_outline_rounded,
      AppSnackBarType.error => Icons.error_outline_rounded,
      AppSnackBarType.warning => Icons.warning_amber_rounded,
      AppSnackBarType.info => Icons.info_outline_rounded,
    };

    final effectiveIcon = icon ?? defaultIcon;

    toastification.dismissAll();

    toastification.showCustom(
      context: context,
      autoCloseDuration: duration,
      alignment: Alignment.topRight,
      animationDuration: const Duration(milliseconds: 240),
      builder: (context, holder) {
        return Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: () => toastification.dismiss(holder),
            child: Container(
              margin: const EdgeInsets.only(top: 8, right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.neonLime,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonLime.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  effectiveIcon,
                  size: 17,
                  color: const Color(0xFF111827),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    cleanedMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: const Color(0xFF111827),
                      letterSpacing: -0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      toastification.dismiss(holder);
                      onAction();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: AppColors.neonLime,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
    );
  }
}
