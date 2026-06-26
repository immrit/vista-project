import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/core/theme/app_theme.dart';
import '../providers/top_groups_provider.dart';
import '../models/top_group_model.dart';

class TopGroupsScreen extends ConsumerWidget {
  const TopGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(topGroupsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'برترین گروه‌ها',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.primary),
          ),
          error: (err, stack) => _buildError(isDark, ref),
          data: (groups) {
            if (groups.isEmpty) {
              return _buildEmpty(isDark);
            }
            return _buildContent(context, groups, isDark);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, List<TopGroup> groups, bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Column(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: Colors.amberAccent, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'رقابت محبوب‌ترین‌ها',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'گروه خود را بسازید و با جذب کاربران فعال و ویژه، به صدر جدول برسید!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final group = groups[index];
              return _buildGroupItem(context, group, index, isDark);
            },
            childCount: groups.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildGroupItem(
      BuildContext context, TopGroup group, int index, bool isDark) {
    final bool isTop3 = index < 3;
    final Color rankColor;
    if (index == 0) {
      rankColor = AppColors.warning; // Gold
    } else if (index == 1) {
      rankColor = const Color(0xFFC0C0C0); // Silver
    } else if (index == 2) {
      rankColor = const Color(0xFFCD7F32); // Bronze
    } else {
      rankColor =
          isDark ? AppColors.darkTextTertiary : AppColors.lightTextSecondary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop3
              ? rankColor.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isTop3 ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // TODO: Navigate to group profile/join
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 32,
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      color: rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: isTop3 ? 18 : 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      (group.image != null && group.image!.isNotEmpty)
                          ? NetworkImage(group.image!)
                          : null,
                  child: (group.image == null || group.image!.isEmpty)
                      ? const Icon(Icons.group_rounded,
                          color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.people_alt_rounded,
                              size: 14,
                              color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            '${group.memberCount} عضو',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark ? Colors.white70 : Colors.black54),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.star_rounded,
                              size: 14, color: Colors.orangeAccent),
                          const SizedBox(width: 4),
                          Text(
                            '${group.score}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Badges
                if (group.premiumCount > 0 || group.verifiedCount > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (group.verifiedCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  size: 12, color: Colors.blueAccent),
                              const SizedBox(width: 4),
                              Text('${group.verifiedCount}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.blueAccent)),
                            ],
                          ),
                        ),
                      if (group.premiumCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium_rounded,
                                  size: 12, color: Colors.purpleAccent),
                              const SizedBox(width: 4),
                              Text('${group.premiumCount}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.purpleAccent)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 64,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextSecondary),
          const SizedBox(height: 16),
          Text(
            'گروه عمومی‌ای یافت نشد',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'خطا در دریافت لیست گروه‌ها',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => ref.invalidate(topGroupsProvider),
            child: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }
}
