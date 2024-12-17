import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vista/View/Screens/authentication/EditeProfile.dart';
import 'package:vista/View/Screens/publicPosts.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  // لیست صفحات
  final List<Widget> _tabs = [
    // const NotesScreen(), // صفحه یادداشت‌ها
    const PublicPostsScreen(), // صفحه پست‌های عمومی
    // const NotificationsPage(), // صفحه اعلان‌ها
    EditProfileScreen()
    // ProfileScreen(
    //   userId: supabase.auth.currentUser!.id,
    //   username: supabase.auth.currentUser!.email!,
    // )
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_filled),
            // selectedIcon: Icon(Icons.dashbohomard),
            label: 'یادداشت‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.notes_outlined),
            selectedIcon: Icon(Icons.notes),
            label: 'کافه ویستا',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'اعلان‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_2_outlined),
            selectedIcon: Icon(Icons.person_2),
            label: 'حساب کاربری',
          ),
        ],
        elevation: 3,
        animationDuration: const Duration(milliseconds: 500),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

class Classmain extends StatelessWidget {
  const Classmain({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
        child: Text("data"),
      ),
    );
  }
}
