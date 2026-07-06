import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../provider/provider.dart';
import '../../../services/AppInfoService.dart';
import '../../../services/secure_logout_service.dart';
import '../../../utils/vista_dialog.dart';
import '../../posts/screens/saved_posts_screen.dart';
import '../../profile/screens/updatePassword.dart' show ChangePasswordWidget;
import 'TermsAndConditions.dart';
import 'subpages/AboutSettingsPage.dart';
import 'subpages/ThemeSettingsPage.dart';
import 'subpages/data_storage_settings_page.dart';
import 'subpages/notification_settings_page.dart';
import 'subpages/privacy_security_page.dart';
import 'subpages/VerificationRequestPage.dart';
import 'vistaStore/pricing_page.dart';
import 'package:Vista/l10n/generated/app_localizations.dart';
import 'package:Vista/utils/premium_subscription_utils.dart';
import '../../../provider/locale_provider.dart';
import '../../../utils/directional_navigation.dart';
import 'package:Vista/core/theme/app_theme.dart';

class Settings extends ConsumerWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.settings ?? 'تنظیمات'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        top: false,
        child: profileAsync.when(
          data: (profile) => _buildBody(context, ref, profile, isDark),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Center(child: Text('خطا در بارگذاری تنظیمات')),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? profile,
    bool isDark,
  ) {
    final isPremium = PremiumSubscriptionUtils.isPremiumActive(profile);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        _buildProfileCard(context, profile, isDark),
        const SizedBox(height: 12),
        _buildPremiumEntry(context, isDark, isPremium, profile),
        const SizedBox(height: 12),
        _buildGroup(
          isDark: isDark,
          children: [
            _SettingsTile(
              icon: Icons.person_outline,
              title: AppLocalizations.of(context)?.account ?? 'حساب کاربری',
              onTap: () => Navigator.pushNamed(context, '/editeProfile'),
            ),
            _SettingsTile(
              icon: Icons.shield_outlined,
              title: AppLocalizations.of(context)?.privacySecurity ??
                  'حریم خصوصی و امنیت',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacySecurityPage()),
              ),
            ),
            _SettingsTile(
              icon: Icons.notifications_none_outlined,
              title: AppLocalizations.of(context)?.notifications ?? 'اعلان‌ها',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsPage(),
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.language_outlined,
              title: AppLocalizations.of(context)?.language ?? 'زبان',
              onTap: () => _showLanguageSelector(context, ref, isDark),
            ),
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: AppLocalizations.of(context)?.theme ?? 'ظاهر',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsPage()),
              ),
            ),
            _SettingsTile(
              icon: Icons.storage_outlined,
              title: AppLocalizations.of(context)?.dataStorage ??
                  'داده و ذخیره‌سازی',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DataStorageSettingsPage(),
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.bookmark_border_rounded,
              title: AppLocalizations.of(context)?.savedItems ?? 'ذخیره‌شده‌ها',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedPostsScreen()),
              ),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: AppLocalizations.of(context)?.changePassword ??
                  'تغییر گذرواژه',
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
                  builder: (_) => const VerificationRequestPage(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildGroup(
          isDark: isDark,
          children: [
            _SettingsTile(
              icon: Icons.description_outlined,
              title: AppLocalizations.of(context)?.termsAndConditions ??
                  'قوانین و مقررات',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TermsAndConditionsScreen(),
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: AppLocalizations.of(context)?.aboutVista ?? 'درباره ویستا',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutSettingsPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildGroup(
          isDark: isDark,
          children: [
            _SettingsTile(
              icon: Icons.logout,
              title: AppLocalizations.of(context)?.logout ?? 'خروج از حساب',
              titleColor: Colors.red,
              iconColor: Colors.red,
              onTap: () => _showLogoutDialog(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 26),
        _buildAppVersionLabel(isDark),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPremiumEntry(
    BuildContext context,
    bool isDark,
    bool isPremium,
    Map<String, dynamic>? profile,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PricingPage()),
          ),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: isPremium
                    ? [
                        AppColors.primaryDark.withValues(alpha: 0.35),
                        const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                      ]
                    : [
                        AppColors.primaryDark,
                        const Color(0xFF6C5CE7),
                      ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPremium
                          ? Icons.verified
                          : Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium ? 'ویستا پریمیوم فعال' : 'ویستا پریمیوم',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPremium
                              ? PremiumSubscriptionUtils.remainingLabel(profile)
                              : 'تیک طلایی، استوری ۴۸ساعته، فایل ۵۰مگ و بیشتر',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        if (isPremium &&
                            PremiumSubscriptionUtils.formatExpiryDate(profile)
                                .isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'تمدید اشتراک → روزها به موجودی شما اضافه می‌شود',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    directionalForwardChevronIcon(context),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Icon(
                    Icons.person,
                    size: 24,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/editeProfile'),
            icon: Icon(
              directionalForwardChevronIcon(context),
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(14),
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

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await VistaDialog.showLogoutDialog(context);
    if (confirmed == true && context.mounted) {
      await SecureLogoutService.performLogout(context, ref);
    }
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final currentLocale = ref.read(localeProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)?.selectLanguage ?? 'انتخاب زبان',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.language),
                trailing: currentLocale.languageCode == 'fa'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                title: Text('فارسی',
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black)),
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale('fa');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                trailing: currentLocale.languageCode == 'en'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                title: Text('English',
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black)),
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale('en');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                trailing: currentLocale.languageCode == 'ar'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                title: Text('العربية',
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black)),
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale('ar');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.iconColor,
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
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor ?? defaultTextColor,
        ),
      ),
      trailing: Icon(
        directionalForwardChevronIcon(context),
        color: isDark ? Colors.grey[700] : Colors.grey[400],
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
    );
  }
}
