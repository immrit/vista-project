import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../provider/provider.dart';
import 'ActiveSessionsPage.dart';
import '../Settings.dart';
import '../../ouathUser/TwoFactorSetupScreen.dart';

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
                await _upsertUserSetting(
                    context, ref, 'allow_profile_zoom', next);
              },
            );
          }),
          _buildDivider(),
          Consumer(builder: (context, ref, _) {
            final settingsAsync = ref.watch(currentUserSettingsProvider);
            final isPrivate =
                settingsAsync.value?['is_private'] as bool? ?? false;
            return TelegramSwitchItem(
              icon: Icons.lock,
              iconColor: Colors.deepPurple,
              title: 'حساب خصوصی',
              subtitle: 'فقط دنبالکنندگان تایید شده محتوای شما را میبینند',
              value: isPrivate,
              onChanged: (bool next) async {
                await _upsertUserSetting(context, ref, 'is_private', next);
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
          // تایید دو مرحله‌ای
          Consumer(
            builder: (context, ref, child) {
              final securityAsync = ref.watch(securityNotifierProvider);
              final isEnabled = securityAsync?.twoFactorEnabled ?? false;

              return TelegramSwitchItem(
                icon: Icons.verified_user,
                iconColor: Colors.green,
                title: 'تایید دو مرحله‌ای',
                subtitle: isEnabled
                    ? 'حساب شما محافظت اضافی دارد'
                    : 'افزایش امنیت با کد تایید',
                value: isEnabled,
                onChanged: (value) =>
                    _handleTwoFactorToggle(context, ref, value),
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
                  builder: (context) => const ActiveSessionsPage(),
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
            onTap: () => _showSecurityLogs(context, ref),
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
          color: isDark ? Colors.grey[700] : Colors.grey[200],
        );
      },
    );
  }

  // Helper methods
  // بروزرسانی تنظیمات در جدول user_settings (در صورت نبود رکورد، ایجاد میشود)
  Future<void> _upsertUserSetting(BuildContext context, WidgetRef ref,
      String setting, dynamic value) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('user_settings').upsert({
        'user_id': user.id,
        setting: value,
        'updated_at': DateTime.now().toIso8601String(),
      });

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
        _upsertUserSetting(context, ref, 'last_seen_visibility', value);
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

  /// مدیریت تغییر وضعیت 2FA
  Future<void> _handleTwoFactorToggle(
      BuildContext context, WidgetRef ref, bool value) async {
    try {
      if (value) {
        // فعال کردن 2FA
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TwoFactorSetupScreen(),
          ),
        );
      } else {
        // غیرفعال کردن 2FA
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تایید'),
            content: const Text(
                'آیا مطمئن هستید که می‌خواهید تایید دو مرحله‌ای را غیرفعال کنید؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('انصراف'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('تایید'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await ref.read(securityNotifierProvider.notifier).disableTwoFactor();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تایید دو مرحله‌ای غیرفعال شد'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// نمایش لاگ‌های امنیتی
  void _showSecurityLogs(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(securityLogsProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تاریخچه امنیت'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('خطا: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.refresh(securityLogsProvider);
                    },
                    child: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            ),
            data: (logs) => logs.isEmpty
                ? const Center(
                    child: Text('هیچ رویداد امنیتی یافت نشد'),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _buildLogCard(context, log);
                    },
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, dynamic log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _getLogIcon(log.eventType),
              color: _getLogColor(log.eventType),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.description ?? log.eventType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.ipAddress ?? 'IP نامشخص',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(log.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// فرمت کردن تاریخ و زمان
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }

  /// دریافت آیکون مناسب برای نوع لاگ
  IconData _getLogIcon(String eventType) {
    switch (eventType) {
      case 'successful_login':
        return Icons.login;
      case 'failed_login_attempt':
        return Icons.block;
      case 'two_factor_enabled':
        return Icons.verified_user;
      case 'two_factor_disabled':
        return Icons.person_off;
      default:
        return Icons.security;
    }
  }

  /// دریافت رنگ مناسب برای نوع لاگ
  Color _getLogColor(String eventType) {
    switch (eventType) {
      case 'successful_login':
      case 'two_factor_enabled':
        return Colors.green;
      case 'failed_login_attempt':
        return Colors.red;
      case 'two_factor_disabled':
        return Colors.orange;
      default:
        return Colors.blue;
    }
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
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: iconColor,
          ),
        ],
      ),
    );
  }
}
