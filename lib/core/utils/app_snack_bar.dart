import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

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

    final toastType = switch (type) {
      AppSnackBarType.success => ToastificationType.success,
      AppSnackBarType.delete => ToastificationType.error,
      AppSnackBarType.error => ToastificationType.error,
      AppSnackBarType.warning => ToastificationType.warning,
      AppSnackBarType.info => ToastificationType.info,
    };

    final IconData defaultIcon = switch (type) {
      AppSnackBarType.success => Icons.check_circle_rounded,
      AppSnackBarType.delete => Icons.delete_outline_rounded,
      AppSnackBarType.error => Icons.error_outline_rounded,
      AppSnackBarType.warning => Icons.warning_amber_rounded,
      AppSnackBarType.info => Icons.info_outline_rounded,
    };

    final effectiveIcon = icon ?? defaultIcon;

    toastification.dismissAll();

    Widget titleWidget = Text(
      cleanedMessage,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
        letterSpacing: -0.2,
      ),
    );

    if (actionLabel != null && onAction != null) {
      titleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: titleWidget),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              toastification.dismissAll();
              onAction();
            },
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    }

    toastification.show(
      context: context,
      title: titleWidget,
      icon: Icon(effectiveIcon, size: 20),
      type: toastType,
      style: ToastificationStyle.fillColored,
      autoCloseDuration: duration,
      alignment: Alignment.topCenter,
      showProgressBar: false,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
