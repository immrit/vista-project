// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:Vista/core/theme/app_theme.dart';
import '../models/services_hub_model.dart';
import '../providers/services_hub_provider.dart';
import 'in_app_web_screen.dart';

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
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback Function(BuildContext) onTap;

  const _QuickBtn({
    required this.label,
    required this.icon,
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
  bool _contactsLoaded = false;
  bool _contactsLoading = false;

  // Lazily build buttons so we have BuildContext for navigation
  List<_QuickBtn> _buttons(BuildContext ctx) => [
        _QuickBtn(
          label: 'اطراف من',
          icon: Icons.radar_rounded,
          gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          onTap: (_) => () => ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('بزودی...')),
              ),
        ),
        _QuickBtn(
          label: 'بازی',
          icon: Icons.sports_esports_rounded,
          gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
          onTap: (_) => () => ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('بزودی...')),
              ),
        ),
        _QuickBtn(
          label: 'گروه‌ها',
          icon: Icons.groups_rounded,
          gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
          onTap: (_) => () => ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('بزودی...')),
              ),
        ),
        _QuickBtn(
          label: 'مخاطبین',
          icon: Icons.contacts_rounded,
          gradient: const [Color(0xFF2196F3), Color(0xFF21CBF3)],
          onTap: (_) => _loadContacts,
        ),
      ];

  void _openBanner(ServiceBanner banner) {
    if (banner.link.isEmpty || banner.linkType == 'none') return;
    if (banner.linkType == 'route') {
      Navigator.pushNamed(context, banner.link);
    } else {
      // 'web' — open in-app WebView (URL never shown to user)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              InAppWebScreen(url: banner.link, title: banner.title),
        ),
      );
    }
  }

  Future<void> _loadContacts() async {
    if (_contactsLoading || _contactsLoaded) return;
    setState(() => _contactsLoading = true);

    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('برای نمایش مخاطبین، دسترسی به مخاطبین لازم است')),
        );
      }
      setState(() => _contactsLoading = false);
      return;
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final phones = <String>{};
    for (final c in contacts) {
      for (final p in c.phones) phones.add(p.number);
    }

    await ref.read(contactsProvider.notifier).load(phones.toList());
    if (mounted) setState(() {
      _contactsLoading = false;
      _contactsLoaded = true;
    });
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
          child: hub.when(
            loading: () => _skeleton(isDark),
            error: (_, __) => _error(isDark),
            data: (data) => _body(data, isDark),
          ),
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _body(ServicesHubData data, bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── AppBar
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: ShaderMask(
            shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
            child: const Text(
              'سرویس‌ها',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
            ),
          ),
        ),

        // ── 2×2 quick-access grid (hardcoded)
        SliverToBoxAdapter(child: _quickGrid(isDark)),

        // ── Dynamic banners from backend
        if (data.banners.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _bannerCard(data.banners[i], isDark),
                ),
                childCount: data.banners.length,
              ),
            ),
          ),

        // ── Contacts section (shown after user triggers load from Contacts button)
        if (_contactsLoaded || _contactsLoading)
          SliverToBoxAdapter(
              child: _contactsSection(ref.watch(contactsProvider), isDark)),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // ── 2×2 Grid ─────────────────────────────────────────────────────────────
  Widget _quickGrid(bool isDark) {
    final btns = _buttons(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _quickCard(btns[0], isDark)),
            const SizedBox(width: 14),
            Expanded(child: _quickCard(btns[1], isDark)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _quickCard(btns[2], isDark)),
            const SizedBox(width: 14),
            Expanded(child: _quickCard(btns[3], isDark)),
          ]),
        ],
      ),
    );
  }

  Widget _quickCard(_QuickBtn btn, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        btn.onTap(context)();
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    btn.gradient[0].withValues(alpha: 0.38),
                    btn.gradient[1].withValues(alpha: 0.18),
                  ]
                : [
                    btn.gradient[0].withValues(alpha: 0.10),
                    btn.gradient[1].withValues(alpha: 0.04),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark
                ? btn.gradient[0].withValues(alpha: 0.45)
                : btn.gradient[0].withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: btn.gradient[0].withValues(alpha: isDark ? 0.28 : 0.22),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          children: [
            // background glow circle
            Positioned(
              right: -18,
              bottom: -18,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      btn.gradient[0].withValues(alpha: isDark ? 0.45 : 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: btn.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: btn.gradient[0].withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(btn.icon, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    btn.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Banner card ───────────────────────────────────────────────────────────
  Widget _bannerCard(ServiceBanner banner, bool isDark) {
    final bg = _hex(banner.bgColor);
    final fg = _hex(banner.textColor);
    final height = banner.heightDp;
    final clickable = banner.link.isNotEmpty && banner.linkType != 'none';

    return GestureDetector(
      onTap: clickable ? () => _openBanner(banner) : null,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: bg,
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (banner.imageUrl.isNotEmpty)
              Image.network(
                banner.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            // gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            // Text + arrow
            Positioned(
              bottom: 16,
              right: 18,
              left: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (banner.title.isNotEmpty)
                          Text(
                            banner.title,
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w800,
                              fontSize: height > 160 ? 18 : 15,
                              shadows: const [
                                Shadow(color: Colors.black54, blurRadius: 8)
                              ],
                            ),
                          ),
                        if (banner.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            banner.subtitle,
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.85),
                              fontSize: 12,
                              shadows: const [
                                Shadow(color: Colors.black45, blurRadius: 6)
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (clickable)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: fg),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contacts section ──────────────────────────────────────────────────────
  Widget _contactsSection(
      AsyncValue<List<ContactVistaUser>> state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.contacts_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'مخاطبین در ویستا',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_contactsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary),
              ),
            )
          else
            state.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary),
                ),
              ),
              error: (_, __) => _contactsError(isDark),
              data: (users) => users.isEmpty
                  ? _noContacts(isDark)
                  : _contactsGrid(users, isDark),
            ),
        ],
      ),
    );
  }

  Widget _contactsGrid(List<ContactVistaUser> users, bool isDark) {
    final count = users.length > 20 ? 20 : users.length;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${users.length} نفر از مخاطبینت ویستا دارن',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: count,
            itemBuilder: (_, i) => _contactItem(users[i], isDark),
          ),
        ],
      ),
    );
  }

  Widget _contactItem(ContactVistaUser u, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/profile/${u.id}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: u.avatarUrl.isNotEmpty
                ? NetworkImage(u.avatarUrl)
                : null,
            child: u.avatarUrl.isEmpty
                ? Text(
                    u.fullName.isNotEmpty ? u.fullName[0] : '?',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            u.username.isNotEmpty ? '@${u.username}' : u.fullName,
            style: TextStyle(
              fontSize: 11,
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
    );
  }

  Widget _noContacts(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.group_off_rounded,
              size: 40,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextSecondary),
          const SizedBox(height: 10),
          Text(
            'هنوز کسی از مخاطبینت ویستا نصب نکرده',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _contactsError(bool isDark) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.error),
        const SizedBox(width: 8),
        Text('خطا در بارگذاری مخاطبین',
            style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary)),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() {
            _contactsLoaded = false;
            _contactsLoading = false;
          }),
          child: const Text('تلاش مجدد',
              style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }

  // ── Skeleton / Error ──────────────────────────────────────────────────────
  Widget _skeleton(bool isDark) {
    final c =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 72),
          Row(children: [
            Expanded(
                child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                        color: c, borderRadius: BorderRadius.circular(24)))),
            const SizedBox(width: 14),
            Expanded(
                child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                        color: c, borderRadius: BorderRadius.circular(24)))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                        color: c, borderRadius: BorderRadius.circular(24)))),
            const SizedBox(width: 14),
            Expanded(
                child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                        color: c, borderRadius: BorderRadius.circular(24)))),
          ]),
          const SizedBox(height: 24),
          Container(
              height: 160,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(22))),
          const SizedBox(height: 14),
          Container(
              height: 100,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(22))),
        ],
      ),
    );
  }

  Widget _error(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 52,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextSecondary),
          const SizedBox(height: 14),
          Text('خطا در بارگذاری سرویس‌ها',
              style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary)),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => ref.refresh(servicesHubProvider),
            child: const Text('تلاش مجدد',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
