import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../../emoji/domain/emoji_render_policy.dart';
import '../../emoji/widgets/telegram_emoji_text.dart';
import '../services/chat_transfer_manager.dart';
import '../theme/chat_theme.dart';
import '../utils/chat_text_direction.dart';

class FileMessageBubble extends StatefulWidget {
  final String messageId;
  final String fileUrl;
  final String fileName;
  final int? fileSizeBytes;
  final String? localFilePath;
  final String? caption; // متن پیام یا کپشن ضمیمه شده به فایل
  final bool isMe;
  final DateTime time;

  const FileMessageBubble({
    super.key,
    required this.messageId,
    required this.fileUrl,
    required this.fileName,
    this.fileSizeBytes,
    this.localFilePath,
    this.caption,
    required this.isMe,
    required this.time,
  });

  @override
  State<FileMessageBubble> createState() => _FileMessageBubbleState();
}

class _FileMessageBubbleState extends State<FileMessageBubble> {
  final ChatTransferManager _transferManager = ChatTransferManager();
  StreamSubscription<ChatTransferTask?>? _taskSub;

  ChatTransferTask? _task;
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _bindTask();
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    super.dispose();
  }

  Future<void> _bindTask() async {
    final providedLocalPath = widget.localFilePath;
    if (providedLocalPath != null && providedLocalPath.isNotEmpty) {
      final providedFile = File(providedLocalPath);
      if (providedFile.existsSync()) {
        _localFile = providedFile;
      }
    }

    _taskSub?.cancel();
    _taskSub = _transferManager.watchTask(widget.messageId).listen((task) {
      if (!mounted) return;
      setState(() {
        _task = task;
        final path = task?.localPath ?? widget.localFilePath;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          _localFile = file.existsSync() ? file : null;
        } else if ((_localFile?.existsSync() ?? false) == false) {
          _localFile = null;
        }
      });
    });

    final file = await _transferManager.getLocalFileIfExists(widget.messageId);
    if (!mounted) return;
    if (file != null) {
      setState(() => _localFile = file);
    } else if (providedLocalPath != null && providedLocalPath.isNotEmpty) {
      final providedFile = File(providedLocalPath);
      if (providedFile.existsSync()) {
        setState(() => _localFile = providedFile);
      }
    }
  }

  Future<void> _onMainAction() async {
    HapticFeedback.lightImpact();
    final status = _task?.status;

    if (_localFile != null && _localFile!.existsSync()) {
      await OpenFilex.open(_localFile!.path);
      return;
    }

    if (status == TransferTaskStatus.downloading) {
      await _transferManager.pause(_task!.taskId);
      return;
    }

    if (status == TransferTaskStatus.paused ||
        status == TransferTaskStatus.queued) {
      await _transferManager.resume(_task!.taskId);
      return;
    }

    if (status == TransferTaskStatus.failed ||
        status == TransferTaskStatus.canceled) {
      await _transferManager.startDownload(
        widget.messageId,
        widget.fileUrl,
        widget.fileName,
      );
      return;
    }

    await _transferManager.startDownload(
      widget.messageId,
      widget.fileUrl,
      widget.fileName,
    );
  }

  Future<void> _cancelTransfer() async {
    final taskId = _task?.taskId;
    if (taskId == null) return;
    await _transferManager.cancel(taskId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final isLightOutgoing = widget.isMe && !theme.isDark;
    final fileExt = _getFileExtension(widget.fileName);
    final fileInfo = _getFileTypeInfo(fileExt);
    final status = _task?.status;
    final hasOffline = _localFile != null && _localFile!.existsSync();
    final progress = _task?.progress ?? 0;
    final primaryForeground = widget.isMe
        ? (isLightOutgoing ? const Color(0xFF1E293B) : Colors.white)
        : theme.textColor;
    final captionDirection = resolveChatTextDirection(
      widget.caption,
      fallback: Directionality.of(context),
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 285, minWidth: 220),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _onMainAction,
            child: Row(
              children: [
                _buildFileIcon(theme, fileInfo, status, progress, hasOffline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryForeground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _buildSubtitle(status, progress, hasOffline),
                        style: TextStyle(
                          fontSize: 12,
                          color: (widget.isMe
                                  ? primaryForeground
                                  : theme.secondaryTextColor)
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.caption != null && widget.caption!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Directionality(
              textDirection: captionDirection,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TelegramEmojiText(
                  widget.caption!,
                  useTelegramEmoji:
                      EmojiRenderPolicy.useTelegramEmojiRenderer(),
                  textDirection: captionDirection,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: primaryForeground,
                    fontSize: 14,
                    height: 1.35,
                    fontFamily: 'Vazir',
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (!hasOffline &&
                  (status == TransferTaskStatus.downloading ||
                      status == TransferTaskStatus.paused ||
                      status == TransferTaskStatus.queued)) ...[
                _buildControlChip(
                  theme: theme,
                  isLightOutgoing: isLightOutgoing,
                  icon: status == TransferTaskStatus.downloading
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: status == TransferTaskStatus.downloading
                      ? 'توقف'
                      : 'ادامه',
                  onTap: _onMainAction,
                ),
                const SizedBox(width: 6),
                _buildControlChip(
                  theme: theme,
                  isLightOutgoing: isLightOutgoing,
                  icon: Icons.close_rounded,
                  label: 'لغو',
                  onTap: _cancelTransfer,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(
    ChatTheme theme,
    _FileTypeInfo fileInfo,
    TransferTaskStatus? status,
    double progress,
    bool hasOffline,
  ) {
    final isLightOutgoing = widget.isMe && !theme.isDark;
    final iconBgColor = widget.isMe
        ? (isLightOutgoing
            ? theme.sendButtonColor.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.18))
        : fileInfo.color.withValues(alpha: 0.12);
    final iconColor = widget.isMe
        ? (isLightOutgoing ? theme.sendButtonColor : Colors.white)
        : fileInfo.color;

    IconData icon;
    if (hasOffline) {
      icon = Icons.folder_open_rounded;
    } else if (status == TransferTaskStatus.downloading) {
      icon = Icons.pause_rounded;
    } else if (status == TransferTaskStatus.paused) {
      icon = Icons.play_arrow_rounded;
    } else if (status == TransferTaskStatus.failed) {
      icon = Icons.refresh_rounded;
    } else {
      icon = fileInfo.icon;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          if (status == TransferTaskStatus.downloading)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2.5,
                  color: iconColor,
                  backgroundColor: iconColor.withValues(alpha: 0.22),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlChip({
    required ChatTheme theme,
    required bool isLightOutgoing,
    required IconData icon,
    required String label,
    required Future<void> Function() onTap,
  }) {
    final chipBg = widget.isMe
        ? (isLightOutgoing
            ? theme.sendButtonColor.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.16))
        : theme.inputBackgroundColor;
    final foreground = widget.isMe
        ? (isLightOutgoing ? theme.sendButtonColor : Colors.white)
        : theme.textColor;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        unawaited(onTap());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(14),
          border: isLightOutgoing
              ? Border.all(color: theme.sendButtonColor.withValues(alpha: 0.24))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle(
    TransferTaskStatus? status,
    double progress,
    bool hasOffline,
  ) {
    final sizeText = _formatFileSize(widget.fileSizeBytes ?? 0);
    if (hasOffline) {
      return '$sizeText • آماده باز کردن';
    }
    if (status == TransferTaskStatus.downloading) {
      return '$sizeText • ${(progress * 100).toStringAsFixed(0)}%';
    }
    if (status == TransferTaskStatus.paused) {
      return '$sizeText • متوقف شده';
    }
    if (status == TransferTaskStatus.queued) {
      return '$sizeText • در صف دانلود';
    }
    if (status == TransferTaskStatus.failed) {
      return '$sizeText • خطا در دانلود';
    }
    if (status == TransferTaskStatus.completed) {
      return '$sizeText • آماده باز کردن';
    }
    return sizeText;
  }

  String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  _FileTypeInfo _getFileTypeInfo(String extension) {
    switch (extension) {
      case 'pdf':
        return _FileTypeInfo(Icons.picture_as_pdf_rounded, Colors.red);
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'ogg':
      case 'm4a':
        return _FileTypeInfo(Icons.audio_file_rounded, Colors.pink);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return _FileTypeInfo(Icons.image_rounded, Colors.teal);
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
