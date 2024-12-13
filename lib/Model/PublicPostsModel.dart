class PublicPostModel {
  final String username;
  final String fullName;
  final String avatarUrl;
  final String content;
  final int likeCount;
  final int commentCount;
  final bool isLiked;

  PublicPostModel({
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.content,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
  });

  factory PublicPostModel.fromDocument(Map<String, dynamic>? data) {
    if (data == null) {
      throw ArgumentError('Data cannot be null');
    }

    return PublicPostModel(
      username: data['username'] as String? ?? 'Unknown',
      fullName: data['full_name'] as String? ?? 'Unknown User',
      avatarUrl: data['avatar_url'] as String? ?? '',
      content: data['content'] as String? ?? '',
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      isLiked: data['isLiked'] as bool? ?? false,
    );
  }
}
