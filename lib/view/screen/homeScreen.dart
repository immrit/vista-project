import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/main.dart';
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

  // لیست صفحات
  final List<Widget> _tabs = [
    const PublicPostsScreen(), // صفحه پست‌های عمومی
    Searchpage(), // صفحه جستجو
    // AddPublicPostScreen(), // صفحه افزودن پست
    const NotificationsPage(), // صفحه اعلان‌ها
    ProfileScreen(
      userId: supabase.auth.currentUser!.id,
      username: supabase.auth.currentUser!.email!,
    ), // صفحه پروفایل
  ];

  // هندل کردن تغییر تب
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home),
            // selectedIcon: Icon(Icons.home),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search_outlined),
            label: '',
          ),
          // NavigationDestination(
          //   icon: Icon(Icons.add),
          //   selectedIcon: Icon(Icons.add),
          //   label: '',
          // ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_2_outlined),
            selectedIcon: Icon(Icons.person_2),
            label: '',
          ),
        ],
        elevation: 3,
        animationDuration: const Duration(milliseconds: 500),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
