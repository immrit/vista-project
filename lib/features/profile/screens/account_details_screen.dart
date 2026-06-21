import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../model/ProfileModel.dart';
import '../../../utils/birth_date_picker.dart';
import '../../../utils/time_utils.dart';
import '../../../utils/verification_badge_utils.dart';
import '../../../widgets/profile_avatar_widget.dart';
import '../../../widgets/verification_badge_icon.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:url_launcher/url_launcher.dart';

class AccountDetailsScreen extends StatefulWidget {
  final ProfileModel profile;

  const AccountDetailsScreen({super.key, required this.profile});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  late ProfileModel _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'جزییات اکانت',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          _ProfileHeaderCard(profile: _profile, isDark: isDark),
          const SizedBox(height: 12),
          _AccountTypeCard(profile: _profile, isDark: isDark),
          const SizedBox(height: 12),
          _MembershipCard(profile: _profile, isDark: isDark),
          const SizedBox(height: 12),
          _AdditionalAccountDetailsCard(profile: _profile, isDark: isDark),
          const SizedBox(height: 12),
          _StatsCard(profile: _profile, isDark: isDark),
          if (_profile.bio != null && _profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BioCard(profile: _profile, isDark: isDark),
          ],
          const SizedBox(height: 20),
          _AccountIdFooter(profile: _profile, isDark: isDark),
        ],
      ),
    );
  }
}

// ─── Profile Header ──────────────────────────────────────────────────────────

class _ProfileHeaderCard extends StatelessWidget {
  final ProfileModel profile;
  final bool isDark;

