import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../model/channel_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../provider/channel_provider.dart';

class ChannelSettingsScreen extends ConsumerWidget {
  final ChannelModel channel;

  const ChannelSettingsScreen({Key? key, required this.channel})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin =
        channel.memberRole == 'admin' || channel.memberRole == 'owner';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات کانال'),
      ),
      body: ListView(
        children: [
          _buildChannelInfo(context),
          const Divider(),
          if (isAdmin) _buildAdminSection(context, ref),
          _buildMemberSection(context, ref),
          const Divider(),
          _buildActionButtons(context, ref),
        ],
      ),
    );
  }

  Widget _buildChannelInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: channel.avatarUrl != null
                ? CachedNetworkImageProvider(channel.avatarUrl!)
                : null,
            child: channel.avatarUrl == null
                ? Text(
                    channel.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            channel.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (channel.username != null)
            Text(
              '@${channel.username}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 8),
          if (channel.description != null)
            Text(
              channel.description!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          Text(
            '${channel.memberCount} عضو',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'تنظیمات مدیریت',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('ویرایش اطلاعات کانال'),
          onTap: () => _showEditChannelDialog(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('لینک دعوت'),
          onTap: () => _showInviteLinkDialog(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('مدیریت اعضا'),
          onTap: () => _showMemberManagementDialog(context, ref),
        ),
      ],
    );
  }

  Widget _buildMemberSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'اعضای کانال',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        // نمایش لیست اعضا
        // این بخش باید با استفاده از provider تکمیل شود
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (channel.isSubscribed)
            ElevatedButton(
              onPressed: () => _showLeaveChannelDialog(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('خروج از کانال'),
            )
          else
            ElevatedButton(
              onPressed: () => _joinChannel(context, ref),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('عضویت در کانال'),
            ),
        ],
      ),
    );
  }

  // Dialog methods
  void _showEditChannelDialog(BuildContext context, WidgetRef ref) {
    // پیاده‌سازی دیالوگ ویرایش کانال
  }

  void _showInviteLinkDialog(BuildContext context, WidgetRef ref) {
    // پیاده‌سازی دیالوگ لینک دعوت
  }

  void _showMemberManagementDialog(BuildContext context, WidgetRef ref) {
    // پیاده‌سازی دیالوگ مدیریت اعضا
  }

  void _showLeaveChannelDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خروج از کانال'),
        content: const Text('آیا مطمئن هستید که می‌خواهید از کانال خارج شوید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(channelProvider.notifier).leaveChannel(channel.id);
              Navigator.pop(context); // برگشت به صفحه قبل
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  void _joinChannel(BuildContext context, WidgetRef ref) {
    ref.read(channelProvider.notifier).joinChannel(channel.id).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('با موفقیت به کانال پیوستید')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در عضویت: $error')),
      );
    });
  }
}
