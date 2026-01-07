import 'package:Vista/features/chat/screens/ChatConversationsScreen.dart'
    show ChatConversationsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import 'package:Vista/provider/profile_completion_provider.dart';
import 'package:Vista/utils/const.dart';
import 'package:Vista/features/posts/screens/AddPost.dart';
import 'package:Vista/features/posts/screens/profileScreen.dart';
import 'package:Vista/features/posts/screens/publicPosts.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import 'package:Vista/provider/chat_provider.dart';
import 'package:Vista/provider/optimized_conversations_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/auth/widgets/otp_dialog.dart';
import '../../../provider/provider.dart';

import '../../../utils/responsive_constants.dart';
// import 'package:Vista/utils/responsive_constants.dart';

// ✅ Provider تعداد مکالمه‌های خوانده‌نشده (با استفاده از provider بهینه‌شده)
final unreadConversationsCountProvider = Provider<int>((ref) {
  // استفاده از provider بهینه‌شده
  return ref.watch(totalUnreadCountProvider);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastPressed;

  // لیست صفحات با استفاده از late برای اینیشیالایز تنها یکبار
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _checkProfileCompletion();
    _checkPhoneVerification();
    // ساخت یکبار صفحات در initState
    final currentUser = supabase.auth.currentUser;
    final userId = currentUser?.id ?? '';
    final username = currentUser?.userMetadata?['username'] ??
        currentUser?.userMetadata?['full_name'] ??
        'کاربر';

    _tabs = [
      const PublicPostsScreen(), // صفحه پست‌های عمومی
      const SearchPage(), // صفحه جستجو
      const AddPublicPostScreen(), // صفحه افزودن پست
      const ChatConversationsScreen(), // صفحه چت
      ProfileScreen(
        userId: userId,
        username: username,
      ), // صفحه پروفایل
    ];
  }

  void _checkProfileCompletion() {
    // اجرای غیرمسدودکننده در پس‌زمینه
    Future.microtask(() async {
      try {
        final isComplete = await ref
            .read(profileCompletionProvider.notifier)
            .checkProfileCompletion()
            .timeout(const Duration(seconds: 2), onTimeout: () => true);
        if (!isComplete && mounted) {
          // انتقال به صفحه ویرایش پروفایل با تأخیر کوتاه
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushNamed(context, '/editeProfile');
          }
        }
      } catch (e) {
        // خطا را نادیده می‌گیریم - کاربر نباید متوجه شود
      }
    });
  }

  void _checkPhoneVerification() async {
    // اجرای غیرمسدودکننده در پس‌زمینه
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastSkipped =
            prefs.getInt('last_phone_verification_skipped_time');

        // اگر قبلاً رد کرده و کمتر از 15 دقیقه گذشته، مزاحم نشو
        if (lastSkipped != null) {
          final lastSkippedTime =
              DateTime.fromMillisecondsSinceEpoch(lastSkipped);
          final diff = DateTime.now().difference(lastSkippedTime);
          if (diff.inMinutes < 15) {
            return;
          }
        }

        final user = supabase.auth.currentUser;
        if (user == null) return;

        // دریافت اطلاعات پروفایل
        final profile = await supabase
            .from('profiles')
            .select('phone')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          final phone = profile['phone'] as String?;
          // اگر شماره تلفن ندارد یا خالی است
          if (phone == null || phone.isEmpty) {
            if (mounted) {
              await Future.delayed(const Duration(seconds: 1)); // تاخیر کوتاه
              _showPhoneVerificationDialog();
            }
          }
        }
      } catch (e) {
        // خطا را نادیده می‌گیریم
      }
    });
  }

  void _showPhoneVerificationDialog() {
    if (!mounted) return;

    final phoneController = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'تایید شماره موبایل',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'برای ادامه فعالیت و امنیت بیشتر حساب کاربری، لطفاً شماره موبایل خود را تایید کنید.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'شماره موبایل (مثال: 0912...)',
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    // ذخیره زمان رد کردن
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('last_phone_verification_skipped_time',
                        DateTime.now().millisecondsSinceEpoch);
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('بعداً یادآوری کن'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final phone = phoneController.text.trim();
                          if (phone.isEmpty ||
                              !RegExp(r'^\+?[0-9]{10,13}$').hasMatch(phone)) {
                            setDialogState(() {
                              errorText = 'شماره موبایل نامعتبر است';
                            });
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            errorText = null;
                          });

                          try {
                            // ارسال کد
                            await ref
                                .read(authNotifierProvider.notifier)
                                .sendOtp(phone);

                            if (!mounted) return;
                            setDialogState(() {
                              isLoading = false;
                            });

                            // بستن این دیالوگ و باز کردن OTP
                            Navigator.of(dialogContext).pop();

                            // نمایش OTP Dialog
                            final verified =
                                await showOtpDialog(context, ref, phone);
                            if (verified) {
                              // آپدیت پروفایل با شماره تلفن
                              try {
                                await supabase.from('profiles').update({
                                  'phone': phone,
                                }).eq('id', supabase.auth.currentUser!.id);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'شماره موبایل با موفقیت تایید شد')),
                                );
                              } catch (e) {
                                // اگر در آپدیت خطا خورد، لااقل می‌دانیم وریفای شده ولی سیو نشده
                              }
                            } else {
                              // اگر وریفای نشد، دوباره دیالوگ اول را نشان بده (یا ولش کن تا دفعه بعد)
                              // فعلاً ولش می‌کنیم تا کاربر اذیت نشود، دفعه بعد (15 دقیقه بعد) دوباره می‌آید
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() {
                                isLoading = false;
                                errorText = 'خطا در ارسال پیامک: $e';
                              });
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ارسال کد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // هندل کردن تغییر تب
  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AddPublicPostScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return false;
    } else {
      final now = DateTime.now();
      if (_lastPressed == null ||
          now.difference(_lastPressed!) > const Duration(seconds: 2)) {
        _lastPressed = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('برای خروج دوباره دکمه بازگشت را بزنید'),
          ),
        );
        return false;
      }
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // فعال کردن Provider سراسری نوتیفیکیشن چت (در پس‌زمینه)
    ref.watch(globalChatNotificationProvider);

    // ✅ تعداد مکالمه‌های خوانده‌نشده (با provider بهینه‌شده)
    final unreadCount = ref.watch(unreadConversationsCountProvider);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // استفاده از IndexedStack برای حفظ وضعیت صفحات
        body: IndexedStack(index: _selectedIndex, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: Image.asset(
                'lib/utils/images/bottomnavigation/home-outline.png',
                width: 24,
                height: 24,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              selectedIcon: Image.asset(
                'lib/utils/images/bottomnavigation/home.png',
                width: 24,
                height: 24,
                color: Theme.of(context).primaryColor,
              ),
              label: '',
            ),
            NavigationDestination(
              icon: Image.asset(
                'lib/utils/images/bottomnavigation/magnifying-glass.png',
                width: 24,
                height: 24,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              selectedIcon: Image.asset(
                'lib/utils/images/bottomnavigation/magnifying-glass.png',
                width: 24,
                height: 24,
                color: Theme.of(context).primaryColor,
              ),
              label: '',
            ),
            NavigationDestination(
              icon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.add,
                  size: 26,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              selectedIcon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: const Icon(Icons.add, size: 26, color: Colors.white),
              ),
              label: '',
            ),
            // تب چت با بج نمایش پیام‌های جدید
            NavigationDestination(
              icon: _buildMessageBadge(
                'lib/utils/images/bottomnavigation/email-outline.png',
                false,
                unreadCount,
              ),
              selectedIcon: _buildMessageBadge(
                'lib/utils/images/bottomnavigation/email.png',
                true,
                unreadCount,
              ),
              label: '',
            ),
            NavigationDestination(
              icon: Image.asset(
                'lib/utils/images/bottomnavigation/user-outline.png',
                width: 24,
                height: 24,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              selectedIcon: Image.asset(
                'lib/utils/images/bottomnavigation/user.png',
                width: 24,
                height: 24,
                color: Theme.of(context).primaryColor,
              ),
              label: '',
            ),
          ],
          elevation: 3,
          animationDuration: const Duration(milliseconds: 500),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }

  // ✅ تابع بهینه‌شده برای نمایش بج تعداد مکالمه‌های خوانده‌نشده
  Widget _buildMessageBadge(
    String iconPath,
    bool isSelected,
    int count,
  ) {
    return badges.Badge(
      showBadge: count > 0,
      badgeContent: Text(
        count > 9 ? '۹+' : count.toString(),
        style: AppTextStyles.labelTiny.copyWith(color: Colors.white),
      ),
      badgeStyle: badges.BadgeStyle(
        badgeColor: Colors.red,
        padding: EdgeInsets.all(count > 9 ? 4 : 5),
      ),
      position: badges.BadgePosition.topEnd(top: -12, end: -12),
      child: Image.asset(
        iconPath,
        width: 24,
        height: 24,
        color: isSelected
            ? Theme.of(context).primaryColor
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }
}
