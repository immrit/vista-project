import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import '../../model/publicPostModel.dart';
import '../../model/ProfileModel.dart';

/// ویجت قالب استوری Vista
class VistaStoryTemplateWidget extends StatelessWidget {
  final PublicPostModel post;
  final String? customBackgroundText;
  final Color? backgroundColor;
  final Color? textColor;
  final String? customPostText;
  final String? customImageUrl;
  final GlobalKey? repaintBoundaryKey;

  const VistaStoryTemplateWidget({
    Key? key,
    required this.post,
    this.customBackgroundText,
    this.backgroundColor,
    this.textColor,
    this.customPostText,
    this.customImageUrl,
    this.repaintBoundaryKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: Container(
        width: 1080, // ابعاد استاندارد اینستاگرام
        height: 1920, // نسبت 9:16 استاندارد
        color: backgroundColor ?? Colors.white,
        child: Stack(
          children: [
            // پس‌زمینه با نوشته VISTA بزرگ
            _buildBackgroundText(),

            // کارت پست در وسط
            Center(child: _buildPostCard()),
          ],
        ),
      ),
    );
  }

  /// ساخت پس‌زمینه با نوشته VISTA
  Widget _buildBackgroundText() {
    return CustomPaint(
      size: const Size(1080, 1920),
      painter: VistavistaStylePainter(
        textColor: textColor ?? Colors.black,
      ),
    );
  }

