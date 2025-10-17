import 'package:flutter/material.dart';

enum SnackBarType { info, success, warning, error }

class EnhancedSnackBar {
  static SnackBar create({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    bool persistent = false,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = Colors.green.shade600;
        textColor = Colors.white;
        icon = Icons.check_circle_outline;
        break;
      case SnackBarType.warning:
        backgroundColor = Colors.orange.shade600;
        textColor = Colors.white;
        icon = Icons.warning_outlined;
        break;
      case SnackBarType.error:
        backgroundColor = Colors.red.shade600;
        textColor = Colors.white;
        icon = Icons.error_outline;
        break;
      case SnackBarType.info:
      default:
        backgroundColor = Theme.of(context).colorScheme.inverseSurface;
        textColor = Theme.of(context).colorScheme.onInverseSurface;
        icon = Icons.info_outline;
        break;
    }

    return SnackBar(
      content: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: textColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      elevation: 8,
      duration: persistent
          ? const Duration(days: 1)
          : Duration(seconds: type == SnackBarType.error ? 6 : 3),
      action: actionLabel != null && onActionPressed != null
          ? SnackBarAction(
        label: actionLabel,
        textColor: textColor.withOpacity(0.9),
        onPressed: onActionPressed,
      )
          : null,
      dismissDirection: DismissDirection.horizontal,
    );
  }
}
