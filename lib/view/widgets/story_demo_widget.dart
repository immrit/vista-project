import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/publicPostModel.dart';
import '../../model/ProfileModel.dart';
import 'post_image_share_widget.dart';

class StoryDemoWidget extends StatelessWidget {
  const StoryDemoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // ایجاد یک پست نمونه برای تست
    final samplePost = PublicPostModel(
      id: 'demo_post_1',
      userId: 'demo_user_id',
      fullName: 'کاربر نمونه',
      username: 'demo_user',
      content:
          'این یک پست نمونه برای تست قابلیت استوری است. می‌توانید پست را جابجا کنید و تصویر زیبایی با بک‌گراند سفارشی Vista ایجاد کنید.',
      imageUrl: 'https://picsum.photos/400/300',
      avatarUrl: 'https://picsum.photos/100/100',
      likeCount: 42,
      commentCount: 8,
      hashtags: ['vista', 'demo', 'story'],
      createdAt: DateTime.now(),
      isVerified: true,
      verificationType: VerificationType.blueTick,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('تست استوری Vista'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 80.sp,
              color: Colors.blue,
            ),
            SizedBox(height: 20.h),
            Text(
              'قابلیت استوری Vista',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'پست‌ها را با بک‌گراند زیبا و قابل جابجایی به اشتراک بگذارید',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 40.h),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PostImageShareWidget(
                      post: samplePost,
                      onShareComplete: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('استوری با موفقیت به اشتراک گذاشته شد!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('تست استوری'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 30.w,
                  vertical: 15.h,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 40.w),
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15.r),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'ویژگی‌های استوری:',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  _buildFeatureItem('سایز استوری اینستاگرام (9:16)'),
                  _buildFeatureItem('بک‌گراند گرادیانت زیبا'),
                  _buildFeatureItem('لوگو VISTA در مرکز'),
                  _buildFeatureItem('قابلیت جابجایی پست'),
                  _buildFeatureItem('اشتراک‌گذاری به اینستاگرام'),
                  _buildFeatureItem('ذخیره در گالری'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