  /// ساخت کارت پست
  Widget _buildPostCard() {
    return Container(
      width: 950, // اندازه خیلی بزرگ‌تر
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // هدر پست (پروفایل کاربر)
          _buildPostHeader(),

          // متن پست
          _buildPostContent(),

          // تصویر پست
          _buildPostImage(),

          // فوتر پست (لایک، کامنت، تاریخ)
          _buildPostFooter(),
        ],
      ),
    );
  }

  /// ساخت هدر پست
  Widget _buildPostHeader() {
    return Container(
      padding: const EdgeInsets.all(20), // پدینگ بیشتر
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.02),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // آواتار کاربر
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 2, // ضخامت بیشتر
              ),
            ),
            child: CircleAvatar(
              radius: 50, // اندازه خیلی بزرگ‌تر
              backgroundColor: Colors.grey[300],
              backgroundImage: post.avatarUrl.isNotEmpty
                  ? NetworkImage(post.avatarUrl)
                  : null,
              child: post.avatarUrl.isEmpty
                  ? Text(
                      post.fullName.isNotEmpty
                          ? post.fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 40, // اندازه خیلی بزرگ‌تر
                      ),
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 15), // فاصله بیشتر
          // نام کاربر و تیک تأیید
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      post.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 40, // اندازه خیلی بزرگ‌تر
                        color: Colors.black,
                      ),
                    ),
                    if (post.isVerified) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _getVerificationColor(post.verificationType),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.verified,
                          size: 30, // اندازه خیلی بزرگ‌تر
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // لوگوی برنامه
          Container(
            padding: const EdgeInsets.all(8), // پدینگ بیشتر
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'lib/view/util/images/logo/black-logo.png',
              width: 60, // اندازه خیلی بزرگ‌تر
              height: 60,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.more_horiz,
                  color: Colors.grey[600],
                  size: 45, // اندازه خیلی بزرگ‌تر
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ساخت محتوای پست
  Widget _buildPostContent() {
    final String displayText = customPostText ?? post.content;

    if (displayText.isEmpty) {
      return const SizedBox.shrink();
    }

    // محدود کردن متن برای جلوگیری از overflow
    final String limitedText = displayText.length > 150
        ? '${displayText.substring(0, 150)}...'
        : displayText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        limitedText,
        style: const TextStyle(
          fontSize: 36, // اندازه خیلی بزرگ‌تر
          color: Colors.black,
          height: 1.2,
        ),
        textAlign:
            _isPersianText(limitedText) ? TextAlign.right : TextAlign.left,
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// ساخت تصویر پست
  Widget _buildPostImage() {
    final String imageUrl = customImageUrl ?? post.imageUrl ?? '';

    if (imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: 500, // اندازه خیلی بزرگ‌تر
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(
                Icons.image,
                size: 80, // اندازه بزرگ‌تر
                color: Colors.grey,
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  /// ساخت فوتر پست
  Widget _buildPostFooter() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // آیکون‌های تعامل با تعداد واقعی
          Row(
            children: [
              Row(
                children: [
                  Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 40, // اندازه خیلی بزرگ‌تر
                    color: post.isLiked ? Colors.red : Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatNumber(post.likeCount),
                    style: TextStyle(
                      fontSize: 28, // اندازه خیلی بزرگ‌تر
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Image.asset(
                    'lib/view/util/images/component/comment.png',
                    width: 40, // اندازه خیلی بزرگ‌تر
                    height: 40,
                    color: Colors.grey[600],
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.chat_bubble_outline,
                        size: 40, // اندازه خیلی بزرگ‌تر
                        color: Colors.grey[600],
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatNumber(post.commentCount),
                    style: TextStyle(
                      fontSize: 28, // اندازه خیلی بزرگ‌تر
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                _formatDate(post.createdAt),
                style: TextStyle(
                  fontSize: 28, // اندازه خیلی بزرگ‌تر
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),

          if (post.commentCount > 0) ...[
            const SizedBox(height: 6),
            // لینک مشاهده همه کامنت‌ها
            Row(
              children: [
                Text(
                  'view all ${_formatNumber(post.commentCount)} comments',
                  style: TextStyle(
                    fontSize: 28, // اندازه خیلی بزرگ‌تر
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// فرمت کردن تاریخ
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  /// فرمت کردن اعداد (K, M)
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  /// دریافت رنگ تیک تأیید بر اساس نوع
  Color _getVerificationColor(VerificationType type) {
    switch (type) {
      case VerificationType.blueTick:
        return Colors.blue;
      case VerificationType.goldTick:
        return Colors.amber;
      case VerificationType.blackTick:
        return Colors.black;
      case VerificationType.none:
        return Colors.grey;
    }
  }

  /// تشخیص زبان متن (فارسی یا انگلیسی)
  bool _isPersianText(String text) {
    final persianRegex = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    );
    return persianRegex.hasMatch(text);
  }
}

/// CustomPainter برای ایجاد پس‌زمینه زیبا و ساده
class VistavistaStylePainter extends CustomPainter {
  final Color textColor;

  VistavistaStylePainter({required this.textColor});

  @override
  void paint(Canvas canvas, Size size) {
    // پس‌زمینه سفید
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // رسم سه دایره بزرگ و زیبا
    _drawCircles(canvas, size);
  }

  void _drawCircles(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 120;

    // دایره اول - بالا چپ (نصفش توی صفحه)
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.1),
      size.width * 0.4,
      paint,
    );

    // دایره دوم - وسط راست (نصفش توی صفحه)
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.5),
      size.width * 0.35,
      paint,
    );

    // دایره سوم - پایین چپ (نصفش توی صفحه)
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.9),
      size.width * 0.45,
      paint,
    );

    // رسم متن VISTA روی دایره‌ها
    _drawTextOnCircles(canvas, size);
  }

  void _drawTextOnCircles(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      fontSize: 80,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: 6,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: 'VISTA', style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // متن روی دایره اول
    _drawTextOnCircle(canvas, size.width * 0.1, size.height * 0.1,
        size.width * 0.4, textPainter);

    // متن روی دایره دوم
    _drawTextOnCircle(canvas, size.width * 0.9, size.height * 0.5,
        size.width * 0.35, textPainter);

    // متن روی دایره سوم
    _drawTextOnCircle(canvas, size.width * 0.2, size.height * 0.9,
        size.width * 0.45, textPainter);
  }

  void _drawTextOnCircle(Canvas canvas, double centerX, double centerY,
      double radius, TextPainter textPainter) {
    final circumference = 2 * math.pi * radius;
    final repetitions = (circumference / textPainter.width * 0.8).floor();

    for (int i = 0; i < repetitions; i++) {
      final angle = (i / repetitions) * 2 * math.pi;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + math.pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}
