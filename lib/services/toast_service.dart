import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ToastService {
  static void showToast(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 2),
    bool isError = false,
  }) {
    // Haptic feedback for errors
    if (isError) {
      HapticFeedback.lightImpact();
    }

    // Remove any existing snackbar
    ScaffoldMessenger.of(context).clearSnackBars();

    // Show toast message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: backgroundColor ??
            (isError ? Colors.red.shade600 : Colors.green.shade600),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 6,
        action: SnackBarAction(
          label: 'بستن',
          textColor: Colors.white70,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccessToast(BuildContext context, String message) {
    showToast(
      context,
      message,
      backgroundColor: Colors.green.shade600,
      textColor: Colors.white,
    );
  }

  static void showErrorToast(BuildContext context, String message) {
    showToast(
      context,
      message,
      backgroundColor: Colors.red.shade600,
      textColor: Colors.white,
      isError: true,
    );
  }

  static void showInfoToast(BuildContext context, String message) {
    showToast(
      context,
      message,
      backgroundColor: Colors.blue.shade600,
      textColor: Colors.white,
    );
  }

  static void showWarningToast(BuildContext context, String message) {
    showToast(
      context,
      message,
      backgroundColor: Colors.orange.shade600,
      textColor: Colors.white,
    );
  }
}
