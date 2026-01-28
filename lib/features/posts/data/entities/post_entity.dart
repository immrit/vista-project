import 'package:isar/isar.dart';
import '../../../../model/publicPostModel.dart';
import '../../../../model/ProfileModel.dart';

part 'post_entity.g.dart';

@collection
class PostEntity {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String userId;

  late String fullName;
  late String content;

  String? imageUrl;
  String? videoUrl;
  String? musicUrl;

  late DateTime createdAt;

  // Denormalized user info for feed performance
  late String username;
  late String avatarUrl;

  int likeCount = 0;
  bool isLiked = false;

  int commentCount = 0;

  bool isVerified = false;

  @Enumerated(EnumType.name)
  VerificationType verificationType = VerificationType.none;

  List<String> hashtags = [];

  String? title;

  // Moderation info
  String? moderatorId;
  String? moderatorUsername;
  DateTime? moderatedAt;
  String? moderationReason;

  // Cache metadata
  DateTime cachedAt = DateTime.now();

  static PostEntity fromModel(PublicPostModel model) {
    return PostEntity()
      ..id = model.id
      ..userId = model.userId
      ..fullName = model.fullName
      ..content = model.content
      ..imageUrl = model.imageUrl
      ..videoUrl = model.videoUrl
      ..musicUrl = model.musicUrl
      ..createdAt = model.createdAt
      ..username = model.username
      ..avatarUrl = model.avatarUrl
      ..likeCount = model.likeCount
      ..isLiked = model.isLiked
      ..commentCount = model.commentCount
      ..isVerified = model.isVerified
      ..verificationType = model.verificationType
      ..hashtags = model.hashtags
      ..title = model.title
      ..moderatorId = model.moderatorId
      ..moderatorUsername = model.moderatorUsername
      ..moderatedAt = model.moderatedAt
      ..moderationReason = model.moderationReason
      ..cachedAt = DateTime.now();
  }

  PublicPostModel toModel() {
    return PublicPostModel(
      id: id,
      userId: userId,
      fullName: fullName,
      content: content,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      createdAt: createdAt,
      username: username,
      avatarUrl: avatarUrl,
      likeCount: likeCount,
      isLiked: isLiked,
      isVerified: isVerified,
      verificationType: verificationType,
      commentCount: commentCount,
      hashtags: hashtags,
      musicUrl: musicUrl,
      title: title,
      moderatorId: moderatorId,
      moderatorUsername: moderatorUsername,
      moderatedAt: moderatedAt,
      moderationReason: moderationReason,
      // Note: `profiles` map in model is redundant if we have username/avatar/verification fields
      // but we can reconstruct it if needed
      profiles: {
        'username': username,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'is_verified': isVerified,
        'verification_type': verificationType.name,
      },
    );
  }
}

/// FNV-1a 64bit hash algorithm optimized for Dart Strings
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}
