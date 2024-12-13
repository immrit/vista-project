// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:dart_appwrite/dart_appwrite.dart';
// import 'package:vistaNote/models/profile_model.dart';
// import 'package:vistaNote/models/public_post_model.dart';
// import 'package:vistaNote/providers/appwrite_providers.dart';
// import 'package:vistaNote/util/constants.dart';
// import 'package:vistaNote/util/widgets.dart';
// import 'followers_and_followings/followers_screen.dart';
// import 'followers_and_followings/following_screen.dart';
// import 'edit_profile_screen.dart';
// import 'add_post_screen.dart';

// class ProfileScreen extends ConsumerStatefulWidget {
//   final String userId;
//   final String username;

//   const ProfileScreen({
//     Key? key,
//     required this.userId,
//     required this.username,
//   }) : super(key: key);

//   @override
//   _ProfileScreenState createState() => _ProfileScreenState();
// }

// class _ProfileScreenState extends ConsumerState<ProfileScreen> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance!.addPostFrameCallback((_) {
//       ref
//           .read(userProfileProvider(widget.userId).notifier)
//           .fetchProfile(widget.userId);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final profileState = ref.watch(userProfileProvider(widget.userId));
//     final currentUser = ref.watch(currentUserProvider);
//     final isCurrentUserProfile = profileState != null &&
//         currentUser != null &&
//         profileState.id == currentUser.$id;

//     return Scaffold(
//       endDrawer: isCurrentUserProfile ? CustomDrawer(currentUser) : null,
//       body: profileState == null
//           ? const Center(child: CircularProgressIndicator())
//           : RefreshIndicator(
//               onRefresh: _refreshProfile,
//               child: CustomScrollView(
//                 slivers: [
//                   _buildSliverAppBar(profileState, isCurrentUserProfile),
//                   _buildPostsList(profileState),
//                 ],
//               ),
//             ),
//       floatingActionButton: isCurrentUserProfile
//           ? FloatingActionButton(
//               child: const Icon(Icons.edit),
//               onPressed: () {
//                 Navigator.of(context).push(
//                   MaterialPageRoute(
//                     builder: (context) => const AddPublicPostScreen(),
//                   ),
//                 );
//               },
//             )
//           : null,
//     );
//   }

//   Future<void> _refreshProfile() async {
//     try {
//       await ref
//           .read(userProfileProvider(widget.userId).notifier)
//           .fetchProfile(widget.userId);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error refreshing profile: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   SliverAppBar _buildSliverAppBar(
//       ProfileModel profile, bool isCurrentUserProfile) {
//     return SliverAppBar(
//       expandedHeight: 320,
//       backgroundColor: Brightness.dark == Theme.of(context).brightness
//           ? Colors.grey[900]
//           : null,
//       floating: false,
//       pinned: true,
//       actions: [
//         if (!isCurrentUserProfile)
//           PopupMenuButton(
//             onSelected: (value) {
//               showDialog(
//                 context: context,
//                 builder: (context) => ReportProfileDialog(
//                   userId: widget.userId,
//                 ),
//               );
//             },
//             itemBuilder: (BuildContext context) {
//               return <PopupMenuEntry<String>>[
//                 const PopupMenuItem<String>(
//                   value: 'report',
//                   child: Text('Report'),
//                 ),
//               ];
//             },
//           )
//       ],
//       title: _buildAppBarTitle(profile),
//       flexibleSpace: FlexibleSpaceBar(
//         background: _buildProfileHeader(profile),
//       ),
//     );
//   }

//   Row _buildAppBarTitle(ProfileModel profile) {
//     return Row(
//       children: [
//         Text(profile.username),
//         const SizedBox(width: 5),
//         if (profile.isVerified)
//           const Icon(Icons.verified, color: Colors.blue, size: 16),
//       ],
//     );
//   }

//   Widget _buildProfileHeader(ProfileModel profile) {
//     final bool isCurrentUserProfile =
//         profile.id == ref.read(currentUserProvider)?.$id;

//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox(height: 60),
//           _buildProfileInfo(profile, isCurrentUserProfile),
//         ],
//       ),
//     );
//   }

