import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// سرویس ساده تایید دو مرحله‌ای بر اساس رمز شخصی کاربر
class Simple2FAService {
  static const int _backupCodeCount = 10;

  /// تولید رمز تصادفی برای تایید دو مرحله‌ای
  static String generatePassword() {
    try {
      final random = Random.secure();
      final bytes = Uint8List.fromList(
        List<int>.generate(16, (i) => random.nextInt(256)),
      );

      // تبدیل به Base64 و حذف کاراکترهای غیرمجاز
      final base64Password = base64.encode(bytes);
      final cleanPassword = base64Password
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .substring(0, 12); // رمز 12 کاراکتری

      print(
          '🔐 رمز 2FA تولید شد: $cleanPassword (طول: ${cleanPassword.length})');
      return cleanPassword;
    } catch (e) {
      print('❌ خطا در تولید رمز 2FA: $e');
      return 'VISTA2FA2024';
    }
  }

  /// تولید کدهای پشتیبان
  static List<String> generateBackupCodes({int count = _backupCodeCount}) {
    final random = Random.secure();
    final codes = <String>[];

    for (int i = 0; i < count; i++) {
      // تولید کد 8 رقمی با فرمت XXXX-XXXX
      final code = List<int>.generate(8, (i) => random.nextInt(10))
          .join()
          .replaceAllMapped(RegExp(r'(.{4})'), (match) => '${match.group(1)}-')
          .substring(0, 9); // حذف آخرین خط تیره
      codes.add(code);
    }

    return codes;
  }

  /// تایید رمز
  static bool verifyPassword(String storedPassword, String inputPassword) {
    try {
      // مقایسه ساده رمزها
      return storedPassword == inputPassword;
    } catch (e) {
      print('❌ خطا در تایید رمز: $e');
      return false;
    }
  }

  /// تایید کد پشتیبان
  static bool verifyBackupCode(
      List<String> storedBackupCodes, String inputCode) {
    try {
      // بررسی اینکه آیا کد در لیست کدهای پشتیبان وجود دارد
      return storedBackupCodes.contains(inputCode);
    } catch (e) {
      print('❌ خطا در تایید کد پشتیبان: $e');
      return false;
    }
  }

  /// حذف کد پشتیبان استفاده شده
  static List<String> removeUsedBackupCode(
      List<String> backupCodes, String usedCode) {
    try {
      final updatedCodes = List<String>.from(backupCodes);
      updatedCodes.remove(usedCode);
      print('✅ کد پشتیبان استفاده شده حذف شد: $usedCode');
      return updatedCodes;
    } catch (e) {
      print('❌ خطا در حذف کد پشتیبان: $e');
      return backupCodes;
    }
  }

  /// بررسی نیاز به تولید کدهای پشتیبان جدید
  static bool needsNewBackupCodes(List<String> backupCodes) {
    // اگر کمتر از 3 کد باقی مانده باشد، نیاز به تولید کدهای جدید است
    return backupCodes.length < 3;
  }

  /// تولید کدهای پشتیبان جدید و اضافه کردن به لیست موجود
  static List<String> generateAdditionalBackupCodes(List<String> existingCodes,
      {int additionalCount = 5}) {
    try {
      final newCodes = generateBackupCodes(count: additionalCount);
      final allCodes = [...existingCodes, ...newCodes];
      print('✅ ${additionalCount} کد پشتیبان جدید تولید و اضافه شد');
      return allCodes;
    } catch (e) {
      print('❌ خطا در تولید کدهای پشتیبان جدید: $e');
      return existingCodes;
    }
  }

  /// بررسی وضعیت کدهای پشتیبان
  static Map<String, dynamic> checkBackupCodesStatus(List<String> backupCodes) {
    final remainingCount = backupCodes.length;
    final needsNew = needsNewBackupCodes(backupCodes);
    final status = remainingCount > 0 ? 'active' : 'depleted';

    // محاسبه درصد باقی‌مانده
    final percentage = (remainingCount / 10) * 100;

    // تعیین سطح هشدار
    String warningLevel;
    String recommendation;

    if (remainingCount == 0) {
      warningLevel = 'critical';
      recommendation = 'حساب شما قفل شده است. با پشتیبانی تماس بگیرید.';
    } else if (remainingCount <= 2) {
      warningLevel = 'high';
      recommendation = 'فوراً کدهای جدید تولید کنید!';
    } else if (remainingCount <= 5) {
      warningLevel = 'medium';
      recommendation = 'به زودی کدهای جدید تولید کنید.';
    } else {
      warningLevel = 'low';
      recommendation = 'کدهای پشتیبان کافی هستند.';
    }

    return {
      'remaining_count': remainingCount,
      'needs_new_codes': needsNew,
      'status': status,
      'warning_level': warningLevel,
      'percentage': percentage,
      'recommendation': recommendation,
      'is_critical': remainingCount == 0,
      'can_generate': remainingCount > 0,
    };
  }

  /// بررسی اینکه آیا کاربر می‌تواند کدهای جدید تولید کند
  static bool canGenerateNewCodes(List<String> backupCodes) {
    return backupCodes.isNotEmpty;
  }

  /// تولید کدهای پشتیبان اضطراری (برای مواقع بحرانی)
  static List<String> generateEmergencyBackupCodes({int count = 15}) {
    try {
      final codes = generateBackupCodes(count: count);
      print('🚨 کدهای پشتیبان اضطراری تولید شدند: ${codes.length} کد');
      return codes;
    } catch (e) {
      print('❌ خطا در تولید کدهای اضطراری: $e');
      return [];
    }
  }

  /// بررسی اعتبار رمز
  static bool isValidPassword(String password) {
    try {
      // بررسی طول و فرمت
      if (password.length < 8) return false;

      // بررسی اینکه آیا فقط حروف و اعداد است
      final validChars = RegExp(r'^[A-Za-z0-9]+$');
      if (!validChars.hasMatch(password)) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// تولید هش رمز برای ذخیره امن
  static String hashPassword(String password) {
    try {
      final bytes = utf8.encode(password);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('❌ خطا در تولید هش رمز: $e');
      return '';
    }
  }

  /// تایید رمز با استفاده از هش
  static bool verifyPasswordHash(String storedHash, String inputPassword) {
    try {
      final inputHash = hashPassword(inputPassword);
      return storedHash == inputHash;
    } catch (e) {
      print('❌ خطا در تایید هش رمز: $e');
      return false;
    }
  }

  /// تست عملکرد سرویس
  static Map<String, dynamic> testService() {
    try {
      final password = generatePassword();
      final backupCodes = generateBackupCodes();
      final passwordHash = hashPassword(password);

      return {
        'password': password,
        'password_length': password.length,
        'is_valid_password': isValidPassword(password),
        'password_hash': passwordHash,
        'backup_codes_count': backupCodes.length,
        'backup_codes': backupCodes,
        'test_password_verification': verifyPassword(password, password),
        'test_hash_verification': verifyPasswordHash(passwordHash, password),
        'test_backup_code_verification':
            verifyBackupCode(backupCodes, backupCodes.first),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}
