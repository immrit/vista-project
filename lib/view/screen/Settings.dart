import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ایمپورت‌های مربوط به پروژه شما
import '../../main.dart';
import '../../provider/provider.dart';
import '../../util/themes.dart';
import 'ouathUser/updatePassword.dart';

class Settings extends ConsumerWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final getprofile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
      ),
      body: getprofile.when(
        data: (getprofile) {
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 30,
                  backgroundImage: getprofile!['avatar_url'] != null
                      ? NetworkImage(getprofile['avatar_url'].toString())
                      : const AssetImage('lib/util/images/default-avatar.jpg')
                          as ImageProvider,
                ),
                title: Row(
                  children: [
                    Text(
                      "${getprofile['username']}",
                    ),
                    if (getprofile['is_verified'])
                      const Icon(
                        Icons.check_circle,
                        color: Colors.blue,
                        size: 16.0,
                      ),
                  ],
                ),
                subtitle: Text(
                  '${supabase.auth.currentUser!.email}',
                ),
              ),
              const SizedBox(height: 20),
              const Divider(
                endIndent: 20,
                indent: 20,
              ),
              const SizedBox(height: 10),
              ProfileFields('ویرایش پروفایل', Icons.person, () {
                Navigator.pushNamed(context, '/editeProfile');
              }),
              ProfileFields('تغییر رمز عبور', Icons.lock, () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ChangePasswordWidget()));
              }),
              ProfileFields('تم و استایل', Icons.color_lens, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ThemeItems()));
              }),
            ],
          );
        },
        error: (error, stack) {
          final errorMsg = error.toString() == 'User is not logged in'
              ? 'کاربر وارد سیستم نشده است، لطفاً ورود کنید.'
              : 'خطا در دریافت اطلاعات کاربر، لطفاً دوباره تلاش کنید.';

          return Center(child: Text(errorMsg));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: const SizedBox(
        width: double.infinity,
        height: 50,
        child: Align(
          alignment: Alignment.center,
          child: VersionNumber(),
        ),
      ),
    );
  }
}

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('تغییر تم'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                "استایل‌ها:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 15, // فاصله افقی بین آیتم‌ها
              runSpacing: 15, // فاصله عمودی بین ردیف‌ها
              alignment: WrapAlignment.center,
              children: [
                _buildThemeOption(
                  context,
                  color: Colors.blue,
                  icon: Icons.wb_sunny,
                  themeName: 'light',
                  onTap: () {
                    themeNotifier.state = lightTheme;
                    _saveThemeToHive('light');
                  },
                ),
                _buildThemeOption(
                  context,
                  color: Colors.blueGrey,
                  icon: Icons.nightlight_round,
                  themeName: 'dark',
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
                  onTap: () {
                    themeNotifier.state = tealWhiteTheme;
                    _saveThemeToHive('teal');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // متد کمکی برای ساخت آپشن‌های تم
  Widget _buildThemeOption(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String themeName,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white24
                : Colors.black12,
            width: 2,
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
    );
  }
}

// ویجت قابل استفاده مجدد برای نمایش گزینه‌های تنظیمات کاربری
class ProfileFields extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const ProfileFields(this.title, this.icon, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}

// ویجت نمایش نسخه برنامه
class VersionNumber extends StatelessWidget {
  const VersionNumber({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      '2.0.11+86 :نسخه', // به‌روز‌رسانی این خط با شماره نسخه فعلی برنامه
      style: TextStyle(fontSize: 16),
    );
  }
}
