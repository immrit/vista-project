import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../provider/provider.dart';
import 'SecuritySettingsPage.dart';
import '../Settings.dart'; // برای TelegramSettingsItem

class PrivacySettingsPage extends ConsumerWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('حریم خصوصی و امنیت'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF252525) : Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // بخش حریم خصوصی پروفایل
          _buildPrivacySection(context, ref),

          const SizedBox(height: 20),

          // بخش امنیت حساب
          _buildSecuritySection(context, ref),

          const SizedBox(height: 20),

          // بخش مسدودسازی و گزارش
          _buildBlockingSection(context, ref),

          const SizedBox(height: 20),

          // بخش داده‌ها و حفظ حریم خصوصی
          _buildDataSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
                settingsAsync.value?['allow_profile_zoom'] as bool? ?? true;
            return TelegramSwitchItem(
              icon: Icons.zoom_in,
              iconColor: Colors.blue,
              title: 'اجازه بزرگنمایی پروفایل',
              subtitle: 'دیگران بتوانند عکس پروفایل شما را بزرگنمایی کنند',
              value: value,
              onChanged: (bool next) async {
                await _updatePrivacySetting(
                    context, ref, 'allow_profile_zoom', next);
              },
            );
          }),
          _buildDivider(),
          TelegramSettingsItem(
            icon: Icons.visibility,
            iconColor: Colors.green,
            title: 'آخرین بازدید',
            subtitle: 'کنترل نمایش آخرین بازدید شما',
            onTap: () => _showLastSeenDialog(context, ref),
          ),
          _buildDivider(),
          TelegramSettingsItem(
            icon: Icons.phone,
            iconColor: Colors.orange,
            title: 'شماره تلفن',
            subtitle: 'کنترل نمایش شماره تلفن شما',
            onTap: () => _showPhoneNumberDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TelegramSettingsItem(
            icon: Icons.security,
            iconColor: Colors.red,
            title: 'امنیت حساب کاربری',
            subtitle: 'تایید دو مرحله‌ای، قفل اپلیکیشن، جلسات فعال',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecuritySettingsPage(),
                ),
              );
            },
          ),
          _buildDivider(),
          TelegramSettingsItem(
            icon: Icons.devices,
            iconColor: Colors.purple,
            title: 'جلسات فعال',
            subtitle: 'مدیریت دستگاه‌های متصل به حساب شما',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActiveSessionsScreen(),
                ),
              );
            },
          ),
          _buildDivider(),
          TelegramSettingsItem(
            icon: Icons.history,
            iconColor: Colors.teal,
            title: 'تاریخچه امنیت',
            subtitle: 'مشاهده فعالیت‌های امنیتی اخیر',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecurityLogsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBlockingSection(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TelegramSettingsItem(
            icon: Icons.block,
            iconColor: Colors.brown,
            title: 'کاربران مسدود شده',
            subtitle: 'مدیریت لیست کاربران مسدود شده',
            onTap: () {
              _showComingSoon(context,
                  'قابلیت مدیریت کاربران مسدود شده به زودی اضافه خواهد شد!');
            },
          ),
          _buildDivider(),
          TelegramSettingsItem(
            icon: Icons.report_problem,
            iconColor: Colors.deepOrange,
            title: 'گزارش مشکل',
            subtitle: 'گزارش محتوای نامناسب یا مشکلات امنیتی',
            onTap: () {
              _showComingSoon(
                  context, 'قابلیت گزارش مشکل به زودی اضافه خواهد شد!');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TelegramSettingsItem(
            icon: Icons.delete_forever,
            iconColor: Colors.redAccent,
            title: 'پاک کردن کش',
            subtitle: 'آزاد کردن فضای ذخیره‌سازی',
            onTap: () {
              _showComingSoon(
                  context, 'قابلیت پاک کردن کش به زودی اضافه خواهد شد!');
            },
          ),
          _buildDivider(),
          TelegramSettingsItem(
            icon: Icons.download,
            iconColor: Colors.indigo,
            title: 'دانلود اطلاعات من',
            subtitle: 'دریافت کپی از اطلاعات حساب شما',
            onTap: () {
              _showComingSoon(
                  context, 'قابلیت دانلود اطلاعات به زودی اضافه خواهد شد!');
            },
          ),
          _buildDivider(),
          TelegramSettingsItem(
            icon: Icons.account_circle,
            iconColor: Colors.grey,
            title: 'حذف حساب کاربری',
            subtitle: 'حذف دائمی حساب و اطلاعات شما',
            onTap: () {
              _showDeleteAccountDialog(context);
            },
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

  // Helper methods
  Future<void> _updatePrivacySetting(BuildContext context, WidgetRef ref,
      String setting, dynamic value) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('profiles').update({
        setting: value,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      final _ = ref.refresh(currentUserSettingsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تنظیمات با موفقیت به‌روزرسانی شد'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در به‌روزرسانی: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLastSeenDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('آخرین بازدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('همه'),
              onTap: () => Navigator.pop(context, 'everyone'),
            ),
            ListTile(
              title: const Text('مخاطبین من'),
              onTap: () => Navigator.pop(context, 'my_contacts'),
            ),
            ListTile(
              title: const Text('هیچکس'),
              onTap: () => Navigator.pop(context, 'nobody'),
            ),
          ],
        ),
      ),
    ).then((value) {
      if (value != null) {
        _updatePrivacySetting(context, ref, 'last_seen_visibility', value);
      }
    });
  }

  void _showPhoneNumberDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نمایش شماره تلفن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('همه'),
              onTap: () => Navigator.pop(context, 'everyone'),
            ),
            ListTile(
              title: const Text('مخاطبین من'),
              onTap: () => Navigator.pop(context, 'my_contacts'),
            ),
            ListTile(
              title: const Text('هیچکس'),
              onTap: () => Navigator.pop(context, 'nobody'),
            ),
          ],
        ),
      ),
    ).then((value) {
      if (value != null) {
        _updatePrivacySetting(context, ref, 'phone_number_visibility', value);
      }
    });
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('هشدار'),
          ],
        ),
        content: const Text(
          'حذف حساب کاربری غیرقابل بازگشت است.\n\nبرای حذف حساب، لطفاً با پشتیبانی تماس بگیرید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }
}

// Widget برای آیتم‌های Switch
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }
}
