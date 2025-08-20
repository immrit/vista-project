import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// سرویس TOTP برای تولید و تایید کدهای دو مرحله‌ای
/// پیاده‌سازی شده مطابق با استاندارد RFC 6238
class TOTPService {
  static const int _digits = 6;
  static const int _period = 30; // 30 ثانیه
  static const String _algorithm = 'SHA1';

  /// تولید سکرت تصادفی برای TOTP
  /// سکرت باید Base32 باشد و حداقل 128 بیت (16 کاراکتر) طول داشته باشد
  static String generateSecret() {
    try {
      // تولید 128 بیت (16 بایت) داده تصادفی
      final random = Random.secure();
      final bytes = Uint8List.fromList(
        List<int>.generate(16, (i) => random.nextInt(256)),
      );

      // تبدیل به Base32
      final base32Secret = _base32Encode(bytes);

      // اطمینان از طول مناسب (حداقل 16 کاراکتر)
      final finalSecret = base32Secret.length >= 16
          ? base32Secret.substring(0, 16)
          : base32Secret + 'A' * (16 - base32Secret.length);

      print('🔐 سکرت TOTP تولید شد: $finalSecret (طول: ${finalSecret.length})');
      print('🔐 سکرت Base32: ${_base32Encode(bytes)}');
      return finalSecret;
    } catch (e) {
      print('❌ خطا در تولید سکرت TOTP: $e');
      // در صورت خطا، سکرت پیش‌فرض تولید کن
      return 'JBSWY3DPEHPK3PXP';
    }
  }

  /// تولید کد TOTP فعلی
  static String generateCode(String secret) {
    try {
      final now = DateTime.now();
      final timestamp = (now.millisecondsSinceEpoch / 1000).floor();
      final counter = (timestamp / _period).floor();

      final code = _generateHOTP(secret, counter);
      print('🔐 کد TOTP تولید شد: $code (سکرت: $secret, counter: $counter)');
      return code;
    } catch (e) {
      print('❌ خطا در تولید کد TOTP: $e');
      return _generateRandomCode();
    }
  }

  /// تولید کد HOTP
  static String _generateHOTP(String secret, int counter) {
    try {
      // تبدیل سکرت Base32 به bytes
      final secretBytes = _base32Decode(secret);
      if (secretBytes.isEmpty) {
        print('❌ خطا در تبدیل سکرت Base32: $secret');
        return _generateRandomCode();
      }

      // تبدیل counter به bytes (8 bytes, big-endian)
      final counterBytes = Uint8List(8);
      var tempCounter = counter;
      for (int i = 7; i >= 0; i--) {
        counterBytes[i] = tempCounter & 0xFF;
        tempCounter >>= 8;
      }

      // تولید HMAC-SHA1
      final hmac = Hmac(sha1, secretBytes);
      final digest = hmac.convert(counterBytes);

      // Dynamic Truncation (RFC 4226 Section 5.4)
      final offset = digest.bytes[digest.bytes.length - 1] & 0x0F;

      // ترکیب 4 بایت از offset
      final code = ((digest.bytes[offset] & 0x7F) << 24) |
          ((digest.bytes[offset + 1] & 0xFF) << 16) |
          ((digest.bytes[offset + 2] & 0xFF) << 8) |
          (digest.bytes[offset + 3] & 0xFF);

      // تبدیل به کد 6 رقمی
      final codeString = (code % 1000000).toString().padLeft(6, '0');
      print('🔐 کد HOTP تولید شد: $codeString (counter: $counter)');
      return codeString;
    } catch (e) {
      print('❌ خطا در تولید کد HOTP: $e');
      return _generateRandomCode();
    }
  }

  /// تولید کد تصادفی در صورت خطا
  static String _generateRandomCode() {
    final random = Random.secure();
    return random.nextInt(1000000).toString().padLeft(6, '0');
  }

  /// تبدیل Base32 به bytes
  static Uint8List _base32Decode(String input) {
    try {
      const base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
      final inputUpper = input.toUpperCase();

      var bits = 0;
      var value = 0;
      final output = <int>[];

      for (int i = 0; i < inputUpper.length; i++) {
        final char = inputUpper[i];
        final index = base32Chars.indexOf(char);
        if (index == -1) continue;

        value = (value << 5) | index;
        bits += 5;

        if (bits >= 8) {
          output.add((value >> (bits - 8)) & 0xFF);
          bits -= 8;
        }
      }

      return Uint8List.fromList(output);
    } catch (e) {
      print('❌ خطا در تبدیل Base32: $e');
      return Uint8List(0);
    }
  }

