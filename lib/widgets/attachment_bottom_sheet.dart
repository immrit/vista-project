import '../../security/logging_utility.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'media_picker_bottom_sheet.dart';
import 'image_preview_bottom_sheet.dart';

class AttachmentBottomSheet extends StatefulWidget {
  final Function(File) onImageSelected;
  final Function(List<File>) onImagesSelected;
  final Function(File) onFileSelected;
  final VoidCallback onCameraSelected;
  final BuildContext parentContext;

  const AttachmentBottomSheet({
    super.key,
    required this.onImageSelected,
    required this.onImagesSelected,
    required this.onFileSelected,
    required this.onCameraSelected,
    required this.parentContext,
  });

  @override
  State<AttachmentBottomSheet> createState() => _AttachmentBottomSheetState();
}

class _AttachmentBottomSheetState extends State<AttachmentBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeSheet() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _selectFromGallery() {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.parentContext.mounted) {
        showModalBottomSheet(
          context: widget.parentContext,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          isDismissible: true,
          enableDrag: true,
          builder: (context) => MediaPickerBottomSheet(
            onImageSelected: (file) {
              widget.onImagesSelected([file]);
            },
            onImagesSelected: widget.onImagesSelected,
          ),
        );
      }
    });
  }

  void _selectFromCamera() async {
    Navigator.of(context).pop();
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.parentContext.mounted) {
            showModalBottomSheet(
              context: widget.parentContext,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => ImagePreviewBottomSheet(
                files: [File(image.path)],
                onConfirm: (confirmedFiles, caption) {
                  if (confirmedFiles.isNotEmpty) {
                    widget.onImagesSelected(confirmedFiles);
                  }
                },
              ),
            );
          }
        });
      }
    } catch (e) {
      logDebug('Error picking image from camera: $e');
    }
  }

  void _selectFile() async {
    Navigator.of(context).pop();
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        // بررسی پسوند فایل
        final fileName = result.files.single.name.toLowerCase();
        if (!fileName.endsWith('.pdf')) {
          _showErrorDialog('فقط فایل‌های PDF پشتیبانی می‌شوند');
          return;
        }

        final fileSize = await file.length();

        // Check file size limit (5MB)
        if (fileSize > 5 * 1024 * 1024) {
          _showErrorDialog('حجم فایل PDF باید کمتر از ۵ مگابایت باشد');
          return;
        }

        // حداقل حجم فایل برای جلوگیری از فایل‌های خالی
        if (fileSize < 1024) {
          _showErrorDialog('فایل PDF باید حداقل ۱ کیلوبایت حجم داشته باشد');
          return;
        }

        widget.onFileSelected(file);
      }
    } catch (e) {
      _showErrorDialog('خطا در انتخاب فایل PDF');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطا'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF48484A)
                            : const Color(0xFFC7C7CC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Title
                    Text(
                      'انتخاب ضمیمه',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Options
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSquareOption(
                              icon: Icons.photo_library_outlined,
                              title: 'گالری',
                              color: const Color(0xFF4CAF50),
                              onTap: _selectFromGallery,
                            ),
                            _buildSquareOption(
                              icon: Icons.camera_alt_outlined,
                              title: 'دوربین',
                              color: const Color(0xFF2196F3),
                              onTap: _selectFromCamera,
                            ),
                            _buildSquareOption(
                              icon: Icons.picture_as_pdf_rounded,
                              title: 'PDF',
                              color: Colors.red,
                              onTap: _selectFile,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cancel button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _closeSheet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFF2F2F7),
                            foregroundColor:
                                isDark ? Colors.white : Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark
                                    ? const Color(0xFF3A3A3C)
                                    : const Color(0xFFD1D1D6),
                                width: 1,
                              ),
                            ),
                          ),
                          child: const Text(
                            'انصراف',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSquareOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
