import 'package:Vista/view/screen/chat/ChatConversationsScreen.dart'
    show ChatConversationsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import '../../provider/profile_completion_provider.dart';
import '../../provider/provider.dart';
import '/main.dart';
import 'PublicPosts/AddPost.dart';
import 'PublicPosts/profileScreen.dart';
import 'PublicPosts/publicPosts.dart';
import 'searchPage.dart';
import '../../provider/chat_provider.dart';

// استریم تعداد پیام‌های خوانده‌نشده (سریع و به‌روز)
final unreadMessagesCountProvider = StreamProvider<int>((ref) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();

  // فقط پیام‌هایی که is_read=false و فرستنده کاربر فعلی نیست (یعنی پیام دریافتی و خوانده‌نشده)
  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('is_read', false)
      .map((messages) => messages
          .where((msg) =>
              msg['sender_id'] != userId &&
              // اگر پیام حذف شده یا مخفی شده برای کاربر فعلی دارید، اینجا هم باید چک شود
              // (مثلاً msg['is_hidden'] != true)
              true)
          .length);
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

  void _checkProfileCompletion() async {
    final isComplete = await ref
        .read(profileCompletionProvider.notifier)
        .checkProfileCompletion();
    if (!isComplete && mounted) {
      // انتقال به صفحه ویرایش پروفایل
      Navigator.pushNamed(context, '/editeProfile');
    }
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
    // فعال کردن Provider سراسری نوتیفیکیشن چت (در پس‌زمینه)
    ref.watch(globalChatNotificationProvider);

    // استریم تعداد پیام‌های خوانده‌نشده
    final unreadCountAsync = ref.watch(unreadMessagesCountProvider);

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
              icon: _buildMessageBadge(
                  Icons.chat_bubble_outline, false, unreadCountAsync),
              selectedIcon:
                  _buildMessageBadge(Icons.chat_bubble, true, unreadCountAsync),
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

  // تابع برای نمایش بج پیام جدید (سریع و فقط برای پیام‌های خوانده‌نشده)
  Widget _buildMessageBadge(
      IconData icon, bool isSelected, AsyncValue<int> unreadCountAsync) {
    // فقط آیکون را نمایش بده، بج را حذف کن
    return Icon(
      icon,
      // color: isSelected ? Theme.of(context).colorScheme.primary : null,
    );
  }
}
