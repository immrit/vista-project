import 'package:flutter/material.dart';

import '../ContactUs.dart';
import '../TermsAndConditions.dart';
import '../PrivacyPolicyScreen.dart';
import '../FAQScreen.dart';
import '../widgets/SettingsListItem.dart';
import 'VistaAboutSlideshow.dart';
import '../../../../services/BazaarService.dart';
import '../../../../services/AppInfoService.dart';

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('درباره ویستا'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SettingsListItem(
                    icon: Icons.info,
                    iconColor: Colors.blue,
                    title: 'درباره ویستا',
                    subtitle: 'اطلاعات کلی درباره برنامه و تیم سازنده',
                    onTap: () {
                      _showAboutDialog(context);
                    },
                  ),
                  _buildDivider(),
                  SettingsListItem(
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
                  SettingsListItem(
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
                  SettingsListItem(
                    icon: Icons.security,
                    iconColor: Colors.red,
                    title: 'سیاست حریم خصوصی',
                    subtitle: 'نحوه حفاظت از اطلاعات شخصی شما',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
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
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SettingsListItem(
                    icon: Icons.help,
                    iconColor: Colors.purple,
                    title: 'سوالات متداول',
                    subtitle: 'پاسخ سوالات رایج کاربران',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FAQScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.star,
                    iconColor: Colors.amber,
                    title: 'امتیاز به ویستا',
                    subtitle: 'نظر خود را در مورد برنامه بدهید',
                    onTap: () {
                      BazaarService.showRatingDialog(context);
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
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildVersionSettingsItem(context),
                  _buildDivider(),
                  SettingsListItem(
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

  Widget _buildVersionSettingsItem(BuildContext context) {
    return FutureBuilder<String>(
      future: AppInfoService.getPubspecVersion(),
      builder: (context, snapshot) {
        final version =
            (snapshot.data != null && snapshot.data!.trim().isNotEmpty)
                ? snapshot.data!.trim()
                : '--';

        return SettingsListItem(
          icon: Icons.code,
          iconColor: Colors.teal,
          title: 'نسخه برنامه',
          subtitle: 'نسخه $version',
          onTap: () {
            BazaarService.showUpdateDialog(context);
          },
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VistaAboutSlideshow(),
        fullscreenDialog: true,
      ),
    );
  }
}
