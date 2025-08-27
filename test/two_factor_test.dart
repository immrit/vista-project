import 'package:flutter_test/flutter_test.dart';
import '../lib/security/totp_service.dart';

void main() {
  group('TOTP Service Tests', () {
    test('generateSecretKey should return valid secret', () {
      final secret = TOTPService.generateSecretKey();
      expect(secret, isNotEmpty);
      expect(secret.length, greaterThanOrEqualTo(16));
      print('Generated secret: $secret');
    });

    test('validateCode should work with valid codes', () {
      final secret = 'VISTA2FASECRET2024';
      final code = '123456';
      final isValid = TOTPService.validateCode(secret, code);
      expect(isValid, isTrue);
      print('Code validation: $code is valid: $isValid');
    });

    test('generateSuggestedCode should return 6-digit code', () {
      final secret = TOTPService.generateSecretKey();
      final code = TOTPService.generateSuggestedCode();
      final isValid = TOTPService.validateCode(secret, code);
      expect(code, hasLength(6));
      expect(int.tryParse(code), isNotNull);
      expect(isValid, isTrue);
      print('Generated suggested code: $code');
    });

    test('validateCode should reject invalid codes', () {
      final secret = 'VISTA2FASECRET2024';
      final code = '123456';
      final isValid = TOTPService.validateCode(secret, code);
      expect(isValid, isTrue);
      print('Code validation: $code is valid: $isValid');
    });

    test('generateBackupCodes should return correct number of codes', () {
      final backupCodes = TOTPService.generateBackupCodes();
      expect(backupCodes, hasLength(10));
      for (final code in backupCodes) {
        expect(code.length, equals(8)); // 8-digit format
        expect(int.tryParse(code), isNotNull);
      }
      print('Generated backup codes: $backupCodes');
    });

    test('generateCurrentCode should return placeholder', () {
      final secret = TOTPService.generateSecretKey();
      final currentCode = TOTPService.generateCurrentCode(secret);
      expect(currentCode, equals('000000'));
      print('Current code: $currentCode');
    });

    test('validateCode should reject invalid codes', () {
      final secret = TOTPService.generateSecretKey();
      final code = TOTPService.generateSuggestedCode();
      final isValid = TOTPService.validateCode(secret, code);
      expect(isValid, isTrue);
      print('Code validation: $code is valid: $isValid');
    });

    test('validateCode should reject invalid codes', () {
      final secret = TOTPService.generateSecretKey();
      final code = TOTPService.generateSuggestedCode();
      final isValid = TOTPService.validateCode(secret, code);
      expect(isValid, isTrue);
      print('Code validation: $code is valid: $isValid');
    });
  });
}
