import 'dart:convert';
import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final DateTime createdAt;
  final String type;
  final String username;
  final bool userIsVerified;
  final String avatarUrl;
  final String PostId;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.createdAt,
    this.type = 'general',
    required this.username,
    required this.avatarUrl,
    required this.userIsVerified,
    required this.PostId,
    this.isRead = false,
  });

  // سازنده از Map با هندلینگ پیشرفته
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    try {
      return NotificationModel(
        id: (map['id'] ?? '').toString(),
        senderId: (map['sender_id'] ?? '').toString(),
        recipientId: (map['recipient_id'] ?? '').toString(),
        content: (map['content'] ?? '❤️').toString(),
        createdAt: map['created_at'] is String
            ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
            : DateTime.now(),
        type: (map['type'] ?? 'general').toString(),
        username: map['sender']?['username']?.toString() ?? 'Unknown',
        avatarUrl: map['sender']?['avatar_url']?.toString() ?? '',
        userIsVerified: map['sender']?['is_verified'] == true,
        PostId: map['post_id']?.toString() ?? '',
        isRead: map['is_read'] == true,
      );
    } catch (e) {
      print('Error parsing notification: $e');
      rethrow;
    }
  }

  // تبدیل به Map با ساختار کامل
  Map<String, dynamic> toMap() => {
        'id': id,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'type': type,
        'profiles': {
          'username': username,
          'avatar_url': avatarUrl,
          'is_verified': userIsVerified,
        },
        'post_id': PostId,
        'is_read': isRead,
      };

  // متد copyWith برای تغییرات ایمن
  NotificationModel copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? content,
    DateTime? createdAt,
    String? notificationType,
    String? username,
    String? avatarUrl,
    bool? userIsVerified,
    String? PostId,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      type: notificationType ?? type,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      userIsVerified: userIsVerified ?? this.userIsVerified,
      PostId: PostId ?? this.PostId,
      isRead: isRead ?? this.isRead,
    );
  }

  // تبدیل به JSON
  String toJson() => json.encode(toMap());

  // از JSON
  factory NotificationModel.fromJson(String source) =>
      NotificationModel.fromMap(json.decode(source));

  // Override equals و hashCode از طریق Equatable
  @override
  List<Object?> get props =>
      [id, senderId, recipientId, content, createdAt, type];

  // toString برای لاگ و دیباگ
  @override
  String toString() => '''
    Notification(
      id: $id, 
      sender: $senderId, 
      content: $content, 
      type: $type, 
      postid: $PostId,
      read: $isRead
    )''';

  // متد مقایسه
  bool isSameNotification(NotificationModel other) =>
      id == other.id && content == other.content;
}
