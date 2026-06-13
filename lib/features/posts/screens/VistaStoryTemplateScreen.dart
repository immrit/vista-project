import 'package:flutter/material.dart';
import '../../../model/publicPostModel.dart';
import '../../../services/vista_story_template_generator.dart';
import '../../../utils/user_friendly_error_utils.dart';
import 'package:Vista/widgets/vista_story_template_widget.dart';

/// صفحه ویرایش و سفارشی‌سازی قالب استوری Vista
class VistaStoryTemplateScreen extends StatefulWidget {
  final PublicPostModel post;

  const VistaStoryTemplateScreen({
    super.key,
    required this.post,
  });

  @override
  State<VistaStoryTemplateScreen> createState() =>
      _VistaStoryTemplateScreenState();
}

class _VistaStoryTemplateScreenState extends State<VistaStoryTemplateScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final VistaStoryTemplateGenerator _generator = VistaStoryTemplateGenerator();
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('قالب استوری Vista'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // پیش‌نمایش قالب
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 200,
                    height: 355, // نسبت 9:16
                    child: Transform.scale(
                      scale: 0.185, // مقیاس برای نمایش کوچک‌تر در پیش‌نمایش
                      child: RepaintBoundary(
                        key: _repaintBoundaryKey,
                        child: VistaStoryTemplateWidget(
                          post: widget.post,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // دکمه‌های عملیات
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateImage,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                        _isGenerating ? 'در حال تولید...' : 'ذخیره در گالری'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateAndShare,
                    icon: const Icon(Icons.share),
                    label: const Text('اشتراک‌گذاری'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateImage() async {
    setState(() => _isGenerating = true);

    try {
      final imageFile = await _generator.generateStoryTemplate(
        post: widget.post,
        repaintBoundaryKey: _repaintBoundaryKey,
      );

      if (imageFile != null) {
        final saved = await _generator.saveToGallery(imageFile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(saved
                  ? 'تصویر با موفقیت در گالری ذخیره شد'
                  : 'خطا در ذخیره تصویر'),
              backgroundColor: saved ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطا در تولید تصویر'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);

    try {
      final imageFile = await _generator.generateStoryTemplate(
        post: widget.post,
        repaintBoundaryKey: _repaintBoundaryKey,
      );

      if (imageFile != null) {
        await _generator.shareToSocialStory(imageFile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تصویر آماده اشتراک‌گذاری است'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطا در تولید تصویر'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