  /// تبدیل bytes به Base32
  static String _base32Encode(Uint8List bytes) {
    try {
      const base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
      var bits = 0;
      var value = 0;
      final output = <String>[];

      for (int i = 0; i < bytes.length; i++) {
        value = (value << 8) | bytes[i];
        bits += 8;

        while (bits >= 5) {
          output.add(base32Chars[(value >> (bits - 5)) & 31]);
          bits -= 5;
        }
      }

      if (bits > 0) {
        value <<= (5 - bits);
        output.add(base32Chars[value & 31]);
      }

      return output.join();
    } catch (e) {
      print('❌ خطا در تبدیل به Base32: $e');
      return '';
    }
  }

  /// تایید کد TOTP
  static bool verifyCode(String secret, String code, {int window = 1}) {
    try {
      final now = DateTime.now();
      final timestamp = (now.millisecondsSinceEpoch / 1000).floor();
      final counter = (timestamp / _period).floor();

      // بررسی کد فعلی و کدهای قبلی/بعدی در window
      for (int i = -window; i <= window; i++) {
        final testCounter = counter + i;
        final testCode = _generateHOTP(secret, testCounter);
        if (testCode == code) {
          print('✅ کد TOTP تایید شد: $code (counter: $testCounter)');
          return true;
        }
      }

      print('❌ کد TOTP تایید نشد: $code');
      return false;
    } catch (e) {
      print('❌ خطا در تایید کد TOTP: $e');
      return false;
    }
  }

  /// تولید کدهای پشتیبان
  static List<String> generateBackupCodes({int count = 10}) {
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

  /// تولید QR Code برای اپلیکیشن‌های احراز هویت
  /// مطابق با استاندارد Google Authenticator
  static String generateQRCodeData({
    required String secret,
    required String accountName,
    required String issuer,
  }) {
    // URL encoding برای accountName و issuer
    final encodedAccountName = Uri.encodeComponent(accountName);
    final encodedIssuer = Uri.encodeComponent(issuer);

    // تولید URL TOTP استاندارد
    final uri = 'otpauth://totp/$encodedIssuer:$encodedAccountName?'
        'secret=$secret'
        '&issuer=$encodedIssuer'
        '&algorithm=$_algorithm'
        '&digits=$_digits'
        '&period=$_period';

    print('🔐 QR Data تولید شد: $uri');
    return uri;
  }

  /// بررسی اعتبار سکرت
  static bool isValidSecret(String secret) {
    try {
      // بررسی طول و فرمت
      if (secret.length < 16) return false;

      // بررسی اینکه آیا فقط حروف و اعداد Base32 است
      final validChars = RegExp(r'^[A-Z2-7]+$');
      if (!validChars.hasMatch(secret)) return false;

      // بررسی اینکه آیا می‌توان به bytes تبدیل کرد
      final bytes = _base32Decode(secret);
      return bytes.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// دریافت زمان باقی‌مانده تا کد بعدی
  static int getTimeRemaining() {
    final now = DateTime.now();
    final timestamp = (now.millisecondsSinceEpoch / 1000).floor();
    return _period - (timestamp % _period);
  }

  /// بررسی اینکه آیا کد منقضی شده یا نه
  static bool isCodeExpired(String code, String secret) {
    try {
      final now = DateTime.now();
      final timestamp = (now.millisecondsSinceEpoch / 1000).floor();
      final currentCounter = (timestamp / _period).floor();

      // بررسی کد فعلی
      final currentCode = _generateHOTP(secret, currentCounter);
      if (currentCode == code) return false;

      // بررسی کد قبلی
      final previousCounter = currentCounter - 1;
      final previousCode = _generateHOTP(secret, previousCounter);
      if (previousCode == code) return false;

      return true;
    } catch (e) {
      return true; // در صورت خطا، کد را منقضی در نظر بگیر
    }
  }

  /// تست عملکرد TOTP
  static Map<String, dynamic> testTOTP(String secret) {
    try {
      final now = DateTime.now();
      final timestamp = (now.millisecondsSinceEpoch / 1000).floor();
      final counter = (timestamp / _period).floor();

      final currentCode = _generateHOTP(secret, counter);
      final previousCode = _generateHOTP(secret, counter - 1);
      final nextCode = _generateHOTP(secret, counter + 1);

      return {
        'secret': secret,
        'secret_length': secret.length,
        'is_valid_base32': _base32Decode(secret).isNotEmpty,
        'current_counter': counter,
        'current_code': currentCode,
        'previous_code': previousCode,
        'next_code': nextCode,
        'timestamp': timestamp,
        'time_remaining': getTimeRemaining(),
        'test_verification': verifyCode(secret, currentCode),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'secret': secret,
      };
    }
  }

  /// تولید سکرت تست ثابت برای تست
  static String generateTestSecret() {
    return 'JBSWY3DPEHPK3PXP'; // سکرت تست معروف
  }

  /// تست با سکرت ثابت
  static String generateTestCode() {
    final testSecret = generateTestSecret();
    return generateCode(testSecret);
  }
}
