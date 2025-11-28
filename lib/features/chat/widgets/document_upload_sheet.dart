// lib/features/chat/widgets/document_upload_sheet.dart
//
// Bottom Sheet برای آپلود اسناد و فایل‌ها
//
// ویژگی‌ها:
// ✅ انتخاب فایل با UI زیبا
// ✅ پیش‌نمایش فایل
// ✅ Progress indicator
// ✅ کپشن برای فایل
// ✅ انیمیشن‌های روان
//

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/document_handler_service.dart';
import '../../../services/toast_service.dart';

/// نتیجه انتخاب فایل
class DocumentSelectionResult {
  final File file;
  final String caption;
  final DocumentType type;

  const DocumentSelectionResult({
    required this.file,
    required this.caption,
    required this.type,
  });
}

/// Bottom Sheet برای آپلود سند
class DocumentUploadSheet extends StatefulWidget {
  final String? initialCaption;

  const DocumentUploadSheet({
    super.key,
    this.initialCaption,
  });

  /// نمایش Bottom Sheet
  static Future<DocumentSelectionResult?> show({
    required BuildContext context,
    String? initialCaption,
  }) {
    return showModalBottomSheet<DocumentSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DocumentUploadSheet(
        initialCaption: initialCaption,
      ),
    );
  }

  @override
  State<DocumentUploadSheet> createState() => _DocumentUploadSheetState();
}

class _DocumentUploadSheetState extends State<DocumentUploadSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _captionController = TextEditingController();
  final _documentService = DocumentHandlerService();

  File? _selectedFile;
  String? _fileName;
  int? _fileSize;
  DocumentType? _fileType;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCaption != null) {
      _captionController.text = widget.initialCaption!;
    }
    _setupAnimations();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(theme),
                  if (_selectedFile == null)
                    _buildFileSelector(theme, isDark)
                  else
                    _buildFilePreview(theme, isDark),
                  if (_selectedFile != null) _buildCaptionInput(theme, isDark),
                  _buildActions(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  color: theme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'آپلود فایل',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedFile == null
                          ? 'انتخاب فایل از دستگاه'
                          : 'فایل آماده ارسال',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: theme.hintColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: theme.dividerColor),
      ],
    );
  }

  Widget _buildFileSelector(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // انتخاب از دستگاه
          _buildFileSelectorButton(
            theme: theme,
            isDark: isDark,
            icon: Icons.insert_drive_file_rounded,
            title: 'انتخاب از دستگاه',
            subtitle: 'PDF, Word, Excel, و سایر فایل‌ها',
            color: Colors.blue,
            onTap: _pickFile,
          ),
          const SizedBox(height: 12),
          // محدودیت‌ها
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'حداکثر حجم: 100 مگابایت',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelectorButton({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.hintColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // آیکون فایل
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getFileColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _fileType?.emoji ?? '📎',
                style: const TextStyle(fontSize: 32),
              ),
            ),
            const SizedBox(width: 16),
            // اطلاعات فایل
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName ?? 'فایل',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getFileColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _fileType?.displayName ?? 'File',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getFileColor(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _documentService.getFormattedSize(_fileSize ?? 0),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // دکمه حذف
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedFile = null;
                  _fileName = null;
                  _fileSize = null;
                  _fileType = null;
                });
              },
              icon: Icon(
                Icons.close_rounded,
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionInput(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: TextField(
        controller: _captionController,
        maxLines: 3,
        maxLength: 200,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: 'کپشن فایل (اختیاری)...',
          filled: true,
          fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.dividerColor.withOpacity(0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.primaryColor,
              width: 2,
            ),
          ),
          prefixIcon: Icon(
            Icons.edit_note_rounded,
            color: theme.hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_selectedFile != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedFile = null;
                          _fileName = null;
                          _fileSize = null;
                          _fileType = null;
                        });
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('تغییر فایل'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _selectedFile == null || _isLoading
                  ? null
                  : _handleSend,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _selectedFile == null ? 'انتخاب فایل' : 'ارسال',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      HapticFeedback.lightImpact();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final fileName = result.files.first.name;
      final fileSize = await file.length();

      // بررسی حجم
      if (fileSize > DocumentHandlerService.maxFileSizeInBytes) {
        if (!mounted) return;
        ToastService.showErrorToast(
          context,
          'حجم فایل بیش از ${DocumentHandlerService.maxFileSizeInMB} مگابایت است',
        );
        return;
      }

      // تشخیص نوع
      final extension = fileName.split('.').last;
      final fileType = DocumentType.fromExtension(extension);

      setState(() {
        _selectedFile = file;
        _fileName = fileName;
        _fileSize = fileSize;
        _fileType = fileType;
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      ToastService.showErrorToast(context, 'خطا در انتخاب فایل');
    }
  }

  void _handleSend() {
    if (_selectedFile == null) return;

    HapticFeedback.mediumImpact();

    Navigator.pop(
      context,
      DocumentSelectionResult(
        file: _selectedFile!,
        caption: _captionController.text.trim(),
        type: _fileType ?? DocumentType.other,
      ),
    );
  }

  Color _getFileColor() {
    switch (_fileType) {
      case DocumentType.pdf:
        return Colors.red;
      case DocumentType.word:
        return Colors.blue;
      case DocumentType.excel:
        return Colors.green;
      case DocumentType.powerpoint:
        return Colors.orange;
      case DocumentType.image:
        return Colors.purple;
      case DocumentType.video:
        return Colors.pink;
      case DocumentType.audio:
        return Colors.teal;
      case DocumentType.archive:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
