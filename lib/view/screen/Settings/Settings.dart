import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ایمپورت‌های مربوط به پروژه شما
import '../../../main.dart';
import '../../../provider/provider.dart';
import '../../util/themes.dart';
import '../../widgets/VideoPlayerConfig.dart';
import '../ouathUser/updatePassword.dart';
import 'ContactUs.dart';
import 'TermsAndConditions.dart';
import 'vistaStore/store.dart';

class Settings extends ConsumerWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final getprofile = ref.watch(profileProvider);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final autoPlay = ref.watch(autoPlayProvider);

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تنظیمات'),
          elevation: 0, // حذف سایه
          centerTitle: true, // مرکز قرار دادن عنوان
        ),
        body: getprofile.when(
          data: (getprofile) {
            return SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // پروفایل کاربر - با طراحی زیباتر
                      _buildUserProfileCard(context, getprofile, colorScheme),

                      const SizedBox(height: 24),

                      // بخش تنظیمات حساب کاربری
                      _buildSectionHeader('حساب کاربری', Icons.person_outline),
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ProfileFields(
                              'ویرایش پروفایل',
                              Icons.person,
                              () {
                                Navigator.pushNamed(context, '/editeProfile');
                              },
                              colorScheme.primary,
                            ),
                            const Divider(height: 1),
                            ProfileFields(
                              'تغییر رمز عبور',
                              Icons.lock,
                              () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) =>
                                        ChangePasswordWidget()));
                              },
                              colorScheme.primary,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // بخش ظاهر و شخصی‌سازی
                      _buildSectionHeader('ظاهر و شخصی‌سازی', Icons.palette),
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ProfileFields(
                          'تم و استایل',
                          Icons.color_lens,
                          () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const ThemeItems()));
                          },
                          colorScheme.primary,
                        ),
                      ),

                      const SizedBox(height: 24),
                      const SizedBox(height: 24),

                      // فروشگاه ویستا
                      _buildSectionHeader('ویستا استور', Icons.palette),
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            ProfileFields('نشان‌های ویژه', Icons.verified, () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const VerificationBadgeStore()));
                        }, colorScheme.primary),
                      ),

                      const SizedBox(height: 24),

                      // اضافه کردن بخش جدید - درباره ما
                      _buildSectionHeader('درباره ما', Icons.info_outline),
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ProfileFields(
                              'شرایط و قوانین',
                              Icons.gavel,
                              () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            TermsAndConditionsScreen()));
                              },
                              colorScheme.primary,
                            ),
                            const Divider(height: 1),
                            ProfileFields(
                              'تماس با ما',
                              Icons.contact_support,
                              () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            ContactUsScreen()));
                              },
                              colorScheme.primary,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // بخش تنظیمات پخش ویدیو
                      _buildSectionHeader(
                          'تنظیمات پخش ویدیو', Icons.play_circle_outline),
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('حالت ذخیره داده'),
                              subtitle: const Text('پخش ویدیو با کیفیت پایین'),
                              value: ref.watch(dataSaverProvider),
                              onChanged: (value) {
                                ref.read(dataSaverProvider.notifier).state =
                                    value;
                                VideoPlayerConfig().setDataSaverMode(value);
                              },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('تنظیم خودکار کیفیت'),
                              subtitle: const Text('بر اساس سرعت اینترنت'),
                              value: ref.watch(autoQualityProvider),
                              onChanged: (value) {
                                ref.read(autoQualityProvider.notifier).state =
                                    value;
                                VideoPlayerConfig().setAutoQuality(value);
                              },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: Text('پخش خودکار ویدیو'),
                              subtitle: Text(
                                  'در صورت غیرفعال بودن، ویدیوها به صورت خودکار پخش نمی‌شوند'),
                              value: autoPlay,
                              onChanged: (val) {
                                ref.read(autoPlayProvider.notifier).set(val);
                              },
                              secondary:
                                  Icon(Icons.play_circle_filled_outlined),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          error: (error, stack) {
            final errorMsg = error.toString() == 'User is not logged in'
                ? 'کاربر وارد سیستم نشده است، لطفاً ورود کنید.'
                : 'خطا در دریافت اطلاعات کاربر، لطفاً دوباره تلاش کنید.';

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    errorMsg,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ref.refresh(profileProvider);
                    },
                    child: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('در حال بارگذاری...'),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: const Align(
            alignment: Alignment.center,
            child: VersionNumber(),
          ),
        ),
      ),
    );
  }

  // ایجاد هدر برای هر بخش
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // کارت پروفایل کاربر با طراحی زیباتر
  Widget _buildUserProfileCard(BuildContext context,
      Map<String, dynamic>? profile, ColorScheme colorScheme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'profile-avatar',
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: profile!['avatar_url'] != null
                        ? NetworkImage(profile['avatar_url'].toString())
                        : const AssetImage(
                                'lib/view/util/images/default-avatar.jpg')
                            as ImageProvider,
                  ),
                ),
                // اضافه کردن نشان تأیید بر اساس نوع آن
                _buildVerificationBadge(context, profile),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          "${profile['username']}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // نمایش نشان در کنار نام کاربری
                      _buildInlineVerificationBadge(profile),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${supabase.auth.currentUser!.email}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/editeProfile');
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('ویرایش'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      visualDensity: VisualDensity.compact,
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

  Widget _buildVerificationBadge(
      BuildContext context, Map<String, dynamic>? profile) {
    // بررسی وضعیت تأیید حساب کاربری
    final bool isVerified = profile?['is_verified'] ?? false;
    if (!isVerified) {
      return const SizedBox.shrink();
    }

    // بررسی نوع نشان تأیید
    final String verificationType = profile?['verification_type'] ?? 'none';
    IconData iconData = Icons.verified;
    Color iconColor = Colors.blue;

    // تعیین نوع و رنگ آیکون بر اساس نوع نشان
    switch (verificationType) {
      case 'blueTick':
        iconData = Icons.verified;
        iconColor = Colors.blue;
        break;
      case 'goldTick':
        iconData = Icons.verified;
        iconColor = Colors.amber;
        break;
      case 'blackTick':
        iconData = Icons.verified;
        iconColor = const Color(0xFF303030); // رنگ مشکی متمایل به خاکستری تیره
        break;
      default:
        // حالت پیش‌فرض برای پروفایل‌های تأیید شده بدون نوع مشخص
        iconData = Icons.verified;
        iconColor = Colors.blue;
    }

    // نمایش نشان با امکان کلیک برای مشاهده اطلاعات بیشتر
    return Positioned(
      bottom: 0,
      right: 0,
      child: GestureDetector(
        onTap: () => _showVerificationBadgeInfo(context, profile),
        child: Container(
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
      ),
    );
  }

// تابع نمایش نشان در کنار نام کاربری
  Widget _buildInlineVerificationBadge(Map<String, dynamic>? profile) {
    // بررسی وضعیت تأیید حساب کاربری
    final bool isVerified = profile?['is_verified'] ?? false;
    if (!isVerified) {
      return const SizedBox.shrink();
    }

    // بررسی نوع نشان تأیید
    final String verificationType = profile?['verification_type'] ?? 'none';
    IconData iconData = Icons.verified;
    Color iconColor = Colors.blue;

    // تعیین نوع و رنگ آیکون بر اساس نوع نشان
    switch (verificationType) {
      case 'blueTick':
        iconColor = Colors.blue;
        break;
      case 'goldTick':
        iconColor = Colors.amber;
        break;
      case 'blackTick':
        iconColor = const Color(0xFF303030); // رنگ مشکی متمایل به خاکستری تیره
        break;
      default:
        iconColor = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Icon(iconData, color: iconColor, size: 16),
    );
  }

// نمایش اطلاعات نشان وقتی کاربر روی آیکون نشان کلیک می‌کند
  void _showVerificationBadgeInfo(
      BuildContext context, Map<String, dynamic>? profile) {
    final bool isVerified = profile?['is_verified'] ?? false;
    final String verificationType = profile?['verification_type'] ?? 'none';

    if (!isVerified) return;

    String title = 'نشان تأیید';
    String description = 'حساب کاربری شما تأیید شده است.';
    Color badgeColor = Colors.blue;

    // تنظیم عنوان، توضیحات و رنگ براساس نوع نشان
    switch (verificationType) {
      case 'blueTick':
        title = 'نشان تأیید آبی';
        description =
            'این نشان مخصوص کاربران ویژه و تأیید شده است که هویت آن‌ها توسط تیم ویستا تأیید شده است.';
        badgeColor = Colors.blue;
        break;
      case 'goldTick':
        title = 'نشان طلایی';
        description =
            'این نشان مخصوص حساب‌های تجاری، سلبریتی‌ها و برندهای معتبر است که به صورت رسمی تأیید شده‌اند.';
        badgeColor = Colors.amber;
        break;
      case 'blackTick':
        title = 'نشان مشکی';
        description =
            'این نشان مخصوص تولیدکنندگان محتوا و افراد تأثیرگذار است که توسط تیم ویستا تأیید شده‌اند.';
        badgeColor = const Color(0xFF303030);
        break;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.verified, color: badgeColor),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 16),
              const Text(
                'این نشان به صورت رسمی به شما اعطا شده و در پروفایل شما قابل مشاهده است.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('متوجه شدم'),
            ),
          ],
        );
      },
    );
  }
}

