// lib/features/chat/services/chat_attachment_service.dart
//
// سرویس یکپارچه مدیریت پیوست‌ها (فایل، عکس، صدا)
//
// این سرویس از سرویس‌های موجود استفاده میکنه و API ساده‌ای ارائه میده
//

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/uploadFileChatService.dart';
import '../../../services/uploadImageChatService.dart';
import '../../../services/uploadAudioChatService.dart';
import '../../../services/audio_recording_service.dart';
import '../../../security/logging_utility.dart';

/// نوع پیوست
enum AttachmentType {
  image,
  video,
  file,
  audio,
  voice,
}

/// نتیجه آپلود
class AttachmentResult {
  final bool success;
  final String? url;
  final String? fileName;
  final AttachmentType type;
  final int? duration; // برای صوتی
  final String? error;

  AttachmentResult({
    required this.success,
    this.url,
    this.fileName,
    required this.type,
    this.duration,
    this.error,
  });
}

/// سرویس مدیریت پیوست‌ها
class ChatAttachmentService {
  static final ChatAttachmentService _instance = ChatAttachmentService._internal();
  factory ChatAttachmentService() => _instance;
  ChatAttachmentService._internal();

  final ImagePicker _imagePicker = ImagePicker();

  // ═══════════════════════════════════════════════════════════════════════════
  // 📷 IMAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// انتخاب عکس از گالری
  Future<AttachmentResult> pickImageFromGallery({
    required String conversationId,
    void Function(double)? onProgress,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // فشرده‌سازی
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.image,
          error: 'انتخاب لغو شد',
        );
      }

