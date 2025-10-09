import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

class ImagePreviewBottomSheet extends StatefulWidget {
  final List<File> files;
  final Function(List<File>, String?)? onConfirm;

  const ImagePreviewBottomSheet({
    super.key,
    required this.files,
    this.onConfirm,
  });

  @override
  State<ImagePreviewBottomSheet> createState() =>
      _ImagePreviewBottomSheetState();
}

class _ImagePreviewBottomSheetState extends State<ImagePreviewBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late PageController _pageController;
  late TextEditingController _captionController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _pageController = PageController();
    _captionController = TextEditingController();

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _closeSheet() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _sendImages() {
    final caption = _captionController.text.trim();
    if (widget.onConfirm != null) {
      widget.onConfirm!(widget.files, caption.isEmpty ? null : caption);
    }
    _closeSheet();
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
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 16, bottom: 12),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF4A4A4A)
                            : const Color(0xFFD0D0D0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            'پیش‌نمایش تصاویر',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const Spacer(),
                          if (widget.files.length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.primaryColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${_currentIndex + 1} / ${widget.files.length}',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: _closeSheet,
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark
                                    ? const Color(0xFF9E9E9E)
                                    : const Color(0xFF6B6B6B),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Image viewer
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentIndex = index;
                              });
                            },
                            itemCount: widget.files.length,
                            itemBuilder: (context, index) {
                              return PhotoView(
                                imageProvider: FileImage(widget.files[index]),
                                minScale: PhotoViewComputedScale.contained,
                                maxScale: PhotoViewComputedScale.covered * 2,
                                backgroundDecoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[900]
                                      : Colors.grey[100],
                                ),
                                loadingBuilder: (context, event) => Center(
                                  child: CircularProgressIndicator(
                                    color: theme.primaryColor,
                                    value: event == null
                                        ? null
                                        : event.cumulativeBytesLoaded /
                                            event.expectedTotalBytes!,
                                  ),
                                ),
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        size: 64,
                                        color: isDark
                                            ? Colors.grey[600]
                                            : Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'خطا در بارگذاری تصویر',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Thumbnail strip (if multiple images)
                    if (widget.files.length > 1)
                      Container(
                        height: 80,
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: widget.files.length,
                          itemBuilder: (context, index) {
                            final isSelected = index == _currentIndex;
                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Container(
                                width: 60,
                                height: 60,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(
                                          color: theme.primaryColor,
                                          width: 2,
                                        )
                                      : Border.all(
                                          color: isDark
                                              ? Colors.grey[700]!
                                              : Colors.grey[300]!,
                                          width: 1,
                                        ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    widget.files[index],
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[200],
                                      child: Icon(
                                        Icons.broken_image,
                                        color: isDark
                                            ? Colors.grey[600]
                                            : Colors.grey[400],
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Caption input
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _captionController,
                        maxLines: 3,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'پیام (اختیاری)',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                    // Send button
                    Container(
                      margin: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _sendImages,
                            icon: const Icon(Icons.send_rounded, size: 22),
                            label: Text(
                              widget.files.length > 1
                                  ? 'ارسال ${widget.files.length} تصویر'
                                  : 'ارسال تصویر',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
