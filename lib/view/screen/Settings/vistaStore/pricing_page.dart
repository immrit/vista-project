import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

class PricingPage extends ConsumerStatefulWidget {
  const PricingPage({super.key});

  @override
  ConsumerState<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends ConsumerState<PricingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _selectedPlanIndex = 1; // پیش‌فرض پلن سالانه (بیشترین صرفه‌جویی)
  final Uri _premiumRedirectUri = Uri.parse('https://cafevista.ir');

  final List<Map<String, dynamic>> _pricingPlans = [
    {
      'id': 'monthly',
      'title': 'یک ماهه',
      'price': 99000,
      'originalPrice': 99000,
      'discount': 0,
      'duration': '۱ ماه',
      'badge': '🌟 پرطرفدار',
      'color': Colors.blue,
      'features': [
        'تیک طلایی اختصاصی',
        'پشتیبانی اولویت‌دار',
        'بدون تبلیغات',
        'امکانات پیشرفته',
      ],
    },
    {
      'id': 'yearly',
      'title': 'یک ساله',
      'price': 799000,
      'originalPrice': 1188000,
      'discount': 33,
      'duration': '۱۲ ماه',
      'badge': '💎 بیشترین صرفه‌جویی',
      'color': Colors.purple,
      'monthlyPrice': '۶۶ هزار تومان/ماه',
      'features': [
        'همه مزایای پلن ماهانه',
        '۳۳٪ تخفیف',
        'پروفایل تایید شده',
        'دسترسی زودهنگام به ویژگی‌های جدید',
      ],
      'popular': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // AppBar با افکت گلس
            SliverAppBar(
              expandedHeight: 200.h,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.amber.withOpacity(0.3),
                        Colors.orange.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Blur effect
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: Colors.black.withOpacity(0.1),
                          ),
                        ),
                      ),
                      // محتوا
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 40.h),
                            // آیکون طلایی
                            Container(
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber,
                                    Colors.orange,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.verified,
                                size: 40.sp,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'ویستا پریمیوم',
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'تجربه‌ای فراتر از عادی',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: isDark ? Colors.white70 : Colors.black54,
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

            // آمار و ارقام جذاب
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('۱۰,۰۰۰+', 'کاربر فعال', Icons.people),
                    _buildStatItem('۳x', 'دیده شدن بیشتر', Icons.visibility),
                    _buildStatItem('۴.۹⭐', 'رضایت کاربران', Icons.star),
                  ],
                ),
              ),
            ),

            // پلن‌های قیمت‌گذاری
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final plan = _pricingPlans[index];
                    final isSelected = _selectedPlanIndex == index;
                    final isPopular = plan['popular'] == true;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.only(bottom: 16.h),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPlanIndex = index;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: isSelected
                                  ? plan['color']
                                  : Colors.grey.withOpacity(0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      plan['color'].withOpacity(0.1),
                                      plan['color'].withOpacity(0.05),
                                    ],
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: plan['color'].withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              // Badge برای پلن محبوب
                              if (isPopular)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.orange, Colors.deepOrange],
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(20.r),
                                        bottomLeft: Radius.circular(20.r),
                                      ),
                                    ),
                                    child: Text(
                                      plan['badge'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

                              // محتوای کارت
                              Padding(
                                padding: EdgeInsets.all(20.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // عنوان و قیمت
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              plan['title'],
                                              style: TextStyle(
                                                fontSize: 20.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              plan['duration'],
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            // قیمت با تخفیف
                                            Row(
                                              children: [
                                                if (plan['discount'] > 0) ...[
                                                  Text(
                                                    _formatPrice(plan['originalPrice']),
                                                    style: TextStyle(
                                                      fontSize: 14.sp,
                                                      color: Colors.grey,
                                                      decoration: TextDecoration
                                                          .lineThrough,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8.w),
                                                ],
                                                Text(
                                                  _formatPrice(plan['price']),
                                                  style: TextStyle(
                                                    fontSize: 20.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: plan['color'],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // قیمت ماهانه
                                            if (plan['monthlyPrice'] != null) ...[
                                              SizedBox(height: 4.h),
                                              Text(
                                                plan['monthlyPrice'],
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 16.h),

                                    // Badge تخفیف
                                    if (plan['discount'] > 0)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12.w,
                                          vertical: 6.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Text(
                                          '${plan['discount']}٪ تخفیف',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                    SizedBox(height: 16.h),

                                    // لیست ویژگی‌ها
                                    ...List.generate(
                                      (plan['features'] as List).length,
                                      (i) => Padding(
                                        padding: EdgeInsets.only(bottom: 8.h),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 20.sp,
                                              color: plan['color'],
                                            ),
                                            SizedBox(width: 12.w),
                                            Expanded(
                                              child: Text(
                                                plan['features'][i],
                                                style: TextStyle(fontSize: 14.sp),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // چک مارک برای انتخاب شده
                              if (isSelected)
                                Positioned(
                                  bottom: 16.h,
                                  left: 16.w,
                                  child: Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: plan['color'],
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20.sp,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _pricingPlans.length,
                ),
              ),
            ),

            // دکمه خرید
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    // دکمه اصلی
                    ElevatedButton(
                      onPressed: () => _handlePurchase(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _pricingPlans[_selectedPlanIndex]['color'],
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 56.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'خرید پلن ${_pricingPlans[_selectedPlanIndex]['title']}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(Icons.arrow_back, size: 20.sp),
                        ],
                      ),
                    ),

                    SizedBox(height: 12.h),

                    // نوار اطمینان
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user,
                          size: 16.sp,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'پرداخت امن و مطمئن',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24.h),

                    // سوالات متداول
                    _buildFAQSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            icon,
            color: Colors.amber,
            size: 24.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFAQSection() {
    return ExpansionTile(
      title: Text(
        'سوالات متداول',
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
      children: [
        _buildFAQItem(
          'آیا می‌توانم پلن را تغییر دهم؟',
          'بله، در هر زمان می‌توانید پلن خود را ارتقا دهید.',
        ),
        _buildFAQItem(
          'آیا امکان بازگشت وجه وجود دارد؟',
          'در صورت عدم رضایت تا ۷ روز امکان بازگشت وجه دارید.',
        ),
        _buildFAQItem(
          'تیک طلایی چه مزایایی دارد؟',
          'پست‌های شما ۳ برابر بیشتر دیده می‌شوند و پشتیبانی اختصاصی دارید.',
        ),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            answer,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    return '${(price / 1000).toStringAsFixed(0)} هزار تومان';
  }

  Future<void> _handlePurchase() async {
    final selectedPlan = _pricingPlans[_selectedPlanIndex];

    // نمایش دیالوگ تایید
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتقال به وب‌سایت ویستا'),
        content: Text(
          'برای تکمیل خرید پلن ${selectedPlan['title']} به وب‌سایت cafevista.ir هدایت می‌شوید. ادامه می‌دهید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ادامه'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _redirectToPremiumSite();
    }
  }

  Future<void> _redirectToPremiumSite() async {
    if (!await launchUrl(_premiumRedirectUri,
        mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('امکان باز کردن سایت ویستا وجود ندارد.'),
        ),
      );
    }
  }
}

