import 'dart:convert';

import 'package:flutter/material.dart';

/// مدل اطلاعات امنیتی کاربر
class UserSecurityModel {
  final String id;
  final String userId;
  final bool twoFactorEnabled;
  final String? twoFactorSecret;
  final String? userCode;
  final String? backupCodes; // Changed from List<String> to String to match DB
  final DateTime? twoFactorSetupAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? loginAttempts;
  final DateTime? lastLoginAttempt;
  final bool? accountLocked;
  final DateTime? lockExpiresAt;
  final int? maxLoginAttempts;
  final int? lockDurationMinutes;

  UserSecurityModel({
    required this.id,
    required this.userId,
    required this.twoFactorEnabled,
    this.twoFactorSecret,
    this.userCode,
    this.backupCodes,
    this.twoFactorSetupAt,
    required this.createdAt,
    required this.updatedAt,
    this.loginAttempts,
    this.lastLoginAttempt,
    this.accountLocked,
    this.lockExpiresAt,
    this.maxLoginAttempts,
    this.lockDurationMinutes,
  });

  factory UserSecurityModel.fromMap(Map<String, dynamic> map) {
    try {
      debugPrint('🔍 Creating UserSecurityModel from map: $map');

      final model = UserSecurityModel(
        id: map['id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        twoFactorEnabled: map['two_factor_enabled'] == true,
        twoFactorSecret: map['two_factor_secret']?.toString(),
        userCode: map['user_code']?.toString(),
        backupCodes: map['backup_codes']?.toString(),
        twoFactorSetupAt: map['two_factor_setup_at'] != null
            ? DateTime.parse(map['two_factor_setup_at'].toString())
            : null,
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
        loginAttempts: map['login_attempts'] is int
            ? map['login_attempts']
            : int.tryParse(map['login_attempts']?.toString() ?? '0'),
        lastLoginAttempt: map['last_login_attempt'] != null
            ? DateTime.parse(map['last_login_attempt'].toString())
            : null,
        accountLocked: map['account_locked'] == true,
        lockExpiresAt: map['lock_expires_at'] != null
            ? DateTime.parse(map['lock_expires_at'].toString())
            : null,
        maxLoginAttempts: map['max_login_attempts'] is int
            ? map['max_login_attempts']
            : int.tryParse(map['max_login_attempts']?.toString() ?? '5'),
        lockDurationMinutes: map['lock_duration_minutes'] is int
            ? map['lock_duration_minutes']
            : int.tryParse(map['lock_duration_minutes']?.toString() ?? '30'),
      );

      debugPrint('✅ UserSecurityModel با موفقیت ایجاد شد');
      return model;
    } catch (e, stackTrace) {
      debugPrint('❌ خطا در UserSecurityModel.fromMap: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'two_factor_enabled': twoFactorEnabled,
      'two_factor_secret': twoFactorSecret,
      'user_code': userCode,
      'backup_codes': backupCodes,
      'two_factor_setup_at': twoFactorSetupAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'login_attempts': loginAttempts,
      'last_login_attempt': lastLoginAttempt?.toIso8601String(),
      'account_locked': accountLocked,
      'lock_expires_at': lockExpiresAt?.toIso8601String(),
      'max_login_attempts': maxLoginAttempts,
      'lock_duration_minutes': lockDurationMinutes,
    };
  }

  String toJson() => json.encode(toMap());

  factory UserSecurityModel.fromJson(String source) =>
      UserSecurityModel.fromMap(json.decode(source));

  UserSecurityModel copyWith({
    String? id,
    String? userId,
    bool? twoFactorEnabled,
    String? twoFactorSecret,
    String? userCode,
    String? backupCodes,
    DateTime? twoFactorSetupAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? loginAttempts,
    DateTime? lastLoginAttempt,
    bool? accountLocked,
    DateTime? lockExpiresAt,
    int? maxLoginAttempts,
    int? lockDurationMinutes,
  }) {
    return UserSecurityModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      twoFactorSecret: twoFactorSecret ?? this.twoFactorSecret,
      userCode: userCode ?? this.userCode,
      backupCodes: backupCodes ?? this.backupCodes,
      twoFactorSetupAt: twoFactorSetupAt ?? this.twoFactorSetupAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      loginAttempts: loginAttempts ?? this.loginAttempts,
      lastLoginAttempt: lastLoginAttempt ?? this.lastLoginAttempt,
      accountLocked: accountLocked ?? this.accountLocked,
      lockExpiresAt: lockExpiresAt ?? this.lockExpiresAt,
      maxLoginAttempts: maxLoginAttempts ?? this.maxLoginAttempts,
      lockDurationMinutes: lockDurationMinutes ?? this.lockDurationMinutes,
    );
  }

  /// بررسی اینکه حساب قفل شده یا نه
  bool get isLocked {
    if (lockExpiresAt == null) return false;
    return DateTime.now().isBefore(lockExpiresAt!);
  }

  /// بررسی اینکه آیا 2FA فعال و تنظیم شده یا نه
  bool get isTwoFactorSetup {
    return twoFactorEnabled && twoFactorSecret != null;
  }

  /// تبدیل backup_codes از رشته به لیست
  List<String> get backupCodesList {
    if (backupCodes == null || backupCodes!.isEmpty) return [];
    return backupCodes!.split(',').map((e) => e.trim()).toList();
  }

  /// تبدیل لیست به رشته برای ذخیره در دیتابیس
  static String backupCodesToString(List<String> codes) {
    return codes.join(',');
  }
}

/// مدل جلسات فعال
class ActiveSessionModel {
  final String id;
  final String userId;
  final String sessionToken;
  final String? refreshTokenHash;
  final String? deviceType; // 'mobile', 'web', 'desktop'
  final String? deviceName;
  final String? osName;
  final String? osVersion;
  final String? appVersion;
  final String? ipAddress;
  final Map<String, dynamic>? location;
  final bool isCurrent;
  final DateTime lastActivity;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? browserInfo;
  final String? platform;
  final bool isTrusted;
  final String loginMethod;
  final Map<String, dynamic>? sessionMetadata;

