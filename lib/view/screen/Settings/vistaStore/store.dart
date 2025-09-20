import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../main.dart';
import '../../../../provider/provider.dart';

class VerificationBadgeStore extends ConsumerStatefulWidget {
  const VerificationBadgeStore({super.key});

  @override
  ConsumerState<VerificationBadgeStore> createState() =>
      _VerificationBadgeStoreState();
}

class _VerificationBadgeStoreState
    extends ConsumerState<VerificationBadgeStore> {
  late ConfettiController _confettiController;
  bool _isLightingActive = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _playConfetti() {
    _confettiController.play();
  }

  void _launchPaymentURL(String url) async {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('انتقال به درگاه پرداخت'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('شما در حال انتقال به درگاه پرداخت زرین‌پال هستید.'),
              SizedBox(height: 16),
              Text(
                'پس از پرداخت موفق، تا ۱ الی ۴ ساعت آینده نشان شما فعال خواهد شد.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                launchUrl(Uri.parse(url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('انتقال به درگاه پرداخت'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('ادامه'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در اتصال به درگاه پرداخت: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('در حال انتقال به $url'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در باز کردن لینک'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در باز کردن لینک: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _activateLighting() {
    setState(() {
      _isLightingActive = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isLightingActive = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final getprofile = ref.watch(profileProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نشان‌های ویژه'),
          centerTitle: true,
          elevation: 0,
        ),
        body: getprofile.when(
          data: (profile) {
            final bool hasGoldBadge =
                profile != null && profile['badge_type'] == 'gold';
            final bool hasBlackBadge =
                profile != null && profile['badge_type'] == 'black';

            return Stack(
              alignment: Alignment.topCenter,
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(context),
                        const SizedBox(height: 24),
                        _buildActivationNotice(context),
                        const SizedBox(height: 24),
                        _sectionTitle(context, 'نشان‌های ویژه موجود'),
                        const SizedBox(height: 16),
                        _buildBadgeCard(
                          context: context,
                          title: 'نشان تأیید طلایی',
                          description:
                              'با نشان طلایی، حساب کاربری خود را ویژه کنید و از کاربران عادی متمایز شوید. اعتبار نشان به مدت یک ماه می‌باشد.',
                          price: '۸۰,۰۰۰ تومان',
                          iconColor: Colors.amber,
                          gradientColors: [
                            Colors.amber.shade300,
                            Colors.amber.shade700,
                          ],
                          isOwned: hasGoldBadge,
                          onTap: () {
                            if (!hasGoldBadge) {
                              _launchPaymentURL('https://zarinp.al/694791');

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('انتقال به درگاه پرداخت'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          specialEffect: () {
                            _playConfetti();
                          },
                          paymentLink: 'https://zarinp.al/694791',
                        ),
                        const SizedBox(height: 16),
                        _buildBadgeCard(
                          context: context,
                          title: 'نشان تأیید مشکی (پریمیوم)',
                          description:
                              'نشان مشکی نماد برترین و معتبرترین حساب‌های کاربری در پلتفرم ماست. با این نشان، شما در گروه نخبگان قرار می‌گیرید. اعتبار نشان به مدت یک ماه می‌باشد.',
                          price: '۵۰,۰۰۰ تومان',
                          iconColor: Colors.black,
                          gradientColors: [
                            Colors.grey.shade800,
                            Colors.black,
                          ],
                          isOwned: hasBlackBadge,
                          onTap: () {
                            if (!hasBlackBadge) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('انتقال به درگاه پرداخت'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _launchPaymentURL('https://zarinp.al/694791');
                            }
                          },
                          specialEffect: () {
                            _activateLighting();
                          },
                          paymentLink: 'https://zarinp.al/694751',
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle(context, 'مزایای نشان‌های ویژه'),
                        const SizedBox(height: 16),
                        _buildBenefitsList(context),
                        const SizedBox(height: 24),
                        _sectionTitle(context, 'سوالات متداول'),
                        const SizedBox(height: 16),
                        _buildFAQSection(context),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: -Math.pi / 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  maxBlastForce: 40,
                  minBlastForce: 10,
                  gravity: 0.1,
                ),
                if (_isLightingActive)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.7),
                          Colors.transparent,
                        ],
                        stops: const [0.1, 1.0],
                        radius: 0.8,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => Center(
            child: Text('خطایی رخ داد: ${error.toString()}'),
          ),
        ),
      ),
    );
  }

  Widget _buildActivationNotice(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.amber.shade800,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'اطلاعیه مهم',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'بعد از پرداخت موفق، فعال شدن نشان حدود ۱ الی ۴ ساعت زمان خواهد برد. در صورت عدم فعالسازی، لطفاً از طریق پشتیبانی تلگرام یا ایمیل با ما در ارتباط باشید.',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _contactChip(context, Icons.telegram, 'پشتیبانی تلگرام', () {
                _launchURL('https://t.me/vistasupp');
              }),
              const SizedBox(width: 12),
              _contactChip(context, Icons.email, 'ایمیل پشتیبانی', () {
                _launchURL('mailto:ahmadesmaili.official@gmail.com');
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactChip(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.black,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'نشان‌های ویژه هویت شما',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'نشان‌های ویژه به شما کمک می‌کنند تا اعتبار حساب کاربری خود را افزایش دهید. پروفایل شما با این نشان‌ها برجسته‌تر شده و سطح اعتماد دیگر کاربران به شما افزایش می‌یابد.',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Container(
            width: .4,
            height: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard({
    required BuildContext context,
    required String title,
    required String description,
    required String price,
    required Color iconColor,
    required List<Color> gradientColors,
    required bool isOwned,
    required VoidCallback onTap,
    required VoidCallback specialEffect,
    required String paymentLink,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isOwned
              ? BorderSide(color: colorScheme.primary, width: 2)
              : BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: isOwned
                  ? gradientColors
                  : [
                      colorScheme.surface,
                      colorScheme.surfaceContainerHighest,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: specialEffect,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: iconColor.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.verified,
                          color: iconColor,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isOwned ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: isOwned
                                    ? Colors.white70
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'اعتبار: یک ماه',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isOwned
                                      ? Colors.white70
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOwned ? 'فعال شده' : price,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isOwned
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // if (!isOwned)
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isOwned
                        ? Colors.white.withOpacity(0.9)
                        : colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _featureChip(context, 'اعتبار بیشتر', isOwned),
                    _featureChip(context, 'اولویت در جستجو', isOwned),
                    _featureChip(context, 'امکانات ویژه', isOwned),
                  ],
                ),
                if (!isOwned) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      _launchPaymentURL(paymentLink);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_cart,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'خرید آنلاین',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureChip(BuildContext context, String label, bool isWhiteText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWhiteText
            ? Colors.white.withOpacity(0.2)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWhiteText
              ? Colors.white.withOpacity(0.3)
              : Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isWhiteText ? Colors.white : null,
        ),
      ),
    );
  }

  Widget _buildBenefitsList(BuildContext context) {
    final benefits = [
      {
        'title': 'اعتبار و شهرت',
        'description':
            'نشان ویژه به پروفایل شما اعتبار بیشتری می‌بخشد و آن را از سایرین متمایز می‌کند.',
        'icon': Icons.trending_up,
        'color': Colors.blue,
        'animation': true,
      },
      {
        'title': 'ویدیوهای طولانی‌تر',
        'description':
            'با داشتن نشان ویژه، می‌توانید کلیپ‌های ویدیویی تا ۲ دقیقه آپلود کنید، در حالی که کاربران عادی محدود به ۱ دقیقه هستند.',
        'icon': Icons.video_collection_rounded,
        'color': Colors.red,
        'animation': false,
      },
      {
        'title': 'اولویت در جستجو',
        'description':
            'حساب‌های کاربری دارای نشان ویژه در نتایج جستجو در اولویت قرار می‌گیرند.',
        'icon': Icons.search,
        'color': Colors.purple,
        'animation': false,
      },
      {
        'title': 'دسترسی به امکانات انحصاری',
        'description':
            'با داشتن نشان ویژه، به امکانات و ویژگی‌های انحصاری دسترسی خواهید داشت.',
        'icon': Icons.star,
        'color': Colors.amber,
        'animation': true,
      },
      {
        'title': 'پشتیبانی ویژه',
        'description':
            'کاربران دارای نشان ویژه از پشتیبانی اختصاصی و سریع‌تر بهره‌مند می‌شوند.',
        'icon': Icons.support_agent,
        'color': Colors.teal,
        'animation': false,
      },
      {
        'title': 'اطلاع‌رسانی پیشرفته',
        'description':
            'دریافت اعلان‌های ویژه و اطلاع از آخرین رویدادها و قابلیت‌های پلتفرم قبل از سایر کاربران.',
        'icon': Icons.notifications_active,
        'color': Colors.orange,
        'animation': true,
      },
      {
        'title': 'نمایش در بخش کاربران برتر',
        'description':
            'پروفایل شما در بخش کاربران برتر پلتفرم نمایش داده می‌شود که باعث افزایش بازدید و تعامل با پروفایل شما می‌شود.',
        'icon': Icons.people,
        'color': Colors.indigo,
        'animation': false,
      },
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: benefits.length,
      itemBuilder: (context, index) {
        final benefit = benefits[index];
        final Color benefitColor = benefit['color'] as Color;
        final bool hasAnimation = benefit['animation'] as bool;

        return _buildBenefitCard(
          context: context,
          title: benefit['title'] as String,
          description: benefit['description'] as String,
          icon: benefit['icon'] as IconData,
          color: benefitColor,
          hasAnimation: hasAnimation,
        );
      },
    );
  }

  Widget _buildBenefitCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool hasAnimation,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 4,
      color: colorScheme.surface,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => _buildBenefitDetailSheet(
              context: context,
              title: title,
              description: description,
              icon: icon,
              color: color,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              hasAnimation
                  ? _buildAnimatedIcon(context, icon, color)
                  : _buildStaticIcon(context, icon, color),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaticIcon(BuildContext context, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: 36,
      ),
    );
  }

  Widget _buildAnimatedIcon(BuildContext context, IconData icon, Color color) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: 0.8 + (value * 0.2),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3 * value),
                  blurRadius: 12 * value,
                  spreadRadius: 2 * value,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 36,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBenefitDetailSheet({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'این مزیت به صورت خودکار با فعال شدن نشان ویژه برای شما فعال خواهد شد.',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeComparisonTable(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final features = [
      'نمایش نشان کنار نام کاربری',
      'اولویت در نتایج جستجو',
      'دسترسی به امکانات اختصاصی',
      'پشتیبانی ویژه',
      'نمایش در بخش کاربران برتر',
      'اطلاع‌رسانی پیشرفته',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: Text(
                      'ویژگی',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.verified,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'طلایی',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.verified,
                          color: Colors.black,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'مشکی',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: features.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  color: index.isEven
                      ? colorScheme.surfaceContainerHighest.withOpacity(0.05)
                      : Colors.transparent,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: Text(
                            features[index],
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Icon(
                            index < 3 ? Icons.check_circle : Icons.close,
                            color: index < 3 ? Colors.green : Colors.grey,
                            size: 18,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(
        expansionTileTheme: ExpansionTileThemeData(
          backgroundColor: colorScheme.surface,
          collapsedBackgroundColor: colorScheme.surface,
        ),
      ),
      child: ExpansionPanelList.radio(
        elevation: 2,
        expandedHeaderPadding: EdgeInsets.zero,
        children: [
          ExpansionPanelRadio(
            headerBuilder: (context, isExpanded) {
              return const ListTile(
                title: Text('نشان ویژه چیست و چه کاربردی دارد؟'),
              );
            },
            body: const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'نشان ویژه نمادی است که نشان‌دهنده اعتبار و اصالت حساب کاربری شما است. با داشتن این نشان، دیگر کاربران اطمینان بیشتری به شما خواهند داشت و پروفایل شما از سایرین متمایز خواهد شد.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.justify,
              ),
            ),
            value: 0,
          ),
          ExpansionPanelRadio(
            headerBuilder: (context, isExpanded) {
              return const ListTile(
                title: Text('تفاوت نشان طلایی و مشکی چیست؟'),
              );
            },
            body: const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'نشان طلایی نشان‌دهنده اعتبار حساب کاربری شماست. نشان مشکی علاوه بر اعتبار، نشان‌دهنده جایگاه ویژه شما در پلتفرم ماست و دسترسی به امکانات بیشتری را فراهم می‌کند.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.justify,
              ),
            ),
            value: 1,
          ),
          ExpansionPanelRadio(
            headerBuilder: (context, isExpanded) {
              return const ListTile(
                title:
                    Text('آیا می‌توانم نشان ویژه را به حساب دیگری منتقل کنم؟'),
              );
            },
            body: const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'خیر، نشان ویژه مختص حساب کاربری شماست و قابل انتقال به حساب دیگری نیست.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.justify,
              ),
            ),
            value: 2,
          ),
          ExpansionPanelRadio(
            headerBuilder: (context, isExpanded) {
              return const ListTile(
                title: Text(
                    'پس از خرید، چه مدت طول می‌کشد تا نشان ویژه فعال شود؟'),
              );
            },
            body: const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'پس از تأیید پرداخت، فعالسازی نشان ویژه حدود 1 الی 4 ساعت زمان خواهد برد. اگر پس از این مدت نشان شما فعال نشد، لطفاً با پشتیبانی تماس بگیرید.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.justify,
              ),
            ),
            value: 3,
          ),
          ExpansionPanelRadio(
            headerBuilder: (context, isExpanded) {
              return const ListTile(
                title: Text('مدت اعتبار نشان‌های ویژه چقدر است؟'),
              );
            },
            body: const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'مدت اعتبار هر یک از نشان‌های ویژه طلایی و مشکی یک ماه می‌باشد.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.justify,
              ),
            ),
            value: 4,
          ),
        ],
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, String badgeType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('خرید نشان $badgeType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'آیا مطمئن هستید که می‌خواهید نشان $badgeType را خریداری کنید؟'),
            const SizedBox(height: 16),
            const Text(
              'پس از تأیید، به درگاه پرداخت هدایت خواهید شد.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _processPurchase(context, badgeType);
            },
            child: const Text('تأیید و پرداخت'),
          ),
        ],
      ),
    );
  }

  void _processPurchase(BuildContext context, String badgeType) {
    final String paymentUrl = badgeType == 'طلایی'
        ? 'https://zarinp.al/694791'
        : 'https://zarinp.al/694751';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('خرید نشان $badgeType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('شما در حال خرید اشتراک یک ماهه نشان $badgeType هستید.'),
            const SizedBox(height: 12),
            const Text(
              'توجه: پس از پرداخت موفق، فعال‌سازی نشان بین ۱ تا ۴ ساعت زمان خواهد برد.',
              style: TextStyle(fontSize: 13, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            const Text(
              'در صورت عدم فعال‌سازی پس از ۴ ساعت، لطفاً از طریق پشتیبانی تلگرام یا ایمیل با ما در تماس باشید.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(paymentUrl));
            },
            child: const Text('انتقال به درگاه پرداخت'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserBadge(String badgeType) async {
    try {
      final userID = supabase.auth.currentUser!.id;

      await supabase.from('profiles').update({
        'badge_type': badgeType,
        'is_verified': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userID);

      ref.refresh(profileProvider);

      if (badgeType == 'gold') {
        _playConfetti();
      } else if (badgeType == 'black') {
        _activateLighting();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در بروزرسانی پروفایل: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
