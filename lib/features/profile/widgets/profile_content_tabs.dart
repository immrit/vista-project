import 'package:flutter/material.dart';

/// تب‌های محتوای پروفایل - طراحی Instagram
class ProfileContentTabs extends StatelessWidget {
  final TabController tabController;

  const ProfileContentTabs({
    super.key,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.grey[600] : Colors.grey[400];
    final borderColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          top: BorderSide(color: borderColor!, width: 0.5),
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: TabBar(
        controller: tabController,
        labelColor: activeColor,
        unselectedLabelColor: inactiveColor,
        indicatorColor: activeColor,
        indicatorWeight: 1,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(icon: Icon(Icons.grid_on, size: 24)),
          Tab(icon: Icon(Icons.play_arrow_outlined, size: 26)),
          Tab(icon: Icon(Icons.person_pin_outlined, size: 24)),
        ],
      ),
    );
  }
}

/// دلگیت تب‌بار برای SliverPersistentHeader
class ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final bool isDark;

  ProfileTabBarDelegate({
    required this.tabController,
    required this.isDark,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ProfileContentTabs(tabController: tabController);
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

/// پلیسهولدر حساب خصوصی
class PrivateAccountPlaceholder extends StatelessWidget {
  final bool isDark;

  const PrivateAccountPlaceholder({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.lock_outline,
                size: 40,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'حساب کاربری خصوصی است',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'برای مشاهده پست‌ها این حساب را دنبال کنید',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// پلیسهولدر بدون پست
class EmptyPostsPlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDark;

  const EmptyPostsPlaceholder({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 40,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
