import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../model/ProfileModel.dart';
import '../../provider/provider.dart';
import 'PublicPosts/profileScreen.dart';

class Searchpage extends ConsumerStatefulWidget {
  const Searchpage({super.key});

  @override
  ConsumerState<Searchpage> createState() => _SearchpageState();
}

class _SearchpageState extends ConsumerState<Searchpage> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  Map<String, bool> followState = {};
  bool isSearching = false;

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
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : const AssetImage('assets/images/default_avatar.png')
                as ImageProvider,
      ),
      title: Text(user.username),
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
    final searchResults = ref.watch(searchUsersProvider(searchQuery));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Search Bar
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText:
                          isSearching ? 'جستجو در بین همه کاربران...' : 'جستجو',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  searchQuery = '';
                                  isSearching = false;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        isSearching = value.isNotEmpty;
                      });
                    },
                    onTap: () => setState(() => isSearching = true),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(8.0),
            sliver: !isSearching
                ? followingProvider.when(
                    data: (following) => following.isEmpty
                        ? const SliverFillRemaining(
                            child: Center(
                              child: Text(
                                'هنوز کسی را دنبال نکرده‌اید',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  UserCard(user: following[index]),
                              childCount: following.length,
                            ),
                          ),
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => SliverFillRemaining(
                      child: Center(child: Text('خطا: $error')),
                    ),
                  )
                : searchResults.when(
                    data: (users) => users.isEmpty
                        ? const SliverFillRemaining(
                            child: Center(
                              child: Text(
                                'نتیجه‌ای یافت نشد',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => UserCard(user: users[index]),
                              childCount: users.length,
                            ),
                          ),
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => SliverFillRemaining(
                      child: Center(child: Text('خطا: $error')),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class UserCard extends StatelessWidget {
  final ProfileModel user;

  const UserCard({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                userId: user.id,
                username: user.username,
              ),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : const AssetImage('assets/images/default_avatar.png')
                      as ImageProvider,
            ),
            const SizedBox(height: 10),
            Text(
              user.username,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              user.fullName,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FollowingTile extends ConsumerStatefulWidget {
  final ProfileModel followed;

  const FollowingTile({super.key, required this.followed});

  @override
  ConsumerState<FollowingTile> createState() => _FollowingTileState();
}

class _FollowingTileState extends ConsumerState<FollowingTile> {
  bool _isLoading = false;

  void _toggleFollow(String userId) async {
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
    final userProfile = ref.watch(userProfileProvider(widget.followed.id));

    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: widget.followed.avatarUrl != null
            ? NetworkImage(widget.followed.avatarUrl!)
            : const AssetImage('assets/images/default_avatar.png')
                as ImageProvider,
      ),
      title: Text(widget.followed.username),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.followed.fullName.isNotEmpty) ...[
            Text(widget.followed.fullName),
            const SizedBox(height: 4),
          ],
          SizedBox(
            width: 120,
            height: 32,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: () => _toggleFollow(widget.followed.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: userProfile?.isFollowed ?? false
                          ? Colors.grey
                          : Theme.of(context).primaryColor,
                    ),
                    child: Text(
                      userProfile?.isFollowed ?? false
                          ? 'دنبال شده'
                          : 'دنبال کردن',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              userId: widget.followed.id,
              username: widget.followed.username,
            ),
          ),
        );
      },
    );
  }
}
