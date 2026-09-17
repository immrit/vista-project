// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:Vista/widgets/skeleton_loading.dart';

import 'package:Vista/core/theme/app_theme.dart';
import 'package:Vista/features/nearby/screens/nearby_screen.dart';
import 'package:Vista/features/settings/screens/ContactUs.dart';
import '../models/services_hub_model.dart';
import '../providers/services_hub_provider.dart';
import 'contacts_screen.dart';
import 'game_launch_screen.dart';
import 'in_app_web_screen.dart';
import 'top_groups_screen.dart';

// ── color helper ──────────────────────────────────────────────────────────────
Color _hex(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return AppColors.primary;
  }
}

// ── 4 hardcoded main buttons ─────────────────────────────────────────────────
class _QuickBtn {
  final String label;
  final String subtitle;
  final IconData icon;
  final List<IconData> backgroundIcons;
  final List<Color> gradient;
  final VoidCallback Function(BuildContext) onTap;

  const _QuickBtn({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.backgroundIcons,
    required this.gradient,
    required this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  // Lazily build buttons so we have BuildContext for navigation
  List<_QuickBtn> _buttons(BuildContext ctx) => [
        _QuickBtn(
          label: 'اطراف من',
          subtitle: 'آدم‌های نزدیکت را پیدا کن',
          icon: Icons.radar_rounded,
          backgroundIcons: const [
            Icons.near_me_outlined,
            Icons.location_on_outlined,
            Icons.my_location_rounded,
          ],
          gradient: const [AppColors.primary, AppColors.secondary],
          onTap: (c) => () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const NearbyScreen()),
              ),
        ),
        _QuickBtn(
          label: 'بازی',
          subtitle: 'رقابت کن و امتیاز بگیر',
          icon: Icons.sports_esports_rounded,
          backgroundIcons: const [
            Icons.emoji_events_outlined,
            Icons.bolt_rounded,
            Icons.stars_rounded,
          ],
          gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
          onTap: (_) => _openGame,
        ),
        _QuickBtn(
          label: 'گروه‌ها',
          subtitle: 'جمع‌های محبوب ویستا را ببین',
          icon: Icons.groups_rounded,
          backgroundIcons: const [
            Icons.forum_outlined,
            Icons.group_add_outlined,
            Icons.diversity_3_outlined,
          ],
          gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
          onTap: (_) => () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TopGroupsScreen()),
            );
          },
        ),
        _QuickBtn(
          label: 'مخاطبین',
          subtitle: 'دوستانت را در ویستا پیدا کن',
          icon: Icons.contacts_rounded,
          backgroundIcons: const [
            Icons.person_add_alt_outlined,
            Icons.alternate_email_rounded,
            Icons.call_outlined,
          ],
          gradient: const [AppColors.info, Color(0xFF21CBF3)],
          onTap: (_) => () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            );
          },
        ),
      ];

  /// Immediately opens the animated game launch screen which silently mints
  /// an SSO ticket, bootstraps a scoped session, and transitions into the
  /// in-app webview game lobby — all without the user seeing a login form.
  void _openGame() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameLaunchScreen()),
    );
  }

  void _openBanner(ServiceBanner banner) {
    if (banner.link.isEmpty || banner.linkType == 'none') return;
    try {
      if (banner.linkType == 'route') {
        Navigator.pushNamed(context, banner.link);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                InAppWebScreen(url: banner.link, title: banner.title),
          ),
        );
      }
    } catch (_) {
      _showUnavailable();
    }
  }

  void _openSection(ServiceSection section) {
    final route = section.route.trim();
    if (route.isEmpty) {
      _showUnavailable();
      return;
    }

    HapticFeedback.selectionClick();
    try {
      final normalized = route.toLowerCase();
      if (normalized.startsWith('https://') ||
          normalized.startsWith('http://')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InAppWebScreen(url: route, title: section.title),
          ),
        );
        return;
      }

      switch (normalized) {
        case 'vista://shop':
        case 'vista://store':
          Navigator.pushNamed(context, '/verification-store');
          return;
        case 'vista://game':
        case 'vista://games':
          _openGame();
          return;
        case 'vista://nearby':
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const NearbyScreen()));
          return;
        case 'vista://group':
        case 'vista://groups':
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TopGroupsScreen()));
          return;
        case 'vista://contact':
        case 'vista://contacts':
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()));
          return;
        case 'vista://premium':
          Navigator.pushNamed(context, '/premium');
          return;
        case 'vista://support':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactUsScreen()),
          );
          return;
      }

      if (route.startsWith('/')) {
        Navigator.pushNamed(context, route);
        return;
      }
      _showUnavailable();
    } catch (_) {
      _showUnavailable();
    }
  }

  void _showUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('این سرویس فعلاً در دسترس نیست')),
      );
  }

  IconData _iconForSection(String icon) {
    switch (icon.trim().toLowerCase()) {
      case 'shopping_bag':
      case 'shop':
        return Icons.shopping_bag_rounded;
      case 'trophy':
      case 'games':
      case 'game':
        return Icons.emoji_events_rounded;
      case 'headset':
      case 'support':
        return Icons.support_agent_rounded;
      case 'star':
      case 'premium':
        return Icons.workspace_premium_rounded;
      case 'people':
      case 'groups':
        return Icons.groups_rounded;
      case 'contacts':
        return Icons.contacts_rounded;
      case 'nearby':
      case 'radar':
        return Icons.radar_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  List<ServiceSection> _uniqueSections(Iterable<ServiceSection> source) {
    final sorted = source.where((section) => section.isActive).toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.id.compareTo(b.id);
      });
    final unique = <String, ServiceSection>{};
    for (final section in sorted) {
      final route = section.route.trim().toLowerCase();
      final title = section.title.trim().toLowerCase();
      final key = route.isNotEmpty ? 'route:$route' : 'title:$title';
      unique.putIfAbsent(key, () => section);
    }
    return unique.values.toList();
  }

  List<ServiceBanner> _uniqueBanners(Iterable<ServiceBanner> source) {
    final sorted = source.where((banner) => banner.isActive).toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.id.compareTo(b.id);
      });
    final unique = <String, ServiceBanner>{};
    for (final banner in sorted) {
      final key = banner.id > 0
          ? 'id:${banner.id}'
          : '${banner.link.trim()}|${banner.imageUrl.trim()}|${banner.title.trim()}';
      unique.putIfAbsent(key, () => banner);
    }
    return unique.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hub = ref.watch(servicesHubProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(servicesHubProvider.future),
          color: AppColors.primary,
          child: _body(hub, isDark),
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _body(AsyncValue<ServicesHubData> hub, bool isDark) {
    return CustomScrollView(
      key: const PageStorageKey<String>('services-hub-scroll'),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          centerTitle: false,
          titleSpacing: 16.w,
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'سرویس‌ها',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
          ),
          actions: [
            IconButton(
              tooltip: 'به‌روزرسانی',
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.invalidate(servicesHubProvider);
              },
              icon: Icon(Icons.refresh_rounded, size: 22.sp),
            ),
            SizedBox(width: 8.w),
          ],
        ),
        ..._buildCampaignSlivers(hub, isDark),
        SliverToBoxAdapter(
          child: _sectionHeading(
            title: 'دسترسی سریع',
            subtitle: 'مسیرهای پرکاربرد',
          ),
        ),
        SliverToBoxAdapter(child: _quickGrid(isDark)),
        const SliverToBoxAdapter(child: _ContactsHorizontalList()),
        ..._buildSectionSlivers(hub, isDark),
        SliverToBoxAdapter(child: SizedBox(height: 120.h)),
      ],
    );
  }

  Widget _sectionHeading({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16.w, 24.h, 16.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10.5.sp,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCampaignSlivers(
    AsyncValue<ServicesHubData> hub,
    bool isDark,
  ) {
    return hub.maybeWhen<List<Widget>>(
      data: (data) {
        final banners = _uniqueBanners(data.banners);
        if (banners.isEmpty) return const <Widget>[];
        return [
          SliverToBoxAdapter(
            child: _sectionHeading(
              title: 'برای شما',
              subtitle: 'انتخاب‌های تازه ویستا',
            ),
          ),
          SliverPadding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w),
            sliver: SliverList.separated(
              itemCount: banners.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (_, index) => _bannerCard(banners[index], isDark),
            ),
          ),
        ];
      },
      orElse: () => const <Widget>[],
    );
  }

  // Manager-ordered, deduplicated RTL rail with resettable scroll state.
  List<Widget> _buildSectionSlivers(
    AsyncValue<ServicesHubData> hub,
    bool isDark,
  ) {
    return hub.when<List<Widget>>(
      loading: () => [SliverToBoxAdapter(child: _hubSkeleton())],
      error: (_, __) => [SliverToBoxAdapter(child: _hubError(isDark))],
      data: (data) {
        final sections = _uniqueSections(data.sections);
        if (sections.isEmpty) return const <Widget>[];
        return [
          SliverToBoxAdapter(
            child: _sectionHeading(
              title: 'سرویس‌های بیشتر',
              subtitle: 'انتخاب‌هایی که از ویستا برایت آماده شده',
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 96.h,
              child: ListView.separated(
                key: ValueKey(
                  'managed-services-${sections.map((section) => section.id).join('-')}',
                ),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w),
                itemCount: sections.length,
                separatorBuilder: (_, __) => SizedBox(width: 9.w),
                itemBuilder: (_, index) =>
                    _dynamicSectionCard(sections[index], isDark),
              ),
            ),
          ),
        ];
      },
    );
  }

  Widget _dynamicSectionCard(ServiceSection section, bool isDark) {
    final accent = _hex(section.color);
    final surface = isDark ? AppColors.darkSurfaceVariant : Colors.white;

    return SizedBox(
      width: 208.w,
      child: Semantics(
        button: true,
        label: section.subtitle.isEmpty
            ? section.title
            : '${section.title}، ${section.subtitle}',
        child: Material(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: accent.withValues(alpha: isDark ? 0.24 : 0.14),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: section.route.trim().isEmpty
                ? null
                : () => _openSection(section),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    accent.withValues(alpha: isDark ? 0.13 : 0.065),
                    surface,
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(12.w, 10.h, 12.w, 10.h),
                child: Row(
                  children: [
                    Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.20 : 0.11),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        _iconForSection(section.icon),
                        color: accent,
                        size: 21.sp,
                      ),
                    ),
                    SizedBox(width: 11.w),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (section.subtitle.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              section.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 9.5.sp),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 7.w),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Icon(
                        section.route.isEmpty
                            ? Icons.lock_clock_rounded
                            : Icons.arrow_back_ios_new_rounded,
                        color: accent.withValues(alpha: 0.82),
                        size: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hubSkeleton() {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16.w, 24.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseSkeletonWidget(width: 142.w, height: 18.h),
          SizedBox(height: 12.h),
          BaseSkeletonWidget(
            width: double.infinity,
            height: 126.h,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ],
      ),
    );
  }

  Widget _hubError(bool isDark) {
    return _inlineHubState(
      isDark: isDark,
      icon: Icons.cloud_off_rounded,
      title: 'تازه‌های ویستا بارگذاری نشد',
      subtitle: 'سرویس‌های اصلی همچنان در دسترس‌اند.',
      actionLabel: 'تلاش دوباره',
      onAction: () => ref.invalidate(servicesHubProvider),
    );
  }

  Widget _inlineHubState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final useStackedLayout = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final iconBox = Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: AppColors.primary, size: 22.sp),
    );
    final textBlock = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
          ),
          SizedBox(height: 3.h),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10.5.sp,
                ),
          ),
        ],
      ),
    );
    final infoRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconBox,
        SizedBox(width: 12.w),
        textBlock,
      ],
    );

    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(16.w, 24.h, 16.w, 0),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: useStackedLayout && onAction != null && actionLabel != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoRow,
                SizedBox(height: 8.h),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                iconBox,
                SizedBox(width: 12.w),
                textBlock,
                if (onAction != null && actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
              ],
            ),
    );
  }

  // ── Bespoke 2×2 quick actions ─────────────────────────────────────────────
  Widget _quickGrid(bool isDark) {
    final btns = _buttons(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w),
      child: GridView.builder(
        shrinkWrap: true,
        primary: false,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: btns.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 10.h,
          childAspectRatio: textScale > 1.2 ? 1.02 : 1.20,
        ),
        itemBuilder: (_, index) => _quickCard(btns[index], isDark),
      ),
    );
  }

  Widget _quickCard(_QuickBtn btn, bool isDark) {
    final accent = btn.gradient.first;
    final surface = isDark ? AppColors.darkSurfaceVariant : Colors.white;
    final startSurface = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.20 : 0.12),
      surface,
    );
    final endSurface = Color.alphaBlend(
      btn.gradient.last.withValues(alpha: isDark ? 0.14 : 0.075),
      surface,
    );
    final iconBox = Container(
      width: 50.w,
      height: 50.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: btn.gradient,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.22 : 0.24),
            blurRadius: 14.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Icon(btn.icon, color: Colors.white, size: 24.sp),
    );
    return Semantics(
      button: true,
      label: '${btn.label}، ${btn.subtitle}',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.09),
                    blurRadius: 12.r,
                    offset: Offset(0, 5.h),
                  ),
                ],
        ),
        child: Material(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              btn.onTap(context)();
            },
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [startSurface, endSurface],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: _quickCardMotifs(btn, accent, isDark),
                  ),
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(13.w, 12.h, 13.w, 12.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: iconBox,
                        ),
                        SizedBox(height: 11.h),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            btn.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        SizedBox(height: 3.h),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            btn.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 9.6.sp,
                                      height: 1.35,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickCardMotifs(_QuickBtn btn, Color accent, bool isDark) {
    final color = accent.withValues(alpha: isDark ? 0.105 : 0.075);
    return Stack(
      fit: StackFit.expand,
      children: [
        PositionedDirectional(
          start: -7.w,
          top: 13.h,
          child: Icon(btn.backgroundIcons[0], size: 34.sp, color: color),
        ),
        PositionedDirectional(
          end: -6.w,
          top: 43.h,
          child: Icon(btn.backgroundIcons[1], size: 39.sp, color: color),
        ),
        PositionedDirectional(
          start: 16.w,
          bottom: -8.h,
          child: Icon(btn.backgroundIcons[2], size: 31.sp, color: color),
        ),
      ],
    );
  }

  // ── Banner card ───────────────────────────────────────────────────────────
  Widget _bannerCard(ServiceBanner banner, bool isDark) {
    final bg = _hex(banner.bgColor);
    final fg = _hex(banner.textColor);
    final height = banner.heightDp.h;
    final clickable = banner.link.isNotEmpty && banner.linkType != 'none';
    final hasImage = banner.imageUrl.trim().isNotEmpty;

    return Semantics(
      button: clickable,
      label: banner.subtitle.isEmpty
          ? banner.title
          : '${banner.title}، ${banner.subtitle}',
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: clickable ? () => _openBanner(banner) : null,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: (MediaQuery.sizeOf(context).width *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                if (hasImage)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.03),
                          Colors.black.withValues(alpha: 0.58),
                        ],
                        stops: const [0.25, 1],
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    16.w,
                    14.h,
                    16.w,
                    14.h,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (banner.title.isNotEmpty)
                              Text(
                                banner.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: fg,
                                  fontWeight: FontWeight.w900,
                                  fontSize:
                                      banner.heightDp > 160 ? 17.sp : 14.5.sp,
                                  height: 1.35,
                                  shadows: hasImage
                                      ? const [
                                          Shadow(
                                            color: Colors.black45,
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            if (banner.subtitle.isNotEmpty) ...[
                              SizedBox(height: 3.h),
                              Text(
                                banner.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: fg.withValues(alpha: 0.86),
                                  fontSize: 10.5.sp,
                                  height: 1.45,
                                  shadows: hasImage
                                      ? const [
                                          Shadow(
                                            color: Colors.black38,
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (clickable) ...[
                        SizedBox(width: 12.w),
                        Container(
                          width: 32.w,
                          height: 32.w,
                          decoration: BoxDecoration(
                            color: fg.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 17.sp,
                              color: fg,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Horizontal Contacts List ────────────────────────────────────────────────
class _ContactsHorizontalList extends ConsumerStatefulWidget {
  const _ContactsHorizontalList();

  @override
  ConsumerState<_ContactsHorizontalList> createState() =>
      _ContactsHorizontalListState();
}

class _ContactsHorizontalListState
    extends ConsumerState<_ContactsHorizontalList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactsProvider.notifier).loadIfGranted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(contactsProvider);

    return state.when(
      loading: () => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: BaseSkeletonWidget(width: 150, height: 14),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: 5,
                itemBuilder: (_, __) => Container(
                  width: 70,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      BaseSkeletonWidget(
                          width: 52,
                          height: 52,
                          borderRadius: BorderRadius.all(Radius.circular(26))),
                      SizedBox(height: 6),
                      BaseSkeletonWidget(width: 50, height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      error: (error, __) {
        final needsPermission = error == ContactsNotifier.permissionDenied ||
            error == ContactsNotifier.permissionRequired;
        return _compactState(
          isDark: isDark,
          icon: needsPermission
              ? Icons.contact_page_outlined
              : Icons.sync_problem_rounded,
          title: needsPermission
              ? 'دوستانت را در ویستا پیدا کن'
              : 'مخاطبین بارگذاری نشد',
          subtitle: needsPermission
              ? 'برای دیدن دوستان ویستایی، دسترسی مخاطبین را فعال کن.'
              : 'می‌توانی دوباره برای همگام‌سازی تلاش کنی.',
          actionLabel: needsPermission ? 'فعال‌سازی' : 'تلاش دوباره',
          onAction: needsPermission
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactsScreen()),
                  )
              : () => ref.read(contactsProvider.notifier).load(),
        );
      },
      data: (users) {
        if (users.isEmpty) {
          return _compactState(
            isDark: isDark,
            icon: Icons.person_search_rounded,
            title: 'هنوز دوستی پیدا نشد',
            subtitle: 'هر وقت یکی از مخاطبینت به ویستا بیاید، اینجا می‌بینی.',
            actionLabel: 'مشاهده مخاطبین',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            ),
          );
        }

        return Container(
          margin: EdgeInsetsDirectional.fromSTEB(16.w, 24.h, 16.w, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
            border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            boxShadow: isDark ? null : AppElevation.e1,
          ),
          padding: EdgeInsets.symmetric(vertical: 13.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: 14.w),
                child: Row(
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(Icons.people_alt_rounded,
                          color: AppColors.success, size: 18.sp),
                    ),
                    SizedBox(width: 9.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'آشناها در ویستا',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            '${users.length} نفر از مخاطبینت اینجا هستند',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 9.8.sp),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ContactsScreen()),
                      ),
                      child: const Text('همه'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                height: 82.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsetsDirectional.symmetric(horizontal: 10.w),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final u = users[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => Navigator.pushNamed(context, '/profile',
                          arguments: u.id),
                      child: Container(
                        width: 66.w,
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 25.r,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              backgroundImage: u.avatarUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(u.avatarUrl)
                                  : null,
                              child: u.avatarUrl.isEmpty
                                  ? Text(
                                      u.fullName.isNotEmpty
                                          ? u.fullName[0]
                                          : '?',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17.sp,
                                      ),
                                    )
                                  : null,
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              u.username.isNotEmpty
                                  ? '@${u.username}'
                                  : u.fullName,
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _compactState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final useStackedLayout = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final iconBox = Container(
      width: 46.w,
      height: 46.w,
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: AppColors.info, size: 22.sp),
    );
    final textBlock = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w800,
                ),
          ),
          SizedBox(height: 3.h),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9.8.sp,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
    final infoRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconBox,
        SizedBox(width: 11.w),
        textBlock,
      ],
    );

    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(16.w, 24.h, 16.w, 0),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark ? null : AppElevation.e1,
      ),
      child: useStackedLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoRow,
                SizedBox(height: 8.h),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                iconBox,
                SizedBox(width: 11.w),
                textBlock,
                SizedBox(width: 8.w),
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ],
            ),
    );
  }
}
