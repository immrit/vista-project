import 'package:flutter_test/flutter_test.dart';
import '../lib/security/totp_service.dart';

void main() {
  group('TOTP Service Tests', () {
    test('should generate valid secret', () {
      final secret = TOTPService.generateSecret();
      expect(secret, isNotEmpty);
      expect(secret.length, greaterThanOrEqualTo(16));
      expect(TOTPService.isValidSecret(secret), isTrue);
    });

    test('should generate valid TOTP code', () {
      final secret = TOTPService.generateSecret();
      final code = TOTPService.generateCode(secret);

      expect(code, isNotEmpty);
      expect(code.length, equals(6));
      expect(int.tryParse(code), isNotNull);
    });

    test('should verify valid TOTP code', () {
      final secret = TOTPService.generateSecret();
      final code = TOTPService.generateCode(secret);

      final isValid = TOTPService.verifyCode(secret, code);
      expect(isValid, isTrue);
    });

    test('should reject invalid TOTP code', () {
      final secret = TOTPService.generateSecret();
      final isValid = TOTPService.verifyCode(secret, '000000');
      expect(isValid, isFalse);
    });

    test('should generate backup codes', () {
      final backupCodes = TOTPService.generateBackupCodes(count: 5);

      expect(backupCodes, isNotEmpty);
      expect(backupCodes.length, equals(5));

      for (final code in backupCodes) {
        expect(code, contains('-'));
        expect(code.length, equals(9)); // XXXX-XXXX format
      }
    });

    test('should generate valid QR code data', () {
      final secret = TOTPService.generateSecret();
      final qrData = TOTPService.generateQRCodeData(
        secret: secret,
        accountName: 'test@example.com',
        issuer: 'TestApp',
      );

      expect(qrData, contains('otpauth://totp/'));
      expect(qrData, contains(secret));
      expect(qrData, contains('TestApp'));
      expect(qrData, contains('test@example.com'));
    });

    test('should get time remaining', () {
      final timeRemaining = TOTPService.getTimeRemaining();
      expect(timeRemaining, greaterThanOrEqualTo(0));
      expect(timeRemaining, lessThanOrEqualTo(30));
    });

    test('should check if code is expired', () {
      final secret = TOTPService.generateSecret();
      final currentCode = TOTPService.generateCode(secret);

      // Current code should not be expired
      expect(TOTPService.isCodeExpired(currentCode, secret), isFalse);

      // Invalid code should be considered expired
      expect(TOTPService.isCodeExpired('000000', secret), isTrue);
    });
  });
}
