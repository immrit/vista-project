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

// استریم تعداد *مکالمه‌های* خوانده‌نشده
final unreadConversationsCountProvider = StreamProvider<int>((ref) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();

  // به استریم مکالمات گوش می‌دهیم
  // تغییر به cachedConversationsStreamProvider برای واکنش سریع‌تر به تغییرات کش
  return ref
      .watch(cachedConversationsStreamProvider)
      .when(
        data: (conversations) {
          // مکالماتی را که پیام خوانده‌نشده دارند، فیلتر و شمارش می‌کنیم
          final count = conversations.where((c) => (c.unreadCount) > 0).length;
          return Stream.value(count);
        },
        loading: () => Stream.value(0), // در حال بارگذاری، تعداد صفر است
        error: (error, stackTrace) {
          print('Error in unreadConversationsCountProvider: $error');
          return Stream.value(0); // در صورت خطا، تعداد صفر است
        },
      );
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
    final isComplete =
        await ref
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

    // استریم تعداد *مکالمه‌های* خوانده‌نشده
    final unreadConversationsCountAsync = ref.watch(
      unreadConversationsCountProvider,
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // استفاده از IndexedStack برای حفظ وضعیت صفحات
        body: IndexedStack(index: _selectedIndex, children: _tabs),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color:
                      Theme.of(context).brightness == Brightness.dark
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
                Icons.chat_bubble_outline,
                false,
                unreadConversationsCountAsync,
              ),
              selectedIcon: _buildMessageBadge(
                Icons.chat_bubble,
                true,
                unreadConversationsCountAsync,
              ),
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
      showBadge: ref
          .watch(hasNewNotificationProvider)
          .when(
            data: (hasNewNotification) => hasNewNotification,
            loading: () => false,
            error: (_, __) => false,
          ),
      badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
      position: badges.BadgePosition.topEnd(top: -10, end: -10),
      child: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }

  // تابع برای نمایش بج تعداد مکالمه‌های خوانده‌نشده
  Widget _buildMessageBadge(
    IconData iconData,
    bool isSelected,
    AsyncValue<int> unreadConversationsCountAsync,
  ) {
    return unreadConversationsCountAsync.when(
      data: (count) {
        return badges.Badge(
          showBadge: count > 0,
          badgeContent: Text(
            count > 9 ? '۹+' : count.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          badgeStyle: badges.BadgeStyle(
            badgeColor: Colors.red,
            padding: EdgeInsets.all(count > 9 ? 4 : 5), // پدینگ بج
          ),
          position: badges.BadgePosition.topEnd(top: -12, end: -12),
          child: Icon(
            iconData,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
        );
      },
      loading:
          () => Icon(
            iconData,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ), // نمایش آیکون بدون بج در حال لود
      error:
          (err, stack) => Icon(
            iconData,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ), // نمایش آیکون بدون بج در صورت خطا
    );
  }
}