//   Widget _buildProfileInfo(ProfileModel profile, bool isCurrentUserProfile) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             _buildProfileAvatar(profile),
//             const Spacer(),
//             _buildProfileActionButton(profile, isCurrentUserProfile),
//           ],
//         ),
//         const SizedBox(height: 16),
//         _buildProfileDetails(profile),
//       ],
//     );
//   }

//   Widget _buildProfileAvatar(ProfileModel profile) {
//     return Padding(
//       padding: const EdgeInsets.only(top: 20),
//       child: CircleAvatar(
//         radius: 40,
//         backgroundImage:
//             profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
//         child: profile.avatarUrl == null
//             ? const CircleAvatar(
//                 backgroundImage: AssetImage(defaultAvatarUrl),
//                 radius: 40,
//               )
//             : null,
//       ),
//     );
//   }

//   Widget _buildProfileActionButton(
//       ProfileModel profile, bool isCurrentUserProfile) {
//     final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

//     return ElevatedButton(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: isCurrentUserProfile || profile.isFollowed
//             ? Colors.black
//             : Colors.white,
//         foregroundColor: isCurrentUserProfile || !profile.isFollowed
//             ? Colors.white
//             : Colors.black,
//       ),
//       onPressed: () => isCurrentUserProfile
//           ? Navigator.of(context).push(MaterialPageRoute(
//               builder: (context) => const EditProfileScreen()))
//           : _toggleFollow(profile.id),
//       child: Text(isCurrentUserProfile
//           ? 'Edit Profile'
//           : profile.isFollowed
//               ? 'Unfollow'
//               : 'Follow'),
//     );
//   }

//   Widget _buildProfileDetails(ProfileModel profile) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           profile.fullName,
//           style: const TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         if (profile.bio != null) ...[
//           const SizedBox(height: 10),
//           Text(profile.bio!),
//         ],
//         const SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             GestureDetector(
//               onTap: () => Navigator.of(context).push(MaterialPageRoute(
//                   builder: (context) =>
//                       FollowingScreen(userId: widget.userId))),
//               child: Column(
//                 children: [
//                   Text(' ${profile.followingCount}',
//                       style: const TextStyle(fontWeight: FontWeight.bold)),
//                   const Text('Following',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 20),
//             GestureDetector(
//               onTap: () => Navigator.of(context).push(MaterialPageRoute(
//                   builder: (context) =>
//                       FollowersScreen(userId: widget.userId))),
//               child: Column(
//                 children: [
//                   Text(' ${profile.followersCount}',
//                       style: const TextStyle(fontWeight: FontWeight.bold)),
//                   const Text('Followers',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 20),
//             GestureDetector(
//               child: Column(
//                 children: [
//                   Text(' ${profile.posts.length}',
//                       style: const TextStyle(fontWeight: FontWeight.bold)),
//                   const Text('Posts',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   SliverList _buildPostsList(ProfileModel profile) {
//     return SliverList(
//       delegate: SliverChildBuilderDelegate(
//         (context, index) {
//           if (profile.posts.isEmpty) {
//             return const Center(child: Text('No posts yet.'));
//           }
//           return _buildPostItem(profile, profile.posts[index]);
//         },
//         childCount: profile.posts.isEmpty ? 1 : profile.posts.length,
//       ),
//     );
//   }

//   Widget _buildPostItem(ProfileModel profile, PublicPostModel post) {
//     final userProvider = ref.read(userProfileProvider(widget.userId).notifier);

//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               _buildPostHeader(profile, post),
//               PopupMenuButton<String>(
//                 onSelected: (value) async {
//                   switch (value) {
//                     case 'report':
//                       _showReportDialog(post);
//                       break;
//                     case 'copy':
//                       Clipboard.setData(ClipboardData(text: post.content));
//                       ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(content: Text('Text copied!')));
//                       break;
//                     case 'delete':
//                       _showDeleteConfirmation(post);
//                       break;
//                   }
//                 },
//                 itemBuilder: (BuildContext context) {
//                   return [
//                     const PopupMenuItem<String>(
//                         value: 'report', child: Text('Report')),
//                     const PopupMenuItem<String>(
//                         value: 'copy', child: Text('Copy')),
//                     if (post.userId == profile.id)
//                       const PopupMenuItem<String>(
//                           value: 'delete', child: Text('Delete')),
//                   ];
//                 },
//                 icon: const Icon(Icons.more_vert),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(post.content),
//           const SizedBox(height: 16),
//           _buildPostActions(post, userProvider),
//         ],
//       ),
//     );
//   }

