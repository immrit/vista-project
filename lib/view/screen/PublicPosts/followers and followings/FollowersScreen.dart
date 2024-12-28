import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../model/ProfileModel.dart';
import '../../../../provider/provider.dart';
import '../profileScreen.dart';

class FollowersScreen extends ConsumerWidget {
  final String userId;

  const FollowersScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // دریافت داده‌های دنبال‌کنندگان از پروایدر
    final followersProvider = ref.watch(userFollowersProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('دنبال‌کنندگان'),
      ),
      body: followersProvider.when(
        data: (followers) => _buildFollowersList(followers),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          debugPrint('Error fetching followers: $error'); // لاگ خطا
          return Center(
            child: Text(
              'خطا در دریافت دنبال‌کنندگان: ${error.toString()}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  // ویجت نمایش لیست دنبال‌کنندگان
  Widget _buildFollowersList(List<ProfileModel> followers) {
    if (followers.isEmpty) {
      return const Center(
        child: Text(
          'هیچ دنبال‌کننده‌ای وجود ندارد.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      );
    }

    return ListView.builder(
      itemCount: followers.length,
      itemBuilder: (context, index) {
        final follower = followers[index];
        return FollowerTile(follower: follower);
      },
    );
  }
}

class FollowerTile extends StatelessWidget {
  final ProfileModel follower;

  const FollowerTile({super.key, required this.follower});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: follower.avatarUrl != null
            ? NetworkImage(follower.avatarUrl!)
            : const AssetImage('assets/images/default_avatar.png')
                as ImageProvider,
      ),
      title: Text(
        follower.username,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: follower.fullName.isNotEmpty
          ? Text(
              follower.fullName,
              style: const TextStyle(color: Colors.grey),
            )
          : null,
      onTap: () {
        // انتقال به صفحه پروفایل دنبال‌کننده
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              userId: follower.id,
              username: follower.username,
            ),
          ),
        );
      },
    );
  }
}
