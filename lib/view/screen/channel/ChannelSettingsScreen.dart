import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../model/channel_model.dart';
import '../../../provider/channel_provider.dart';

class ChannelSettingsScreen extends ConsumerStatefulWidget {
  final ChannelModel channel;

  const ChannelSettingsScreen({Key? key, required this.channel})
      : super(key: key);

  @override
  ConsumerState<ChannelSettingsScreen> createState() =>
      _ChannelSettingsScreenState();
}

class _ChannelSettingsScreenState extends ConsumerState<ChannelSettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.channel.memberRole == 'admin' ||
        widget.channel.memberRole == 'owner';
    final isOwner = widget.channel.memberRole == 'owner';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات کانال'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showMoreOptions(context),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _refreshChannelData(),
              child: ListView(
                children: [
                  _buildChannelInfo(context),
                  const Divider(height: 1),
                  if (isAdmin) ...[
                    _buildAdminSection(context, isOwner),
                    const Divider(height: 1),
                  ],
                  _buildMemberSection(context),
                  const Divider(height: 1),
                  _buildNotificationSettings(context),
                  const Divider(height: 1),
                  _buildActionButtons(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildChannelInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.channel.avatarUrl != null
                    ? CachedNetworkImageProvider(widget.channel.avatarUrl!)
                    : null,
                child: widget.channel.avatarUrl == null
                    ? Text(
                        widget.channel.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (widget.channel.isPrivate)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.channel.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          if (widget.channel.username != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _copyToClipboard('@${widget.channel.username}'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${widget.channel.username}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (widget.channel.description != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.channel.description!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInfoChip(
                icon: Icons.people,
                label: '${widget.channel.memberCount} عضو',
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                icon: widget.channel.isPrivate ? Icons.lock : Icons.public,
                label: widget.channel.isPrivate ? 'خصوصی' : 'عمومی',
                color: widget.channel.isPrivate ? Colors.orange : Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context, bool isOwner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'تنظیمات مدیریت',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
        _buildSettingsTile(
          icon: Icons.edit,
          title: 'ویرایش اطلاعات کانال',
          subtitle: 'تغییر نام، توضیحات و آواتار',
          onTap: () => _showEditChannelDialog(context),
        ),
        _buildSettingsTile(
          icon: Icons.link,
          title: 'لینک دعوت',
          subtitle: 'ایجاد و مدیریت لینک‌های دعوت',
          onTap: () => _showInviteLinkDialog(context),
        ),
        _buildSettingsTile(
          icon: Icons.people_outline,
          title: 'مدیریت اعضا',
          subtitle: 'مشاهده و مدیریت اعضای کانال',
          onTap: () => _showMemberManagementDialog(context),
        ),
        if (isOwner)
          _buildSettingsTile(
            icon: Icons.security,
            title: 'تنظیمات امنیتی',
            subtitle: 'مجوزها و محدودیت‌ها',
            onTap: () => _showSecuritySettings(context),
          ),
      ],
    );
  }

  Widget _buildMemberSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.people, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'اعضای کانال',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showAllMembers(context),
                child: const Text('مشاهده همه'),
              ),
            ],
          ),
        ),
        // نمایش چند عضو اول
        _buildMemberPreview(),
      ],
    );
  }

  Widget _buildMemberPreview() {
    // این بخش باید با داده‌های واقعی از API پر شود
    return Column(
      children: [
        _buildMemberTile(
          name: 'مدیر کانال',
          role: 'owner',
          avatar: null,
          isOnline: true,
        ),
        _buildMemberTile(
          name: 'کاربر نمونه',
          role: 'member',
          avatar: null,
          isOnline: false,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'و ${widget.channel.memberCount > 2 ? widget.channel.memberCount - 2 : 0} عضو دیگر...',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTile({
    required String name,
    required String role,
    String? avatar,
    required bool isOnline,
  }) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage:
                avatar != null ? CachedNetworkImageProvider(avatar) : null,
            child: avatar == null ? Text(name[0].toUpperCase()) : null,
          ),
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(name),
      subtitle: Text(_getRoleText(role)),
      trailing: _getRoleIcon(role),
    );
  }

  Widget _buildNotificationSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.notifications, color: Colors.purple),
              const SizedBox(width: 8),
              const Text(
                'اعلان‌ها',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('اعلان پیام‌های جدید'),
          subtitle: const Text('دریافت اعلان برای پیام‌های جدید'),
          value: true, // باید از تنظیمات کاربر بیاد
          onChanged: (value) {
            // پیاده‌سازی تغییر تنظیمات اعلان
          },
          secondary: const Icon(Icons.message),
        ),
        SwitchListTile(
          title: const Text('اعلان منشن‌ها'),
          subtitle: const Text('دریافت اعلان وقتی منشن می‌شوید'),
          value: true, // باید از تنظیمات کاربر بیاد
          onChanged: (value) {
            // پیاده‌سازی تغییر تنظیمات اعلان
          },
          secondary: const Icon(Icons.alternate_email),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.channel.isSubscribed) ...[
            ElevatedButton.icon(
              onPressed: () => _showLeaveChannelDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.exit_to_app),
              label: const Text('خروج از کانال'),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: () => _joinChannel(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('عضویت در کانال'),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _shareChannel(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.share),
            label: const Text('اشتراک‌گذاری کانال'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  // Helper methods
  String _getRoleText(String role) {
    switch (role) {
      case 'owner':
        return 'مالک کانال';
      case 'admin':
        return 'مدیر';
      case 'moderator':
        return 'ناظر';
      default:
        return 'عضو';
    }
  }

  Widget _getRoleIcon(String role) {
    switch (role) {
      case 'owner':
        return const Icon(Icons.admin_panel_settings, color: Colors.amber);
      case 'admin':
        return const Icon(Icons.admin_panel_settings, color: Colors.red);
      case 'moderator':
        return const Icon(Icons.shield, color: Colors.blue);
      default:
        return const SizedBox.shrink();
    }
  }

  // Action methods
  Future<void> _refreshChannelData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // رفرش داده‌های کانال
      await ref
          .read(channelNotifierProvider.notifier)
          .refreshChannel(widget.channel.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بروزرسانی: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('کپی شد')),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('اطلاعات کانال'),
            onTap: () {
              Navigator.pop(context);
              _showChannelInfo(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text('گزارش کانال'),
            onTap: () {
              Navigator.pop(context);
              _reportChannel(context);
            },
          ),
        ],
      ),
    );
  }

  // Dialog methods
  void _showEditChannelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ویرایش کانال'),
        content: const Text('این قابلیت به زودی اضافه خواهد شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  void _showInviteLinkDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('لینک دعوت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('لینک دعوت کانال:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'https://app.com/channel/${widget.channel.username}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      _copyToClipboard(
                        'https://app.com/channel/${widget.channel.username}',
                      );
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  void _showMemberManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مدیریت اعضا'),
        content: const Text('این قابلیت به زودی اضافه خواهد شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  void _showSecuritySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنظیمات امنیتی'),
        content: const Text('این قابلیت به زودی اضافه خواهد شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  void _showAllMembers(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('همه اعضا'),
        content: const Text('این قابلیت به زودی اضافه خواهد شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  void _showChannelInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اطلاعات کانال'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('شناسه: ${widget.channel.id}'),
            Text('تاریخ ایجاد: ${widget.channel.createdAt}'),
            Text('آخرین بروزرسانی: ${widget.channel.updatedAt}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  void _reportChannel(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('گزارش کانال'),
        content: const Text('این قابلیت به زودی اضافه خواهد شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  void _shareChannel(BuildContext context) {
    final shareText = widget.channel.username != null
        ? 'بیا توی کانال ${widget.channel.name} عضو شو:\nhttps://app.com/channel/${widget.channel.username}'
        : 'بیا توی کانال ${widget.channel.name} عضو شو!';

    // پیاده‌سازی اشتراک‌گذاری
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لینک کپی شد: $shareText')),
    );
  }

  void _showLeaveChannelDialog(BuildContext context) {
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(channelNotifierProvider.notifier)
                    .leaveChannel(widget.channel.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('با موفقیت از کانال خارج شدید')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در خروج: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  void _joinChannel(BuildContext context) async {
    try {
      await ref
          .read(channelNotifierProvider.notifier)
          .joinChannel(widget.channel.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('با موفقیت به کانال پیوستید')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در عضویت: $e')),
        );
      }
    }
  }
}
