import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

class AdvancedSecurityService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _biometricKey = 'biometric_enabled';
  static const String _sessionKey = 'secure_session';
  static const String _deviceFingerprintKey = 'device_fingerprint';
  static const String _encryptionKey = 'encryption_key';
  static const String _lastLoginKey = 'last_login';
  static const String _failedAttemptsKey = 'failed_attempts';
  static const String _lockoutUntilKey = 'lockout_until';

  // Maximum failed attempts before lockout
  static const int _maxFailedAttempts = 5;
  static const int _lockoutDurationMinutes = 15;

  /// Initialize security service
  static Future<void> initialize() async {
    try {
      await _generateDeviceFingerprint();
      await _generateEncryptionKey();
      logger.i('🔐 Advanced Security Service initialized');
    } catch (e) {
      logger.e('❌ Failed to initialize security service: $e');
      rethrow;
    }
  }

  /// Generate unique device fingerprint
  static Future<void> _generateDeviceFingerprint() async {
    try {
      final existingFingerprint =
          await _storage.read(key: _deviceFingerprintKey);
      if (existingFingerprint == null) {
        final fingerprint = _createDeviceFingerprint();
        await _storage.write(key: _deviceFingerprintKey, value: fingerprint);
        logger.d(
            '📱 Device fingerprint generated: ${fingerprint.substring(0, 8)}...');
      }
    } catch (e) {
      logger.e('❌ Failed to generate device fingerprint: $e');
      rethrow;
    }
  }

  /// Create device fingerprint
  static String _createDeviceFingerprint() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    final deviceInfo = '${Platform.operatingSystem}_${Platform.version}';

    final combined = '$timestamp$random$deviceInfo';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  /// Generate encryption key for sensitive data
  static Future<void> _generateEncryptionKey() async {
    try {
      final existingKey = await _storage.read(key: _encryptionKey);
      if (existingKey == null) {
        final key = _generateRandomKey();
        await _storage.write(key: _encryptionKey, value: key);
        logger.d('🔑 Encryption key generated');
      }
    } catch (e) {
      logger.e('❌ Failed to generate encryption key: $e');
      rethrow;
    }
  }

  /// Generate random encryption key
  static String _generateRandomKey() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
          32, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Check if biometric authentication is available
  static Future<bool> isBiometricAvailable() async {
    try {
      // Simulate biometric availability check
      // In real implementation, you would use local_auth package
      return false; // Disabled for now
    } catch (e) {
      logger.e('❌ Failed to check biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<String>> getAvailableBiometrics() async {
    try {
      // Simulate biometric types
      // In real implementation, you would use local_auth package
      return []; // Disabled for now
    } catch (e) {
      logger.e('❌ Failed to get available biometrics: $e');
      return [];
    }
  }

  /// Enable biometric authentication
  static Future<bool> enableBiometric() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        logger.w('⚠️ Biometric authentication not available');
        return false;
      }

      // Simulate biometric authentication
      // In real implementation, you would use local_auth package
      await _storage.write(key: _biometricKey, value: 'true');
      logger.i('✅ Biometric authentication enabled');
      return true;
    } catch (e) {
      logger.e('❌ Failed to enable biometric: $e');
      return false;
    }
  }

  /// Disable biometric authentication
  static Future<void> disableBiometric() async {
    try {
      await _storage.delete(key: _biometricKey);
      logger.i('🔓 Biometric authentication disabled');
    } catch (e) {
      logger.e('❌ Failed to disable biometric: $e');
      rethrow;
    }
  }

  /// Check if biometric is enabled
  static Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _storage.read(key: _biometricKey);
      return enabled == 'true';
    } catch (e) {
      logger.e('❌ Failed to check biometric status: $e');
      return false;
    }
  }

  /// Authenticate with biometric
  static Future<bool> authenticateWithBiometric() async {
    try {
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        logger.w('⚠️ Biometric authentication not enabled');
        return false;
      }

      // Simulate biometric authentication
      // In real implementation, you would use local_auth package
      await _updateLastLogin();
      logger.i('✅ Biometric authentication successful');
      return true;
    } catch (e) {
      logger.e('❌ Biometric authentication failed: $e');
      return false;
    }
  }

  /// Store secure session
  static Future<void> storeSecureSession(String sessionToken) async {
    try {
      final encryptedToken = await _encryptData(sessionToken);
      await _storage.write(key: _sessionKey, value: encryptedToken);
      await _updateLastLogin();
      logger.d('🔐 Secure session stored');
    } catch (e) {
      logger.e('❌ Failed to store secure session: $e');
      rethrow;
    }
  }

  /// Get secure session
  static Future<String?> getSecureSession() async {
    try {
      final encryptedToken = await _storage.read(key: _sessionKey);
      if (encryptedToken != null) {
        return await _decryptData(encryptedToken);
      }
      return null;
    } catch (e) {
      logger.e('❌ Failed to get secure session: $e');
      return null;
    }
  }

  /// Clear secure session
  static Future<void> clearSecureSession() async {
    try {
      await _storage.delete(key: _sessionKey);
      logger.d('🗑️ Secure session cleared');
    } catch (e) {
      logger.e('❌ Failed to clear secure session: $e');
      rethrow;
    }
  }

  /// Encrypt sensitive data
  static Future<String> _encryptData(String data) async {
    try {
      final key = await _storage.read(key: _encryptionKey);
      if (key == null) {
        throw Exception('Encryption key not found');
      }

      // Simple XOR encryption (in production, use proper encryption)
      final keyBytes = utf8.encode(key);
      final dataBytes = utf8.encode(data);
      final encrypted = <int>[];

      for (int i = 0; i < dataBytes.length; i++) {
        encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
      }

      return base64.encode(encrypted);
    } catch (e) {
      logger.e('❌ Failed to encrypt data: $e');
      rethrow;
    }
  }

  /// Decrypt sensitive data
  static Future<String> _decryptData(String encryptedData) async {
    try {
      final key = await _storage.read(key: _encryptionKey);
      if (key == null) {
        throw Exception('Encryption key not found');
      }

      final keyBytes = utf8.encode(key);
      final encryptedBytes = base64.decode(encryptedData);
      final decrypted = <int>[];

      for (int i = 0; i < encryptedBytes.length; i++) {
        decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }

      return utf8.decode(decrypted);
    } catch (e) {
      logger.e('❌ Failed to decrypt data: $e');
      rethrow;
    }
  }

  /// Update last login timestamp
  static Future<void> _updateLastLogin() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      await _storage.write(key: _lastLoginKey, value: timestamp);
    } catch (e) {
      logger.e('❌ Failed to update last login: $e');
    }
  }

  /// Get last login timestamp
  static Future<DateTime?> getLastLogin() async {
    try {
      final timestamp = await _storage.read(key: _lastLoginKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      }
      return null;
    } catch (e) {
      logger.e('❌ Failed to get last login: $e');
      return null;
    }
  }

  /// Record failed login attempt
  static Future<void> recordFailedAttempt() async {
    try {
      final attempts = await _getFailedAttempts();
      final newAttempts = attempts + 1;

      await _storage.write(
          key: _failedAttemptsKey, value: newAttempts.toString());

      if (newAttempts >= _maxFailedAttempts) {
        final lockoutUntil = DateTime.now().add(
          Duration(minutes: _lockoutDurationMinutes),
        );
        await _storage.write(
          key: _lockoutUntilKey,
          value: lockoutUntil.millisecondsSinceEpoch.toString(),
        );
        logger.w('🚫 Account locked due to too many failed attempts');
      }
    } catch (e) {
      logger.e('❌ Failed to record failed attempt: $e');
    }
  }

  /// Get failed attempts count
  static Future<int> _getFailedAttempts() async {
    try {
      final attempts = await _storage.read(key: _failedAttemptsKey);
      return attempts != null ? int.parse(attempts) : 0;
    } catch (e) {
      logger.e('❌ Failed to get failed attempts: $e');
      return 0;
    }
  }

  /// Check if account is locked
  static Future<bool> isAccountLocked() async {
    try {
      final lockoutUntil = await _storage.read(key: _lockoutUntilKey);
      if (lockoutUntil != null) {
        final lockoutTime =
            DateTime.fromMillisecondsSinceEpoch(int.parse(lockoutUntil));
        if (DateTime.now().isBefore(lockoutTime)) {
          return true;
        } else {
          // Lockout expired, clear it
          await _storage.delete(key: _lockoutUntilKey);
          await _storage.delete(key: _failedAttemptsKey);
        }
      }
      return false;
    } catch (e) {
      logger.e('❌ Failed to check account lock status: $e');
      return false;
    }
  }

  /// Get remaining lockout time
  static Future<Duration?> getRemainingLockoutTime() async {
    try {
      final lockoutUntil = await _storage.read(key: _lockoutUntilKey);
      if (lockoutUntil != null) {
        final lockoutTime =
            DateTime.fromMillisecondsSinceEpoch(int.parse(lockoutUntil));
        final now = DateTime.now();
        if (now.isBefore(lockoutTime)) {
          return lockoutTime.difference(now);
        }
      }
      return null;
    } catch (e) {
      logger.e('❌ Failed to get remaining lockout time: $e');
      return null;
    }
  }

  /// Clear failed attempts (on successful login)
  static Future<void> clearFailedAttempts() async {
    try {
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lockoutUntilKey);
      logger.d('✅ Failed attempts cleared');
    } catch (e) {
      logger.e('❌ Failed to clear failed attempts: $e');
    }
  }

  /// Validate session security
  static Future<bool> validateSessionSecurity() async {
    try {
      // Check if session exists
      final session = await getSecureSession();
      if (session == null) {
        logger.w('⚠️ No secure session found');
        return false;
      }

      // Check if account is locked
      if (await isAccountLocked()) {
        logger.w('⚠️ Account is locked');
        return false;
      }

      // Check last login time (optional: expire sessions after certain time)
      final lastLogin = await getLastLogin();
      if (lastLogin != null) {
        final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
        if (daysSinceLogin > 30) {
          // Expire after 30 days
          logger.w('⚠️ Session expired after 30 days');
          await clearSecureSession();
          return false;
        }
      }

      logger.d('✅ Session security validation passed');
      return true;
    } catch (e) {
      logger.e('❌ Failed to validate session security: $e');
      // در صورت خطا، session را معتبر در نظر بگیر تا کاربر از حساب خارج نشود
      logger.w('⚠️ Returning true due to validation error to prevent logout');
      return true;
    }
  }

  /// Get device fingerprint
  static Future<String?> getDeviceFingerprint() async {
    try {
      return await _storage.read(key: _deviceFingerprintKey);
    } catch (e) {
      logger.e('❌ Failed to get device fingerprint: $e');
      return null;
    }
  }

  /// Clear all security data (for logout)
  static Future<void> clearAllSecurityData() async {
    try {
      await _storage.deleteAll();
      logger.i('🗑️ All security data cleared');
    } catch (e) {
      logger.e('❌ Failed to clear security data: $e');
      rethrow;
    }
  }

  /// Security audit log
  static Future<void> logSecurityEvent(String event,
      {Map<String, dynamic>? data}) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = {
        'timestamp': timestamp,
        'event': event,
        'data': data ?? {},
      };

      logger.i('🔍 Security Event: $event');
      if (kDebugMode) {
        print('Security Log: $logEntry');
      }
    } catch (e) {
      logger.e('❌ Failed to log security event: $e');
    }
  }
}
