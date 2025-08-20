import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../lib/security/totp_service.dart';
import '../lib/model/SecurityModels.dart';

void main() {
  group('TOTP Service Tests', () {
    test('generateSecret should return non-empty string', () {
      final secret = TOTPService.generateSecret();
      expect(secret, isNotEmpty);
      expect(secret.length, greaterThanOrEqualTo(16));
      print('Generated secret: $secret');
    });

    test('generateCode should return 6-digit code', () {
      final secret = 'VISTA2FASECRET2024';
      final code = TOTPService.generateCode(secret);
      expect(code, hasLength(6));
      expect(int.tryParse(code), isNotNull);
      print('Generated code: $code for secret: $secret');
    });

    test('verifyCode should work with generated code', () {
      final secret = 'VISTA2FASECRET2024';
      final code = TOTPService.generateCode(secret);
      final isValid = TOTPService.verifyCode(secret, code);
      expect(isValid, isTrue);
      print('Code verification: $code is valid: $isValid');
    });

    test('generateBackupCodes should return 10 codes', () {
      final backupCodes = TOTPService.generateBackupCodes();
      expect(backupCodes, hasLength(10));
      for (final code in backupCodes) {
        expect(code, contains('-'));
        expect(code.length, equals(9)); // XXXX-XXXX format
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

  group('QR Code Generation Tests', () {
    test('QR data should be valid TOTP URL', () {
      final secret = 'VISTA2FASECRET2024';
      final email = 'test@vista.app';
      final issuer = 'Vista';

      final qrData =
          'otpauth://totp/$issuer:$email?secret=$secret&issuer=$issuer';

      expect(qrData, startsWith('otpauth://totp/'));
      expect(qrData, contains('secret=$secret'));
      expect(qrData, contains('issuer=$issuer'));

      print('Generated QR data: $qrData');
    });
  });
}
