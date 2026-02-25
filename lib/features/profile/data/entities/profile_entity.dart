import 'package:isar/isar.dart';
import '../../../../model/ProfileModel.dart';

part 'profile_entity.g.dart';

@collection
class ProfileEntity {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  late String id;

  late String username;
  late String fullName;
  String? avatarUrl;
  String? email;
  String? bio;

  int followersCount = 0;
  int followingCount = 0;
  int postsCount = 0;

  DateTime? createdAt;

  bool isVerified = false;

  @Enumerated(EnumType.name)
  VerificationType verificationType = VerificationType.none;

  bool isFollowed = false;
  bool isPrivate = false;

  String? role;

  // Last time this profile was updated in cache
  DateTime lastUpdated = DateTime.now();

  /// Convert from Domain Model to Entity
  static ProfileEntity fromModel(ProfileModel model) {
    return ProfileEntity()
      ..id = model.id
      ..username = model.username
      ..fullName = model.fullName
      ..avatarUrl = model.avatarUrl
      ..email = model.email
      ..bio = model.bio
      ..followersCount = model.followersCount
      ..followingCount = model.followingCount
      ..postsCount = model.postsCount
      ..createdAt = model.createdAt
      ..isVerified = model.isVerified
      ..verificationType = model.verificationType
      ..isFollowed = model.isFollowed
      ..isPrivate = model.isPrivate
      ..role = model.role
      ..lastUpdated = DateTime.now();
  }

  /// Convert to Domain Model
  ProfileModel toModel() {
    return ProfileModel(
      id: id,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      email: email,
      bio: bio,
      followersCount: followersCount,
      followingCount: followingCount,
      createdAt: createdAt,
      isVerified: isVerified,
      verificationType: verificationType,
      isFollowed: isFollowed,
      isPrivate: isPrivate,
      role: role,
      postsCount: postsCount,
      // Note: `posts` are loaded separately using PostEntity query
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
