import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:Vista/DB/profile_cache_service.dart';
import 'package:Vista/features/profile/providers/profile_controller.dart';
import 'package:Vista/services/payment_service.dart';
import 'package:Vista/services/current_user_service.dart';
import 'package:Vista/services/sensitive_action_guard.dart';
import 'package:Vista/services/system_ui_bar_service.dart';
import 'package:Vista/utils/directional_navigation.dart';
import 'package:Vista/utils/premium_subscription_utils.dart';

/// صفحه خرید اشتراک ویستا پریمیوم از درگاه کافه‌بازار.
class PricingPage extends ConsumerStatefulWidget {
  const PricingPage({super.key});

  @override
  ConsumerState<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends ConsumerState<PricingPage>
    with SingleTickerProviderStateMixin {
  // تم رنگی لاکچری و پریمیوم
  static const Color _goldStart = Color(0xFFFFD700);
  static const Color _goldEnd = Color(0xFFFDB931);
  static const Color _darkBg = Color(0xFF0F0F13);

  final PaymentService _paymentService = PaymentService();
  bool _isBazaarConnected = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  int _selectedPlanIndex = 1;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// مبالغ هم‌خوان با محصول‌های تعریف‌شده در بازار.
  static const int _monthlyAmount = 100;
  static const int _threeMonthlyAmount = 280;
  static const int _yearlyAmount = 1000000;

  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'monthly',
      'productId': 'vista_premium_monthly',
      'title': 'ماهانه',
      'amount': _monthlyAmount,
      'durationDays': 30,
      'desc': 'انعطاف‌پذیر برای شروع',
    },
    {
      'id': 'three_monthly',
      'productId': 'vista_premium_3monthly',
      'title': 'سه‌ماهه',
      'amount': _threeMonthlyAmount,
      'durationDays': 90,
      'desc': 'سه ماه پریمیوم پیوسته',
      'badge': 'پیشنهاد ویستا',
    },
    {
      'id': 'yearly',
      'productId': 'vista_premium_yearly',
      'title': 'سالانه',
      'amount': _yearlyAmount,
      'durationDays': 365,
      'desc': 'یک سال کامل پریمیوم',
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
      'subtitle':
          'استوری‌های شما تا ۴۸ ساعت در فید باقی می‌مانند (کاربران عادی: ۲۴ ساعت).',
    },
    {
      'icon': Icons.edit_note,
      'title': 'ویرایش پست پس از انتشار',
      'subtitle': 'کپشن و رسانه پست‌های خود را هر زمان ویرایش کنید.',
    },
    {
      'icon': Icons.text_snippet,
      'title': 'پست‌های طولانی‌تر',
      'subtitle': 'نوشتن متن تا ۱٬۰۰۰ کاراکتر (کاربران عادی: ۵۰۰ کاراکتر).',
    },
    {
      'icon': Icons.upload_file,
      'title': 'ارسال فایل تا ۱۰۰ مگابایت',
      'subtitle':
          'می‌توانید تصویر، کلیپ، موزیک، PDF و فایل‌ها را تا ۱۰۰ مگابایت ارسال کنید (کاربران عادی: ۱۵ مگابایت).',
    },
    {
      'icon': Icons.video_collection,
      'title': 'ویدیو تا ۲ دقیقه',
      'subtitle': 'آپلود و برش ویدیو تا ۲ دقیقه (کاربران عادی: ۱ دقیقه).',
    },
    {
      'icon': Icons.collections,
      'title': 'آلبوم چندعکسی تا ۱۰ عکس',
      'subtitle':
          'در هر پست تا ۱۰ عکس به‌صورت اسلایدی منتشر کنید (کاربران عادی: ۳ عکس).',
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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initBazaar();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initBazaar() async {
    final connected = await _paymentService.init();
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
    return _plans[planIndex]['durationDays'] as int;
  }

  Future<void> _onPurchaseTap() async {
    if (!_isBazaarConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'اتصال به کافه‌بازار برقرار نشد. لطفاً اپ بازار را نصب یا به‌روزرسانی کنید.'),
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
    final result = await _paymentService.purchaseSubscription(
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
            backgroundColor: _darkBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: _goldStart, width: 1.5)),
            title: const Text('تبریک!',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: _goldStart, fontWeight: FontWeight.bold)),
            content: Text(
              'اشتراک ویستا پریمیوم با موفقیت به‌روزرسانی شد.$daysText\nتیک طلایی و امکانات ویژه فعال است.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('باشه', style: TextStyle(color: _goldStart)),
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
            selectedPlan['title'] as String)
        : null;
    final yearlySavings = (_monthlyAmount * 12) - _yearlyAmount;
    final savingsPercent =
        ((yearlySavings / (_monthlyAmount * 12)) * 100).round();

