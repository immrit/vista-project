// lib/features/chat/widgets/file_message_bubble.dart
//
// ویجت نمایش فایل در حباب پیام - با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ آیکون بر اساس نوع فایل
// ✅ نمایش نام و سایز فایل
// ✅ دانلود با progress
// ✅ باز کردن فایل
// ✅ انیمیشن‌های روان
//

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../theme/chat_theme.dart';

/// ویجت نمایش فایل در حباب پیام
class FileMessageBubble extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final int? fileSizeBytes;
  final bool isMe;
  final DateTime time;

  const FileMessageBubble({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.fileSizeBytes,
    required this.isMe,
    required this.time,
  });

  @override
  State<FileMessageBubble> createState() => _FileMessageBubbleState();
}

class _FileMessageBubbleState extends State<FileMessageBubble>
    with SingleTickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🎮 STATE
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _downloadProgress = 0.0;
  String? _localPath;
  late AnimationController _iconController;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎬 LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkIfDownloaded();
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _checkIfDownloaded() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/downloads/${widget.fileName}');
    if (file.existsSync()) {
      setState(() {
        _isDownloaded = true;
        _localPath = file.path;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📥 DOWNLOAD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _downloadFile() async {
    if (_isDownloading) {
      // لغو دانلود
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final uri = Uri.parse(widget.fileUrl);
      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed');
      }

      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/downloads');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      final file = File('${downloadsDir.path}/${widget.fileName}');
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        if (!_isDownloading) {
          await sink.close();
          await file.delete();
          return;
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (totalBytes > 0 && mounted) {
          setState(() {
            _downloadProgress = downloadedBytes / totalBytes;
          });
        }
      }

      await sink.close();

      if (mounted) {
        setState(() {
          _localPath = file.path;
          _isDownloading = false;
          _isDownloaded = true;
        });
        _iconController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('خطا در دانلود فایل'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openFile() async {
    if (_localPath == null) {
      await _downloadFile();
      return;
    }

    HapticFeedback.lightImpact();
    await OpenFilex.open(_localPath!);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔨 BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final fileExt = _getFileExtension(widget.fileName);
    final fileInfo = _getFileTypeInfo(fileExt);

    return GestureDetector(
      onTap: _openFile,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260, minWidth: 200),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // آیکون فایل
            _buildFileIcon(theme, fileInfo),

            const SizedBox(width: 12),

            // اطلاعات فایل
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // نام فایل
                  Text(
                    widget.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.isMe
                          ? theme.myBubbleTextColor
                          : theme.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // سایز و وضعیت
                  Row(
                    children: [
                      Text(
                        _formatFileSize(widget.fileSizeBytes ?? 0),
                        style: TextStyle(
                          color: (widget.isMe
                                  ? theme.myBubbleTextColor
                                  : theme.secondaryTextColor)
                              .withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      if (_isDownloading) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${(_downloadProgress * 100).toInt()}%',
                          style: TextStyle(
                            color: widget.isMe
                                ? theme.myBubbleTextColor
                                : theme.sendButtonColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_isDownloaded && !_isDownloading) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: widget.isMe
                              ? Colors.white.withOpacity(0.8)
                              : Colors.green,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(ChatTheme theme, _FileTypeInfo fileInfo) {
    final iconBgColor = widget.isMe
        ? Colors.white.withOpacity(0.2)
        : fileInfo.color.withOpacity(0.1);

    final iconColor = widget.isMe ? Colors.white : fileInfo.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // آیکون فایل
          if (!_isDownloading)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isDownloaded ? Icons.folder_open_rounded : fileInfo.icon,
                key: ValueKey(_isDownloaded),
                color: iconColor,
                size: 24,
              ),
            ),

          // Progress
          if (_isDownloading)
            SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    strokeWidth: 2.5,
                    color: iconColor,
                    backgroundColor: iconColor.withOpacity(0.2),
                  ),
                  Icon(
                    Icons.close_rounded,
                    color: iconColor,
                    size: 16,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  _FileTypeInfo _getFileTypeInfo(String extension) {
    switch (extension) {
      // Documents
      case 'pdf':
        return _FileTypeInfo(Icons.picture_as_pdf_rounded, Colors.red);
      case 'doc':
      case 'docx':
        return _FileTypeInfo(Icons.description_rounded, Colors.blue);
      case 'xls':
      case 'xlsx':
        return _FileTypeInfo(Icons.table_chart_rounded, Colors.green);
      case 'ppt':
      case 'pptx':
        return _FileTypeInfo(Icons.slideshow_rounded, Colors.orange);
      case 'txt':
        return _FileTypeInfo(Icons.text_snippet_rounded, Colors.grey);

      // Archives
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return _FileTypeInfo(Icons.folder_zip_rounded, Colors.amber);

      // Code
      case 'json':
      case 'xml':
      case 'html':
      case 'css':
      case 'js':
      case 'dart':
      case 'py':
      case 'java':
        return _FileTypeInfo(Icons.code_rounded, Colors.purple);

      // Audio
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'ogg':
      case 'm4a':
        return _FileTypeInfo(Icons.audio_file_rounded, Colors.pink);

      // Video
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
      case 'webm':
        return _FileTypeInfo(Icons.video_file_rounded, Colors.indigo);

      // Image
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'svg':
        return _FileTypeInfo(Icons.image_rounded, Colors.teal);

      // APK
      case 'apk':
        return _FileTypeInfo(Icons.android_rounded, Colors.lightGreen);

      default:
        return _FileTypeInfo(Icons.insert_drive_file_rounded, Colors.blueGrey);
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
}

class _FileTypeInfo {
  final IconData icon;
  final Color color;

  const _FileTypeInfo(this.icon, this.color);
}

