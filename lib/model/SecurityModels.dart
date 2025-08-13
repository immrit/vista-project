import 'dart:convert';

/// مدل اطلاعات امنیتی کاربر
class UserSecurityModel {
  final String id;
  final String userId;
  final bool twoFactorEnabled;
  final String? twoFactorSecret;
  final List<String>? backupCodes;
  final DateTime? twoFactorSetupAt;
  final bool appLockEnabled;
  final String? appLockType; // 'pin', 'pattern', 'biometric'
  final String? appLockHash;
  final DateTime? lastLoginAt;
  final String? loginIpAddress;
  final Map<String, dynamic>? deviceInfo;
  final int failedLoginAttempts;
  final DateTime? lockedUntil;
  final int? securityScore;
  final DateTime? lastSecurityCheck;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSecurityModel({
    required this.id,
    required this.userId,
    required this.twoFactorEnabled,
    this.twoFactorSecret,
    this.backupCodes,
    this.twoFactorSetupAt,
    required this.appLockEnabled,
    this.appLockType,
    this.appLockHash,
    this.lastLoginAt,
    this.loginIpAddress,
    this.deviceInfo,
    required this.failedLoginAttempts,
    this.lockedUntil,
    this.securityScore,
    this.lastSecurityCheck,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSecurityModel.fromMap(Map<String, dynamic> map) {
    return UserSecurityModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      twoFactorEnabled: map['two_factor_enabled'] ?? false,
      twoFactorSecret: map['two_factor_secret'],
      backupCodes: map['backup_codes'] != null
          ? List<String>.from(map['backup_codes'])
          : null,
      twoFactorSetupAt: map['two_factor_setup_at'] != null
          ? DateTime.parse(map['two_factor_setup_at'])
          : null,
      appLockEnabled: map['app_lock_enabled'] ?? false,
      appLockType: map['app_lock_type'],
      appLockHash: map['app_lock_hash'],
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.parse(map['last_login_at'])
          : null,
      loginIpAddress: map['login_ip_address'],
      deviceInfo: map['device_info'] != null
          ? Map<String, dynamic>.from(map['device_info'])
          : null,
      failedLoginAttempts: map['failed_login_attempts'] ?? 0,
      lockedUntil: map['locked_until'] != null
          ? DateTime.parse(map['locked_until'])
          : null,
      securityScore: map['security_score'],
      lastSecurityCheck: map['last_security_check'] != null
          ? DateTime.parse(map['last_security_check'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'two_factor_enabled': twoFactorEnabled,
      'two_factor_secret': twoFactorSecret,
      'backup_codes': backupCodes,
      'two_factor_setup_at': twoFactorSetupAt?.toIso8601String(),
      'app_lock_enabled': appLockEnabled,
      'app_lock_type': appLockType,
      'app_lock_hash': appLockHash,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'login_ip_address': loginIpAddress,
      'device_info': deviceInfo,
      'failed_login_attempts': failedLoginAttempts,
      'locked_until': lockedUntil?.toIso8601String(),
      'security_score': securityScore,
      'last_security_check': lastSecurityCheck?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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
    List<String>? backupCodes,
    DateTime? twoFactorSetupAt,
    bool? appLockEnabled,
    String? appLockType,
    String? appLockHash,
    DateTime? lastLoginAt,
    String? loginIpAddress,
    Map<String, dynamic>? deviceInfo,
    int? failedLoginAttempts,
    DateTime? lockedUntil,
    int? securityScore,
    DateTime? lastSecurityCheck,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSecurityModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      twoFactorSecret: twoFactorSecret ?? this.twoFactorSecret,
      backupCodes: backupCodes ?? this.backupCodes,
      twoFactorSetupAt: twoFactorSetupAt ?? this.twoFactorSetupAt,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockType: appLockType ?? this.appLockType,
      appLockHash: appLockHash ?? this.appLockHash,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      loginIpAddress: loginIpAddress ?? this.loginIpAddress,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      securityScore: securityScore ?? this.securityScore,
      lastSecurityCheck: lastSecurityCheck ?? this.lastSecurityCheck,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// بررسی اینکه آیا حساب قفل شده یا نه
  bool get isLocked {
    if (lockedUntil == null) return false;
    return DateTime.now().isBefore(lockedUntil!);
  }

  /// بررسی اینکه آیا 2FA فعال و تنظیم شده یا نه
  bool get isTwoFactorSetup {
    return twoFactorEnabled && twoFactorSecret != null;
  }

  /// محاسبه سطح امنیت بر اساس امتیاز
  SecurityLevel get securityLevel {
    final score = securityScore ?? 50;
    if (score >= 80) return SecurityLevel.high;
    if (score >= 60) return SecurityLevel.medium;
    return SecurityLevel.low;
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
  });

  factory ActiveSessionModel.fromMap(Map<String, dynamic> map) {
    return ActiveSessionModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      sessionToken: map['session_token'] ?? '',
      refreshTokenHash: map['refresh_token_hash'],
      deviceType: map['device_type'],
      deviceName: map['device_name'],
      osName: map['os_name'],
      osVersion: map['os_version'],
      appVersion: map['app_version'],
      ipAddress: map['ip_address'],
      location: map['location'] != null
          ? Map<String, dynamic>.from(map['location'])
          : null,
      isCurrent: map['is_current'] ?? false,
      lastActivity: DateTime.parse(map['last_activity']),
      createdAt: DateTime.parse(map['created_at']),
      expiresAt:
          map['expires_at'] != null ? DateTime.parse(map['expires_at']) : null,
    );
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
}

/// مدل لاگ‌های امنیتی
class SecurityLogModel {
  final String id;
  final String userId;
  final String eventType;
  final String? description;
  final Map<String, dynamic>? metadata;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  SecurityLogModel({
    required this.id,
    required this.userId,
    required this.eventType,
    this.description,
    this.metadata,
    this.ipAddress,
    this.userAgent,
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
      userAgent: map['user_agent'],
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
      'user_agent': userAgent,
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
