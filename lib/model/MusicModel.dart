import 'package:equatable/equatable.dart';

class MusicModel extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String artist;
  final String? coverUrl;
  final String musicUrl;
  final DateTime createdAt;
  final int playCount;
  final String username;
  final String avatarUrl;
  final bool isVerified;
  final List<String> genres;

  const MusicModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.artist,
    this.coverUrl,
    required this.musicUrl,
    required this.createdAt,
    this.playCount = 0,
    required this.username,
    required this.avatarUrl,
    this.isVerified = false,
    this.genres = const [],
  });

  factory MusicModel.fromMap(Map<String, dynamic> map) {
    return MusicModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      coverUrl: map['cover_url'],
      musicUrl: map['music_url'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      playCount: map['play_count'] ?? 0,
      username: map['profiles']?['username'] ?? '',
      avatarUrl: map['profiles']?['avatar_url'] ?? '',
      isVerified: map['profiles']?['is_verified'] ?? false,
      genres: List<String>.from(map['genres'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'artist': artist,
      'cover_url': coverUrl,
      'music_url': musicUrl,
      'created_at': createdAt.toIso8601String(),
      'play_count': playCount,
      'genres': genres,
    };
  }

  MusicModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? artist,
    String? coverUrl,
    String? musicUrl,
    DateTime? createdAt,
    int? playCount,
    String? username,
    String? avatarUrl,
    bool? isVerified,
    List<String>? genres,
  }) {
    return MusicModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverUrl: coverUrl ?? this.coverUrl,
      musicUrl: musicUrl ?? this.musicUrl,
      createdAt: createdAt ?? this.createdAt,
      playCount: playCount ?? this.playCount,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      genres: genres ?? this.genres,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        artist,
        coverUrl,
        musicUrl,
        createdAt,
        playCount,
        username,
        avatarUrl,
        isVerified,
        genres,
      ];
}
