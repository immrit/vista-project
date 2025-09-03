import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../../model/publicPostModel.dart';
import '../../services/post_image_generator.dart';
import 'post_image_widget.dart';

class PostImageShareWidget extends StatefulWidget {
  final PublicPostModel post;
  final VoidCallback? onShareComplete;

  const PostImageShareWidget({
    super.key,
    required this.post,
    this.onShareComplete,
  });

  @override
  State<PostImageShareWidget> createState() => _PostImageShareWidgetState();
}

class _PostImageShareWidgetState extends State<PostImageShareWidget> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isGenerating = false;
  File? _generatedImage;

  @override
  void dispose() {
    // پاک کردن فایل‌های موقت هنگام خروج
    PostImageGenerator().cleanupTempFiles();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'اشتراک‌گذاری تصویر پست',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (!_isGenerating)
            TextButton(
              onPressed: _generateAndShowOptions,
              child: Text(
                'بعدی',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // پیش‌نمایش تصویر پست
          Expanded(
            child: Center(
              child: Container(
                margin: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: RepaintBoundary(
                    key: _repaintBoundaryKey,
                    child: PostImageWidget(
                      post: widget.post,
                      size:
                          Size(750.w, 1334.h), // اندازه بزرگتر برای کیفیت بهتر
                    ),
                  ),
                ),
              ),
            ),
          ),

          // وضعیت تولید تصویر
          if (_isGenerating)
            Container(
              padding: EdgeInsets.all(16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LoadingAnimationWidget.staggeredDotsWave(
                    color: Colors.blue,
                    size: 30.sp,
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'در حال تولید تصویر...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),

          // گزینه‌های اشتراک‌گذاری
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'انتخاب پلاتفرم اشتراک‌گذاری',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareButton(
                      icon: Icons.camera_alt,
                      label: 'اینستاگرام\nاستوری',
                      color: Colors.purple,
                      onTap: () => _shareToInstagramStory(),
                    ),
                    _buildShareButton(
                      icon: Icons.chat,
                      label: 'واتساپ',
                      color: Colors.green,
                      onTap: () => _shareToWhatsApp(),
                    ),
                    _buildShareButton(
                      icon: Icons.share,
                      label: 'سایر\nاپ‌ها',
                      color: Colors.blue,
                      onTap: () => _shareToOtherApps(),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // دکمه‌های تست
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showImagePreview(),
                            icon: Icon(Icons.preview, size: 18.sp),
                            label: Text(
                              'پیش‌نمایش تصویر',
                              style: TextStyle(fontSize: 12.sp),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _saveImageToGallery(),
                            icon: Icon(Icons.save_alt, size: 18.sp),
                            label: Text(
                              'ذخیره در گالری',
                              style: TextStyle(fontSize: 12.sp),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    ElevatedButton.icon(
                      onPressed: () => _saveImageToDocuments(),
                      icon: Icon(Icons.folder, size: 18.sp),
                      label: Text(
                        'ذخیره در Documents (برای بررسی فایل)',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  'تصویر پست شما آماده اشتراک‌گذاری است',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isGenerating ? null : onTap,
      child: Column(
        children: [
          Container(
            width: 60.w,
            height: 60.h,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: color.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _generateImage() async {
    if (_generatedImage != null) return;

    setState(() => _isGenerating = true);

    try {
      final PostImageGenerator generator = PostImageGenerator();
      _generatedImage = await generator.generatePostImage(
        widget.post,
        _repaintBoundaryKey,
      );

      if (_generatedImage == null) {
        throw Exception('Failed to generate image');
      }

      // تغییر اندازه تصویر برای اشتراک‌گذاری بهتر
      _generatedImage = await generator.resizeImageForSharing(
        _generatedImage!,
        maxWidth: 1080,
        maxHeight: 1920,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در تولید تصویر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _generateAndShowOptions() async {
    await _generateImage();
    // گزینه‌ها از قبل نمایش داده شده‌اند
  }

  Future<void> _shareToInstagram() async {
    await _generateImage();

    if (_generatedImage == null) return;

    try {
      final PostImageGenerator generator = PostImageGenerator();
      await generator.shareToInstagramStory(_generatedImage!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تصویر به اینستاگرام ارسال شد'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onShareComplete?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareToWhatsApp() async {
    await _generateImage();

    if (_generatedImage == null) return;

    try {
      final PostImageGenerator generator = PostImageGenerator();
      await generator.shareToWhatsApp(
        _generatedImage!,
        text: 'پست جدید از Vista\n@${widget.post.username}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تصویر به واتساپ ارسال شد'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onShareComplete?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareToOtherApps() async {
    await _generateImage();

    if (_generatedImage == null) return;

    try {
      final PostImageGenerator generator = PostImageGenerator();
      await generator.shareToOtherApps(
        _generatedImage!,
        text: 'پست جدید از Vista\n@${widget.post.username}',
      );

      if (mounted) {
        widget.onShareComplete?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareToInstagramStory() async {
    await _generateImage();

    if (_generatedImage == null) return;

    try {
      final PostImageGenerator generator = PostImageGenerator();
      await generator.shareToInstagramStory(_generatedImage!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تصویر به اینستاگرام ارسال شد'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onShareComplete?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showImagePreview() async {
    await _generateImage();

    if (_generatedImage == null) return;

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.black,
                title: Text(
                  'پیش‌نمایش تصویر پست',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.save, color: Colors.white),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _saveImageToGallery();
                    },
                    tooltip: 'ذخیره در گالری',
                  ),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  child: Image.file(
                    _generatedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16.w),
                color: Colors.grey[900],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _saveImageToGallery();
                      },
                      icon: Icon(Icons.save_alt, size: 18.sp),
                      label: Text('ذخیره', style: TextStyle(fontSize: 14.sp)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _shareToInstagram();
                      },
                      icon: Icon(Icons.camera_alt, size: 18.sp),
                      label:
                          Text('اینستاگرام', style: TextStyle(fontSize: 14.sp)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _shareToWhatsApp();
                      },
                      icon: Icon(Icons.chat, size: 18.sp),
                      label: Text('واتساپ', style: TextStyle(fontSize: 14.sp)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _saveImageToGallery() async {
    // استفاده از قالب استوری برای ذخیره
    await _saveStoryToGallery();
  }

  Future<void> _saveStoryToGallery() async {
    // تولید و ذخیره مستقیم تصویر استوری
    await _generateImage();

    if (_generatedImage == null) return;

    try {
      // درخواست مجوز دسترسی به گالری
      final bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final bool granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception('دسترسی به گالری رد شد');
        }
      }

      // ذخیره تصویر در گالری
      await Gal.putImage(_generatedImage!.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تصویر استوری در گالری ذخیره شد ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ذخیره تصویر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveImageToDocuments() async {
    await _generateImage();

    if (_generatedImage == null) return;

    try {
      // گرفتن مسیر Documents
      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'vista_post_${widget.post.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final File documentsFile = File('${documentsDir.path}/$fileName');

      // کپی کردن فایل به Documents
      await _generatedImage!.copy(documentsFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تصویر در Documents ذخیره شد ✅'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // نمایش مسیر فایل
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('مسیر: ${documentsFile.path}'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 8),
            action: SnackBarAction(
              label: 'کپی مسیر',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: documentsFile.path));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('مسیر کپی شد'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ),
        );

        // نمایش dialog با جزئیات بیشتر
        final int fileSize = (await documentsFile.length() / 1024).round();

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('✅ تصویر ذخیره شد'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📁 مسیر فایل:'),
                  SelectableText(
                    documentsFile.path,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.sp,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text('📏 اندازه فایل: $fileSize KB'),
                  SizedBox(height: 8.h),
                  Text('🔍 برای مشاهده فایل می‌توانید:'),
                  Text('• از File Manager دستگاه استفاده کنید'),
                  Text('• مسیر بالا را کپی کرده و در Explorer وارد کنید'),
                  Text('• از ADB استفاده کنید:'),
                  SelectableText(
                    'adb pull "${documentsFile.path}" .',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.sp,
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('باشه'),
                ),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: documentsFile.path));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('مسیر کپی شد')),
                    );
                  },
                  child: const Text('کپی مسیر'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ذخیره تصویر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
