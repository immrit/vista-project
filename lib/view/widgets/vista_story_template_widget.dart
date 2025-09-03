import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
        width: 400, // اندازه مناسب برای استوری
        height: 711, // نسبت 9:16
        color: backgroundColor ?? Colors.white,
        child: Stack(
          children: [
            // پس‌زمینه با نوشته VISTA بزرگ
            _buildBackgroundText(),

            // کارت پست در وسط
            Center(
              child: _buildPostCard(),
            ),
          ],
        ),
      ),
    );
  }

  /// ساخت پس‌زمینه با نوشته VISTA
  Widget _buildBackgroundText() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (backgroundColor ?? Colors.white).withOpacity(0.95),
              (backgroundColor ?? Colors.white).withOpacity(0.98),
            ],
          ),
        ),
        child: Stack(
          children: [
            // متن بالا - VISTA (پشت کادر پست)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Text(
                'VISTA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 110,
                  fontWeight: FontWeight.w900,
                  color: (textColor ?? Colors.black).withOpacity(0.07),
                  letterSpacing: 7,
                  fontFamily: 'Arial',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ساخت کارت پست
  Widget _buildPostCard() {
    return Container(
      width: 350, // اندازه بزرگ‌تر برای بهتر دیده شدن
      margin: const EdgeInsets.symmetric(horizontal: 10),
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
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
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
      padding: const EdgeInsets.all(10),
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
                width: 1,
              ),
            ),
            child: CircleAvatar(
              radius: 12,
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
                        fontSize: 10,
                      ),
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 6),

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
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    ),
                    if (post.isVerified) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: _getVerificationColor(post.verificationType),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.verified,
                          size: 8,
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
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'lib/view/util/images/logo/black-logo.png',
              width: 16,
              height: 16,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.more_horiz,
                  color: Colors.grey[600],
                  size: 12,
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
          fontSize: 9,
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
      height: 140, // بزرگ‌تر برای بهتر دیده شدن
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                size: 30,
                color: Colors.grey,
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
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
                    size: 12,
                    color: post.isLiked ? Colors.red : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(post.likeCount),
                    style: TextStyle(
                      fontSize: 8,
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
                    width: 10,
                    height: 10,
                    color: Colors.grey[600],
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.chat_bubble_outline,
                        size: 12,
                        color: Colors.grey[600],
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(post.commentCount),
                    style: TextStyle(
                      fontSize: 8,
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
                  fontSize: 8,
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
                    fontSize: 8,
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
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return persianRegex.hasMatch(text);
  }
}
