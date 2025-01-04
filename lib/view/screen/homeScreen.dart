import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // لیست صفحات
  final List<Widget> _tabs = [
    const PublicPostsScreen(), // صفحه پست‌های عمومی
    Searchpage(), // صفحه جستجو
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          const NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
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
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
    );
  }
}
