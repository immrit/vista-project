// lib/features/chat/widgets/simple_attachment_sheet.dart
//
// منوی تمیز برای انتخاب ضمیمه چت
// شامل فقط 3 گزینه مهم: گالری، دوربین، فایل
// این ورژن ساده‌تر و تمیز‌تر از نسخه قدیم است

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SimpleAttachmentSheet extends StatelessWidget {
  static const Color _galleryLightColor = Color(0xFF7C3AED);
  static const Color _galleryDarkColor = Color(0xFFC4B5FD);
  static const Color _cameraLightColor = Color(0xFF0EA5E9);
  static const Color _cameraDarkColor = Color(0xFF7DD3FC);
  static const Color _fileLightColor = Color(0xFFF97316);
  static const Color _fileDarkColor = Color(0xFFFDBA74);

  /// تابع فراخوانی‌شده هنگام انتخاب گالری
  final VoidCallback onGalleryTap;

  /// تابع فراخوانی‌شده هنگام انتخاب دوربین
  final VoidCallback onCameraTap;

  /// تابع فراخوانی‌شده هنگام انتخاب فایل
  final VoidCallback onFileTap;

  const SimpleAttachmentSheet({
    super.key,
    required this.onGalleryTap,
    required this.onCameraTap,
    required this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final galleryColor = isDark ? _galleryDarkColor : _galleryLightColor;
    final cameraColor = isDark ? _cameraDarkColor : _cameraLightColor;
    final fileColor = isDark ? _fileDarkColor : _fileLightColor;

    return Container(
      padding: EdgeInsets.only(
        top: 20.h,
        left: 16.w,
        right: 16.w,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : const Color(0xFFFCFDFF),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ═══════════════════════════════════════════════════════════
          // هندل کوچک بالای شیت (برای نشان‌دادن درک‌شده‌بودن)
          // ═══════════════════════════════════════════════════════════
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 24.h),

          // ═══════════════════════════════════════════════════════════
          // ردیف آیکون‌های ضمیمه
          // ═══════════════════════════════════════════════════════════
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // گالری
              _buildAttachmentOption(
                context: context,
                icon: Icons.image,
                label: 'گالری',
                color: galleryColor,
                onTap: () {
                  Navigator.pop(context);
                  onGalleryTap();
                },
              ),

              // دوربین
              _buildAttachmentOption(
                context: context,
                icon: Icons.camera_alt,
                label: 'دوربین',
                color: cameraColor,
                onTap: () {
                  Navigator.pop(context);
                  onCameraTap();
                },
              ),

              // فایل
              _buildAttachmentOption(
                context: context,
                icon: Icons.insert_drive_file,
                label: 'فایل',
                color: fileColor,
                onTap: () {
                  Navigator.pop(context);
                  onFileTap();
                },
              ),
            ],
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  /// ساخت یک گزینه ضمیمه
  ///
  /// نمایش:
  /// - آیکون رنگی در دایره
  /// - برچسب متن
  /// - انیمیشن روی فشار
  Widget _buildAttachmentOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // آیکون در باکس رنگی
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: color,
                    size: 28.sp,
                  ),
                ),
              ),
              SizedBox(height: 10.h),

              // برچسب متن
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// نمایش منو در bottom sheet
  ///
  /// استفاده:
  /// ```dart
  /// SimpleAttachmentSheet.show(
  ///   context,
  ///   onGalleryTap: () { ... },
  ///   onCameraTap: () { ... },
  ///   onFileTap: () { ... },
  /// );
  /// ```
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onGalleryTap,
    required VoidCallback onCameraTap,
    required VoidCallback onFileTap,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => SimpleAttachmentSheet(
        onGalleryTap: onGalleryTap,
        onCameraTap: onCameraTap,
        onFileTap: onFileTap,
      ),
    );
  }
}
