import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import '../../provider/provider.dart';
import '/main.dart';
import 'PublicPosts/AddPost.dart';
import 'PublicPosts/notificationScreen.dart';
import 'PublicPosts/profileScreen.dart';
import 'PublicPosts/publicPosts.dart';
import 'searchPage.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastPressed;

  // لیست صفحات
  final List<Widget> _tabs = [
    const PublicPostsScreen(), // صفحه پست‌های عمومی
    const SearchPage(), // صفحه جستجو
    const AddPublicPostScreen(), // صفحه افزودن پست
    const NotificationsPage(), // صفحه اعلان‌ها
    ProfileScreen(
      userId: supabase.auth.currentUser!.id,
      username: supabase.auth.currentUser!.email!,
    ), // صفحه پروفایل
  ];

  // هندل کردن تغییر تب
  void _onItemTapped(int index) {
    if (index == 2) {
      // Navigate to AddPostScreen directly instead of changing index
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
    final hasNewNotificationAsync = ref.watch(hasNewNotificationProvider);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: _tabs[_selectedIndex],
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

// استفاده از تابع در NavigationDestination:
            NavigationDestination(
              icon: _buildNotificationBadge(Icons.favorite_border, false),
              selectedIcon: _buildNotificationBadge(Icons.favorite, true),
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
}
