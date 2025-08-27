import 'dart:math';
import 'dart:typed_data';

import 'package:base32/base32.dart';

/// سرویس احراز هویت دو مرحله‌ای ساده
/// کاربر خودش رمز 6 رقمی تعیین می‌کند
class TOTPService {
  // تنظیمات
  static const int _codeLength = 6;
  static const int _backupCodeCount = 10;
  static const int _backupCodeLength = 8;

  /// تولید کلید مخفی 160 بیتی (Base32 encoded)
  static String generateSecretKey() {
    final random = Random.secure();
    final bytes = Uint8List(20); // 160 bits
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base32.encode(bytes);
  }

  /// تولید کدهای بکاپ 8 رقمی
  static List<String> generateBackupCodes() {
    final random = Random.secure();
    final codes = <String>[];

    for (int i = 0; i < _backupCodeCount; i++) {
      final code = StringBuffer();
      for (int j = 0; j < _backupCodeLength; j++) {
        code.write(random.nextInt(10));
      }
      codes.add(code.toString());
    }

    return codes;
  }

  /// تولید کد 6 رقمی پیشنهادی (اختیاری)
  static String generateSuggestedCode() {
    final random = Random.secure();
    final code = StringBuffer();
    for (int i = 0; i < _codeLength; i++) {
      code.write(random.nextInt(10));
    }
    return code.toString();
  }

  /// اعتبارسنجی کد 6 رقمی
  static bool validateCode(String secretKey, String code) {
    if (code.length != _codeLength) return false;

    try {
      // بررسی اینکه کد فقط شامل اعداد باشد
      if (!RegExp(r'^\d{6}$').hasMatch(code)) return false;

      // در این سیستم، کاربر خودش کد را تعیین می‌کند
      // این متد فقط فرمت کد را بررسی می‌کند
      // اعتبارسنجی واقعی در Simple2FAService.validateUserCode انجام می‌شود
      return true;
    } catch (e) {
      return false;
    }
  }

  /// اعتبارسنجی کد بکاپ
  static bool validateBackupCode(List<String> backupCodes, String code) {
    if (code.length != _backupCodeLength) return false;

    try {
      // بررسی اینکه کد فقط شامل اعداد باشد
      if (!RegExp(r'^\d{8}$').hasMatch(code)) return false;

      // بررسی وجود کد در لیست
      return backupCodes.contains(code);
    } catch (e) {
      return false;
    }
  }

  /// حذف کد بکاپ استفاده شده
  static List<String> removeUsedBackupCode(
      List<String> backupCodes, String usedCode) {
    return backupCodes.where((code) => code != usedCode).toList();
  }

  /// تولید کد 6 رقمی فعلی (برای نمایش)
  static String generateCurrentCode(String secretKey) {
    // در این سیستم، کاربر خودش کد را تعیین می‌کند
    // این متد فقط برای سازگاری نگه داشته شده
    return '000000';
  }
}
