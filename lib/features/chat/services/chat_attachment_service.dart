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
import 'package:path/path.dart' as p;
import '../../../core/services/media_upload_service.dart';
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
  final int? duration; // for voice/audio
  final String? error;
  final String? errorStage;
  final String? errorCode;
  final String? technicalError;

  AttachmentResult({
    required this.success,
    this.url,
    this.fileName,
    required this.type,
    this.duration,
    this.error,
    this.errorStage,
    this.errorCode,
    this.technicalError,
  });
}

/// سرویس مدیریت پیوست‌ها
class ChatAttachmentService {
  static final ChatAttachmentService _instance =
      ChatAttachmentService._internal();
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
      return _failedResult(
        type: AttachmentType.image,
        error: e,
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
      return _failedResult(
        type: AttachmentType.image,
        error: e,
      );
    }
  }

  /// آپلود مستقیم فایلی که قبلاً انتخاب شده (برای استفاده در ChatAttachmentSheet)
  /// این متد picker را باز نمی‌کند و فقط فایل را آپلود می‌کند
  Future<AttachmentResult> uploadImage({
    required File file,
    required String conversationId,
    void Function(double)? onProgress,
  }) async {
    try {
      final url = await MediaUploadService.uploadChatImage(
        file,
        conversationId,
        onProgress: onProgress,
      );

      if (url == null || url.isEmpty) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.image,
          error: 'آپلود ناموفق بود',
        );
      }

      return AttachmentResult(
        success: true,
        url: url,
        fileName: p.basename(file.path),
        type: AttachmentType.image,
      );
    } catch (e) {
      logInfo('❌ خطا در آپلود عکس: $e');
      return _failedResult(
        type: AttachmentType.image,
        error: e,
      );
    }
  }

  Future<AttachmentResult> _uploadImage(
    File file,
    String conversationId,
    void Function(double)? onProgress,
  ) async {
    return await uploadImage(
      file: file,
      conversationId: conversationId,
      onProgress: onProgress,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎥 VIDEO
  // ═══════════════════════════════════════════════════════════════════════════

  /// آپلود مستقیم ویدیویی که قبلاً انتخاب شده (برای استفاده در ChatAttachmentSheet)
  /// این متد picker را باز نمی‌کند و فقط فایل را آپلود می‌کند
  Future<AttachmentResult> uploadVideo({
    required File file,
    required String conversationId,
    void Function(double)? onProgress,
  }) async {
    try {
      // برای ویدیو از uploadChatBinaryFile استفاده میکنیم
      final url = await MediaUploadService.uploadChatBinaryFile(
        file,
        conversationId,
        onProgress: onProgress,
      );

      if (url == null || url.isEmpty) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.video,
          error: 'آپلود ناموفق بود',
        );
      }

      return AttachmentResult(
        success: true,
        url: url,
        fileName: p.basename(file.path),
        type: AttachmentType.video,
      );
    } catch (e) {
      logInfo('❌ خطا در آپلود ویدیو: $e');
      return _failedResult(
        type: AttachmentType.video,
        error: e,
      );
    }
  }

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

      return await uploadVideo(
        file: File(video.path),
        conversationId: conversationId,
        onProgress: onProgress,
      );
    } catch (e) {
      logInfo('❌ خطا در انتخاب ویدیو: $e');
      return _failedResult(
        type: AttachmentType.video,
        error: e,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📁 FILE
  // ═══════════════════════════════════════════════════════════════════════════

  /// آپلود مستقیم فایلی که قبلاً انتخاب شده (برای استفاده در ChatAttachmentSheet)
  /// این متد picker را باز نمی‌کند و فقط فایل را آپلود می‌کند
  Future<AttachmentResult> uploadFile({
    required File file,
    required String conversationId,
    void Function(double)? onProgress,
  }) async {
    try {
      final extension =
          p.extension(file.path).replaceFirst('.', '').toLowerCase();
      String? url;
      AttachmentType resultType = AttachmentType.file;

      if (extension == 'pdf') {
        url = await MediaUploadService.uploadChatPdfFile(
          file,
          conversationId,
          onProgress: onProgress,
        );
      } else if (_isAudioExtension(extension)) {
        url = await MediaUploadService.uploadChatAudio(
          file,
          conversationId,
          onProgress: onProgress,
        );
        resultType = AttachmentType.audio;
      } else {
        url = await MediaUploadService.uploadChatBinaryFile(
          file,
          conversationId,
          onProgress: onProgress,
        );
      }

      if (url == null || url.isEmpty) {
        return AttachmentResult(
          success: false,
          type: AttachmentType.file,
          error: 'آپلود ناموفق بود',
        );
      }

      return AttachmentResult(
        success: true,
        url: url,
        fileName: p.basename(file.path),
        type: resultType,
      );
    } catch (e) {
      logInfo('❌ خطا در آپلود فایل: $e');
      return _failedResult(
        type: AttachmentType.file,
        error: e,
      );
    }
  }

  /// انتخاب فایل
  Future<AttachmentResult> pickFile({
    required String conversationId,
    void Function(double)? onProgress,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
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

      return await uploadFile(
        file: file,
        conversationId: conversationId,
        onProgress: onProgress,
      );
    } catch (e) {
      logInfo('❌ خطا در انتخاب فایل: $e');
      return _failedResult(
        type: AttachmentType.file,
        error: e,
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
      final url = await MediaUploadService.uploadChatAudio(
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
        fileName: p.basename(audioFile.path),
        type: AttachmentType.voice,
        duration: duration,
      );
    } catch (e) {
      logInfo('❌ خطا در آپلود صدا: $e');
      return _failedResult(
        type: AttachmentType.voice,
        error: e,
      );
    }
  }

  Future<AttachmentResult> uploadAudioFile({
    required File audioFile,
    required String conversationId,
    void Function(double)? onProgress,
  }) async {
    try {
      final url = await MediaUploadService.uploadChatAudio(
        audioFile,
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
        fileName: p.basename(audioFile.path),
        type: AttachmentType.audio,
      );
    } catch (e) {
      logInfo('❌ خطا در آپلود فایل صوتی: $e');
      return _failedResult(
        type: AttachmentType.audio,
        error: e,
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
      final result = await FilePicker.pickFiles(
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

      final url = await MediaUploadService.uploadChatAudio(
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
      return _failedResult(
        type: AttachmentType.audio,
        error: e,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🛠️ UTILS
  // ═══════════════════════════════════════════════════════════════════════════
  static String _friendlyError(dynamic error) {
    final raw = error.toString().trim();
    final withoutException = raw.startsWith('Exception:')
        ? raw.substring('Exception:'.length).trim()
        : raw;
    const marker = '| technical:';
    final markerIndex = withoutException.indexOf(marker);
    final friendly = markerIndex >= 0
        ? withoutException.substring(0, markerIndex).trim()
        : withoutException;
    if (friendly.isEmpty) {
      return 'Upload failed. Please try again.';
    }
    return friendly;
  }

  static String _technicalError(dynamic error) {
    final raw = error.toString().trim();
    const marker = '| technical:';
    final markerIndex = raw.indexOf(marker);
    if (markerIndex >= 0) {
      final extracted = raw.substring(markerIndex + marker.length).trim();
      if (extracted.isNotEmpty) {
        return extracted;
      }
    }
    return '${error.runtimeType}: $error';
  }

  static AttachmentResult _failedResult({
    required AttachmentType type,
    required Object error,
  }) {
    final parsed = _parseTechnicalError(error);
    return AttachmentResult(
      success: false,
      type: type,
      error: _friendlyError(error),
      errorStage: parsed.stage,
      errorCode: parsed.code,
      technicalError: parsed.technical,
    );
  }

  static _ParsedTechnical _parseTechnicalError(Object error) {
    final technical = _technicalError(error);
    String? stage;
    String? code;

    final stageMatch = RegExp(r'stage=([a-zA-Z0-9_]+)').firstMatch(technical);
    if (stageMatch != null) {
      stage = stageMatch.group(1);
    }

    final codeMatch = RegExp(r'code=([A-Z0-9_]+)').firstMatch(technical);
    if (codeMatch != null) {
      code = codeMatch.group(1);
    }

    return _ParsedTechnical(
      technical: technical,
      stage: stage,
      code: code,
    );
  }

  static bool _isAudioExtension(String ext) {
    return const {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'}.contains(ext);
  }

  /// Show attachment picker bottom sheet
  static Future<AttachmentType?> showAttachmentPicker(
      BuildContext context) async {
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
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp')) {
      return AttachmentType.image;
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv')) {
      return AttachmentType.video;
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.aac') ||
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

class _ParsedTechnical {
  final String technical;
  final String? stage;
  final String? code;

  const _ParsedTechnical({
    required this.technical,
    this.stage,
    this.code,
  });
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
