import 'package:Vista/core/security/input_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeDigits', () {
    test('normalizes Persian and Arabic digits', () {
      expect(
        normalizeDigits(
            '\u06F0\u06F9\u06F1\u06F2\u0663\u0664\u0665\u06F6\u06F7\u06F8\u06F9'),
        '09123456789',
      );
    });
  });

  group('normalizePhone09', () {
    test('accepts local phone format', () {
      expect(normalizePhone09('09123456789'), '09123456789');
    });

    test('normalizes +98 to local 09 format', () {
      expect(normalizePhone09('+989123456789'), '09123456789');
    });

    test('rejects invalid format', () {
      expect(normalizePhone09('9123456789'), isNull);
      expect(normalizePhone09('0912abc6789'), isNull);
    });
  });

  group('validateUsername', () {
    test('accepts valid username', () {
      final result = validateUsername('vista.user_01');
      expect(result.isValid, isTrue);
    });

    test('rejects uppercase username', () {
      final result = validateUsername('VistaUser');
      expect(result.isValid, isFalse);
      expect(result.reasonCode, 'username_lowercase_only');
    });

    test('rejects reserved username', () {
      final result = validateUsername('admin');
      expect(result.isValid, isFalse);
      expect(result.reasonCode, 'username_reserved');
    });

    test('rejects double dot', () {
      final result = validateUsername('vista..user');
      expect(result.isValid, isFalse);
      expect(result.reasonCode, 'username_double_dot');
    });
  });

  group('validatePasswordBalanced', () {
    test('accepts balanced password', () {
      final result = validatePasswordBalanced('Abcdef1!');
      expect(result.isValid, isTrue);
    });

    test('rejects short password', () {
      final result = validatePasswordBalanced('Aa1!');
      expect(result.isValid, isFalse);
      expect(result.reasonCode, 'password_length');
    });

    test('rejects low category password', () {
      final result = validatePasswordBalanced('abcdefgh');
      expect(result.isValid, isFalse);
      expect(result.reasonCode, 'password_category');
    });
  });

  group('sanitizeProfilePayload', () {
    test('removes null and invalid sensitive fields', () {
      final sanitized = sanitizeProfilePayload({
        'username': '_invalid',
        'email': '',
        'full_name': '   ',
        'phone_number': '9123456789',
        'bio': '',
        'id': 'abc',
      });

      expect(sanitized.containsKey('username'), isFalse);
      expect(sanitized.containsKey('email'), isFalse);
      expect(sanitized.containsKey('full_name'), isFalse);
      expect(sanitized.containsKey('phone_number'), isFalse);
      expect(sanitized['bio'], '');
      expect(sanitized['id'], 'abc');
    });

    test('normalizes valid phone and username', () {
      final sanitized = sanitizeProfilePayload({
        'username': 'vista_user',
        'phone_number': '+989123456789',
      });

      expect(sanitized['username'], 'vista_user');
      expect(sanitized['phone_number'], '09123456789');
    });
  });
}
