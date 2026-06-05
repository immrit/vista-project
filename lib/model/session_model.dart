import 'package:flutter/foundation.dart';
import 'package:Vista/services/device_id_service.dart';

class SessionModel {
  final String id;
  final String userId;
  final String? sessionToken;
  final SessionDeviceInfo deviceInfo;
  final String? ipAddress;
  final DateTime lastActivity;
  final DateTime createdAt;
  final bool isActive;
  final bool isCurrentSession;
  final String? deviceName;
  final String? appVersion;
  final String? platform;
  final String? fcmToken;
  final SessionLocation? location;

  SessionModel({
    required this.id,
    required this.userId,
    this.sessionToken,
    required this.deviceInfo,
    this.ipAddress,
    required this.lastActivity,
    required this.createdAt,
    required this.isActive,
    this.isCurrentSession = false,
    this.deviceName,
    this.appVersion,
    this.platform,
    this.fcmToken,
    this.location,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    // پردازش location: اگر location به صورت JSON object است، از آن استفاده کن
    // در غیر این صورت، از location_city و location_country استفاده کن
    SessionLocation? location;
    final fallbackCity = json['location_city'] as String?;
    final fallbackCountry = json['location_country'] as String?;
    final fallbackRegion = json['location_region'] as String?;

    if (json['location'] != null) {
      try {
        // اگر location به صورت Map است
        if (json['location'] is Map<String, dynamic>) {
          location = SessionLocation.fromJson(
            json['location'] as Map<String, dynamic>,
            fallbackCity: fallbackCity,
            fallbackCountry: fallbackCountry,
            fallbackRegion: fallbackRegion,
          );
        }
        // اگر location به صورت string است (مثل "35.6892,51.3890") - برای backward compatibility
        else if (json['location'] is String) {
          // از location_city و location_country استفاده کن
          final city = fallbackCity;
          final country = fallbackCountry;
          final region = fallbackRegion;
          if (city != null || country != null) {
            location = SessionLocation(
              city: city,
              country: country,
              region: region,
            );
          }
        }
      } catch (e) {
        // در صورت خطا، از location_city و location_country استفاده کن
        final city = fallbackCity;
        final country = fallbackCountry;
        final region = fallbackRegion;
        if (city != null || country != null) {
          location = SessionLocation(
            city: city,
            country: country,
            region: region,
          );
        }
      }
    } else {
      // اگر location null است، از location_city و location_country استفاده کن
      final city = fallbackCity;
      final country = fallbackCountry;
      final region = fallbackRegion;
      if (city != null || country != null) {
        location = SessionLocation(
          city: city,
          country: country,
          region: region,
        );
      }
    }

    return SessionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sessionToken: json['session_token'] as String?,
      deviceInfo: SessionDeviceInfo.fromJson(
        json['device_info'] as Map<String, dynamic>,
      ),
      ipAddress: json['ip_address'] as String?,
      lastActivity: DateTime.parse(json['last_activity'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool,
      isCurrentSession: (json['is_current_session'] as bool?) ?? false,
      deviceName: json['device_name'] as String?,
      appVersion: json['app_version'] as String?,
      platform: json['platform'] as String?,
      fcmToken: json['fcm_token'] as String?,
      location: location,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'session_token': sessionToken,
      'device_info': deviceInfo.toJson(),
      'ip_address': ipAddress,
      'last_activity': lastActivity.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
      'is_current_session': isCurrentSession,
      'device_name': deviceName,
      'app_version': appVersion,
      'platform': platform,
      'fcm_token': fcmToken,
      'location': location?.toJson(),
    };
  }

  SessionModel copyWith({
    String? id,
    String? userId,
    String? sessionToken,
    SessionDeviceInfo? deviceInfo,
    String? ipAddress,
    DateTime? lastActivity,
    DateTime? createdAt,
    bool? isActive,
    bool? isCurrentSession,
    String? deviceName,
    String? appVersion,
    String? platform,
    String? fcmToken,
    SessionLocation? location,
  }) {
    return SessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionToken: sessionToken ?? this.sessionToken,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      ipAddress: ipAddress ?? this.ipAddress,
      lastActivity: lastActivity ?? this.lastActivity,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      isCurrentSession: isCurrentSession ?? this.isCurrentSession,
      deviceName: deviceName ?? this.deviceName,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      fcmToken: fcmToken ?? this.fcmToken,
      location: location ?? this.location,
    );
  }

  bool get isCurrentDevice =>
      deviceInfo.deviceId == DeviceIdService.id ||
      (deviceInfo.deviceId == null &&
          defaultTargetPlatform == deviceInfo.targetPlatform);
}

class SessionDeviceInfo {
  final String deviceName;
  final String deviceModel;
  final String osVersion;
  final TargetPlatform targetPlatform;
  final String? deviceId;

  SessionDeviceInfo({
    required this.deviceName,
    required this.deviceModel,
    required this.osVersion,
    required this.targetPlatform,
    this.deviceId,
  });

  factory SessionDeviceInfo.fromJson(Map<String, dynamic> json) {
    return SessionDeviceInfo(
      deviceName: json['device_name'] as String,
      deviceModel: json['device_model'] as String,
      osVersion: json['os_version'] as String,
      targetPlatform: _platformFromString(json['platform'] as String),
      deviceId: json['device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_name': deviceName,
      'device_model': deviceModel,
      'os_version': osVersion,
      'platform': _platformToString(targetPlatform),
      'device_id': deviceId,
    };
  }

  static TargetPlatform _platformFromString(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return TargetPlatform.android;
      case 'ios':
        return TargetPlatform.iOS;
      case 'windows':
        return TargetPlatform.windows;
      case 'macos':
        return TargetPlatform.macOS;
      case 'linux':
        return TargetPlatform.linux;
      default:
        return TargetPlatform.android;
    }
  }

  static String _platformToString(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  String get platformIcon {
    switch (targetPlatform) {
      case TargetPlatform.android:
        return '🤖';
      case TargetPlatform.iOS:
        return '🍎';
      case TargetPlatform.windows:
        return '🪟';
      case TargetPlatform.macOS:
        return '💻';
      case TargetPlatform.linux:
        return '🐧';
      default:
        return '📱';
    }
  }

  String get displayName {
    return '$platformIcon $deviceName ($deviceModel)';
  }
}

class SessionLocation {
  final String? country;
  final String? city;
  final String? region;
  final double? latitude;
  final double? longitude;

  SessionLocation({
    this.country,
    this.city,
    this.region,
    this.latitude,
    this.longitude,
  });

  factory SessionLocation.fromJson(
    Map<String, dynamic> json, {
    String? fallbackCountry,
    String? fallbackCity,
    String? fallbackRegion,
  }) {
    return SessionLocation(
      country: (json['country'] as String?) ?? fallbackCountry,
      city: (json['city'] as String?) ?? fallbackCity,
      region: (json['region'] as String?) ?? fallbackRegion,
      latitude: json['latitude'] != null
          ? (json['latitude'] is num
              ? (json['latitude'] as num).toDouble()
              : double.tryParse(json['latitude'].toString()))
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] is num
              ? (json['longitude'] as num).toDouble()
              : double.tryParse(json['longitude'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'city': city,
      'region': region,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  String get displayName {
    if (city != null && country != null) {
      return '$city, $country';
    } else if (region != null && country != null) {
      return '$region, $country';
    } else if (country != null) {
      return country!;
    } else if (city != null) {
      return city!;
    }
    return 'نامشخص';
  }
}
