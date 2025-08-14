import 'package:flutter/material.dart';

import '../ContactUs.dart';
import '../TermsAndConditions.dart';

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('درباره ویستا'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TelegramSettingsItem(
                  icon: Icons.info,
                  iconColor: Colors.blue,
                  title: 'درباره ویستا',
                  subtitle: 'اطلاعات کلی درباره برنامه و تیم سازنده',
                  onTap: () {
                    _showAboutDialog(context);
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.gavel,
                  iconColor: Colors.orange,
                  title: 'شرایط و قوانین',
                  subtitle: 'قوانین استفاده از ویستا',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TermsAndConditionsScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.contact_support,
                  iconColor: Colors.green,
                  title: 'تماس با ما',
                  subtitle: 'راه‌های ارتباط با تیم پشتیبانی',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContactUsScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.security,
                  iconColor: Colors.red,
                  title: 'سیاست حریم خصوصی',
                  subtitle: 'نحوه حفاظت از اطلاعات شخصی شما',
                  onTap: () {
                    _showPrivacyDialog(context);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // بخش پشتیبانی
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TelegramSettingsItem(
                  icon: Icons.help,
                  iconColor: Colors.purple,
                  title: 'سوالات متداول',
                  subtitle: 'پاسخ سوالات رایج کاربران',
                  onTap: () {
                    _showFAQDialog(context);
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.bug_report,
                  iconColor: Colors.red,
                  title: 'گزارش مشکل',
                  subtitle: 'گزارش باگ یا پیشنهاد بهبود',
                  onTap: () {
                    _showBugReportDialog(context);
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.star,
                  iconColor: Colors.amber,
                  title: 'امتیاز به ویستا',
                  subtitle: 'نظر خود را در مورد برنامه بدهید',
                  onTap: () {
                    _showRatingDialog(context);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // بخش اطلاعات فنی
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TelegramSettingsItem(
                  icon: Icons.code,
                  iconColor: Colors.teal,
                  title: 'نسخه برنامه',
                  subtitle: '۱.۲.۸ (ساخت ۲۶)',
                  onTap: () {
                    _showVersionDialog(context);
                  },
                ),
                _buildDivider(),
                TelegramSettingsItem(
                  icon: Icons.update,
                  iconColor: Colors.indigo,
                  title: 'بررسی به‌روزرسانی',
                  subtitle: 'جستجو برای نسخه جدید',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('شما از آخرین نسخه استفاده می‌کنید')),
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
          color: isDark ? Colors.grey[700] : Colors.grey[200],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('درباره ویستا'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'ویستا یک پلتفرم اجتماعی مدرن برای اشتراک‌گذاری محتوا و ارتباط با دوستان است.'),
            SizedBox(height: 16),
            Text('ویژگی‌ها:'),
            Text('• چت و پیام‌رسانی'),
            Text('• اشتراک‌گذاری عکس و ویدیو'),
            Text('• قابلیت‌های اجتماعی'),
            Text('• رابط کاربری زیبا و ساده'),
          ],
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

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حریم خصوصی'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ویستا متعهد به حفاظت از حریم خصوصی شماست:'),
            SizedBox(height: 8),
            Text('• اطلاعات شما رمزگذاری می‌شود'),
            Text('• هیچ اطلاعاتی به اشتراک گذاشته نمی‌شود'),
            Text('• کنترل کامل بر روی داده‌های خود دارید'),
            Text('• امکان حذف حساب در هر زمان'),
          ],
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

  void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سوالات متداول'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('چگونه حساب کاربری بسازم؟'),
            Text('→ از طریق ایمیل یا شماره تلفن ثبت‌نام کنید'),
            SizedBox(height: 8),
            Text('چگونه رمز عبور را تغییر دهم؟'),
            Text('→ تنظیمات > حساب کاربری > تغییر رمز عبور'),
            SizedBox(height: 8),
            Text('چگونه پروفایل را ویرایش کنم؟'),
            Text('→ روی عکس پروفایل در تنظیمات کلیک کنید'),
          ],
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

  void _showBugReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('گزارش مشکل'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'توضیح مشکل یا پیشنهاد خود را بنویسید...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            SizedBox(height: 16),
            Text(
              'گزارش شما برای ما ارزشمند است و به بهبود ویستا کمک می‌کند.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('گزارش شما ارسال شد. متشکریم!')),
              );
            },
            child: const Text('ارسال'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('امتیاز به ویستا'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('آیا از ویستا راضی هستید؟'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
              ],
            ),
            SizedBox(height: 8),
            Text('۵ ستاره', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بعداً'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('متشکریم از امتیاز شما!')),
              );
            },
            child: const Text('ارسال امتیاز'),
          ),
        ],
      ),
    );
  }

  void _showVersionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اطلاعات نسخه'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('نسخه: ۱.۲.۸'),
            Text('ساخت: ۲۶'),
            Text('تاریخ انتشار: ۱۴۰۳/۱۰/۱۵'),
            SizedBox(height: 16),
            Text('تغییرات این نسخه:'),
            Text('• بهبود رابط کاربری'),
            Text('• رفع مشکلات گزارش شده'),
            Text('• افزایش سرعت برنامه'),
          ],
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
                            : Colors.grey[700],
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
                    : Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
