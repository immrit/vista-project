import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../model/ProfileModel.dart';
import '../../../services/toast_service.dart';
import '../../../utils/directional_navigation.dart';
import '../services/upload_policy_service.dart';

enum DocumentType {
  pdf('PDF', '📄'),
  audio('Audio', '🎵'),
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
  final String displayFileName;
  final String? mimeType;
  final int? sizeBytes;
  final String? audioTitle;
  final String? audioArtist;
  final String? audioAlbum;

  const DocumentSelectionResult({
    required this.file,
    required this.caption,
    required this.type,
    required this.displayFileName,
    this.mimeType,
    this.sizeBytes,
    this.audioTitle,
    this.audioArtist,
    this.audioAlbum,
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
  static const Color _lightAccent = Color(0xFF0F6CBD);
  static const Color _lightSheetBackground = Color(0xFFFCFDFF);
  static const Color _lightSurface = Color(0xFFF3F7FD);

  final _captionController = TextEditingController();
  final UploadPolicyService _uploadPolicy = const UploadPolicyService();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  File? _selectedFile;
  String? _fileName;
  int? _fileSize;
  String? _mimeType;
  DocumentType? _fileType;

  int? get _maxBytes => _uploadPolicy.maxBytesFor(widget.profile);
  String get _limitLabel {
    final maxBytes = _maxBytes;
    if (maxBytes == null) return 'بدون محدودیت حجم';
    return 'تا ${maxBytes ~/ (1024 * 1024)} مگابایت';
  }

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
    final accentColor = _accentColor(theme, isDark);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : _lightSheetBackground,
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
                  _buildHeader(theme, isDark, accentColor),
                  _buildFilePicker(theme, isDark, accentColor),
                  if (_selectedFile != null)
                    _buildCaption(theme, isDark, accentColor),
                  _buildActions(theme, isDark, accentColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark, Color accentColor) {
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
              color: accentColor.withValues(alpha: isDark ? 0.2 : 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.upload_file_rounded, color: accentColor),
          ),
          title: const Text('ارسال فایل'),
          subtitle: Text('Image / PDF / Audio $_limitLabel'),
          trailing: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: theme.iconTheme.color),
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
      ],
    );
  }

  Widget _buildFilePicker(ThemeData theme, bool isDark, Color accentColor) {
    if (_selectedFile == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.16 : 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, color: accentColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'انتخاب فایل از دستگاه',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(directionalForwardChevronIcon(context),
                    color: accentColor),
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
          color: isDark ? const Color(0xFF2A2A2A) : _lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.2 : 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_fileType?.emoji ?? '📎',
                  style: const TextStyle(fontSize: 26)),
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
                  _mimeType = null;
                  _fileType = null;
                });
              },
              icon: Icon(Icons.close_rounded, color: accentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaption(ThemeData theme, bool isDark, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: TextField(
        controller: _captionController,
        maxLines: 3,
        maxLength: 1024,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        decoration: InputDecoration(
          hintText: 'کپشن فایل (اختیاری)...',
          filled: true,
          fillColor: isDark ? const Color(0xFF2A2A2A) : _lightSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(Icons.edit_note_rounded, color: accentColor),
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme, bool isDark, Color accentColor) {
    final canSend = _selectedFile != null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: canSend ? _pickFile : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                side: BorderSide(color: accentColor.withValues(alpha: 0.35)),
              ),
              child: const Text('تغییر فایل'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: canSend ? _send : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    (isDark ? theme.disabledColor : accentColor)
                        .withValues(alpha: 0.38),
              ),
              icon: const Icon(Icons.send_rounded),
              label: Text(canSend ? 'ارسال' : 'انتخاب فایل'),
            ),
          ),
        ],
      ),
    );
  }

  Color _accentColor(ThemeData theme, bool isDark) {
    if (isDark) {
      return theme.colorScheme.primary;
    }
    if (theme.colorScheme.primary.computeLuminance() > 0.9) {
      return _lightAccent;
    }
    return Color.lerp(_lightAccent, theme.colorScheme.primary, 0.35) ??
        _lightAccent;
  }

  Future<void> _pickFile() async {
    try {
      HapticFeedback.lightImpact();
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'bmp',
          'heic',
          'heif',
          'pdf',
          'mp3',
          'm4a',
          'aac',
          'wav',
          'ogg',
          'flac',
        ],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final picked = result.files.first;
      File? file;
      final pickedPath = picked.path;
      if (pickedPath != null && pickedPath.isNotEmpty) {
        file = File(pickedPath);
      } else if (picked.bytes != null && picked.bytes!.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final safeName = picked.name.isNotEmpty
            ? picked.name
            : 'file_${DateTime.now().millisecondsSinceEpoch}';
        final tempPath = p.join(
          tempDir.path,
          'chat_upload_${DateTime.now().millisecondsSinceEpoch}_$safeName',
        );
        file = File(tempPath);
        await file.writeAsBytes(picked.bytes!, flush: true);
      }

      if (file == null) {
        if (!mounted) return;
        ToastService.showErrorToast(context, 'مسیر فایل قابل دسترس نیست');
        return;
      }

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

      final fileName =
          picked.name.isNotEmpty ? picked.name : p.basename(file.path);
      final fileSize = await file.length();
      final type = _typeFromAttachment(validation.attachmentType);
      final mimeType = _guessMimeType(fileName);

      setState(() {
        _selectedFile = file;
        _fileName = fileName;
        _fileSize = fileSize;
        _mimeType = mimeType;
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
      case 'document':
        return DocumentType.pdf;
      case 'audio':
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
        displayFileName: _fileName ?? p.basename(file.path),
        mimeType: _mimeType,
        sizeBytes: _fileSize,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String? _guessMimeType(String fileName) {
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      default:
        return null;
    }
  }
}