    final statusBarColor = Colors.transparent;
    final systemOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
    );
    SystemChrome.setSystemUIOverlayStyle(systemOverlayStyle);
    SystemUiBarService.sync(systemOverlayStyle);

    final busy = _isLoading || _isPurchasing;

    return Scaffold(
      backgroundColor: isDark ? _darkBg : const Color(0xFF14141A),
      body: Stack(
        children: [
          // پس‌زمینه انیمیشنی پریمیوم
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xFF2A1B00),
                    _darkBg,
                    Color(0xFF110A00),
                  ],
                ),
              ),
            ),
          ),
          // هاله درخشان طلایی بالا
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _goldStart.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.transparent,
                systemOverlayStyle: systemOverlayStyle,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    directionalBackIcon(context, ios: true),
                    size: 22,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [_goldStart, _goldEnd],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _goldStart.withValues(alpha: 0.4),
                                blurRadius: 25,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [_goldStart, _goldEnd, Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'ویستا پریمیوم',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'بالاترین سطح تجربه در ویستا',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isPremium)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: _ActivePremiumBanner(
                      profile: profile,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: _goldStart, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'امکانات انحصاری شما',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _FeatureTileUI(
                      feature: _features[index],
                    ),
                  ),
                  childCount: _features.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 6),
                          Text(
                            'پرداخت امن کافه‌بازار',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'پس از پرداخت، اشتراک بلافاصله روی حساب شما فعال می‌شود و در پنل مدیریت ثبت می‌گردد.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      if (!isPremium && savingsPercent > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _goldStart.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _goldStart.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_offer_rounded,
                                  color: _goldStart, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'پلن سالانه نسبت به ۱۲ ماه ماهانه حدود $savingsPercent٪ '
                                  '(${_formatToman(yearlySavings)}) صرفه‌جویی دارد.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _goldStart,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // بخش پایینی (باکس خرید)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A20).withValues(alpha: 0.85),
                    border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1), width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
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
                                        () => _selectedPlanIndex = index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _goldStart.withValues(alpha: 0.12)
                                        : Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? _goldStart
                                          : Colors.white.withValues(alpha: 0.1),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                                color: _goldStart.withValues(
                                                    alpha: 0.15),
                                                blurRadius: 12)
                                          ]
                                        : [],
                                  ),
                                  child: Column(
                                    children: [
                                      if (plan['badge'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          margin:
                                              const EdgeInsets.only(bottom: 6),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                                colors: [_goldStart, _goldEnd]),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            plan['badge'] as String,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        plan['title'] as String,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: isSelected
                                              ? _goldStart
                                              : Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatToman(amount),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        plan['desc'] as String,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white
                                              .withValues(alpha: 0.4),
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
                          const SizedBox(height: 16),
                          Text(
                            extendHint ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'با این خرید حدود ${_approxDaysAddedForPlan(_selectedPlanIndex)} روز به اشتراک فعلی شما اضافه می‌شود',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _goldStart,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: busy || !_isBazaarConnected
                                    ? [
                                        Colors.grey.shade800,
                                        Colors.grey.shade900
                                      ]
                                    : [_goldStart, _goldEnd],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: busy || !_isBazaarConnected
                                  ? []
                                  : [
                                      BoxShadow(
                                        color:
                                            _goldStart.withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                            ),
                            child: ElevatedButton(
                              onPressed: (busy || !_isBazaarConnected)
                                  ? null
                                  : _onPurchaseTap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: busy
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                          color: Colors.black87,
                                          strokeWidth: 2.5),
                                    )
                                  : Text(
                                      _isBazaarConnected
                                          ? (isPremium
                                              ? 'تمدید ${selectedPlan['title']} — ${_formatToman(selectedPlan['amount'] as int)}'
                                              : 'خرید ${selectedPlan['title']} — ${_formatToman(selectedPlan['amount'] as int)}')
                                          : 'کافه‌بازار در دسترس نیست',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: busy || !_isBazaarConnected
                                            ? Colors.white54
                                            : Colors.black87,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        if (!_isBazaarConnected && !_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'برای خرید اشتراک، اپلیکیشن کافه‌بازار باید نصب باشد.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent.shade200),
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
  const _ActivePremiumBanner({required this.profile});

  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context) {
    final remaining = PremiumSubscriptionUtils.remainingLabel(profile);
    final expiry = PremiumSubscriptionUtils.formatExpiryDate(profile);
    final days = PremiumSubscriptionUtils.daysRemaining(profile);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1C18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded,
                  color: Color(0xFFFFD700), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  remaining,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (days != null && days > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (days / 365).clamp(0.05, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
              ),
            ),
          ],
          if (expiry.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'اعتبار تا: $expiry',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureTileUI extends StatelessWidget {
  const _FeatureTileUI({required this.feature});

  final Map<String, dynamic> feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFD700).withValues(alpha: 0.2),
                  const Color(0xFFFDB931).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
            ),
            child: Icon(
              feature['icon'] as IconData,
              color: const Color(0xFFFFD700),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature['title'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  feature['subtitle'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
