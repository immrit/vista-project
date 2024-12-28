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
            : const AssetImage('lib/util/images/default-avatar.jpg')
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

class UserCard extends ConsumerStatefulWidget {
  final ProfileModel user;

  const UserCard({Key? key, required this.user}) : super(key: key);

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
            Text(
              widget.user.username,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
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
