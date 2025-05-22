import 'package:supabase_flutter/supabase_flutter.dart';

class ChannelModel {
  final String id;
  final String creatorId;
  final String name;
  final String? description;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int memberCount;
  final bool isPrivate;
  final String? username;
  final bool isSubscribed;
  final String? memberRole;
  final DateTime? lastReadTime;

  ChannelModel({
    required this.id,
    required this.creatorId,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageTime,
    required this.memberCount,
    required this.isPrivate,
    this.username,
    this.isSubscribed = false,
    this.memberRole,
    this.lastReadTime,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    // اضافه کردن پرینت برای دیباگ
    print('Channel JSON: $json');
    print('Member Role from JSON: ${json['member_role']}');

    return ChannelModel(
      id: json['id'],
      creatorId: json['creator_id'],
      name: json['name'],
      description: json['description'],
      avatarUrl: json['avatar_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastMessage: json['last_message'],
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'])
          : null,
      memberCount: json['member_count'] ?? 0,
      isPrivate: json['is_private'] ?? false,
      username: json['username'],
      isSubscribed: json['is_subscribed'] ?? false,
      memberRole: json['member_role']
          ?.toString(), // مطمئن شوید که به string تبدیل می‌شود
      lastReadTime: json['last_read_time'] != null
          ? DateTime.parse(json['last_read_time'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'member_count': memberCount,
      'is_private': isPrivate,
      'username': username,
      'is_subscribed': isSubscribed,
      'member_role': memberRole,
      'last_read_time': lastReadTime?.toIso8601String(),
    };
  }

  ChannelModel copyWith({
    String? id,
    String? creatorId,
    String? name,
    String? description,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? memberCount,
    bool? isPrivate,
    String? username,
    bool? isSubscribed,
    String? memberRole,
    DateTime? lastReadTime,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      memberCount: memberCount ?? this.memberCount,
      isPrivate: isPrivate ?? this.isPrivate,
      username: username ?? this.username,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      memberRole: memberRole ?? this.memberRole,
      lastReadTime: lastReadTime ?? this.lastReadTime,
    );
  }

  static ChannelModel empty() {
    return ChannelModel(
      id: '',
      creatorId: '',
      name: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      memberCount: 0,
      isPrivate: false,
    );
  }
}
