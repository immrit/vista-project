import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:Vista/DB/profile_cache_service.dart';
import 'package:Vista/features/profile/providers/profile_controller.dart';
import 'package:Vista/services/BazaarPaymentService.dart';
import 'package:Vista/services/current_user_service.dart';
import 'package:Vista/services/sensitive_action_guard.dart';
import 'package:Vista/services/system_ui_bar_service.dart';
import 'package:Vista/utils/premium_subscription_utils.dart';

/// صفحه خرید اشتراک ویستا پریمیوم از درگاه کافه‌بازار.
class PricingPage extends ConsumerStatefulWidget {
  const PricingPage({super.key});

  @override
  ConsumerState<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends ConsumerState<PricingPage> {
  static const Color _premiumColor = Color(0xFF8774E1);

  final BazaarPaymentService _bazaarService = BazaarPaymentService();
  bool _isBazaarConnected = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  int _selectedPlanIndex = 1;

  /// مبالغ هم‌خوان با بک‌اند (`payment/repository.go`).
  static const int _monthlyAmount = 49000;
  static const int _yearlyAmount = 399000;

  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'monthly',
      'productId': 'vista_premium_monthly',
      'title': 'ماهانه',
      'amount': _monthlyAmount,
      'desc': 'انعطاف‌پذیر برای شروع',
    },
    {
      'id': 'yearly',
      'productId': 'vista_premium_yearly',
      'title': 'سالانه',
      'amount': _yearlyAmount,
      'desc': 'به‌صرفه‌ترین انتخاب',
      'badge': 'پیشنهاد ویستا',
    },
  ];

  static const List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.verified,
      'title': 'نشان تأیید طلایی',
      'subtitle':
          'تیک طلایی کنار نام شما در پروفایل، پست‌ها، کامنت‌ها و چت نمایش داده می‌شود.',
    },
    {
      'icon': Icons.timelapse,
      'title': 'استوری ۴۸ ساعته',
      'subtitle': 'استوری‌های شما تا ۴۸ ساعت در فید باقی می‌مانند (کاربران عادی: ۲۴ ساعت).',
    },
    {
      'icon': Icons.edit_note,
      'title': 'ویرایش پست پس از انتشار',
      'subtitle': 'کپشن و رسانه پست‌های خود را هر زمان ویرایش کنید.',
    },
    {
      'icon': Icons.text_snippet,
      'title': 'پست‌های طولانی‌تر',
      'subtitle': 'نوشتن متن تا ۴٬۰۰۰ کاراکتر (کاربران عادی: ۱٬۰۰۰ کاراکتر).',
    },
    {
      'icon': Icons.upload_file,
      'title': 'ارسال فایل تا ۵۰ مگابایت',
      'subtitle':
          'در چت می‌توانید تصویر، PDF و فایل صوتی تا ۵۰ مگابایت ارسال کنید (عادی: ۱۰ مگابایت).',
    },
    {
      'icon': Icons.video_collection,
      'title': 'ویدیو تا ۲ دقیقه',
      'subtitle': 'آپلود و برش ویدیو تا ۲ دقیقه (کاربران عادی: ۱ دقیقه).',
    },
    {
      'icon': Icons.visibility_off_outlined,
      'title': 'کنترل آمار لایک و کامنت',
      'subtitle': 'برای هر پست نمایش تعداد لایک و کامنت را روشن یا خاموش کنید.',
    },
    {
      'icon': Icons.trending_up,
      'title': 'اولویت در جستجو',
      'subtitle': 'پروفایل شما در نتایج جستجو بالاتر دیده می‌شود.',
    },
    {
      'icon': Icons.block,
      'title': 'بدون تبلیغات',
      'subtitle': 'تجربه‌ای تمیزتر بدون نمایش تبلیغ در بخش‌های اصلی برنامه.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initBazaar();
  }

  Future<void> _initBazaar() async {
    final connected = await _bazaarService.init();
    if (mounted) {
      setState(() {
        _isBazaarConnected = connected;
        _isLoading = false;
      });
    }
  }

  String _formatToman(int amount) {
    final formatted = NumberFormat.decimalPattern('fa').format(amount);
    return '$formatted تومان';
  }

  int _approxDaysAddedForPlan(int planIndex) {
    return _plans[planIndex]['id'] == 'yearly' ? 365 : 30;
  }

  Future<void> _onPurchaseTap() async {
    if (!_isBazaarConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اتصال به کافه‌بازار برقرار نشد. لطفاً اپ بازار را نصب یا به‌روزرسانی کنید.',
          ),
        ),
      );
      _initBazaar();
      return;
    }

    final allowed = await SensitiveActionGuard.verify(
      context,
      action: SensitiveAction.payment,
    );
    if (!allowed) return;

    setState(() => _isPurchasing = true);

    final selectedPlan = _plans[_selectedPlanIndex];
    final result = await _bazaarService.purchaseSubscription(
      selectedPlan['productId'] as String,
    );

    if (result['success'] == true) {
      final userId = await CurrentUserService.instance.resolveUserId();
      if (userId != null) {
        await ProfileCacheService().refreshCacheInBackground(userId);
      }
      ref.invalidate(profileProvider);
    }

    if (mounted) {
      setState(() => _isPurchasing = false);
      if (result['success'] == true) {
        final daysAdded = result['days_added'];
        final daysText = daysAdded is num && daysAdded > 0
            ? '\n${daysAdded.round()} روز به اشتراک شما اضافه شد.'
            : '';
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تبریک!', textAlign: TextAlign.center),
            content: Text(
              'اشتراک ویستا پریمیوم با موفقیت به‌روزرسانی شد.$daysText\n'
              'تیک طلایی و امکانات ویژه فعال است.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('باشه'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'خطا در پرداخت'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final isPremium = PremiumSubscriptionUtils.isPremiumActive(profile);
    final selectedPlan = _plans[_selectedPlanIndex];
    final extendHint = isPremium
        ? PremiumSubscriptionUtils.extendHintForPlan(
            selectedPlan['title'] as String,
          )
        : null;
    final yearlySavings = (_monthlyAmount * 12) - _yearlyAmount;
    final savingsPercent =
        ((yearlySavings / (_monthlyAmount * 12)) * 100).round();

    final statusBarColor = isDark ? const Color(0xFF1A1A1F) : Colors.white;
    final systemOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
    );
    SystemChrome.setSystemUIOverlayStyle(systemOverlayStyle);
    SystemUiBarService.sync(systemOverlayStyle);

    final busy = _isLoading || _isPurchasing;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF8F7FC),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: isDark ? const Color(0xFF1A1A1F) : Colors.white,
                systemOverlayStyle: systemOverlayStyle,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _premiumColor.withValues(alpha: isDark ? 0.35 : 0.2),
                          isDark
                              ? const Color(0xFF121214)
                              : const Color(0xFFF8F7FC),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 36),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _premiumColor.withValues(alpha: 0.45),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ویستا پریمیوم',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'همه امکانات ویژه در یک اشتراک',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isPremium)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _ActivePremiumBanner(
                      isDark: isDark,
                      profile: profile,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'با پریمیوم چه می‌گیرید؟',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      index == 0 ? 12 : 0,
                      20,
                      14,
                    ),
                    child: _FeatureTile(
                      feature: _features[index],
                      isDark: isDark,
                    ),
                  ),
                  childCount: _features.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'پرداخت امن از کافه‌بازار',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'پس از پرداخت، اشتراک بلافاصله روی حساب شما فعال می‌شود و در پنل مدیریت ثبت می‌گردد.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: isDark ? Colors.grey[600] : Colors.grey[500],
                        ),
                      ),
                      if (!isPremium && savingsPercent > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'پلن سالانه نسبت به ۱۲ ماه ماهانه حدود $savingsPercent٪ '
                            '(${_formatToman(yearlySavings)}) صرفه‌جویی دارد.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.green[300] : Colors.green[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1A1A1F) : Colors.white)
                            .withValues(alpha: 0.94),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: List.generate(_plans.length, (index) {
                              final plan = _plans[index];
                              final isSelected = _selectedPlanIndex == index;
                              final amount = plan['amount'] as int;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: busy
                                      ? null
                                      : () => setState(
                                            () => _selectedPlanIndex = index,
                                          ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: EdgeInsets.only(
                                      left: index == 0 ? 6 : 0,
                                      right: index == 1 ? 6 : 0,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _premiumColor.withValues(alpha: 0.14)
                                          : (isDark
                                              ? Colors.white10
                                              : Colors.grey.shade100),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? _premiumColor
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        if (plan['badge'] != null)
                                          Text(
                                            plan['badge'] as String,
                                            style: const TextStyle(
                                              color: _premiumColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        Text(
                                          plan['title'] as String,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isSelected
                                                ? _premiumColor
                                                : (isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatToman(amount),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          plan['desc'] as String,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? Colors.grey[500]
                                                : Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        if (isPremium) ...[
                          const SizedBox(height: 10),
                          Text(
                            extendHint ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'با این خرید حدود ${_approxDaysAddedForPlan(_selectedPlanIndex)} روز '
                            'به اشتراک فعلی شما اضافه می‌شود',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _premiumColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (busy || !_isBazaarConnected)
                                ? null
                                : _onPurchaseTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _premiumColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  _premiumColor.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isBazaarConnected
                                        ? (isPremium
                                            ? 'تمدید ${selectedPlan['title']} — ${_formatToman(selectedPlan['amount'] as int)}'
                                            : 'خرید ${selectedPlan['title']} — ${_formatToman(selectedPlan['amount'] as int)}')
                                        : 'کافه‌بازار در دسترس نیست',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                          if (!_isBazaarConnected && !_isLoading)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'برای خرید اشتراک، اپلیکیشن کافه‌بازار باید نصب باشد.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade300,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivePremiumBanner extends StatelessWidget {
  const _ActivePremiumBanner({
    required this.isDark,
    required this.profile,
  });

  final bool isDark;
  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context) {
    final remaining = PremiumSubscriptionUtils.remainingLabel(profile);
    final expiry = PremiumSubscriptionUtils.formatExpiryDate(profile);
    final days = PremiumSubscriptionUtils.daysRemaining(profile);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8774E1).withValues(alpha: 0.28),
            const Color(0xFF6C5CE7).withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8774E1).withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFFFFD54F), size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  remaining,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (days != null && days > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (days / 365).clamp(0.05, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                color: const Color(0xFF8774E1),
              ),
            ),
          ],
          if (expiry.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'تاریخ پایان: $expiry',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'می‌توانید پلن ماهانه یا سالانه بخرید؛ مدت جدید به روزهای باقی‌مانده اضافه می‌شود.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature, required this.isDark});

  final Map<String, dynamic> feature;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF8774E1).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            feature['icon'] as IconData,
            color: const Color(0xFF8774E1),
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feature['title'] as String,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                feature['subtitle'] as String,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
