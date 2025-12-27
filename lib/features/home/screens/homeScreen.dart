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
