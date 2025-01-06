import 'package:Vista/view/screen/PublicPosts/PostDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../main.dart';
import '../../model/ProfileModel.dart';
import '../../model/publicPostModel.dart';
import '../../provider/provider.dart';
import 'PublicPosts/profileScreen.dart';

class SearchPage extends ConsumerStatefulWidget {
  final String? initialHashtag;

  const SearchPage({
    super.key,
    this.initialHashtag,
  });

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  Map<String, bool> followState = {};
  bool isSearching = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialHashtag != null) {
      _searchController.text = widget.initialHashtag!;
      // Trigger search for hashtag
      _performSearch(widget.initialHashtag!);
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      searchQuery = query;
      isSearching = query.isNotEmpty;
    });

    if (query.startsWith('#')) {
      setState(() => _isLoading = true);
      try {
        final response = await supabase
            .from('posts')
            .select('''
              *,
              profiles (
                username,
                full_name,
                avatar_url,
                is_verified
              )
            ''')
            .ilike('content', '%$query%')
            .order('created_at', ascending: false);

        if (!mounted) return;

        final posts = (response as List).map((post) {
          final Map<String, dynamic> postMap = Map<String, dynamic>.from(post);
          return PublicPostModel.fromMap(postMap);
        }).toList();

        ref.read(searchResultsProvider.notifier).state = posts;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _toggleFollow(String userId) async {
    setState(() {
      followState[userId] = !(followState[userId] ?? false);
    });

    try {
      await ref.read(userProfileProvider(userId).notifier).toggleFollow(userId);
    } catch (e) {
      setState(() {
        followState[userId] = !(followState[userId] ?? false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در تغییر وضعیت فالو: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildUserItem(ProfileModel user) {
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? NetworkImage(user.avatarUrl!)
            : const AssetImage('lib/util/images/default-avatar.jpg')
                as ImageProvider,
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback if image loading fails
          debugPrint('Error loading avatar image: $exception');
        },
        backgroundColor: Colors.grey[300],
      ),
      title: Row(
        children: [
          Text(user.username),
          const SizedBox(width: 5),
          if (user.isVerified)
            const Icon(Icons.verified, color: Colors.blue, size: 16),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.fullName),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            height: 32,
            child: ElevatedButton(
              onPressed: () => _toggleFollow(user.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: followState[user.id] ?? false
                    ? Colors.grey
                    : Theme.of(context).primaryColor,
              ),
              child: Text(
                followState[user.id] ?? false ? 'دنبال شده' : 'دنبال کردن',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final followingProvider =
        ref.watch(userFollowingProvider(supabase.auth.currentUser!.id));
    final userSearchResults =
        ref.watch(searchUsersProvider(searchQuery)).asData?.value ?? [];
    final hashtagResults = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'جستجو...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) {
            _performSearch(value);
          },
        ),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!isSearching) {
            return followingProvider.when(
              data: (following) => following.isEmpty
                  ? const Center(child: Text('هنوز کسی را دنبال نکرده‌اید'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: following.length,
                      itemBuilder: (context, index) =>
                          UserCard(user: following[index]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('خطا: $error')),
            );
          }

          if (searchQuery.startsWith('#')) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                itemCount: hashtagResults.length,
                itemBuilder: (context, index) {
                  final post = hashtagResults[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PostDetailsPage(postId: post.id),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post.imageUrl != null &&
                              post.imageUrl!.isNotEmpty)
                            Image.network(
                              post.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              post.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }

          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: userSearchResults.length,
            itemBuilder: (context, index) =>
                UserCard(user: userSearchResults[index]),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class UserCard extends ConsumerStatefulWidget {
  final ProfileModel user;

  const UserCard({super.key, required this.user});

  @override
  ConsumerState<UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<UserCard> {
  bool _isLoading = false;

  Future<void> _toggleFollow(String userId) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(userProfileProvider(userId).notifier).toggleFollow(userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در تغییر وضعیت فالو: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider(widget.user.id));
    final currentColor = ref.watch(themeProvider);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                userId: widget.user.id,
                username: widget.user.username,
              ),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: widget.user.avatarUrl != null
                  ? NetworkImage(widget.user.avatarUrl!)
                  : const AssetImage('lib/util/images/default-avatar.jpg')
                      as ImageProvider,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.user.username,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(width: 3),
                if (widget.user.isVerified)
                  const Icon(Icons.verified, color: Colors.blue, size: 16),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              widget.user.fullName,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              height: 32,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () => _toggleFollow(widget.user.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: userProfile?.isFollowed ?? false
                            ? currentColor.brightness == Brightness.dark
                                ? Colors.black
                                : Colors.grey[300]
                            : currentColor.brightness == Brightness.dark
                                ? Colors.white
                                : Colors
                                    .black, // تغییر رنگ دکمه به مشکی در تم روشن
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        userProfile?.isFollowed ?? false
                            ? 'دنبال شده'
                            : 'دنبال کردن',
                        style: TextStyle(
                          color: userProfile?.isFollowed ?? false
                              ? currentColor.brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black87
                              : currentColor.brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors
                                      .white, // تغییر رنگ متن به سفید در تم روشن
                          fontSize: 12,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Update the provider definition
final searchResultsProvider = StateProvider<List<PublicPostModel>>((ref) => []);

class PostCard extends StatelessWidget {
  final PublicPostModel post;

  const PostCard({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(post.content),
        // Add more post details here
      ),
    );
  }
}

Widget buildPostTile({
  required BuildContext context,
  required PublicPostModel post,
  required String currentUserId,
  required WidgetRef ref,
}) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: ListTile(
      // Only show leading image if post has an image
      leading: post.imageUrl != null && post.imageUrl!.isNotEmpty
          ? Image.network(
              post.imageUrl!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  width: 50,
                  height: 50,
                );
              },
            )
          : null, // Don't show any image if post has no image
      title: Text(post.content),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailsPage(
              postId: post.id,
            ),
          ),
        );
      },
    ),
  );
}
