import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/services/BazaarPaymentService.dart';

class PricingPage extends ConsumerStatefulWidget {
  const PricingPage({super.key});

  @override
  ConsumerState<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends ConsumerState<PricingPage> {
  final BazaarPaymentService _bazaarService = BazaarPaymentService();
  bool _isBazaarConnected = false;
  bool _isLoading = true;
  int _selectedPlanIndex = 1; // پیش‌فرض روی سالانه

  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'monthly',
      'productId': 'vista_premium_monthly', // شناسه دقیق در بازار
      'title': 'ماهانه',
      'price': '۹۹,۰۰۰ تومان',
      'desc': 'مناسب برای تست',
      'color': Colors.blue,
    },
    {
      'id': 'yearly',
      'productId': 'vista_premium_yearly', // شناسه دقیق در بازار
      'title': 'سالانه',
      'price': '۷۹۹,۰۰۰ تومان',
      'desc': '۳۳٪ تخفیف (پیشنهادی)',
      'color': const Color(0xFF8774E1), // رنگ بنفش تلگرام
      'badge': 'بصرفه',
    },
  ];

  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.verified,
      'title': 'تیک طلایی وریفای',
      'subtitle': 'نمایش نشان تایید در کنار نام شما برای همه کاربران'
    },
    {
      'icon': Icons.speed,
      'title': 'سرعت دانلود بیشتر',
      'subtitle': 'بدون محدودیت سرعت در دانلود مدیا و فایل‌ها'
    },
    {
      'icon': Icons.star,
      'title': 'استیکرهای متحرک اختصاصی',
      'subtitle': 'دسترسی به مجموعه‌ای از استیکرهای خاص پریمیوم'
    },
    {
      'icon': Icons.badge,
      'title': 'پروفایل متحرک',
      'subtitle': 'امکان استفاده از ویدیو برای آواتار پروفایل'
    },
    {
      'icon': Icons.block,
      'title': 'بدون تبلیغات',
      'subtitle': 'حذف کامل تبلیغات از تمام بخش‌های برنامه'
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

  @override
  void dispose() {
    super.dispose();
  }

  void _onPurchaseTap() async {
    if (!_isBazaarConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'خطا: عدم دسترسی به سرویس بازار. لطفاً کافه‌بازار را نصب یا بروزرسانی کنید.')),
      );
      // تلاش مجدد برای اتصال
      _initBazaar();
      return;
    }

    setState(() => _isLoading = true);

    final selectedPlan = _plans[_selectedPlanIndex];
    final result =
        await _bazaarService.purchaseSubscription(selectedPlan['productId']);

    setState(() => _isLoading = false);

    if (result['success']) {
      // رفرش کردن استیت کاربر (مثلاً اگر از ریورپاد برای پروفایل استفاده می‌کنید)
      // ref.refresh(profileProvider);

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تبریک! 🎉', textAlign: TextAlign.center),
            content: const Text('اشتراک پریمیوم شما با موفقیت فعال شد.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('باشه'))
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // رنگ بنفش تلگرامی
    const premiumColor = Color(0xFF8774E1);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // هدر با افکت نوری
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor:
                    isDark ? const Color(0xFF1E1E1E) : Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    alignment: Alignment.center,
                    children: [
                      // گرادینت پس‌زمینه
                      Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topCenter,
                            radius: 1.5,
                            colors: [
                              premiumColor.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // آیکون اصلی (ستاره چرخنده یا مشابه تلگرام)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: premiumColor.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.star,
                                color: Colors.white, size: 40),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Vista Premium',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily:
                                  'BauhausBold', // فونت انگلیسی اگر دارید
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // لیست ویژگی‌ها
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      ..._features.map((f) => _buildFeatureItem(f, isDark)),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // بخش پایینی (انتخاب پلن و دکمه خرید)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white)
                          .withOpacity(0.9),
                      border: Border(
                          top: BorderSide(color: Colors.grey.withOpacity(0.2))),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // انتخاب پلن‌ها
                        Row(
                          children: List.generate(_plans.length, (index) {
                            final plan = _plans[index];
                            final isSelected = _selectedPlanIndex == index;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedPlanIndex = index),
                                child: Container(
                                  margin: EdgeInsets.only(
                                      left: index == 0 ? 8 : 0,
                                      right: index == 1 ? 8 : 0),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? premiumColor.withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? premiumColor
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      if (plan['badge'] != null)
                                        Text(
                                          plan['badge'],
                                          style: TextStyle(
                                            color: premiumColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      Text(
                                        plan['title'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isSelected
                                              ? premiumColor
                                              : (isDark
                                                  ? Colors.white
                                                  : Colors.black),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        plan['price'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 16),

                        // دکمه اصلی خرید
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _onPurchaseTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: premiumColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                              shadowColor: premiumColor.withOpacity(0.4),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Text(
                                    _isBazaarConnected
                                        ? 'خرید اشتراک ${_plans[_selectedPlanIndex]['title']} - ${_plans[_selectedPlanIndex]['price']}'
                                        : 'بازار در دسترس نیست',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),

                        if (!_isBazaarConnected && !_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'لطفاً مطمئن شوید برنامه "بازار" روی گوشی نصب است.',
                              style: TextStyle(
                                  color: Colors.red[300], fontSize: 11),
                              textAlign: TextAlign.center,
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

  Widget _buildFeatureItem(Map<String, dynamic> feature, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8774E1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(feature['icon'], color: const Color(0xFF8774E1), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature['subtitle'],
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
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
