import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../model/publicPostModel.dart';

class PostImageWidget extends StatelessWidget {
  final PublicPostModel post;
  final Size? size;
  final bool showLogo;

  const PostImageWidget({
    super.key,
    required this.post,
    this.size,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    // اندازه بزرگتری برای کیفیت بهتر
    final Size containerSize =
        size ?? Size(750.w, 1334.h); // اندازه دو برابر برای کیفیت بهتر

    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Container(
      width: containerSize.width,
      height: containerSize.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  Colors.grey[900]!,
                  Colors.grey[800]!,
                ]
              : [
                  Colors.white,
                  Colors.grey[50]!,
                ],
        ),
      ),
      child: Column(
        children: [
          // هدر شبیه به اپ
          _buildHeader(context),
          // محتوای پست
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w), // padding بزرگتر
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اطلاعات کاربر
                  _buildUserInfo(context),
                  SizedBox(height: 16.h), // فاصله بیشتر
                  // محتوای متنی پست
                  if (post.content.isNotEmpty) ...[
                    _buildPostContent(context),
                    SizedBox(height: 16.h),
                  ],
                  // تصویر پست - نمایش بهبود یافته
                  if (post.hasImage) ...[
                    _buildPostImage(context),
                    SizedBox(height: 16.h),
                  ],
                  // اطلاعات اضافی
                  _buildPostMetadata(context),
                ],
              ),
            ),
          ),
          // فوتر با لوگو
          if (showLogo) _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        border: Border(
          bottom: BorderSide(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
              width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Vista',
            style: TextStyle(
              fontFamily: 'Bauhaus',
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          // استفاده از لوگوی برنامه بر اساس تم
          Image.asset(
            isDarkMode
                ? 'lib/view/util/images/logo/logo-white.png'
                : 'lib/view/util/images/logo/black-logo.png',
            width: 32.w,
            height: 32.h,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading logo: $error');
              // اگر لوگو لود نشد، از آیکون share استفاده کن
              return Icon(
                Icons.share,
                size: 24.sp,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Row(
      children: [
        // آواتار کاربر - اندازه بزرگتر
        CircleAvatar(
          radius: 28.r,
          backgroundImage: post.avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(
                  post.avatarUrl,
                  maxWidth: 112, // اندازه بزرگتر برای کیفیت بهتر
                  maxHeight: 112,
                )
              : const AssetImage('lib/view/util/images/default-avatar.jpg')
                  as ImageProvider,
          backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
        ),
        SizedBox(width: 16.w),
        // اطلاعات کاربر
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    post.username,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  // نشان تأیید - اندازه بزرگتر
                  if (post.hasBlueBadge)
                    Icon(Icons.verified, color: Colors.blue, size: 18.sp)
                  else if (post.hasGoldBadge)
                    Icon(Icons.verified, color: Colors.amber, size: 18.sp)
                  else if (post.hasBlackBadge)
                    Container(
                      padding: EdgeInsets.all(1.w),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white24 : Colors.white60,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified,
                          color: isDarkMode ? Colors.white : Colors.black,
                          size: 16.sp),
                    ),
                ],
              ),
              Text(
                _formatDate(post.createdAt),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostContent(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Directionality(
      textDirection: _getTextDirection(post.content),
      child: Text(
        post.content,
        style: TextStyle(
          fontSize: 18.sp, // اندازه بزرگتر برای خوانایی بهتر
          color: isDarkMode ? Colors.white70 : Colors.black87,
          height: 1.5, // فاصله خطوط بهتر
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.start,
      ),
    );
  }

  Widget _buildPostImage(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: CachedNetworkImage(
          imageUrl: post.imageUrl!,
          placeholder: (context, url) {
            final brightness = Theme.of(context).brightness;
            final isDarkMode = brightness == Brightness.dark;

            return Container(
              height: 300.h, // ارتفاع بزرگتر برای تصویر پست
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            );
          },
          errorWidget: (context, url, error) {
            final brightness = Theme.of(context).brightness;
            final isDarkMode = brightness == Brightness.dark;

            return Container(
              height: 300.h,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      size: 48.sp),
                  SizedBox(height: 8.h),
                  Text(
                    'تصویر بارگذاری نشد',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            );
          },
          fit: BoxFit.cover,
          width: double.infinity,
          height: 300.h, // ارتفاع ثابت برای کیفیت بهتر
          memCacheWidth: 800, // کش با کیفیت بالاتر
          memCacheHeight: 600,
        ),
      ),
    );
  }

  Widget _buildPostMetadata(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1),
      ),
      child: Row(
        children: [
          // تعداد لایک
          Row(
            children: [
              Icon(Icons.favorite, color: Colors.red, size: 18.sp),
              SizedBox(width: 6.w),
              Text(
                post.likeCount.toString(),
                style: TextStyle(
                  fontSize: 16.sp,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(width: 20.w),
          // تعداد کامنت
          Row(
            children: [
              Icon(Icons.comment,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  size: 18.sp),
              SizedBox(width: 6.w),
              Text(
                post.commentCount.toString(),
                style: TextStyle(
                  fontSize: 16.sp,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (post.hashtags.isNotEmpty) ...[
            SizedBox(width: 20.w),
            // تعداد هشتگ
            Row(
              children: [
                Icon(Icons.tag, color: Colors.blue, size: 18.sp),
                SizedBox(width: 6.w),
                Text(
                  post.hashtags.length.toString(),
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
              width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // لوگوی برنامه در فوتر بر اساس تم
          Image.asset(
            isDarkMode
                ? 'lib/view/util/images/logo/logo-white.png'
                : 'lib/view/util/images/logo/black-logo.png',
            width: 24.w,
            height: 24.h,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading footer logo: $error');
              return Icon(
                Icons.app_shortcut,
                size: 20.sp,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              );
            },
          ),
          SizedBox(width: 8.w),
          Text(
            'Vista - coffevista.ir',
            style: TextStyle(
              fontSize: 14.sp,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final Jalali jalaliDate = Jalali.fromDateTime(dateTime);
    return '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';
  }

  TextDirection _getTextDirection(String text) {
    final persianRegex = RegExp(r'[\u0600-\u06FF]');
    final englishRegex = RegExp(r'[a-zA-Z]');

    final persianCount = persianRegex.allMatches(text).length;
    final englishCount = englishRegex.allMatches(text).length;

    return persianCount > englishCount ? TextDirection.rtl : TextDirection.ltr;
  }
}