// ... existing code ...

class ThemeItems extends ConsumerWidget {
  const ThemeItems({super.key});

  // ذخیره تم انتخاب‌شده در Hive
  void _saveThemeToHive(String theme) async {
    var box = Hive.box('settings');
    await box.put('selectedTheme', theme);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.watch(themeProvider.notifier);
    final currentTheme = ref.watch(themeProvider);

    // تعیین تم فعلی
    String currentThemeName = 'light';
    if (currentTheme == darkTheme) {
      currentThemeName = 'dark';
    } else if (currentTheme == redWhiteTheme)
      currentThemeName = 'red';
    else if (currentTheme == yellowBlackTheme)
      currentThemeName = 'yellow';
    else if (currentTheme == tealWhiteTheme) currentThemeName = 'teal';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تغییر تم'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    "انتخاب تم:",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                const Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    "تم مورد نظر خود را انتخاب کنید:",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildThemeOption(
                      context,
                      color: Colors.blue,
                      icon: Icons.wb_sunny,
                      themeName: 'light',
                      label: 'روشن',
                      isSelected: currentThemeName == 'light',
                      onTap: () {
                        themeNotifier.state = lightTheme;
                        _saveThemeToHive('light');
                      },
                    ),
                    _buildThemeOption(
                      context,
                      color: Colors.blueGrey.shade800,
                      icon: Icons.nightlight_round,
                      themeName: 'dark',
                      label: 'تیره',
                      isSelected: currentThemeName == 'dark',
                      onTap: () {
                        themeNotifier.state = darkTheme;
                        _saveThemeToHive('dark');
                      },
                    ),
                    _buildThemeOption(
                      context,
                      color: Colors.red,
                      icon: Icons.color_lens,
                      themeName: 'red',
                      label: 'قرمز',
                      isSelected: currentThemeName == 'red',
                      onTap: () {
                        themeNotifier.state = redWhiteTheme;
                        _saveThemeToHive('red');
                      },
                    ),
                    _buildThemeOption(
                      context,
                      color: Colors.amber,
                      icon: Icons.color_lens,
                      themeName: 'yellow',
                      label: 'زرد',
                      isSelected: currentThemeName == 'yellow',
                      onTap: () {
                        themeNotifier.state = yellowBlackTheme;
                        _saveThemeToHive('yellow');
                      },
                    ),
                    _buildThemeOption(
                      context,
                      color: Colors.teal,
                      icon: Icons.color_lens,
                      themeName: 'teal',
                      label: 'سبزآبی',
                      isSelected: currentThemeName == 'teal',
                      onTap: () {
                        themeNotifier.state = tealWhiteTheme;
                        _saveThemeToHive('teal');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "راهنمای تم‌ها:",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "تم انتخاب شده در تمام بخش‌های برنامه اعمال می‌شود و در دفعات بعدی ورود به برنامه نیز حفظ خواهد شد.",
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // متد کمکی برای ساخت آپشن‌های تم با طراحی جدید
  Widget _buildThemeOption(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String themeName,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: color,
              radius: 35,
              child: Icon(
                icon,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ویجت قابل استفاده مجدد برای نمایش گزینه‌های تنظیمات کاربری
class ProfileFields extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const ProfileFields(this.title, this.icon, this.onTap, this.iconColor,
      {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

// ویجت نمایش نسخه برنامه
class VersionNumber extends StatelessWidget {
  const VersionNumber({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      '1.2.2+20 :نسخه', // به‌روز‌رسانی این خط با شماره نسخه فعلی برنامه
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    );
  }
}
