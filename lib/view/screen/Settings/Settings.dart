import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ایمپورت‌های مربوط به پروژه شما
import '../../../main.dart';
import '../../../provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'subpages/AccountSettingsPage.dart';
import 'subpages/StorageAndMemorySettingsPage.dart';
import 'subpages/ChatSettingsGroupPage.dart';
import 'subpages/AboutSettingsPage.dart';
import 'subpages/ThemeSettingsPage.dart';
import 'subpages/PrivacySettingsPage.dart';

class Settings extends ConsumerWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final getprofile = ref.watch(profileProvider);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('تنظیمات'),
          elevation: 0,
          centerTitle: true,
        ),
        body: getprofile.when(
          data: (getprofile) {
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              children: [
                // پروفایل کاربر - مثل تلگرام
                _buildUserProfileCard(context, getprofile, colorScheme),

                const SizedBox(height: 20),

                // تنظیمات اصلی
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252525) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      SettingsItem(
                        icon: Icons.person,
                        iconColor: Colors.blue,
                        title: 'حساب کاربری',
                        subtitle: 'ویرایش پروفایل، رمز عبور',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AccountSettingsPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(),
                      SettingsItem(
                        icon: Icons.chat,
                        iconColor: Colors.green,
                        title: 'چت و مکالمات',
                        subtitle: 'تنظیمات چت، پوشه‌ها، آرشیو',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ChatSettingsGroupPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(),
                      SettingsItem(
                        icon: Icons.lock,
                        iconColor: Colors.red,
                        title: 'حریم خصوصی و امنیت',
                        subtitle: 'قفل اپلیکیشن، مسدودسازی، تایید دو مرحله‌ای',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrivacySettingsPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(),
                      SettingsItem(
                        icon: Icons.storage_rounded,
                        iconColor: Colors.purple,
                        title: 'حافظه و ذخیره‌سازی',
                        subtitle: 'مدیریت حافظه، کش، تنظیمات ویدیو',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const StorageAndMemorySettingsPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(),
                      SettingsItem(
                        icon: Icons.palette,
                        iconColor: Colors.teal,
                        title: 'ظاهر و شخصی‌سازی',
                        subtitle: 'تم‌ها، رنگ‌ها، استایل‌ها',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ThemeSettingsPage(),
                            ),
                          );
                        },
                      ),
                      // آیتم تنظیمات آفلاین حذف شد
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // بخش دوم - اطلاعات و پشتیبانی
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252525) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      SettingsItem(
                        icon: Icons.store,
                        iconColor: Colors.amber,
                        title: 'ویستا وب',
                        subtitle: 'دسترسی به نسخه وب ویستا',
                        onTap: () async {
                          final session =
                              Supabase.instance.client.auth.currentSession;
                          final accessToken = session?.accessToken;
                          final refreshToken = session?.refreshToken;
                          if (accessToken != null && refreshToken != null) {
                            // به‌جای ارسال توکن در URL، از یک endpoint امن با POST در WebView یا deep link امضاشده استفاده کنید.
                            // اینجا صرفاً باز کردن صفحه عمومی بدون افشای توکن‌ها انجام می‌شود.
                            final url = Uri.parse('https://cafevista.ir');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'امکان باز کردن سایت وجود ندارد.')),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('اطلاعات ورود یافت نشد!')),
                            );
                          }
                        },
                      ),
                      _buildDivider(),
                      SettingsItem(
                        icon: Icons.bug_report,
                        iconColor: Colors.orange,
                        title: 'گزارش مشکل',
                        subtitle: 'گزارش باگ یا پیشنهاد بهبود',
                        onTap: () {
                          _showBugReportBottomSheet(context, ref);
                        },
                      ),
                      _buildDivider(),
                      // آیتم تست عملکرد آفلاین حذف شد
                      SettingsItem(
                        icon: Icons.info,
                        iconColor: Colors.grey,
                        title: 'درباره ویستا',
                        subtitle: 'شرایط و قوانین، تماس با ما',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AboutSettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // نسخه - در پایین
                const Center(
                  child: VersionNumber(),
                ),

                const SizedBox(height: 20),
              ],
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
                      final _ = ref.refresh(profileProvider);
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

  // کارت پروفایل کاربر - مثل تلگرام
  Widget _buildUserProfileCard(BuildContext context,
      Map<String, dynamic>? profile, ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: profile!['avatar_url'] != null
                    ? NetworkImage(profile['avatar_url'].toString())
                    : const AssetImage(
                            'lib/view/util/images/default-avatar.jpg')
                        as ImageProvider,
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
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // نمایش نشان در کنار نام کاربری
                    _buildInlineVerificationBadge(profile),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${supabase.auth.currentUser!.email}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'آنلاین',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/editeProfile');
            },
            icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge(
      BuildContext context, Map<String, dynamic>? profile) {
    final bool isVerified = profile?['is_verified'] ?? false;
    if (!isVerified) {
      return const SizedBox.shrink();
    }

    final String verificationType = profile?['verification_type'] ?? 'none';
    IconData iconData = Icons.verified;
    Color iconColor = Colors.blue;

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
        iconColor = const Color(0xFF303030);
        break;
      default:
        iconData = Icons.verified;
        iconColor = Colors.blue;
    }

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
          child: Icon(iconData, color: iconColor, size: 18),
        ),
      ),
    );
  }

  Widget _buildInlineVerificationBadge(Map<String, dynamic>? profile) {
    final bool isVerified = profile?['is_verified'] ?? false;
    if (!isVerified) {
      return const SizedBox.shrink();
    }

    final String verificationType = profile?['verification_type'] ?? 'none';
    IconData iconData = Icons.verified;
    Color iconColor = Colors.blue;

    switch (verificationType) {
      case 'blueTick':
        iconColor = Colors.blue;
        break;
      case 'goldTick':
        iconColor = Colors.amber;
        break;
      case 'blackTick':
        iconColor = const Color(0xFF303030);
        break;
      default:
        iconColor = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Icon(iconData, color: iconColor, size: 14),
    );
  }

  void _showVerificationBadgeInfo(
      BuildContext context, Map<String, dynamic>? profile) {
    final bool isVerified = profile?['is_verified'] ?? false;
    final String verificationType = profile?['verification_type'] ?? 'none';

    if (!isVerified) return;

    String title = 'نشان تأیید';
    String description = 'حساب کاربری شما تأیید شده است.';
    Color badgeColor = Colors.blue;

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

  // نمایش BottomSheet برای گزارش مشکل
  void _showBugReportBottomSheet(BuildContext context, WidgetRef ref) {
    final getprofile = ref.read(profileProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title with icon
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bug_report,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'گزارش مشکل',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ),
              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'لطفاً مشکل یا پیشنهاد خود را با جزئیات کامل شرح دهید تا بتوانیم بهتر به شما کمک کنیم.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              // Form
              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildBugReportForm(context, getprofile),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // فرم گزارش مشکل
  Widget _buildBugReportForm(
      BuildContext context, AsyncValue<Map<String, dynamic>?> getprofile) {
    return StatefulBuilder(
      builder: (context, setState) {
        final formKey = GlobalKey<FormState>();
        final subjectController = TextEditingController();
        final messageController = TextEditingController();
        bool isSubmitting = false;

        return Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // موضوع
              TextFormField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: 'موضوع',
                  hintText: 'مثال: مشکل در ورود به برنامه',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red[300]!),
                  ),
                  prefixIcon: Icon(
                    Icons.subject,
                    color: Theme.of(context).primaryColor,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفاً موضوع پیام را وارد کنید';
                  }
                  if (value.length < 5) {
                    return 'موضوع باید حداقل ۵ کاراکتر باشد';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // پیام
              TextFormField(
                controller: messageController,
                decoration: InputDecoration(
                  labelText: 'توضیح مشکل یا پیشنهاد',
                  hintText: 'لطفاً مشکل خود را با جزئیات کامل شرح دهید...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red[300]!),
                  ),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                maxLines: 6,
                minLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'لطفاً پیام خود را وارد کنید';
                  }
                  if (value.length < 20) {
                    return 'پیام باید حداقل ۲۰ کاراکتر باشد';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // دکمه ارسال
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: !isSubmitting
                      ? () async {
                          if (formKey.currentState!.validate()) {
                            setState(() {
                              isSubmitting = true;
                            });

                            try {
                              // دریافت اطلاعات کاربر از profile
                              final profile = getprofile.value;
                              final fullName = profile?['full_name'] ?? '';
                              final email =
                                  supabase.auth.currentUser?.email ?? '';
                              final username = profile?['username'] ?? '';

                              // ارسال به سرور - مطابق با ساختار جدول contact_requests
                              final contactData = {
                                'full_name': fullName,
                                'email': email,
                                'username': username,
                                'subject': subjectController.text,
                                'message': messageController.text,
                                'user_id': supabase.auth.currentUser?.id,
                              };

                              await supabase
                                  .from('contact_requests')
                                  .insert(contactData);

                              if (context.mounted) {
                                Navigator.pop(context);
                                // نمایش TOAST موفقیت‌آمیز
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'گزارش مشکل شما با موفقیت ارسال شد. متشکریم!',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.green[600],
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    duration: const Duration(seconds: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'خطا در ارسال گزارش. لطفاً دوباره تلاش کنید.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.red[600],
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    duration: const Duration(seconds: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              setState(() {
                                isSubmitting = false;
                              });
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor:
                        Theme.of(context).primaryColor.withOpacity(0.3),
                  ),
                  child: isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'در حال ارسال...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.send,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ارسال گزارش',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ویجت آیتم تنظیمات
class SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // آیکون مربعی رنگی - دقیقاً مثل تلگرام
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
              // متن و زیرنویس
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
              // فلش - مثل تلگرام
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(DiagnosticsProperty<Color>('iconColor', iconColor));
    properties.add(DiagnosticsProperty<String>('title', title));
    properties.add(DiagnosticsProperty<String>('subtitle', subtitle));
  }
}

class VersionNumber extends StatelessWidget {
  const VersionNumber({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        final buildNumber = snapshot.data?.buildNumber;
        final text = version != null
            ? (buildNumber != null && buildNumber.isNotEmpty
                ? 'نسخه ویستا $version+$buildNumber اندروید'
                : 'نسخه ویستا $version')
            : 'نسخه ویستا';
        return Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        );
      },
    );
  }
}
