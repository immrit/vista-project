import 'package:flutter_test/flutter_test.dart';

import '../lib/security/totp_service.dart';
import '../lib/model/SecurityModels.dart';

void main() {
  group('TOTP Service Tests', () {
    test('generateSecretKey should return non-empty string', () {
      final secret = TOTPService.generateSecretKey();
      expect(secret, isNotEmpty);
      expect(secret.length, greaterThanOrEqualTo(16));
      print('Generated secret: $secret');
    });

    test('generateSuggestedCode should return 6-digit code', () {
      final code = TOTPService.generateSuggestedCode();
      expect(code, hasLength(6));
      expect(int.tryParse(code), isNotNull);
      print('Generated suggested code: $code');
    });

    test('validateCode should work with 6-digit code', () {
      final secret = 'VISTA2FASECRET2024';
      final code = '123456';
      final isValid = TOTPService.validateCode(secret, code);
      expect(isValid, isTrue);
      print('Code validation: $code is valid: $isValid');
    });

    test('generateBackupCodes should return 10 codes', () {
      final backupCodes = TOTPService.generateBackupCodes();
      expect(backupCodes, hasLength(10));
      for (final code in backupCodes) {
        expect(code.length, equals(8)); // 8-digit format
        expect(int.tryParse(code), isNotNull);
      }
      print('Generated backup codes: $backupCodes');
    });
  });

  group('Security Models Tests', () {
    test('ActiveSessionModel should create valid instance', () {
      final now = DateTime.now();
      final session = ActiveSessionModel(
        id: 'test_session_1',
        userId: 'test_user_1',
        sessionToken: 'test_token_123',
        deviceType: 'Mobile',
        deviceName: 'Test Device',
        osName: 'Android',
        osVersion: '12.0',
        isCurrent: true,
        lastActivity: now,
        createdAt: now,
        loginMethod: 'password',
        isTrusted: false,
      );

      expect(session.id, equals('test_session_1'));
      expect(session.userId, equals('test_user_1'));
      expect(session.deviceType, equals('Mobile'));
      expect(session.isCurrent, isTrue);
    });

    test('ActiveSessionModel.toMap should work correctly', () {
      final now = DateTime.now();
      final session = ActiveSessionModel(
        id: 'test_session_2',
        userId: 'test_user_2',
        sessionToken: 'test_token_456',
        deviceType: 'Desktop',
        deviceName: 'Test Computer',
        osName: 'Windows',
        osVersion: '11.0',
        isCurrent: false,
        lastActivity: now,
        createdAt: now,
        loginMethod: 'app',
        isTrusted: true,
      );

      final map = session.toMap();
      expect(map['id'], equals('test_session_2'));
      expect(map['user_id'], equals('test_user_2'));
      expect(map['device_type'], equals('Desktop'));
      expect(map['is_current'], isFalse);
      expect(map['is_trusted'], isTrue);
    });
  });

  group('Code Generation Tests', () {
    test('generateCurrentCode should return placeholder', () {
      final secret = 'VISTA2FASECRET2024';
      final currentCode = TOTPService.generateCurrentCode(secret);
      expect(currentCode, equals('000000'));
      print('Current code: $currentCode');
    });

    test('validateCode should reject invalid codes', () {
      final secret = 'VISTA2FASECRET2024';

      // Test invalid length
      expect(TOTPService.validateCode(secret, '12345'), isFalse); // 5 digits
      expect(TOTPService.validateCode(secret, '1234567'), isFalse); // 7 digits

      // Test non-numeric
      expect(TOTPService.validateCode(secret, '12345a'),
          isFalse); // contains letter
      expect(
          TOTPService.validateCode(secret, '123-45'), isFalse); // contains dash

      // Test valid codes
      expect(TOTPService.validateCode(secret, '123456'), isTrue); // 6 digits
      expect(TOTPService.validateCode(secret, '000000'), isTrue); // 6 digits
    });
  });
}