      return await _uploadImage(File(image.path), conversationId, onProgress);
    } catch (e) {
      logInfo('❌ خطا در انتخاب عکس: $e');
      return AttachmentResult(
        success: false,
        type: AttachmentType.image,
        error: e.toString(),
      );
    }
  }

  /// گرفتن عکس از دوربین
  Future<AttachmentResult> pickImageFromCamera({
    required String conversationId,
    void Function(double)? onProgress,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.image,
          error: 'گرفتن عکس لغو شد',
        );
      }

      return await _uploadImage(File(image.path), conversationId, onProgress);
    } catch (e) {
      logInfo('❌ خطا در گرفتن عکس: $e');
      return AttachmentResult(
        success: false,
        type: AttachmentType.image,
        error: e.toString(),
      );
    }
  }

  Future<AttachmentResult> _uploadImage(
    File file,
    String conversationId,
    void Function(double)? onProgress,
  ) async {
    try {
      final url = await ChatImageUploadService.uploadChatImage(
        file,
        conversationId,
        onProgress: onProgress,
      );

      if (url == null || url.isEmpty) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.image,
          error: 'آپلود ناموفق',
        );
      }

      return AttachmentResult(
        success: true,
        url: url,
        fileName: file.path.split('/').last,
        type: AttachmentType.image,
      );
    } catch (e) {
      return AttachmentResult(
        success: false,
        type: AttachmentType.image,
        error: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎥 VIDEO
  // ═══════════════════════════════════════════════════════════════════════════

  /// انتخاب ویدیو از گالری
  Future<AttachmentResult> pickVideoFromGallery({
    required String conversationId,
    void Function(double)? onProgress,
  }) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video == null) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.video,
          error: 'انتخاب لغو شد',
        );
      }

      // برای ویدیو از uploadChatBinaryFile استفاده میکنیم
      final url = await ChatFileUploadService.uploadChatBinaryFile(
        File(video.path),
        conversationId,
        onProgress: onProgress,
      );

      if (url == null || url.isEmpty) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.video,
          error: 'آپلود ناموفق',
        );
      }

      return AttachmentResult(
        success: true,
        url: url,
        fileName: video.path.split('/').last,
        type: AttachmentType.video,
      );
    } catch (e) {
      logInfo('❌ خطا در انتخاب ویدیو: $e');
      return AttachmentResult(
        success: false,
        type: AttachmentType.video,
        error: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📁 FILE
  // ═══════════════════════════════════════════════════════════════════════════

  /// انتخاب فایل
  Future<AttachmentResult> pickFile({
    required String conversationId,
    void Function(double)? onProgress,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'zip'],
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.file,
          error: 'انتخاب لغو شد',
        );
      }

      final file = File(result.files.first.path!);
      final extension = result.files.first.extension?.toLowerCase() ?? '';

      String? url;
      if (extension == 'pdf') {
        url = await ChatFileUploadService.uploadChatPdfFile(
          file,
          conversationId,
          onProgress: onProgress,
        );
      } else {
        url = await ChatFileUploadService.uploadChatBinaryFile(
          file,
          conversationId,
          onProgress: onProgress,
        );
      }

      if (url == null || url.isEmpty) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.file,
          error: 'آپلود ناموفق',
        );
      }

      return AttachmentResult(
        success: true,
        url: url,
        fileName: result.files.first.name,
        type: AttachmentType.file,
      );
    } catch (e) {
      logInfo('❌ خطا در انتخاب فایل: $e');
      return AttachmentResult(
        success: false,
        type: AttachmentType.file,
        error: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎤 VOICE
  // ═══════════════════════════════════════════════════════════════════════════

  /// شروع ضبط صدا
  Future<bool> startVoiceRecording({
    Function(bool)? onRecordingStateChanged,
    Function(int)? onDurationChanged,
    Function(List<double>)? onWaveformDataChanged,
  }) async {
    VoiceRecordingService.setCallbacks(
      onRecordingStateChanged: onRecordingStateChanged,
      onDurationChanged: onDurationChanged,
      onWaveformDataChanged: onWaveformDataChanged,
    );
    
    return await VoiceRecordingService.startRecording();
  }

  /// توقف ضبط و دریافت فایل
  Future<File?> stopVoiceRecording() async {
    return await VoiceRecordingService.stopRecording();
  }

  /// لغو ضبط
  Future<void> cancelVoiceRecording() async {
    await VoiceRecordingService.cancelRecording();
  }

  /// آیا در حال ضبط هست؟
  bool get isRecording => VoiceRecordingService.isRecording;

  /// مدت زمان ضبط
  int get recordingDuration => VoiceRecordingService.recordingDuration;

  /// آپلود پیام صوتی
  Future<AttachmentResult> uploadVoiceMessage({
    required File audioFile,
    required String conversationId,
    required int duration,
    void Function(double)? onProgress,
  }) async {
    try {
      final url = await ChatAudioUploadService.uploadChatAudio(
        audioFile,
        conversationId,
        onProgress: onProgress,
      );

      if (url == null || url.isEmpty) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.voice,
          error: 'آپلود ناموفق',
        );
      }

      return AttachmentResult(
        success: true,
        url: url,
        fileName: audioFile.path.split('/').last,
        type: AttachmentType.voice,
        duration: duration,
      );
    } catch (e) {
      logInfo('❌ خطا در آپلود صدا: $e');
      return AttachmentResult(
        success: false,
        type: AttachmentType.voice,
        error: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎵 AUDIO FILE
  // ═══════════════════════════════════════════════════════════════════════════

  /// انتخاب فایل صوتی از گالری
  Future<AttachmentResult> pickAudioFile({
    required String conversationId,
    void Function(double)? onProgress,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.audio,
          error: 'انتخاب لغو شد',
        );
      }

      final file = File(result.files.first.path!);
      
      final url = await ChatAudioUploadService.uploadChatAudio(
        file,
        conversationId,
        onProgress: onProgress,
      );

      if (url == null || url.isEmpty) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.audio,
          error: 'آپلود ناموفق',
        );
      }

      return AttachmentResult(
        success: true,
        url: url,
        fileName: result.files.first.name,
        type: AttachmentType.audio,
      );
    } catch (e) {
      logInfo('❌ خطا در انتخاب فایل صوتی: $e');
      return AttachmentResult(
        success: false,
        type: AttachmentType.audio,
        error: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🛠️ UTILS
  // ═══════════════════════════════════════════════════════════════════════════

  /// نمایش Bottom Sheet انتخاب پیوست
  static Future<AttachmentType?> showAttachmentPicker(BuildContext context) async {
    return await showModalBottomSheet<AttachmentType>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachmentOption(
                    icon: Icons.photo_library_rounded,
                    label: 'گالری',
                    color: Colors.purple,
                    onTap: () => Navigator.pop(context, AttachmentType.image),
                  ),
                  _AttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'دوربین',
                    color: Colors.blue,
                    onTap: () => Navigator.pop(context, AttachmentType.image),
                  ),
                  _AttachmentOption(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'فایل',
                    color: Colors.orange,
                    onTap: () => Navigator.pop(context, AttachmentType.file),
                  ),
                  _AttachmentOption(
                    icon: Icons.videocam_rounded,
                    label: 'ویدیو',
                    color: Colors.red,
                    onTap: () => Navigator.pop(context, AttachmentType.video),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// تشخیص نوع پیوست از URL
  static AttachmentType getTypeFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || 
        lower.endsWith('.png') || lower.endsWith('.gif') ||
        lower.endsWith('.webp')) {
      return AttachmentType.image;
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') ||
        lower.endsWith('.avi') || lower.endsWith('.mkv')) {
      return AttachmentType.video;
    }
    if (lower.endsWith('.mp3') || lower.endsWith('.m4a') ||
        lower.endsWith('.wav') || lower.endsWith('.aac') ||
        lower.endsWith('.ogg')) {
      return AttachmentType.audio;
    }
    return AttachmentType.file;
  }

  /// آیکون پیوست
  static IconData getIconForType(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        return Icons.image_rounded;
      case AttachmentType.video:
        return Icons.videocam_rounded;
      case AttachmentType.file:
        return Icons.insert_drive_file_rounded;
      case AttachmentType.audio:
        return Icons.music_note_rounded;
      case AttachmentType.voice:
        return Icons.mic_rounded;
    }
  }
}

/// Widget برای گزینه پیوست
class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

