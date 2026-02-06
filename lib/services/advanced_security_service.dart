import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../security/logging_utility.dart';

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

/// علت قفل شدن حساب
enum LockReason {
  failedLoginAttempts('failed_login_attempts'),
  adminAction('admin_action'),
  violation('violation'),
  suspiciousActivity('suspicious_activity'),
  spam('spam'),
  harassment('harassment'),
  other('other');

  final String value;
  const LockReason(this.value);

  String get persianName {
    switch (this) {
      case LockReason.failedLoginAttempts:
        return 'تلاش‌های ناموفق ورود';
      case LockReason.adminAction:
        return 'اقدام ادمین';
      case LockReason.violation:
        return 'تخلف';
      case LockReason.suspiciousActivity:
        return 'فعالیت مشکوک';
      case LockReason.spam:
        return 'اسپم';
      case LockReason.harassment:
        return 'آزار و اذیت';
      case LockReason.other:
        return 'سایر';
    }
  }
}

/// نوع قفل
enum LockType {
  temporary('temporary'),
  permanent('permanent'),
  admin('admin');

  final String value;
  const LockType(this.value);

  String get persianName {
    switch (this) {
      case LockType.temporary:
        return 'موقت';
      case LockType.permanent:
        return 'دائمی';
      case LockType.admin:
        return 'توسط ادمین';
    }
  }
}

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
  static const String _encryptionKeyV2 = 'encryption_key_v2';
  static const String _lastLoginKey = 'last_login';
  static const String _failedAttemptsKey = 'failed_attempts';
  static const String _lockoutUntilKey = 'lockout_until';

  static final Cipher _cipher = AesGcm.with256bits();

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
      await _generateLegacyEncryptionKeyIfMissing();
      await _generateEncryptionKeyV2IfMissing();
      logger.d('Encryption keys initialized');
    } catch (e) {
      logger.e('Failed to generate encryption keys: $e');
      rethrow;
    }
  }

  static Future<void> _generateLegacyEncryptionKeyIfMissing() async {
    final existingKey = await _storage.read(key: _encryptionKey);
    if (existingKey == null) {
      final key = _generateRandomKey();
      await _storage.write(key: _encryptionKey, value: key);
    }
  }

  static Future<void> _generateEncryptionKeyV2IfMissing() async {
    final existingKey = await _storage.read(key: _encryptionKeyV2);
    if (existingKey == null) {
      final keyBytes = _generateRandomKeyBytes(32);
      final keyB64 = base64.encode(keyBytes);
      await _storage.write(key: _encryptionKeyV2, value: keyB64);
    }
  }

  static Uint8List _generateRandomKeyBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => random.nextInt(256)));
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
      final key = await _getOrCreateEncryptionKeyV2();
      final nonce = _generateRandomKeyBytes(12);
      final secretBox = await _cipher.encrypt(
        utf8.encode(data),
        secretKey: key,
        nonce: nonce,
      );

      final encoded = 'v2:'
          '${base64.encode(secretBox.nonce)}:'
          '${base64.encode(secretBox.cipherText)}:'
          '${base64.encode(secretBox.mac.bytes)}';

      return encoded;
    } catch (e) {
      logger.e('Failed to encrypt data: $e');
      rethrow;
    }
  }

  /// Decrypt sensitive data
  static Future<String> _decryptData(String encryptedData) async {
    try {
      if (encryptedData.startsWith('v2:')) {
        final parts = encryptedData.split(':');
        if (parts.length != 4) {
          throw Exception('Invalid encrypted payload');
        }

        final nonce = base64.decode(parts[1]);
        final cipherText = base64.decode(parts[2]);
        final macBytes = base64.decode(parts[3]);

        final secretBox = SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(macBytes),
        );

        final key = await _getOrCreateEncryptionKeyV2();
        final clearBytes = await _cipher.decrypt(secretBox, secretKey: key);
        return utf8.decode(clearBytes);
      }

      // Legacy XOR decryption
      return _decryptDataLegacyXor(encryptedData);
    } catch (e) {
      logger.e('Failed to decrypt data: $e');
      rethrow;
    }
  }

  static Future<SecretKey> _getOrCreateEncryptionKeyV2() async {
    var keyB64 = await _storage.read(key: _encryptionKeyV2);
    if (keyB64 == null) {
      await _generateEncryptionKeyV2IfMissing();
      keyB64 = await _storage.read(key: _encryptionKeyV2);
    }

    if (keyB64 == null) {
      throw Exception('Failed to generate encryption key');
    }

    var keyBytes = base64.decode(keyB64);
    if (keyBytes.length != 32) {
      keyBytes = _generateRandomKeyBytes(32);
      await _storage.write(
          key: _encryptionKeyV2, value: base64.encode(keyBytes));
    }

    return SecretKey(keyBytes);
  }

  static Future<String> _decryptDataLegacyXor(String encryptedData) async {
    // Lazy initialization: if key does not exist, generate it
    var key = await _storage.read(key: _encryptionKey);
    if (key == null) {
      await _generateLegacyEncryptionKeyIfMissing();
      key = await _storage.read(key: _encryptionKey);
      if (key == null) {
        throw Exception('Failed to generate legacy encryption key');
      }
    }

    final keyBytes = utf8.encode(key);
    final encryptedBytes = base64.decode(encryptedData);
    final decrypted = <int>[];

    for (int i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return utf8.decode(decrypted);
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
  /// [userId] is optional - if provided, will also save to database
  static Future<void> recordFailedAttempt({String? userId}) async {
    try {
      final attempts = await _getFailedAttempts(userId: userId);
      final newAttempts = attempts + 1;

      // ذخیره محلی
      await _storage.write(
          key: _failedAttemptsKey, value: newAttempts.toString());

      DateTime? lockoutUntil;
      if (newAttempts >= _maxFailedAttempts) {
        lockoutUntil = DateTime.now().add(
          Duration(minutes: _lockoutDurationMinutes),
        );
        await _storage.write(
          key: _lockoutUntilKey,
          value: lockoutUntil.millisecondsSinceEpoch.toString(),
        );
        logger.w('🚫 Account locked due to too many failed attempts');
      }

      // ذخیره در دیتابیس اگر userId داده شده باشد
      if (userId != null) {
        try {
          await _saveFailedAttemptsToDatabase(
            userId: userId,
            attempts: newAttempts,
            lockoutUntil: lockoutUntil,
            lockReason:
                lockoutUntil != null ? LockReason.failedLoginAttempts : null,
          );
        } catch (e) {
          logger.w('⚠️ Failed to save to database (continuing with local): $e');
          // ادامه می‌دهیم حتی اگر دیتابیس خطا بدهد
        }
      }
    } catch (e) {
      logger.e('❌ Failed to record failed attempt: $e');
    }
  }

  /// Get failed attempts count
  /// [userId] is optional - if provided, will also check database
  static Future<int> _getFailedAttempts({String? userId}) async {
    try {
      // اول از دیتابیس بخوان (اگر userId داده شده باشد)
      if (userId != null) {
        try {
          final dbAttempts =
              await _getFailedAttemptsFromDatabase(userId: userId);
          if (dbAttempts != null) {
            // همگام‌سازی با محلی
            await _storage.write(
                key: _failedAttemptsKey, value: dbAttempts.toString());
            return dbAttempts;
          }
        } catch (e) {
          logger.w('⚠️ Failed to read from database (using local): $e');
        }
      }

      // اگر دیتابیس در دسترس نبود یا userId داده نشده، از محلی بخوان
      final attempts = await _storage.read(key: _failedAttemptsKey);
      return attempts != null ? int.parse(attempts) : 0;
    } catch (e) {
      logger.e('❌ Failed to get failed attempts: $e');
      return 0;
    }
  }

  /// Check if account is locked
  /// [userId] is optional - if provided, will also check database
  static Future<bool> isAccountLocked({String? userId}) async {
    try {
      // اول از دیتابیس چک کن (اگر userId داده شده باشد)
      if (userId != null) {
        try {
          final dbLockout = await _getLockoutFromDatabase(userId: userId);
          if (dbLockout != null) {
            final lockoutTime = DateTime.fromMillisecondsSinceEpoch(dbLockout);
            if (DateTime.now().isBefore(lockoutTime)) {
              // همگام‌سازی با محلی
              await _storage.write(
                  key: _lockoutUntilKey, value: dbLockout.toString());
              return true;
            } else {
              // Lockout expired, clear it
              await clearFailedAttempts(userId: userId);
              return false;
            }
          }
        } catch (e) {
          logger.w('⚠️ Failed to check database (using local): $e');
        }
      }

      // اگر دیتابیس در دسترس نبود یا userId داده نشده، از محلی چک کن
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
          // پاک کردن از دیتابیس هم
          if (userId != null) {
            try {
              await clearFailedAttempts(userId: userId);
            } catch (e) {
              logger.w('⚠️ Failed to clear from database: $e');
            }
          }
        }
      }
      return false;
    } catch (e) {
      logger.e('❌ Failed to check account lock status: $e');
      return false;
    }
  }

  /// Get remaining lockout time
  /// [userId] is optional - if provided, will also check database
  static Future<Duration?> getRemainingLockoutTime({String? userId}) async {
    try {
      // اول از دیتابیس بخوان (اگر userId داده شده باشد)
      if (userId != null) {
        try {
          final dbLockout = await _getLockoutFromDatabase(userId: userId);
          if (dbLockout != null) {
            final lockoutTime = DateTime.fromMillisecondsSinceEpoch(dbLockout);
            final now = DateTime.now();
            if (now.isBefore(lockoutTime)) {
              // همگام‌سازی با محلی
              await _storage.write(
                  key: _lockoutUntilKey, value: dbLockout.toString());
              return lockoutTime.difference(now);
            }
          }
        } catch (e) {
          logger.w('⚠️ Failed to read from database (using local): $e');
        }
      }

      // اگر دیتابیس در دسترس نبود یا userId داده نشده، از محلی بخوان
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
  /// [userId] is optional - if provided, will also clear from database
  static Future<void> clearFailedAttempts({String? userId}) async {
    try {
      // پاک کردن محلی
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lockoutUntilKey);

      // پاک کردن از دیتابیس اگر userId داده شده باشد
      if (userId != null) {
        try {
          await _clearFailedAttemptsFromDatabase(userId: userId);
        } catch (e) {
          logger.w('⚠️ Failed to clear from database: $e');
          // ادامه می‌دهیم حتی اگر دیتابیس خطا بدهد
        }
      }

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
        logInfo('Security Log: $logEntry');
      }
    } catch (e) {
      logger.e('❌ Failed to log security event: $e');
    }
  }

  // ==================== Database Methods ====================

  /// Save failed attempts to database
  static Future<void> _saveFailedAttemptsToDatabase({
    required String userId,
    required int attempts,
    DateTime? lockoutUntil,
    LockReason? lockReason,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final updateData = <String, dynamic>{
        'failed_attempts': attempts,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (lockoutUntil != null) {
        updateData['lockout_until'] = lockoutUntil.toIso8601String();
        updateData['lock_reason'] =
            lockReason?.value ?? LockReason.failedLoginAttempts.value;
        updateData['lock_type'] = LockType.temporary.value;
        updateData['locked_by'] = 'system';
        updateData['locked_at'] = DateTime.now().toIso8601String();
      }

      await supabase.from('profiles').update(updateData).eq('id', userId);

      logger.d('💾 Saved failed attempts to database for user: $userId');
    } catch (e) {
      // اگر فیلدها وجود ندارند، سعی نکنیم خطا بدهیم
      if (e.toString().contains('column') ||
          e.toString().contains('does not exist')) {
        logger.w(
            '⚠️ Security columns may not exist in database yet. Please run the migration SQL.');
      } else {
        rethrow;
      }
    }
  }

  /// Get failed attempts from database
  static Future<int?> _getFailedAttemptsFromDatabase(
      {required String userId}) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('profiles')
          .select('failed_attempts')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && response['failed_attempts'] != null) {
        return response['failed_attempts'] as int;
      }
      return null;
    } catch (e) {
      if (e.toString().contains('column') ||
          e.toString().contains('does not exist')) {
        logger.w('⚠️ Security columns may not exist in database yet.');
        return null;
      }
      rethrow;
    }
  }

  /// Get lockout time from database
  static Future<int?> _getLockoutFromDatabase({required String userId}) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('profiles')
          .select('lockout_until')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && response['lockout_until'] != null) {
        final lockoutStr = response['lockout_until'] as String;
        final lockoutTime = DateTime.parse(lockoutStr);
        return lockoutTime.millisecondsSinceEpoch;
      }
      return null;
    } catch (e) {
      if (e.toString().contains('column') ||
          e.toString().contains('does not exist')) {
        logger.w('⚠️ Security columns may not exist in database yet.');
        return null;
      }
      rethrow;
    }
  }

  /// Clear failed attempts from database
  static Future<void> _clearFailedAttemptsFromDatabase(
      {required String userId}) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('profiles').update({
        'failed_attempts': null,
        'lockout_until': null,
        'lock_reason': null,
        'lock_type': null,
        'locked_by': null,
        'lock_notes': null,
        'locked_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      logger.d('💾 Cleared failed attempts from database for user: $userId');
    } catch (e) {
      if (e.toString().contains('column') ||
          e.toString().contains('does not exist')) {
        logger.w('⚠️ Security columns may not exist in database yet.');
      } else {
        rethrow;
      }
    }
  }

  // ==================== Admin Lock Methods ====================

  /// قفل کردن حساب کاربر توسط ادمین
  ///
  /// [userId] شناسه کاربری که باید قفل شود
  /// [reason] علت قفل شدن
  /// [lockType] نوع قفل (موقت، دائمی، یا ادمین)
  /// [duration] مدت زمان قفل (فقط برای قفل موقت)
  /// [notes] یادداشت/توضیحات
  /// [adminId] شناسه ادمینی که قفل می‌کند (اختیاری - اگر null باشد از currentUser استفاده می‌شود)
  static Future<void> lockUserByAdmin({
    required String userId,
    required LockReason reason,
    LockType lockType = LockType.admin,
    Duration? duration,
    String? notes,
    String? adminId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // اگر adminId داده نشده، از کاربر فعلی استفاده کن
      final adminUserId = adminId ?? supabase.auth.currentUser?.id;
      if (adminUserId == null) {
        throw Exception('Admin ID is required');
      }

      DateTime? lockoutUntil;
      if (lockType == LockType.temporary && duration != null) {
        lockoutUntil = DateTime.now().add(duration);
      } else if (lockType == LockType.permanent) {
        // برای قفل دائمی، یک تاریخ خیلی دور در آینده تنظیم می‌کنیم
        lockoutUntil =
            DateTime.now().add(const Duration(days: 365 * 100)); // 100 سال
      }

      await supabase.from('profiles').update({
        'lockout_until': lockoutUntil?.toIso8601String(),
        'lock_reason': reason.value,
        'lock_type': lockType.value,
        'locked_by': adminUserId,
        'lock_notes': notes,
        'locked_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // همگام‌سازی با محلی (اگر کاربر همان کاربری است که قفل شده)
      try {
        final currentUserId = supabase.auth.currentUser?.id;
        if (currentUserId == userId) {
          if (lockoutUntil != null) {
            await _storage.write(
              key: _lockoutUntilKey,
              value: lockoutUntil.millisecondsSinceEpoch.toString(),
            );
          }
        }
      } catch (e) {
        logger.w('⚠️ Failed to sync to local storage: $e');
      }

      logger
          .i('🔒 User locked by admin: $userId, Reason: ${reason.persianName}');
    } catch (e) {
      logger.e('❌ Failed to lock user by admin: $e');
      rethrow;
    }
  }

  /// باز کردن قفل حساب کاربر
  ///
  /// [userId] شناسه کاربری که باید قفل آن باز شود
  /// [adminId] شناسه ادمینی که قفل را باز می‌کند (اختیاری)
  static Future<void> unlockUser({
    required String userId,
    String? adminId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // اگر adminId داده نشده، از کاربر فعلی استفاده کن
      final adminUserId = adminId ?? supabase.auth.currentUser?.id;
      if (adminUserId == null) {
        throw Exception('Admin ID is required');
      }

      await supabase.from('profiles').update({
        'lockout_until': null,
        'lock_reason': null,
        'lock_type': null,
        'locked_by': null,
        'lock_notes': null,
        'locked_at': null,
        'failed_attempts': 0, // پاک کردن تلاش‌های ناموفق هم
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // همگام‌سازی با محلی
      try {
        final currentUserId = supabase.auth.currentUser?.id;
        if (currentUserId == userId) {
          await _storage.delete(key: _lockoutUntilKey);
          await _storage.delete(key: _failedAttemptsKey);
        }
      } catch (e) {
        logger.w('⚠️ Failed to sync to local storage: $e');
      }

      logger.i('🔓 User unlocked by admin: $userId');
    } catch (e) {
      logger.e('❌ Failed to unlock user: $e');
      rethrow;
    }
  }

  /// دریافت اطلاعات قفل حساب کاربر
  ///
  /// [userId] شناسه کاربر
  ///
  /// Returns: Map شامل اطلاعات قفل یا null اگر قفل نشده باشد
  static Future<Map<String, dynamic>?> getLockInfo(
      {required String userId}) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('profiles')
          .select(
              'lockout_until, lock_reason, lock_type, locked_by, lock_notes, locked_at')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final lockoutUntil = response['lockout_until'] as String?;
      if (lockoutUntil == null) {
        return null;
      }

      final lockTime = DateTime.parse(lockoutUntil);
      final isLocked = DateTime.now().isBefore(lockTime);

      if (!isLocked) {
        return null; // قفل منقضی شده
      }

      return {
        'lockout_until': lockoutUntil,
        'lock_reason': response['lock_reason'] as String?,
        'lock_type': response['lock_type'] as String?,
        'locked_by': response['locked_by'] as String?,
        'lock_notes': response['lock_notes'] as String?,
        'locked_at': response['locked_at'] as String?,
        'remaining_time': lockTime.difference(DateTime.now()),
      };
    } catch (e) {
      logger.e('❌ Failed to get lock info: $e');
      return null;
    }
  }

  /// دریافت علت قفل شدن به فارسی
  static Future<String?> getLockReasonPersian({required String userId}) async {
    final lockInfo = await getLockInfo(userId: userId);
    if (lockInfo == null) return null;

    final reasonStr = lockInfo['lock_reason'] as String?;
    if (reasonStr == null) return null;

    try {
      final reason = LockReason.values.firstWhere(
        (r) => r.value == reasonStr,
        orElse: () => LockReason.other,
      );
      return reason.persianName;
    } catch (e) {
      return 'نامشخص';
    }
  }
}
