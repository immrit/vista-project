import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../model/ProfileModel.dart';
import '../../../../provider/provider.dart';
import '../profileScreen.dart';

class FollowingScreen extends ConsumerWidget {
  final String userId;

  const FollowingScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // دریافت داده‌های دنبال‌شده‌ها از پروایدر
    final followingProvider = ref.watch(userFollowingProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('دنبال‌شده‌ها'),
      ),
      body: followingProvider.when(
        data: (following) => _buildFollowingList(following),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          debugPrint('Error fetching following: $error'); // لاگ خطا
          return Center(
            child: Text(
              'خطا در دریافت دنبال‌شده‌ها: ${error.toString()}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  // ویجت نمایش لیست دنبال‌شده‌ها
  Widget _buildFollowingList(List<ProfileModel> following) {
    if (following.isEmpty) {
      return const Center(
        child: Text(
          'هیچ دنبال‌شده‌ای وجود ندارد.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      );
    }

    return ListView.builder(
      itemCount: following.length,
      itemBuilder: (context, index) {
        final followed = following[index];
        return FollowingTile(followed: followed);
      },
    );
  }
}

class FollowingTile extends StatelessWidget {
  final ProfileModel followed;

  const FollowingTile({super.key, required this.followed});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: followed.avatarUrl != null
            ? NetworkImage(followed.avatarUrl!)
            : const AssetImage('assets/images/default_avatar.png')
                as ImageProvider,
      ),
      title: Text(
        followed.username,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: followed.fullName.isNotEmpty
          ? Text(
              followed.fullName,
              style: const TextStyle(color: Colors.grey),
            )
          : null,
      onTap: () {
        // انتقال به صفحه پروفایل دنبال‌شده
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              userId: followed.id,
              username: followed.username,
            ),
          ),
        );
      },
    );
  }
}
