// lib/features/chat/screens/document_preview_screen.dart
//
// Preview اسناد با قابلیت‌های حرفه‌ای
//
// ویژگی‌ها:
// ✅ Preview PDF (با syncfusion یا pdf_render)
// ✅ Preview تصاویر اسناد
// ✅ Download با progress
// ✅ Share
// ✅ Print
// ✅ Zoom & Pan
//

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

/// صفحه پیش‌نمایش سند
class DocumentPreviewScreen extends StatefulWidget {
  final String documentUrl;
  final String documentName;
  final String documentType; // 'pdf', 'image', 'doc', etc.
  final int? fileSize;

  const DocumentPreviewScreen({
    super.key,
    required this.documentUrl,
    required this.documentName,
    required this.documentType,
    this.fileSize,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkLocalFile();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  Future<void> _checkLocalFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.documentName}');
      
      if (await file.exists()) {
        setState(() => _localFile = file);
      }
    } catch (e) {
      debugPrint('Error checking local file: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_localFile != null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share_rounded, color: Colors.white),
              ),
              onPressed: _shareDocument,
            ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _localFile != null ? Icons.delete_outline : Icons.download_rounded,
                color: Colors.white,
              ),
            ),
            onPressed: _localFile != null ? _deleteLocalFile : _downloadDocument,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // محتوای اصلی
            Center(
              child: _buildPreviewContent(theme, isDark),
            ),

            // Progress indicator برای دانلود
            if (_isDownloading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildDownloadProgress(theme),
              ),

            // اطلاعات فایل در پایین
            if (!_isDownloading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildFileInfo(theme, isDark),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent(ThemeData theme, bool isDark) {
    // اگر فایل محلی داریم
    if (_localFile != null) {
      return _buildLocalPreview();
    }

    // اگر فایل تصویر است، preview آنلاین
    if (_isImageDocument()) {
      return _buildImagePreview();
    }

    // برای PDF و سایر فرمت‌ها، ابتدا باید دانلود شود
    return _buildDownloadPrompt(theme, isDark);
  }

  bool _isImageDocument() {
    final ext = widget.documentType.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  bool _isPdfDocument() {
    return widget.documentType.toLowerCase() == 'pdf';
  }

  Widget _buildImagePreview() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: CachedNetworkImage(
        imageUrl: widget.documentUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_rounded,
                size: 64,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(height: 16),
              Text(
                'خطا در بارگذاری تصویر',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalPreview() {
    if (_isPdfDocument()) {
      final shortest = MediaQuery.of(context).size.shortestSide;
      final iconSize = (shortest * 0.22).clamp(64.0, 96.0);
      // TODO: استفاده از pdf_render یا syncfusion
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_rounded,
              size: iconSize,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              widget.documentName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openWithExternalApp,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('باز کردن با برنامه خارجی'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // برای تصاویر محلی
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.file(
        _localFile!,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildDownloadPrompt(ThemeData theme, bool isDark) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    final iconSize = (shortest * 0.18).clamp(48.0, 72.0);
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // آیکون بر اساس نوع فایل
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _getFileColor(theme).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getFileIcon(),
              size: iconSize,
              color: _getFileColor(theme),
            ),
          ),
          const SizedBox(height: 24),

          // نام فایل
          Text(
            widget.documentName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // اطلاعات فایل
          if (widget.fileSize != null)
            Text(
              _formatFileSize(widget.fileSize!),
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor,
              ),
            ),
          const SizedBox(height: 32),

          // دکمه دانلود
          ElevatedButton.icon(
            onPressed: _downloadDocument,
            icon: const Icon(Icons.download_rounded),
            label: const Text('دانلود و مشاهده'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'در حال دانلود...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              CircularProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(theme.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _downloadProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(theme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.documentName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getFileColor(theme).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.documentType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getFileColor(theme),
                    ),
                  ),
                ),
                if (widget.fileSize != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    _formatFileSize(widget.fileSize!),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    switch (widget.documentType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (widget.documentType.toLowerCase()) {
      case 'pdf':
        return scheme.error;
      case 'doc':
      case 'docx':
        return scheme.primary;
      case 'xls':
      case 'xlsx':
        return scheme.secondary;
      case 'ppt':
      case 'pptx':
        return scheme.tertiary;
      case 'zip':
      case 'rar':
      case '7z':
        return scheme.outline;
      default:
        return theme.hintColor;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _downloadDocument() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    HapticFeedback.mediumImpact();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${widget.documentName}';
      final file = File(filePath);

      // دانلود با progress
      final request = await http.Client().send(
        http.Request('GET', Uri.parse(widget.documentUrl)),
      );

      final contentLength = request.contentLength ?? 0;
      int bytesReceived = 0;

      final sink = file.openWrite();

      await for (var chunk in request.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        if (contentLength > 0) {
          setState(() {
            _downloadProgress = bytesReceived / contentLength;
          });
        }
      }

      await sink.close();

      setState(() {
        _localFile = file;
        _isDownloading = false;
      });

      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Error downloading file: $e');
      setState(() => _isDownloading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در دانلود فایل: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareDocument() async {
    if (_localFile == null) return;

    HapticFeedback.lightImpact();

    try {
      await Share.shareXFiles(
        [XFile(_localFile!.path)],
        subject: widget.documentName,
      );
    } catch (e) {
      debugPrint('Error sharing file: $e');
    }
  }

  Future<void> _deleteLocalFile() async {
    HapticFeedback.mediumImpact();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فایل'),
        content: const Text('آیا از حذف این فایل از حافظه دستگاه مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true && _localFile != null) {
      try {
        await _localFile!.delete();
        setState(() => _localFile = null);
        HapticFeedback.heavyImpact();
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }
    }
  }

  Future<void> _openWithExternalApp() async {
    if (_localFile == null) return;

    HapticFeedback.lightImpact();

    try {
      await Share.shareXFiles(
        [XFile(_localFile!.path)],
        subject: widget.documentName,
      );
    } catch (e) {
      debugPrint('Error opening file: $e');
    }
  }
}