  const _ProfileHeaderCard({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            userId: profile.id,
            size: 72,
            imageUrl: profile.avatarUrl,
            showOnlineStatus: false,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@${profile.username}',
                        style: TextStyle(fontSize: 14, color: subColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile.hasAnyBadge) ...[
                      const SizedBox(width: 4),
                      VerificationBadgeIcon(
                        isVerified: profile.isVerified,
                        verificationType: profile.verificationType,
                        role: profile.role,
                        size: 16,
                      ),
                    ],
                    if (profile.isPrivate) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_outline, size: 14, color: subColor),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Account Type Card ───────────────────────────────────────────────────────

class _AccountTypeCard extends StatelessWidget {
  final ProfileModel profile;
  final bool isDark;

  const _AccountTypeCard({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final resolvedType = resolveVerificationBadgeType(
      isVerified: profile.isVerified,
      verificationType: profile.verificationType,
      role: profile.role,
    );
    final info = _AccountTypeInfo.from(resolvedType, profile, isDark);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'نوع اکانت', isDark: isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // آیکون تیپ اکانت
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: info.accentColor.withValues(
                      alpha: isDark ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(info.icon, color: info.accentColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        info.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // برای اکانت‌های تأیید‌شده: نوار رنگی کمرنگ پایین کارت
          if (resolvedType != ResolvedVerificationBadgeType.none)
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    info.accentColor.withValues(alpha: 0.0),
                    info.accentColor.withValues(alpha: isDark ? 0.5 : 0.3),
                    info.accentColor.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Membership Card ─────────────────────────────────────────────────────────

class _MembershipCard extends StatelessWidget {
  final ProfileModel profile;
  final bool isDark;

  const _MembershipCard({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final items = <_InfoRowData>[];

    if (profile.joinOrder != null && profile.joinOrder! > 0) {
      final order = profile.joinOrder!;
      items.add(_InfoRowData(
        icon: _tierIcon(order),
        label: 'ترتیب عضویت',
        value: _tierLabel(order),
        valueColor: _tierColor(order, isDark),
        iconBgColor: _tierIconBg(order, isDark),
        iconColor: _tierColor(order, isDark),
      ));
    }

    if (profile.createdAt != null) {
      final cardBg = isDark ? Colors.grey[800]! : Colors.grey[100]!;
      final iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
      items.add(_InfoRowData(
        icon: Icons.calendar_today_outlined,
        label: 'تاریخ عضویت',
        value: _formatDate(profile.createdAt!, context),
        iconBgColor: cardBg,
        iconColor: iconColor,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _SectionLabel(label: 'جزییات عضویت', isDark: isDark),
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return _InfoRow(
              data: entry.value,
              isDark: isDark,
              showDivider: !isLast,
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  IconData _tierIcon(int order) {
    if (order <= 100) return Icons.workspace_premium_outlined;
    if (order <= 1000) return Icons.rocket_launch_outlined;
    if (order <= 10000) return Icons.electric_bolt_outlined;
    return Icons.person_outline;
  }

  String _tierLabel(int order) {
    final n = order >= 1000
        ? '#${(order / 1000).toStringAsFixed(order % 1000 == 0 ? 0 : 1)}K'
        : '#$order';
    if (order <= 100) return 'عضو بنیان‌گذار  $n';
    if (order <= 1000) return 'از اولین هزار نفر  $n';
    if (order <= 10000) return 'عضو پیشگام  $n';
    return 'عضو شماره  $n';
  }

  Color _tierColor(int order, bool isDark) {
    if (order <= 100) {
      return isDark ? const Color(0xFFFFD700) : const Color(0xFF8B6914);
    }
    if (order <= 1000) {
      return isDark ? const Color(0xFF82BBFF) : const Color(0xFF1A5FBB);
    }
    if (order <= 10000) {
      return isDark ? const Color(0xFFD08BFF) : const Color(0xFF6B21A8);
    }
    return isDark ? Colors.grey[400]! : Colors.grey[600]!;
  }

  Color _tierIconBg(int order, bool isDark) {
    if (order <= 100) {
      return isDark ? const Color(0xFF3D2800) : const Color(0xFFFFF3CD);
    }
    if (order <= 1000) {
      return isDark ? const Color(0xFF001A3D) : const Color(0xFFE3EEFF);
    }
    if (order <= 10000) {
      return isDark ? const Color(0xFF1A0030) : const Color(0xFFF3E8FF);
    }
    return isDark ? Colors.grey[800]! : Colors.grey[100]!;
  }

  String _formatDate(DateTime date, BuildContext context) {
    final isPersian = Localizations.localeOf(context).languageCode == 'fa';
    if (isPersian) {
      final jDate = Jalali.fromDateTime(date);
      const persianMonths = [
        'فروردین',
        'اردیبهشت',
        'خرداد',
        'تیر',
        'مرداد',
        'شهریور',
        'مهر',
        'آبان',
        'آذر',
        'دی',
        'بهمن',
        'اسفند'
      ];
      final pYear = TimeUtils.replaceEnglishdigits(jDate.year.toString());
      return '${persianMonths[jDate.month - 1]} $pYear';
    } else {
      const gregorianMonths = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${gregorianMonths[date.month - 1]} ${date.year}';
    }
  }
}

class _AdditionalAccountDetailsCard extends StatelessWidget {
  final ProfileModel profile;
  final bool isDark;

  const _AdditionalAccountDetailsCard({
    required this.profile,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final iconBgColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;
    final iconColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    final items = <_InfoRowData>[
      _InfoRowData(
        icon: Icons.verified_user_outlined,
        label: 'وضعیت تایید حساب',
        value: _verificationStatusText(profile),
        valueColor: _verificationStatusColor(isDark),
        iconBgColor: iconBgColor,
        iconColor: _verificationStatusColor(isDark),
      ),
      _InfoRowData(
        icon: Icons.edit_note_outlined,
        label: 'تعداد تغییر نام کاربری',
        value: profile.usernameChangesCount.toString(),
        iconBgColor: iconBgColor,
        iconColor: iconColor,
      ),
    ];

    final email = profile.email?.trim() ?? '';
    if (profile.showEmail && email.isNotEmpty) {
      items.add(_InfoRowData(
        icon: Icons.email_outlined,
        label: 'ایمیل',
        value: email,
        iconBgColor: iconBgColor,
        iconColor: iconColor,
      ));
    }

    final birthDate = profile.birthDate?.trim() ?? '';
    if (profile.showBirthDate && birthDate.isNotEmpty) {
      items.add(_InfoRowData(
        icon: Icons.cake_outlined,
        label: 'تاریخ تولد',
        value: _formatBirthDate(birthDate, context),
        iconBgColor: iconBgColor,
        iconColor: iconColor,
      ));
    }

    final gender = profile.gender?.trim() ?? '';
    if (profile.showGender && gender.isNotEmpty) {
      items.add(_InfoRowData(
        icon: Icons.person_outline,
        label: 'جنسیت',
        value: _genderLabel(gender),
        iconBgColor: iconBgColor,
        iconColor: iconColor,
      ));
    }

    final maritalStatus = profile.maritalStatus?.trim() ?? '';
    if (profile.showMaritalStatus && maritalStatus.isNotEmpty) {
      items.add(_InfoRowData(
        icon: Icons.favorite_outline,
        label: 'وضعیت تاهل',
        value: _maritalStatusLabel(maritalStatus),
        iconBgColor: iconBgColor,
        iconColor: iconColor,
      ));
    }

    items.addAll([
      _InfoRowData(
        icon: Icons.public_outlined,
        label: 'کشور محل ثبت‌نام',
        value: _orUnknown(profile.registrationCountry),
        iconBgColor: iconBgColor,
        iconColor: iconColor,
      ),
      _InfoRowData(
        icon: Icons.location_on_outlined,
        label: 'مکان / شهر',
        value: _orUnknown(profile.location),
        iconBgColor: iconBgColor,
        iconColor: iconColor,
      ),
      _InfoRowData(
        icon: Icons.link_rounded,
        label: 'لینک وب‌سایت',
        value: _websiteDisplay(profile.websiteUrl),
        iconBgColor: iconBgColor,
        iconColor: iconColor,
        valueColor:
            profile.websiteUrl?.trim().isNotEmpty == true ? Colors.blue : null,
        onTap: profile.websiteUrl?.trim().isNotEmpty == true
            ? () async {
                final urlString = profile.websiteUrl!.trim();
                final uri = Uri.tryParse(urlString.startsWith('http')
                    ? urlString
                    : 'https://$urlString');
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            : null,
      ),
    ]);

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _SectionLabel(label: 'اطلاعات بیشتر اکانت', isDark: isDark),
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return _InfoRow(
              data: entry.value,
              isDark: isDark,
              showDivider: !isLast,
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _orUnknown(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? 'ثبت نشده' : v;
  }

  String _websiteDisplay(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'ثبت نشده';
    return v;
  }

  String _formatBirthDate(String value, BuildContext context) {
    final parsed = parseBirthDate(value);
    if (parsed == null) return value;
    return formatBirthDateForDisplay(parsed, Localizations.localeOf(context));
  }

  String _genderLabel(String value) {
    switch (value) {
      case 'male':
        return 'مرد';
      case 'female':
        return 'زن';
      case 'prefer_not_to_say':
        return 'ترجیح می‌دهم نگویم';
      default:
        return value;
    }
  }

  String _maritalStatusLabel(String value) {
    switch (value) {
      case 'single':
        return 'مجرد';
      case 'married':
        return 'متاهل';
      case 'prefer_not_to_say':
        return 'ترجیح می‌دهم نگویم';
      default:
        return value;
    }
  }

  String _verificationStatusText(ProfileModel p) {
    if (p.isVerified) {
      return 'تایید شده';
    }
    if (p.emailVerifiedAt != null) {
      return 'ایمیل تایید شده';
    }
    return 'تایید نشده';
  }

  Color _verificationStatusColor(bool isDark) {
    if (profile.isVerified || profile.emailVerifiedAt != null) {
      return isDark ? Colors.greenAccent[400]! : Colors.green[700]!;
    }
    return isDark ? Colors.orangeAccent[100]! : Colors.orange[700]!;
  }
}

// ─── Stats Card ──────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final ProfileModel profile;
  final bool isDark;

  const _StatsCard({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final dividerColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _SectionLabel(label: 'آمار', isDark: isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCol(
                  value: _fmt(profile.postsCount),
                  label: 'پست',
                  textColor: textColor,
                  subColor: subColor,
                ),
                Container(width: 1, height: 36, color: dividerColor),
                _StatCol(
                  value: _fmt(profile.followersCount),
                  label: 'دنبال‌کننده',
                  textColor: textColor,
                  subColor: subColor,
                ),
                Container(width: 1, height: 36, color: dividerColor),
                _StatCol(
                  value: _fmt(profile.followingCount),
                  label: 'دنبال‌شونده',
                  textColor: textColor,
                  subColor: subColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _StatCol extends StatelessWidget {
  final String value;
  final String label;
  final Color textColor;
  final Color subColor;

  const _StatCol({
    required this.value,
    required this.label,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: subColor),
        ),
      ],
    );
  }
}

// ─── Bio Card ────────────────────────────────────────────────────────────────

class _BioCard extends StatelessWidget {
  final ProfileModel profile;
  final bool isDark;

  const _BioCard({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final firstChar =
        profile.bio!.trim().isNotEmpty ? profile.bio!.trim()[0] : '';
    final isPersian = RegExp(r'[\u0600-\u06FF]').hasMatch(firstChar);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'بیوگرافی', isDark: isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Directionality(
              textDirection: isPersian ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                profile.bio!,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Account ID Footer ───────────────────────────────────────────────────────

class _AccountIdFooter extends StatelessWidget {
  final ProfileModel profile;
  final bool isDark;

  const _AccountIdFooter({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final subColor = isDark ? Colors.grey[700]! : Colors.grey[400]!;
    final shortId =
        profile.id.length > 8 ? profile.id.substring(0, 8) : profile.id;

    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: profile.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شناسه اکانت کپی شد'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Text(
        'شناسه: $shortId…',
        style: TextStyle(fontSize: 11, color: subColor),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[500] : Colors.grey[500],
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InfoRowData {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconBgColor,
    required this.iconColor,
    this.valueColor,
    this.onTap,
  });
}

class _InfoRow extends StatelessWidget {
  final _InfoRowData data;
  final bool isDark;
  final bool showDivider;

  const _InfoRow({
    required this.data,
    required this.isDark,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[500]! : Colors.grey[500]!;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: data.iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, size: 18, color: data.iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: TextStyle(fontSize: 11.5, color: subColor),
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: data.valueColor ?? textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (data.onTap != null) {
      content = InkWell(
        onTap: data.onTap,
        child: content,
      );
    }

    return Column(
      children: [
        content,
        if (showDivider)
          Divider(
            height: 1,
            indent: 68,
            endIndent: 16,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
      ],
    );
  }
}

// ─── Account Type Info ───────────────────────────────────────────────────────

class _AccountTypeInfo {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const _AccountTypeInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });

  factory _AccountTypeInfo.from(
    ResolvedVerificationBadgeType type,
    ProfileModel profile,
    bool isDark,
  ) {
    switch (type) {
      case ResolvedVerificationBadgeType.blueTick:
        final isAdmin = profile.role == 'admin';
        return _AccountTypeInfo(
          title: isAdmin ? 'مدیر ویستا' : 'ناظر ویستا',
          description: isAdmin
              ? 'این حساب متعلق به یکی از اعضای تیم مدیریت ویستا است. مدیران مسئول نظارت کلی بر پلتفرم و تصمیم‌گیری‌های اجرایی هستند.'
              : 'این حساب متعلق به یکی از ناظران ویستا است. ناظران مسئول حفظ کیفیت محتوا، بررسی گزارش‌ها و اجرای قوانین پلتفرم هستند.',
          icon: Icons.verified,
          accentColor: Colors.blue,
        );

      case ResolvedVerificationBadgeType.goldTick:
        return const _AccountTypeInfo(
          title: 'عضو پریمیوم',
          description:
              'این کاربر اشتراک پریمیوم ویستا را دارد و از امکانات ویژه‌ای نظیر آمار پیشرفته، محتوای انحصاری و دسترسی اولیه به ویژگی‌های جدید بهره‌مند می‌شود.',
          icon: Icons.star_rounded,
          accentColor: Color(0xFFFFD700),
        );

      case ResolvedVerificationBadgeType.blackTick:
        return _AccountTypeInfo(
          title: 'تولیدکننده محتوا',
          description:
              'این کاربر به عنوان یک تولیدکننده محتوای معتبر در ویستا تأیید شده است. محتوای این حساب اصیل و با کیفیت بالاست.',
          icon: Icons.verified,
          accentColor: isDark ? Colors.white : Colors.black87,
        );

      case ResolvedVerificationBadgeType.none:
        return _AccountTypeInfo(
          title: 'کاربر عادی',
          description: 'این یک حساب کاربری معمولی ویستا است.',
          icon: Icons.person_outline_rounded,
          accentColor: isDark ? Colors.grey[500]! : Colors.grey[500]!,
        );
    }
  }
}