  ActiveSessionModel({
    required this.id,
    required this.userId,
    required this.sessionToken,
    this.refreshTokenHash,
    this.deviceType,
    this.deviceName,
    this.osName,
    this.osVersion,
    this.appVersion,
    this.ipAddress,
    this.location,
    required this.isCurrent,
    required this.lastActivity,
    required this.createdAt,
    this.expiresAt,
    this.browserInfo,
    this.platform,
    this.isTrusted = false,
    this.loginMethod = 'password',
    this.sessionMetadata,
  });

  factory ActiveSessionModel.fromMap(Map<String, dynamic> map) {
    try {
      // بررسی فیلدهای اجباری
      if (map['id'] == null ||
          map['user_id'] == null ||
          map['session_token'] == null) {
        debugPrint('❌ فیلدهای اجباری در ActiveSessionModel موجود نیستند: $map');
        throw Exception('فیلدهای اجباری در ActiveSessionModel موجود نیستند');
      }

      // مدیریت فیلدهای تاریخ با مقدار پیش‌فرض
      final now = DateTime.now();
      DateTime lastActivity;
      DateTime createdAt;
      DateTime? expiresAt;

      try {
        lastActivity = map['last_activity'] != null
            ? DateTime.parse(map['last_activity'].toString())
            : now;
      } catch (e) {
        debugPrint('⚠️ خطا در پارس last_activity، استفاده از زمان فعلی: $e');
        lastActivity = now;
      }

      try {
        createdAt = map['created_at'] != null
            ? DateTime.parse(map['created_at'].toString())
            : now;
      } catch (e) {
        debugPrint('⚠️ خطا در پارس created_at، استفاده از زمان فعلی: $e');
        createdAt = now;
      }

      try {
        expiresAt = map['expires_at'] != null
            ? DateTime.parse(map['expires_at'].toString())
            : null;
      } catch (e) {
        debugPrint('⚠️ خطا در پارس expires_at، تنظیم null: $e');
        expiresAt = null;
      }

      return ActiveSessionModel(
        id: map['id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        sessionToken: map['session_token']?.toString() ?? '',
        refreshTokenHash: map['refresh_token_hash']?.toString(),
        deviceType: map['device_type']?.toString(),
        deviceName: map['device_name']?.toString(),
        osName: map['os_name']?.toString(),
        osVersion: map['os_version']?.toString(),
        appVersion: map['app_version']?.toString(),
        ipAddress: map['ip_address']?.toString(),
        location: map['location'] != null
            ? Map<String, dynamic>.from(map['location'])
            : null,
        isCurrent: map['is_current'] ?? false,
        lastActivity: lastActivity,
        createdAt: createdAt,
        expiresAt: expiresAt,
        browserInfo: map['browser_info']?.toString(),
        platform: map['platform']?.toString(),
        isTrusted: map['is_trusted'] ?? false,
        loginMethod: map['login_method']?.toString() ?? 'password',
        sessionMetadata: map['session_metadata'] != null
            ? Map<String, dynamic>.from(map['session_metadata'])
            : null,
      );
    } catch (e) {
      debugPrint('❌ خطا در ایجاد ActiveSessionModel: $e');
      debugPrint('📄 داده ورودی: $map');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'session_token': sessionToken,
      'refresh_token_hash': refreshTokenHash,
      'device_type': deviceType,
      'device_name': deviceName,
      'os_name': osName,
      'os_version': osVersion,
      'app_version': appVersion,
      'ip_address': ipAddress,
      'location': location,
      'is_current': isCurrent,
      'last_activity': lastActivity.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'browser_info': browserInfo,
      'platform': platform,
      'is_trusted': isTrusted,
      'login_method': loginMethod,
      'session_metadata': sessionMetadata,
    };
  }

  String toJson() => json.encode(toMap());

  factory ActiveSessionModel.fromJson(String source) =>
      ActiveSessionModel.fromMap(json.decode(source));

  /// بررسی اینکه آیا جلسه منقضی شده یا نه
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// مدت زمان آخرین فعالیت
  Duration get timeSinceLastActivity {
    return DateTime.now().difference(lastActivity);
  }

  /// آیکون دستگاه بر اساس نوع
  String get deviceIcon {
    switch (deviceType?.toLowerCase()) {
      case 'mobile':
        return '📱';
      case 'web':
        return '🌐';
      case 'desktop':
        return '💻';
      default:
        return '📟';
    }
  }

  /// بررسی اینکه آیا نشست در 24 ساعت گذشته فعال بوده
  bool get isRecentlyActive {
    return timeSinceLastActivity.inHours < 24;
  }

  /// مدت زمان باقی‌مانده تا انقضا
  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  /// نمایش وضعیت نشست
  String get statusText {
    if (isExpired) return 'منقضی شده';
    if (isCurrent) return 'فعلی';
    if (isRecentlyActive) return 'فعال اخیر';
    return 'غیرفعال';
  }

  /// کپی کردن با تغییرات
  ActiveSessionModel copyWith({
    String? id,
    String? userId,
    String? sessionToken,
    String? refreshTokenHash,
    String? deviceType,
    String? deviceName,
    String? osName,
    String? osVersion,
    String? appVersion,
    String? ipAddress,
    Map<String, dynamic>? location,
    bool? isCurrent,
    DateTime? lastActivity,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? browserInfo,
    String? platform,
    bool? isTrusted,
    String? loginMethod,
    Map<String, dynamic>? sessionMetadata,
  }) {
    return ActiveSessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionToken: sessionToken ?? this.sessionToken,
      refreshTokenHash: refreshTokenHash ?? this.refreshTokenHash,
      deviceType: deviceType ?? this.deviceType,
      deviceName: deviceName ?? this.deviceName,
      osName: osName ?? this.osName,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      ipAddress: ipAddress ?? this.ipAddress,
      location: location ?? this.location,
      isCurrent: isCurrent ?? this.isCurrent,
      lastActivity: lastActivity ?? this.lastActivity,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      browserInfo: browserInfo ?? this.browserInfo,
      platform: platform ?? this.platform,
      isTrusted: isTrusted ?? this.isTrusted,
      loginMethod: loginMethod ?? this.loginMethod,
      sessionMetadata: sessionMetadata ?? this.sessionMetadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActiveSessionModel &&
        other.id == id &&
        other.userId == userId &&
        other.sessionToken == sessionToken;
  }

  @override
  int get hashCode {
    return Object.hash(id, userId, sessionToken);
  }

  @override
  String toString() {
    return 'ActiveSessionModel(id: $id, userId: $userId, deviceType: $deviceType, isCurrent: $isCurrent, status: $statusText)';
  }

  /// ایجاد نشست خالی
  static ActiveSessionModel empty() {
    return ActiveSessionModel(
      id: '',
      userId: '',
      sessionToken: '',
      isCurrent: false,
      lastActivity: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }
}

/// مدل لاگ‌های امنیتی
class SecurityLogModel {
  final String id;
  final String userId;
  final String eventType;
  final String? description;
  final Map<String, dynamic>? metadata;
  final String? ipAddress;

  final DateTime createdAt;

  SecurityLogModel({
    required this.id,
    required this.userId,
    required this.eventType,
    this.description,
    this.metadata,
    this.ipAddress,
    required this.createdAt,
  });

  factory SecurityLogModel.fromMap(Map<String, dynamic> map) {
    return SecurityLogModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      eventType: map['event_type'] ?? '',
      description: map['description'],
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
      ipAddress: map['ip_address'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'event_type': eventType,
      'description': description,
      'metadata': metadata,
      'ip_address': ipAddress,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  factory SecurityLogModel.fromJson(String source) =>
      SecurityLogModel.fromMap(json.decode(source));

  /// رنگ رویداد بر اساس نوع
  SecurityEventColor get eventColor {
    switch (eventType) {
      case 'login_success':
      case '2fa_enabled':
      case 'app_lock_enabled':
        return SecurityEventColor.success;
      case 'login_failed':
      case 'suspicious_activity':
        return SecurityEventColor.danger;
      case 'password_changed':
      case 'email_changed':
        return SecurityEventColor.warning;
      default:
        return SecurityEventColor.info;
    }
  }

  /// آیکون رویداد
  String get eventIcon {
    switch (eventType) {
      case 'login_success':
        return '✅';
      case 'login_failed':
        return '❌';
      case 'password_changed':
        return '🔑';
      case 'email_changed':
        return '📧';
      case '2fa_enabled':
        return '🔐';
      case '2fa_disabled':
        return '🔓';
      case 'app_lock_enabled':
        return '📱🔒';
      case 'app_lock_disabled':
        return '📱🔓';
      case 'session_terminated':
        return '⏹️';
      case 'suspicious_activity':
        return '⚠️';
      default:
        return 'ℹ️';
    }
  }

  /// عنوان فارسی رویداد
  String get eventTitle {
    switch (eventType) {
      case 'login_success':
        return 'ورود موفق';
      case 'login_failed':
        return 'ورود ناموفق';
      case 'password_changed':
        return 'تغییر رمز عبور';
      case 'email_changed':
        return 'تغییر ایمیل';
      case '2fa_enabled':
        return 'فعال‌سازی تایید دو مرحله‌ای';
      case '2fa_disabled':
        return 'غیرفعال‌سازی تایید دو مرحله‌ای';
      case 'app_lock_enabled':
        return 'فعال‌سازی قفل اپلیکیشن';
      case 'app_lock_disabled':
        return 'غیرفعال‌سازی قفل اپلیکیشن';
      case 'session_terminated':
        return 'خاتمه جلسه';
      case 'suspicious_activity':
        return 'فعالیت مشکوک';
      default:
        return eventType;
    }
  }
}

/// انواع سطح امنیت
enum SecurityLevel {
  low,
  medium,
  high,
}

/// رنگ‌های رویدادهای امنیتی
enum SecurityEventColor {
  success,
  warning,
  danger,
  info,
}

/// مدل برای تنظیمات قفل اپلیکیشن
class AppLockSettings {
  final bool enabled;
  final AppLockType type;
  final String? hashedPIN;
  final int maxAttempts;
  final Duration lockDuration;

  AppLockSettings({
    required this.enabled,
    required this.type,
    this.hashedPIN,
    this.maxAttempts = 5,
    this.lockDuration = const Duration(minutes: 5),
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'type': type.name,
      'hashedPIN': hashedPIN,
      'maxAttempts': maxAttempts,
      'lockDuration': lockDuration.inMinutes,
    };
  }

  factory AppLockSettings.fromMap(Map<String, dynamic> map) {
    return AppLockSettings(
      enabled: map['enabled'] ?? false,
      type: AppLockType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => AppLockType.pin,
      ),
      hashedPIN: map['hashedPIN'],
      maxAttempts: map['maxAttempts'] ?? 5,
      lockDuration: Duration(minutes: map['lockDuration'] ?? 5),
    );
  }
}

/// انواع قفل اپلیکیشن
enum AppLockType {
  pin,
  pattern,
  biometric,
}

/// مدل برای تنظیمات تایید دو مرحله‌ای
class TwoFactorSettings {
  final bool enabled;
  final String? secret;
  final List<String> backupCodes;
  final DateTime? setupDate;

  TwoFactorSettings({
    required this.enabled,
    this.secret,
    this.backupCodes = const [],
    this.setupDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'secret': secret,
      'backupCodes': backupCodes,
      'setupDate': setupDate?.toIso8601String(),
    };
  }

  factory TwoFactorSettings.fromMap(Map<String, dynamic> map) {
    return TwoFactorSettings(
      enabled: map['enabled'] ?? false,
      secret: map['secret'],
      backupCodes: List<String>.from(map['backupCodes'] ?? []),
      setupDate:
          map['setupDate'] != null ? DateTime.parse(map['setupDate']) : null,
    );
  }

  /// بررسی اینکه آیا کاملاً تنظیم شده یا نه
  bool get isFullySetup {
    return enabled && secret != null && backupCodes.isNotEmpty;
  }
}
