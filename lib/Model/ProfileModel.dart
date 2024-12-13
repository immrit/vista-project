// import 'dart:convert';
// import 'package:equatable/equatable.dart';
// import 'package:flutter/foundation.dart';

// import 'publicPostModel.dart';

// enum VerificationType { none, blueTick, official }

// @immutable
// class ProfileModel extends Equatable {
//   final String id;
//   final String username;
//   final String fullName;
//   final String? avatarUrl;
//   final String? email;
//   final String? bio;
//   final int followersCount;
//   final int followingCount;
//   final DateTime? createdAt;
//   final bool isVerified;
//   final VerificationType verificationType;
//   final bool isFollowed;
//   final List<PublicPostModel> posts;

//   const ProfileModel({
//     required this.id,
//     required this.username,
//     required this.fullName,
//     this.avatarUrl,
//     this.email,
//     this.bio,
//     this.followersCount = 0,
//     this.followingCount = 0,
//     this.createdAt,
//     this.isVerified = false,
//     this.verificationType = VerificationType.none,
//     this.isFollowed = false,
//     this.posts = const [],
//   });

//   // Factory constructor to create an instance from Appwrite's document format
//   factory ProfileModel.fromAppwrite(Map<String, dynamic> document) {
//     return ProfileModel(
//       id: document['\$id'].toString(),
//       username: document['username']?.toString() ?? '',
//       fullName: document['fullName']?.toString() ?? '',
//       avatarUrl: document['avatarUrl']?.toString(),
//       email: document['email']?.toString(),
//       bio: document['bio']?.toString(),
//       followersCount: document['followersCount'] ?? 0,
//       followingCount: document['followingCount'] ?? 0,
//       createdAt: document['\$createdAt'] != null
//           ? DateTime.tryParse(document['\$createdAt'].toString())
//           : null,
//       isVerified: document['isVerified'] ?? false,
//       verificationType: VerificationType.values.firstWhere(
//         (type) => type.name == document['verificationType'],
//         orElse: () => VerificationType.none,
//       ),
//       isFollowed: document['isFollowed'] ?? false,
//       posts: (document['posts'] as List<dynamic>? ?? [])
//           .map((post) => PublicPostModel.fromMap(post))
//           .toList(),
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       '\$id': id,
//       'username': username,
//       'fullName': fullName,
//       'avatarUrl': avatarUrl,
//       'email': email,
//       'bio': bio,
//       'followersCount': followersCount,
//       'followingCount': followingCount,
//       '\$createdAt': createdAt?.toIso8601String(),
//       'isVerified': isVerified,
//       'verificationType': verificationType.name,
//       'isFollowed': isFollowed,
//       'posts': posts.map((post) => post.toMap()).toList(),
//     };
//   }

//   String toJson() => json.encode(toMap());

//   ProfileModel copyWith({
//     String? id,
//     String? username,
//     String? fullName,
//     String? avatarUrl,
//     String? email,
//     String? bio,
//     int? followersCount,
//     int? followingCount,
//     DateTime? createdAt,
//     bool? isVerified,
//     VerificationType? verificationType,
//     bool? isFollowed,
//     List<PublicPostModel>? posts,
//   }) {
//     return ProfileModel(
//       id: id ?? this.id,
//       username: username ?? this.username,
//       fullName: fullName ?? this.fullName,
//       avatarUrl: avatarUrl ?? this.avatarUrl,
//       email: email ?? this.email,
//       bio: bio ?? this.bio,
//       followersCount: followersCount ?? this.followersCount,
//       followingCount: followingCount ?? this.followingCount,
//       createdAt: createdAt ?? this.createdAt,
//       isVerified: isVerified ?? this.isVerified,
//       verificationType: verificationType ?? this.verificationType,
//       isFollowed: isFollowed ?? this.isFollowed,
//       posts: posts ?? this.posts,
//     );
//   }

//   @override
//   List<Object?> get props => [
//         id,
//         username,
//         fullName,
//         avatarUrl,
//         email,
//         bio,
//         followersCount,
//         followingCount,
//         createdAt,
//         isVerified,
//         verificationType,
//         isFollowed,
//         posts,
//       ];
// }
