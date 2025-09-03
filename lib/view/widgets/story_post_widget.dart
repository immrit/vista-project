import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../model/publicPostModel.dart';
import '../../model/ProfileModel.dart';

class StoryPostWidget extends StatelessWidget {
  final PublicPostModel post;
  final Size? size;
  final bool showBackground;

  const StoryPostWidget({
    super.key,
    required this.post,
    this.size,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    // سایز استوری اینستاگرام (9:16)
    final Size storySize = size ?? Size(1080.w, 1920.h);

    return Container(
      width: storySize.width,
      height: storySize.height,
      child: Stack(
        children: [
          // بک‌گراند سفارشی
          if (showBackground) _buildCustomBackground(context, storySize),

          // هدر ثابت با لوگو و متن VISTA
          _buildFixedHeader(context),

          // پست اصلی در موقعیت ثابت
          Positioned(
            left: 50.w,
            top: 200.h,
            child: _buildPostCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedHeader(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Positioned(
      top: 40.h,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
              width: 1,
            ),
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
            // متن VISTA با فونت اپ
            Text(
              'VISTA',
              style: TextStyle(
                fontFamily: 'Bauhaus',
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            // لوگوی برنامه بر اساس تم
            Image.asset(
              isDarkMode
                  ? 'lib/view/util/images/logo/logo-white.png'
                  : 'lib/view/util/images/logo/black-logo.png',
              width: 32.w,
              height: 32.h,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading logo: $error');
                return Icon(
                  Icons.share,
                  size: 24.sp,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBackground(BuildContext context, Size size) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: Colors.white, // پس‌زمینه سفید
      ),
      child: Stack(
        children: [
          // حروف بزرگ در پس‌زمینه
          _buildBackgroundText(size),

          // لوگو VISTA در مرکز
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // لوگوی اصلی
                Container(
                  padding: EdgeInsets.all(40.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Image.asset(
                    isDarkMode
                        ? 'lib/view/util/images/logo/logo-white.png'
                        : 'lib/view/util/images/logo/black-logo.png',
                    width: 120.w,
                    height: 120.h,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.app_shortcut,
                        size: 80.sp,
                        color: Colors.grey.withOpacity(0.8),
                      );
                    },
                  ),
                ),
                SizedBox(height: 30.h),

                // متن VISTA
                Text(
                  'VISTA',
                  style: TextStyle(
                    fontFamily: 'Bauhaus',
                    fontSize: 48.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.withOpacity(0.9),
                    letterSpacing: 8.w,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),

                // زیرنویس
                Text(
                  'coffevista.ir',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.grey.withOpacity(0.7),
                    letterSpacing: 2.w,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundText(Size size) {
    return Stack(
      children: [
        // حرف VISTA در بالا
        Positioned(
          top: size.height * 0.1,
          left: 0,
          right: 0,
          child: Text(
            'VISTA',
            style: TextStyle(
              fontSize: size.height * 0.15, // اندازه بزرگ
              fontWeight: FontWeight.w900,
              color: Colors.grey.withOpacity(0.15), // خیلی محو
              letterSpacing: 20,
              height: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // حرف POST در پایین
        Positioned(
          bottom: size.height * 0.1,
          left: 0,
          right: 0,
          child: Text(
            'POST',
            style: TextStyle(
              fontSize: size.height * 0.15, // اندازه بزرگ
              fontWeight: FontWeight.w900,
              color: Colors.grey.withOpacity(0.15), // خیلی محو
              letterSpacing: 20,
              height: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Container(
      width: 400.w,
      constraints: BoxConstraints(
        maxHeight: 600.h,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // هدر پست
            _buildPostHeader(context),

            // محتوای پست
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اطلاعات کاربر
                    _buildUserInfo(context),
                    SizedBox(height: 12.h),

                    // محتوای متنی
                    if (post.content.isNotEmpty) ...[
                      _buildPostContent(context),
                      SizedBox(height: 12.h),
                    ],

                    // تصویر پست
                    if (post.hasImage) ...[
                      _buildPostImage(context),
                      SizedBox(height: 12.h),
                    ],

                    // متادیتا
                    _buildPostMetadata(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.post_add,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Text(
            'Vista Post',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              'ثابت',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
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
        CircleAvatar(
          radius: 20.r,
          backgroundImage: post.avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(post.avatarUrl)
              : const AssetImage('lib/view/util/images/default-avatar.jpg')
                  as ImageProvider,
          backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    post.username,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  if (post.isVerified)
                    Icon(Icons.verified,
                        color: post.verificationType ==
                                VerificationType.blueTick
                            ? Colors.blue
                            : post.verificationType == VerificationType.goldTick
                                ? Colors.amber
                                : Colors.black,
                        size: 14.sp),
                ],
              ),
              Text(
                _formatDate(post.createdAt),
                style: TextStyle(
                  fontSize: 12.sp,
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
          fontSize: 14.sp,
          color: isDarkMode ? Colors.white70 : Colors.black87,
          height: 1.4,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPostImage(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: CachedNetworkImage(
          imageUrl: post.imageUrl!,
          placeholder: (context, url) => Container(
            height: 150.h,
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 150.h,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          ),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 150.h,
        ),
      ),
    );
  }

  Widget _buildPostMetadata(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetadataItem(
              Icons.favorite, post.likeCount.toString(), Colors.red),
          _buildMetadataItem(Icons.comment, post.commentCount.toString(),
              isDarkMode ? Colors.grey[400]! : Colors.grey[600]!),
          if (post.hashtags.isNotEmpty)
            _buildMetadataItem(
                Icons.tag, post.hashtags.length.toString(), Colors.blue),
        ],
      ),
    );
  }

  Widget _buildMetadataItem(IconData icon, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14.sp),
        SizedBox(width: 4.w),
        Text(
          count,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
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
