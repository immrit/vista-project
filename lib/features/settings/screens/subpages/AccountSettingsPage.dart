import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:Vista/features/profile/screens/updatePassword.dart';
import 'EmailEditPage.dart';
import '../widgets/SettingsListItem.dart';

class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('حساب کاربری'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // بخش تنظیمات حساب کاربری
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.person,
                  iconColor: Colors.blue,
                  title: 'ویرایش پروفایل',
                  subtitle: 'تغییر نام، بیو، عکس پروفایل',
                  onTap: () {
                    Navigator.pushNamed(context, '/editeProfile');
                  },
                ),
                _buildDivider(),
                SettingsListItem(
                  icon: Icons.lock,
                  iconColor: Colors.orange,
                  title: 'تغییر رمز عبور',
                  subtitle: 'تنظیم رمز عبور جدید',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChangePasswordWidget(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                SettingsListItem(
                  icon: Icons.email,
                  iconColor: Colors.green,
                  title: 'ویرایش ایمیل',
                  subtitle: 'تغییر آدرس ایمیل حساب کاربری',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmailEditPage(),
                      ),
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
}
