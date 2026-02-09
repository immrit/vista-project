import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../model/ProfileModel.dart';
import '../../../services/toast_service.dart';
import '../services/upload_policy_service.dart';

enum DocumentType {
  pdf('PDF', '📄'),
  audio('MP3', '🎵'),
  image('Image', '🖼️'),
  other('File', '📎');

  final String displayName;
  final String emoji;

  const DocumentType(this.displayName, this.emoji);
}

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

class DocumentUploadSheet extends StatefulWidget {
  final String? initialCaption;
  final ProfileModel? profile;

  const DocumentUploadSheet({
    super.key,
    this.initialCaption,
    this.profile,
  });

  static Future<DocumentSelectionResult?> show({
    required BuildContext context,
    String? initialCaption,
    ProfileModel? profile,
  }) {
    return showModalBottomSheet<DocumentSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DocumentUploadSheet(
        initialCaption: initialCaption,
        profile: profile,
      ),
    );
  }

  @override
  State<DocumentUploadSheet> createState() => _DocumentUploadSheetState();
}

class _DocumentUploadSheetState extends State<DocumentUploadSheet>
    with SingleTickerProviderStateMixin {
  final _captionController = TextEditingController();
  final UploadPolicyService _uploadPolicy = const UploadPolicyService();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  File? _selectedFile;
  String? _fileName;
  int? _fileSize;
  DocumentType? _fileType;

  int get _maxBytes => _uploadPolicy.maxBytesFor(widget.profile);
  int get _maxMb => _maxBytes ~/ (1024 * 1024);

  @override
  void initState() {
    super.initState();
    if (widget.initialCaption != null) {
      _captionController.text = widget.initialCaption!;
    }
    _animController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  _buildFilePicker(theme, isDark),
                  if (_selectedFile != null) _buildCaption(theme, isDark),
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
        const SizedBox(height: 16),
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.upload_file_rounded, color: theme.primaryColor),
          ),
          title: const Text('ارسال فایل'),
          subtitle: Text('فقط Image / PDF / MP3 تا $_maxMb مگابایت'),
          trailing: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
      ],
    );
  }

  Widget _buildFilePicker(ThemeData theme, bool isDark) {
    if (_selectedFile == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(isDark ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.primaryColor.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, color: theme.primaryColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'انتخاب فایل از دستگاه',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_fileType?.emoji ?? '📎', style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName ?? 'File',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_fileType?.displayName ?? 'File'} • ${_formatBytes(_fileSize ?? 0)}',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
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
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaption(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: TextField(
        controller: _captionController,
        maxLines: 3,
        maxLength: 200,
        decoration: InputDecoration(
          hintText: 'کپشن فایل (اختیاری)...',
          filled: true,
          fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(Icons.edit_note_rounded, color: theme.hintColor),
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    final canSend = _selectedFile != null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: canSend ? _pickFile : null,
              child: const Text('تغییر فایل'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: canSend ? _send : null,
              icon: const Icon(Icons.send_rounded),
              label: Text(canSend ? 'ارسال' : 'انتخاب فایل'),
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
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'pdf', 'mp3'],
      );
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return;
      }

      final file = File(result.files.first.path!);
      final validation = _uploadPolicy.validateFile(
        file: file,
        profile: widget.profile,
        mode: ChatSendMode.file,
      );

      if (!validation.isAllowed) {
        if (!mounted) return;
        ToastService.showErrorToast(
          context,
          validation.error ?? 'فایل مجاز نیست',
        );
        return;
      }

      final fileName = result.files.first.name;
      final fileSize = await file.length();
      final type = _typeFromAttachment(validation.attachmentType);

      setState(() {
        _selectedFile = file;
        _fileName = fileName;
        _fileSize = fileSize;
        _fileType = type;
      });
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (!mounted) return;
      ToastService.showErrorToast(context, 'خطا در انتخاب فایل');
    }
  }

  DocumentType _typeFromAttachment(String? attachmentType) {
    switch (attachmentType) {
      case 'image':
        return DocumentType.image;
      case 'pdf':
        return DocumentType.pdf;
      case 'mp3':
        return DocumentType.audio;
      default:
        return DocumentType.other;
    }
  }

  void _send() {
    final file = _selectedFile;
    if (file == null) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      DocumentSelectionResult(
        file: file,
        caption: _captionController.text.trim(),
        type: _fileType ?? DocumentType.other,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