//   Widget _buildPostHeader(ProfileModel profile, PublicPostModel post) {
//     return Row(
//       children: [
//         CircleAvatar(
//           radius: 20,
//           backgroundImage: profile.avatarUrl != null
//               ? NetworkImage(profile.avatarUrl!)
//               : null,
//         ),
//         const SizedBox(width: 12),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Text(profile.username,
//                     style: const TextStyle(fontWeight: FontWeight.bold)),
//                 const SizedBox(width: 5),
//                 if (profile.isVerified)
//                   const Icon(Icons.verified, color: Colors.blue, size: 16),
//               ],
//             ),
//             Text('${post.createdAt}'),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildPostActions(PublicPostModel post, ProfileNotifier notifier) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Row(
//           children: [
//             _buildLikeButton(post, notifier),
//             _buildCommentButton(post),
//             _buildShareButton(post),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildLikeButton(PublicPostModel post, ProfileNotifier notifier) {
//     return Row(
//       children: [
//         IconButton(
//           icon: Icon(
//             post.isLiked ? Icons.favorite : Icons.favorite_border,
//             color: post.isLiked ? Colors.red : null,
//           ),
//           onPressed: () => _toggleLike(post, notifier),
//         ),
//         Text('${post.likeCount}'),
//       ],
//     );
//   }

//   Widget _buildCommentButton(PublicPostModel post) {
//     return IconButton(
//       icon: const Icon(Icons.comment),
//       onPressed: () => _showComments(post),
//     );
//   }

//   Widget _buildShareButton(PublicPostModel post) {
//     return IconButton(
//       icon: const Icon(Icons.share),
//       onPressed: () => Share.share(post.content),
//     );
//   }

//   void _toggleLike(PublicPostModel post, ProfileNotifier notifier) async {
//     final updatedPost = post.copyWith(
//       isLiked: !post.isLiked,
//       likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
//     );

//     notifier.updatePost(updatedPost);

//     try {
//       final database = ref.read(appwriteDatabaseProvider);
//       if (updatedPost.isLiked) {
//         await database.createDocument(
//           collectionId: 'post_likes',
//           documentId:
//               '${updatedPost.id}_${updatedPost.userId}', // custom document ID to prevent duplicates
//           data: {
//             'postId': updatedPost.id,
//             'userId': updatedPost.userId,
//           },
//         );
//       } else {
//         await database.deleteDocument(
//           collectionId: 'post_likes',
//           documentId: '${updatedPost.id}_${updatedPost.userId}',
//         );
//       }
//     } catch (e) {
//       print('Error toggling like: $e');
//     }
//   }

//   void _toggleFollow(String userId) async {
//     try {
//       ref
//           .read(userProfileProvider(widget.userId).notifier)
//           .toggleFollow(userId);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error toggling follow status: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   void _showComments(PublicPostModel post) {
//     showCommentsBottomSheet(context, ref, post.id, post.userId);
//   }

//   void _showReportDialog(PublicPostModel post) {
//     showDialog(
//       context: context,
//       builder: (context) => ReportDialog(post: post),
//     );
//   }

//   Future<void> _showDeleteConfirmation(PublicPostModel post) async {
//     final confirmDelete = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete Post'),
//         content: const Text('Are you sure you want to delete this post?'),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: const Text('No')),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: const Text('Yes'),
//           ),
//         ],
//       ),
//     );

//     if (confirmDelete ?? false) {
//       try {
//         final database = ref.read(appwriteDatabaseProvider);
//         await database.deleteDocument(
//           collectionId: 'posts',
//           documentId: post.id,
//         );
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Post deleted successfully')));
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Error deleting post!')));
//       }
//     }
//   }
// }
