import 'package:flutter/material.dart';

import 'advanced_security_service.dart';

enum SensitiveAction {
  payment,
  changePassword,
  terminateAllOtherSessions,
}

class SensitiveActionGuard {
  static String _title(SensitiveAction action) {
    switch (action) {
      case SensitiveAction.payment:
        return 'تایید پرداخت';
      case SensitiveAction.changePassword:
        return 'تایید تغییر رمز عبور';
      case SensitiveAction.terminateAllOtherSessions:
        return 'تایید خاتمه نشست‌ها';
    }
  }

  static String _message(SensitiveAction action) {
    switch (action) {
      case SensitiveAction.payment:
        return 'برای ادامه پرداخت، هویت خود را تایید کنید.';
      case SensitiveAction.changePassword:
        return 'برای تغییر رمز عبور، هویت خود را تایید کنید.';
      case SensitiveAction.terminateAllOtherSessions:
        return 'برای خروج از تمام دستگاه‌های دیگر، هویت خود را تایید کنید.';
    }
  }

  static Future<bool> verify(
    BuildContext context, {
    required SensitiveAction action,
  }) async {
    final biometricEnabled = await AdvancedSecurityService.isBiometricEnabled();
    final biometricAvailable = biometricEnabled &&
        await AdvancedSecurityService.isBiometricAvailable();

    if (biometricAvailable) {
      final ok = await AdvancedSecurityService.authenticateWithBiometric();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('احراز هویت ناموفق بود.')),
        );
      }
      return ok;
    }

    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_title(action)),
        content: Text(_message(action)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تایید'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }
}
