import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ویجت SVG ماهی قرمز عید - اصلاح شده با جهت صحیح
class GoldfishSvg extends StatelessWidget {
  final double size;
  final bool isSwimmingRight;

  const GoldfishSvg({
    super.key,
    this.size = 24,
    this.isSwimmingRight = true,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(isSwimmingRight ? 1.0 : -1.0, 1.0),
      child: SvgPicture.string(
        '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <!-- بدن ماهی - اصلاح شده برای حرکت جلورو -->
  <path d="M10,50 C10,35 25,25 40,25 C55,25 70,35 70,50 C70,65 55,75 40,75 C25,75 10,65 10,50 Z" fill="#FF0000" />
  
  <!-- دم ماهی -->
  <path d="M5,50 C-5,35 -22,40 -22,50 C-22,60 -5,65 5,50 Z" fill="#FF0000" />
  
  <!-- باله پشتی -->
  <path d="M40,25 C45,15 55,20 50,30" fill="#FF0000" />
  
  <!-- باله شکمی -->
  <path d="M40,75 C45,85 55,80 50,70" fill="#FF0000" />
  
  <!-- چشم -->
  <circle cx="65" cy="45" r="5" fill="white" />
  <circle cx="65" cy="45" r="3" fill="black" />
  
  <!-- نقاط طلایی روی بدن -->
  <circle cx="40" cy="40" r="2" fill="#FFD700" />
  <circle cx="30" cy="50" r="2" fill="#FFD700" />
  <circle cx="45" cy="60" r="2" fill="#FFD700" />
</svg>
        ''',
        width: size,
        height: size,
      ),
    );
  }
}

// ویجت SVG سبزه عید
class SabzehSvg extends StatelessWidget {
  final double size;

  const SabzehSvg({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <!-- گلدان -->
  <path d="M35,90 L65,90 L60,70 C60,65 55,60 50,60 C45,60 40,65 40,70 L35,90 Z" fill="#D7CCC8" />
  
  <!-- سبزه‌ها - سبزتر -->
  <path d="M45,60 C45,20 30,30 40,5" stroke="#2E7D32" stroke-width="2" fill="none" />
  <path d="M50,60 C50,15 60,25 50,5" stroke="#2E7D32" stroke-width="2" fill="none" />
  <path d="M55,60 C55,20 70,30 60,5" stroke="#2E7D32" stroke-width="2" fill="none" />
  
  <!-- سبزه‌های کوتاه‌تر -->
  <path d="M42,60 C42,40 35,45 38,25" stroke="#4CAF50" stroke-width="1.5" fill="none" />
  <path d="M58,60 C58,40 65,45 62,25" stroke="#4CAF50" stroke-width="1.5" fill="none" />
  <path d="M47,60 C47,30 40,40 42,20" stroke="#4CAF50" stroke-width="1.5" fill="none" />
  <path d="M53,60 C53,30 60,40 58,20" stroke="#4CAF50" stroke-width="1.5" fill="none" />
</svg>
      ''',
      width: size,
      height: size,
    );
  }
}

class FishSwimAnimation extends StatefulWidget {
  final double width;
  final double verticalPosition;
  final double size;

  const FishSwimAnimation({
    super.key,
    required this.width,
    this.verticalPosition = 0,
    this.size = 20,
  });

  @override
  State<FishSwimAnimation> createState() => _FishSwimAnimationState();
}

class _FishSwimAnimationState extends State<FishSwimAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  bool _isGoingRight = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );

    _setupAnimation();

    // اضافه کردن بررسی کننده وضعیت برای تغییر جهت ماهی
    _controller.addListener(() {
      // نقطه‌ی چرخش - زمانی که ماهی به انتها می‌رسد
      final double turnPoint = 0.99;
      final double returnPoint = 0.01;

      if (_controller.value >= turnPoint && _isGoingRight) {
        setState(() {
          _isGoingRight = false;
        });
      } else if (_controller.value <= returnPoint && !_isGoingRight) {
        setState(() {
          _isGoingRight = true;
        });
      }
    });

    _controller.repeat(reverse: true);
  }

  void _setupAnimation() {
    // منحنی حرکت نرم برای ماهی
    _positionAnimation = CurvedAnimation(
      parent: _controller,
      // منحنی مخصوص برای حرکت نرم‌تر در انتها
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _positionAnimation,
      builder: (context, child) {
        // محاسبه موقعیت ماهی
        final double position =
            _positionAnimation.value * widget.width - (widget.width / 2);

        return Positioned(
          top: widget.verticalPosition,
          left: widget.width / 2 + position - widget.size / 2,
          child: GoldfishSvg(
            size: widget.size,
            isSwimmingRight: _isGoingRight,
          ),
        );
      },
    );
  }
}

// ویجت کامل عنوان نوروزی با ماهی متحرک روی نام ویستا
class NoroozTitle extends StatelessWidget {
  const NoroozTitle({super.key});

  void _showNoroozToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🌱نوروز مبارک ',
              style: TextStyle(
                fontFamily: 'Vazir',
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            // SabzehSvg(size: 18),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        duration: Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // اندازه متن ویستا
    const double fontSize = 24;

    // اندازه تقریبی عرض عنوان برای حرکت ماهی
    const double textWidth = 80; // تخمین عرض تقریبی متن "Vista"

    return GestureDetector(
      onTap: () => _showNoroozToast(context),
      child: SizedBox(
        width: textWidth + 20, // اضافه کردن فضای کافی برای ماهی
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // عنوان Vista با یک گرادیانت سبز بهاری
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF4CAF50), // سبز روشن
                  Color(0xFF81C784), // سبز ملایم
                ],
              ).createShader(bounds),
              child: const Text(
                'Vista',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Bauhaus',
                ),
              ),
            ),

            // ماهی قرمز متحرک با کلاس اختصاصی
            FishSwimAnimation(width: textWidth, verticalPosition: 2, size: 20),

            // سبزه های در بالای متن
            Positioned(
              top: -20,
              child: SabzehSvg(size: 22)
                  .animate(onPlay: (controller) => controller.repeat())
                  .shake(
                    duration: const Duration(seconds: 5),
                    rotation: 0.03,
                    hz: 0.3,
                  ),
            ),

            // سبزه های کوچکتر در اطراف بالای متن
            Positioned(
              right: -10,
              top: -15,
              child: SabzehSvg(size: 16)
                  .animate(onPlay: (controller) => controller.repeat())
                  .shake(
                    duration: const Duration(seconds: 3),
                    rotation: 0.05,
                  ),
            ),

            Positioned(
              left: -10,
              top: -15,
              child: SabzehSvg(size: 16)
                  .animate(onPlay: (controller) => controller.repeat())
                  .shake(
                    duration: const Duration(seconds: 4),
                    rotation: 0.05,
                    hz: 0.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
