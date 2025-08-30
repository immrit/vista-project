import 'dart:convert';

import 'package:flutter/material.dart';

/// مدل اطلاعات امنیتی کاربر (ساده شده)
class UserSecurityModel {
  final String id;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSecurityModel({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSecurityModel.fromMap(Map<String, dynamic> map) {
    try {
      debugPrint('🔍 Creating UserSecurityModel from map: $map');

      final model = UserSecurityModel(
        id: map['id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserSecurityModel copyWith({
    String? id,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSecurityModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserSecurityModel(id: $id, userId: $userId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSecurityModel &&
        other.id == id &&
        other.userId == userId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}

/// مدل لاگ امنیتی
class SecurityLogModel {
  final String id;
  final String userId;
  final String eventType;
  final String description;
  final String? ipAddress;
  final Map<String, dynamic>? deviceInfo;
  final DateTime timestamp;
  final String? sessionId;

  SecurityLogModel({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.description,
    this.ipAddress,
    this.deviceInfo,
    required this.timestamp,
    this.sessionId,
  });

  factory SecurityLogModel.fromMap(Map<String, dynamic> map) {
    return SecurityLogModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      ipAddress: map['ip_address']?.toString(),
      deviceInfo: map['device_info'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['device_info'])
          : null,
      timestamp: DateTime.parse(map['timestamp']),
      sessionId: map['session_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'event_type': eventType,
      'description': description,
      'ip_address': ipAddress,
      'device_info': deviceInfo,
      'timestamp': timestamp.toIso8601String(),
      'session_id': sessionId,
    };
  }

  SecurityLogModel copyWith({
    String? id,
    String? userId,
    String? eventType,
    String? description,
    String? ipAddress,
    Map<String, dynamic>? deviceInfo,
    DateTime? timestamp,
    String? sessionId,
  }) {
    return SecurityLogModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventType: eventType ?? this.eventType,
      description: description ?? this.description,
      ipAddress: ipAddress ?? this.ipAddress,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      timestamp: timestamp ?? this.timestamp,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  String toString() {
    return 'SecurityLogModel(id: $id, userId: $userId, eventType: $eventType, description: $description, ipAddress: $ipAddress, deviceInfo: $deviceInfo, timestamp: $timestamp, sessionId: $sessionId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecurityLogModel &&
        other.id == id &&
        other.userId == userId &&
        other.eventType == eventType &&
        other.description == description &&
        other.ipAddress == ipAddress &&
        other.deviceInfo == deviceInfo &&
        other.timestamp == timestamp &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        eventType.hashCode ^
        description.hashCode ^
        ipAddress.hashCode ^
        deviceInfo.hashCode ^
        timestamp.hashCode ^
        sessionId.hashCode;
  }
}
