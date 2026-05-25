import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../utils/vista_dialog.dart';
import '../../../provider/provider.dart';
import '../../../services/secure_logout_service.dart';
import '../../profile/screens/updatePassword.dart' show ChangePasswordWidget;
import '../../posts/screens/saved_posts_screen.dart';
import 'subpages/ThemeSettingsPage.dart';
import 'subpages/privacy_security_page.dart';
import 'subpages/notification_settings_page.dart';
import 'subpages/data_storage_settings_page.dart';
import 'subpages/AboutSettingsPage.dart';
import 'subpages/AboutSettingsPage.dart';
import 'subpages/VerificationRequestPage.dart';
import 'vistaStore/pricing_page.dart';
import 'TermsAndConditions.dart';
import '../../../services/AppInfoService.dart';

/// صفحه تنظیمات ساده و تمیز - الهام گرفته از ویستا
class Settings extends ConsumerWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('تنظیمات'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        top: false,
        child: profileAsync.when(
          data: (profile) => _buildSettingsList(context, ref, profile, isDark),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('خطا در بارگذاری')),
        ),
      ),
    );
  }

  Widget _buildSettingsList(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? profile,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // کارت پروفایل
        _buildProfileCard(context, profile, isDark),
        const SizedBox(height: 24),

        // بخش ویستا پریمیوم (اضافه شده مجدد)
        _buildSectionHeader('ویستا پریمیوم', isDark),
        _buildSettingsGroup(
          isDark: isDark,
          children: [
            _SettingsTile(
              icon: Icons.star_rounded,
              title: 'ویستا پریمیوم',
              iconColor: const Color(0xFF8774E1), // رنگ بنفش پریمیوم
              titleColor: const Color(0xFF8774E1),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF8774E1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ویژه',
                  style: TextStyle(
                    color: Color(0xFF8774E1),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PricingPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // بخش حساب کاربری
        _buildSectionHeader('حساب کاربری', isDark),
        _buildSettingsGroup(
          isDark: isDark,
          children: [
            _SettingsTile(
              icon: Icons.person_outline,
              title: 'ویرایش پروفایل',
              onTap: () => Navigator.pushNamed(context, '/editeProfile'),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: 'امنیت و گذرواژه',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChangePasswordWidget()),
              ),
            ),
            _SettingsTile(
              icon: Icons.verified_outlined,
              title: 'درخواست تیک آبی',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const VerificationRequestPage()),
              ),
            ),
            _SettingsTile(
              icon: Icons.bookmark_border_rounded,
              title: 'پست‌های ذخیره‌شده',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedPostsScreen()),
              ),
            ),
            _SettingsTile(
              icon: Icons.shield_outlined,
              title: 'حریم خصوصی',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacySecurityPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // بخش برنامه
        _buildSectionHeader('برنامه', isDark),
        _buildSettingsGroup(
          isDark: isDark,
          children: [
            _SettingsTile(
              icon: Icons.notifications_none_outlined,
              title: 'اعلان‌ها',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsPage()),
              ),
            ),
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: 'ظاهر و تم',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsPage()),
              ),
            ),
            _SettingsTile(
              icon: Icons.storage_outlined,
              title: 'داده‌ها و ذخیره‌سازی',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DataStorageSettingsPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // بخش پشتیبانی
        _buildSectionHeader('پشتیبانی', isDark),
        _buildSettingsGroup(
          isDark: isDark,
          children: [
            _SettingsTile(
              icon: Icons.description_outlined,
              title: 'قوانین و مقررات',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TermsAndConditionsScreen(),
                  ),
                );
              },
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'درباره ویستا',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutSettingsPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // دکمه خروج
        _buildSettingsGroup(
          isDark: isDark,
          children: [
            _SettingsTile(
              icon: Icons.logout,
              title: 'خروج از حساب',
              titleColor: Colors.red,
              iconColor: Colors.red,
              onTap: () => _showLogoutDialog(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 40),

        // نسخه برنامه
        _buildAppVersionLabel(isDark),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAppVersionLabel(bool isDark) {
    return FutureBuilder<String>(
      future: AppInfoService.getPubspecVersion(),
      builder: (context, snapshot) {
        final version =
            (snapshot.data != null && snapshot.data!.trim().isNotEmpty)
                ? snapshot.data!.trim()
                : '--';

        return Center(
          child: Text(
            'نسخه $version',
            style: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[500],
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    Map<String, dynamic>? profile,
    bool isDark,
  ) {
    final avatarUrl = profile?['avatar_url'];
    final username = profile?['username'] ?? 'کاربر';
    final email = profile?['email']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Icon(
                    Icons.person,
                    size: 30,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/editeProfile'),
            icon: Icon(
              Icons.chevron_left,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          return Column(
            children: [
              children[index],
              if (index < children.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                ),
            ],
          );
        }),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await VistaDialog.showLogoutDialog(context);

    if (confirmed == true && context.mounted) {
      await SecureLogoutService.performLogout(context, ref);
    }
  }
}

/// ویجت آیتم تنظیمات
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDark ? Colors.white : Colors.black;
    final defaultIconColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? defaultIconColor,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: titleColor ?? defaultTextColor,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_left,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
            size: 20,
          ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
