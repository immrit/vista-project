import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../chat/ChatSettingsScreen.dart';
import '../../../../provider/provider.dart';

class ChatSettingsGroupPage extends ConsumerWidget {
  const ChatSettingsGroupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('چت و مکالمات'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF252525) : Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // بخش عمومی
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TelegramSettingsItem(
                  icon: Icons.settings,
                  iconColor: Colors.blue,
                  title: 'تنظیمات کلی چت',
                  subtitle: 'تنظیمات عمومی چت و پیام‌رسانی',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatSettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.archive,
                  iconColor: Colors.orange,
                  title: 'مکالمات آرشیو شده',
                  subtitle: 'مشاهده و مدیریت مکالمات آرشیو شده',
                  onTap: () {
                    // TODO: Navigate to archived conversations
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('به زودی اضافه خواهد شد')),
                    );
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.folder,
                  iconColor: Colors.green,
                  title: 'پوشه‌های چت',
                  subtitle: 'دسته‌بندی و سازماندهی مکالمات',
                  onTap: () {
                    // TODO: Navigate to chat folders
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('به زودی اضافه خواهد شد')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // بخش حریم خصوصی
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Consumer(builder: (context, ref, _) {
                  final settingsAsync = ref.watch(currentUserSettingsProvider);
                  final value =
                      settingsAsync.value?['allow_profile_zoom'] as bool? ??
                          true;
                  return TelegramSwitchItem(
                    icon: Icons.zoom_in,
                    iconColor: Colors.purple,
                    title: 'اجازه بزرگنمایی پروفایل',
                    subtitle:
                        'دیگران بتوانند عکس پروفایل شما را بزرگنمایی کنند',
                    value: value,
                    onChanged: (bool next) async {
                      try {
                        final client = Supabase.instance.client;
                        final userId = client.auth.currentUser?.id;
                        if (userId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('ابتدا وارد حساب خود شوید')),
                          );
                          return;
                        }
                        await client.from('user_settings').upsert({
                          'user_id': userId,
                          'allow_profile_zoom': next,
                        });
                        final _ = await ref
                            .refresh(currentUserSettingsProvider.future);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('تنظیمات حریم خصوصی به‌روزرسانی شد')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطا در ذخیره تنظیم: $e')),
                        );
                      }
                    },
                  );
                }),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.visibility,
                  iconColor: Colors.red,
                  title: 'آخرین بازدید',
                  subtitle: 'تنظیم نمایش آخرین زمان حضور آنلاین',
                  onTap: () {
                    _showLastSeenDialog(context);
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.block,
                  iconColor: Colors.grey,
                  title: 'کاربران مسدود شده',
                  subtitle: 'مشاهده و مدیریت کاربران مسدود شده',
                  onTap: () {
                    // TODO: Navigate to blocked users
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('به زودی اضافه خواهد شد')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // بخش پیام‌ها
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TelegramSettingsItem(
                  icon: Icons.text_fields,
                  iconColor: Colors.teal,
                  title: 'اندازه فونت پیام‌ها',
                  subtitle: 'تنظیم اندازه متن در مکالمات',
                  onTap: () {
                    _showFontSizeDialog(context);
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.download,
                  iconColor: Colors.indigo,
                  title: 'دانلود خودکار رسانه',
                  subtitle: 'تنظیم دانلود خودکار عکس و ویدیو',
                  onTap: () {
                    // TODO: Navigate to auto download settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('به زودی اضافه خواهد شد')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(left: 68.0),
          height: 0.5,
          color: isDark ? Colors.grey[700] : Colors.grey[300],
        );
      },
    );
  }

  void _showLastSeenDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('آخرین بازدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('همه'),
              subtitle: const Text('همه کاربران آخرین بازدید شما را ببینند'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('مخاطبین'),
              subtitle: const Text('فقط مخاطبین شما'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('هیچ‌کس'),
              subtitle: const Text('هیچ‌کس آخرین بازدید شما را نبیند'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSizeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اندازه فونت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('کوچک'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('متوسط'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('بزرگ'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('خیلی بزرگ'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class TelegramSwitchItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const TelegramSwitchItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }
}

class TelegramSettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const TelegramSettingsItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[500]
                    : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
