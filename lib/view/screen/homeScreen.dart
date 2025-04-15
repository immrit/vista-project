import 'package:Vista/view/screen/chat/ChatConversationsScreen.dart'
    show ChatConversationsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import '../../provider/provider.dart';
import '/main.dart';
import 'PublicPosts/AddPost.dart';
import 'PublicPosts/profileScreen.dart';
import 'PublicPosts/publicPosts.dart';
import 'searchPage.dart';

// پرووایدر برای بررسی پیام‌های جدید
final hasNewMessagesProvider = FutureProvider<bool>((ref) async {
  try {
    // دریافت پیام‌های خوانده نشده از سوپابیس
    final response = await supabase
        .from('messages')
        .select('id')
        .eq('receiver_id', supabase.auth.currentUser!.id)
        .eq('read', false)
        .limit(1);

    // اگر حداقل یک پیام خوانده نشده وجود داشت، true برمی‌گرداند
    return (response as List).isNotEmpty;
  } catch (e) {
    print('خطا در بررسی پیام‌های جدید: $e');
    return false;
  }
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
    // ساخت یکبار صفحات در initState
    _tabs = [
      const PublicPostsScreen(), // صفحه پست‌های عمومی
      const SearchPage(), // صفحه جستجو
      const AddPublicPostScreen(), // صفحه افزودن پست
      const ChatConversationsScreen(), // صفحه چت
      ProfileScreen(
        userId: supabase.auth.currentUser!.id,
        username: supabase.auth.currentUser!.email!,
      ), // صفحه پروفایل
    ];
  }

  // هندل کردن تغییر تب
  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const AddPublicPostScreen(),
        ),
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
              content: Text('برای خروج دوباره دکمه بازگشت را بزنید')),
        );
        return false;
      }
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // استفاده از watch فقط برای لاگین بررسی وضعیت اعلان‌ها
    final hasNewNotificationAsync = ref.watch(hasNewNotificationProvider);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // استفاده از IndexedStack برای حفظ وضعیت صفحات
        body: IndexedStack(
          index: _selectedIndex,
          children: _tabs,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          destinations: <NavigationDestination>[
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '',
            ),
            const NavigationDestination(
              icon: Icon(Icons.search),
              selectedIcon: Icon(Icons.search),
              label: '',
            ),
            NavigationDestination(
              icon: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.black12,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.add, size: 26),
              ),
              selectedIcon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: const Icon(Icons.add, size: 26, color: Colors.white),
              ),
              label: '',
            ),
            // تب چت با بج نمایش پیام‌های جدید
            NavigationDestination(
              icon: _buildMessageBadge(Icons.chat_bubble_outline, false),
              selectedIcon: _buildMessageBadge(Icons.chat_bubble, true),
              label: '',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_2_outlined),
              selectedIcon: Icon(Icons.person_2),
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

  // تابع برای نمایش بج اعلان
  Widget _buildNotificationBadge(IconData icon, bool isSelected) {
    return badges.Badge(
      showBadge: ref.watch(hasNewNotificationProvider).when(
            data: (hasNewNotification) => hasNewNotification,
            loading: () => false,
            error: (_, __) => false,
          ),
      badgeStyle: const badges.BadgeStyle(
        badgeColor: Colors.red,
      ),
      position: badges.BadgePosition.topEnd(top: -10, end: -10),
      child: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }

  // تابع برای نمایش بج پیام جدید
  Widget _buildMessageBadge(IconData icon, bool isSelected) {
    return badges.Badge(
      showBadge: ref.watch(hasNewMessagesProvider).when(
            data: (hasNewMessages) => hasNewMessages,
            loading: () => false,
            error: (_, __) => false,
          ),
      badgeStyle: const badges.BadgeStyle(
        badgeColor: Colors.red,
      ),
      position: badges.BadgePosition.topEnd(top: -10, end: -10),
      child: Icon(
        icon,
        // color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}
