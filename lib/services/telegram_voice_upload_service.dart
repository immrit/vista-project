import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'secure_config.dart';
import 'user_friendly_error_handler.dart';
import 'telegram_voice_service.dart';
import '/main.dart';

/// مدل نتیجه آپلود
class VoiceUploadResult {
  final String fileUrl;
  final String fileName;
  final double fileSize;
  final int duration;
  final DateTime uploadTime;
  final String? error;

  const VoiceUploadResult({
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.duration,
    required this.uploadTime,
    this.error,
  });

  bool get isSuccess => error == null;
}

/// مدل تنظیمات آپلود
class UploadConfig {
  final int maxFileSize; // bytes
  final List<String> allowedFormats;
  final bool enableCompression;
  final double compressionQuality;
  final bool enableEncryption;
  final int chunkSize; // bytes

  const UploadConfig({
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
    this.allowedFormats = const ['.m4a', '.aac', '.mp3', '.wav', '.ogg'],
    this.enableCompression = true,
    this.compressionQuality = 0.8,
    this.enableEncryption = false,
    this.chunkSize = 1024 * 1024, // 1MB
  });
}

/// سرویس آپلود وویس پیشرفته مثل تلگرام
class TelegramVoiceUploadService {
  // Singleton instance
  static final TelegramVoiceUploadService _instance =
      TelegramVoiceUploadService._internal();
  factory TelegramVoiceUploadService() => _instance;
  TelegramVoiceUploadService._internal();

  // Upload configuration
  UploadConfig _config = const UploadConfig();

  // Active uploads tracking
  final Map<String, StreamController<double>> _uploadProgressControllers = {};
  final Map<String, bool> _uploadCancellationFlags = {};

  /// تنظیم کانفیگ آپلود
  void setUploadConfig(UploadConfig config) {
    _config = config;
  }

  /// دریافت S3 instance
  S3 get _s3 {
    if (!SecureConfig.isConfigured) {
      throw Exception('AWS credentials not properly configured');
    }

    return S3(
      region: SecureConfig.awsRegion,
      credentials: AwsClientCredentials(
        accessKey: SecureConfig.awsAccessKey,
        secretKey: SecureConfig.awsSecretKey,
      ),
      endpointUrl: SecureConfig.awsEndpointUrl,
    );
  }

  String get _bucketName => SecureConfig.awsBucketName;

  /// آپلود فایل وویس با پیشرفت
  Future<VoiceUploadResult> uploadVoiceFile(
    VoiceRecordingData recordingData,
    String conversationId, {
    String? customFileName,
    Function(double progress)? onProgress,
    Function(String status)? onStatusChanged,
  }) async {
    final uploadId =
        '${DateTime.now().millisecondsSinceEpoch}_${recordingData.filePath.hashCode}';

    try {
      onStatusChanged?.call('آماده‌سازی فایل...');

      // بررسی فایل
      final file = File(recordingData.filePath);
      if (!await file.exists()) {
        throw Exception('فایل صوتی وجود ندارد');
      }

      // بررسی سایز فایل
      final fileSize = await file.length();
      if (fileSize > _config.maxFileSize) {
        throw Exception(
            'حجم فایل بیش از حد مجاز است (${_config.maxFileSize / 1024 / 1024}MB)');
      }

      // بررسی فرمت فایل
      final extension = path.extension(recordingData.filePath).toLowerCase();
      if (!_config.allowedFormats.contains(extension)) {
        throw Exception('فرمت فایل پشتیبانی نمی‌شود');
      }

      onStatusChanged?.call('فشرده‌سازی فایل...');
      onProgress?.call(0.1);

      // فشرده‌سازی فایل (اختیاری) - currently not implemented
      File? processedFile = file;
      // if (_config.enableCompression) {
      //   final compressedFile = await TelegramVoiceService.compressAudioFile(
      //     file,
      //     quality: _config.compressionQuality,
      //   );
      //   if (compressedFile != null) {
      //     processedFile = compressedFile;
      //   }
      // }

      onStatusChanged?.call('آماده‌سازی برای آپلود...');
      onProgress?.call(0.2);

      // تولید نام فایل
      final fileName =
          customFileName ?? _generateFileName(recordingData, conversationId);

      // تولید مسیر S3
      final s3Key = 'chats/$conversationId/voice/$fileName';

      onStatusChanged?.call('آپلود فایل...');
      onProgress?.call(0.3);

      // آپلود فایل
      final uploadResult = await _uploadFileToS3(
        processedFile,
        s3Key,
        recordingData,
        onProgress: (progress) {
          // تبدیل پیشرفت آپلود به پیشرفت کلی (0.3 تا 0.9)
          final overallProgress = 0.3 + (progress * 0.6);
          onProgress?.call(overallProgress);
        },
        uploadId: uploadId,
      );

      onStatusChanged?.call('تکمیل آپلود...');
      onProgress?.call(1.0);

      // تولید URL نهایی
      final fileUrl = 'https://storage.389346.ir.cdn.ir/$_bucketName/$s3Key';

      final result = VoiceUploadResult(
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: uploadResult / 1024, // KB
        duration: recordingData.duration,
        uploadTime: DateTime.now(),
      );

      print('✅ فایل وویس با موفقیت آپلود شد: $fileUrl');
      return result;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'voice_upload');

      final result = VoiceUploadResult(
        fileUrl: '',
        fileName: customFileName ?? 'unknown',
        fileSize: 0,
        duration: recordingData.duration,
        uploadTime: DateTime.now(),
        error: UserFriendlyErrorHandler.getFriendlyMessage(e,
            context: 'voice_upload'),
      );

      print('❌ خطا در آپلود فایل وویس: $e');
      return result;
    } finally {
      // پاکسازی
      _uploadProgressControllers.remove(uploadId);
      _uploadCancellationFlags.remove(uploadId);
    }
  }

  /// آپلود فایل به S3 با پشتیبانی از قطع و ادامه
  Future<double> _uploadFileToS3(
    File file,
    String s3Key,
    VoiceRecordingData recordingData, {
    Function(double progress)? onProgress,
    required String uploadId,
  }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final fileSize = fileBytes.length;

      // برای فایل‌های کوچک، آپلود مستقیم
      if (fileSize <= _config.chunkSize) {
        await _s3.putObject(
          bucket: _bucketName,
          key: s3Key,
          body: fileBytes,
          contentType: _getContentType(file.path),
          acl: ObjectCannedACL.publicRead,
          metadata: {
            'duration': recordingData.duration.toString(),
            'fileSize': fileSize.toString(),
            'uploadTime': DateTime.now().toIso8601String(),
            'waveform': recordingData.waveformData.join(','),
          },
        );

        onProgress?.call(1.0);
        return fileSize.toDouble();
      }

      // برای فایل‌های بزرگ، آپلود تدریجی
      return await _uploadLargeFile(
          fileBytes, s3Key, recordingData, onProgress, uploadId);
    } catch (e) {
      print('❌ خطا در آپلود به S3: $e');
      rethrow;
    }
  }

  /// آپلود فایل‌های بزرگ به صورت تدریجی
  Future<double> _uploadLargeFile(
    Uint8List fileBytes,
    String s3Key,
    VoiceRecordingData recordingData,
    Function(double progress)? onProgress,
    String uploadId,
  ) async {
    try {
      // شروع multipart upload
      final createResponse = await _s3.createMultipartUpload(
        bucket: _bucketName,
        key: s3Key,
        contentType: 'audio/mp4',
        acl: ObjectCannedACL.publicRead,
        metadata: {
          'duration': recordingData.duration.toString(),
          'fileSize': fileBytes.length.toString(),
          'uploadTime': DateTime.now().toIso8601String(),
          'waveform': recordingData.waveformData.join(','),
        },
      );

      final uploadId_s3 = createResponse.uploadId!;
      final parts = <CompletedPart>[];
      final totalChunks = (fileBytes.length / _config.chunkSize).ceil();

      // آپلود هر بخش
      for (int i = 0; i < totalChunks; i++) {
        // بررسی لغو آپلود
        if (_uploadCancellationFlags[uploadId] == true) {
          await _s3.abortMultipartUpload(
            bucket: _bucketName,
            key: s3Key,
            uploadId: uploadId_s3,
          );
          throw Exception('آپلود لغو شد');
        }

        final start = i * _config.chunkSize;
        final end = (start + _config.chunkSize).clamp(0, fileBytes.length);
        final chunk = fileBytes.sublist(start, end);

        final uploadPartResponse = await _s3.uploadPart(
          bucket: _bucketName,
          key: s3Key,
          partNumber: i + 1,
          uploadId: uploadId_s3,
          body: chunk,
        );

        parts.add(CompletedPart(
          eTag: uploadPartResponse.eTag,
          partNumber: i + 1,
        ));

        // به‌روزرسانی پیشرفت
        final progress = (i + 1) / totalChunks;
        onProgress?.call(progress);
      }

      // تکمیل multipart upload
      await _s3.completeMultipartUpload(
        bucket: _bucketName,
        key: s3Key,
        uploadId: uploadId_s3,
        multipartUpload: CompletedMultipartUpload(parts: parts),
      );

      return fileBytes.length.toDouble();
    } catch (e) {
      print('❌ خطا در آپلود تدریجی: $e');
      rethrow;
    }
  }

  /// لغو آپلود
  void cancelUpload(String uploadId) {
    _uploadCancellationFlags[uploadId] = true;
  }

  /// آپلود فایل وویس در وب
  Future<VoiceUploadResult> uploadVoiceFileWeb(
    Uint8List fileBytes,
    String fileName,
    String conversationId,
    int duration,
    List<double> waveformData, {
    Function(double progress)? onProgress,
    Function(String status)? onStatusChanged,
  }) async {
    try {
      onStatusChanged?.call('آماده‌سازی فایل...');
      onProgress?.call(0.1);

      // بررسی سایز فایل
      if (fileBytes.length > _config.maxFileSize) {
        throw Exception('حجم فایل بیش از حد مجاز است');
      }

      // بررسی فرمت فایل
      final extension = path.extension(fileName).toLowerCase();
      if (!_config.allowedFormats.contains(extension)) {
        throw Exception('فرمت فایل پشتیبانی نمی‌شود');
      }

      onStatusChanged?.call('آپلود فایل...');
      onProgress?.call(0.3);

      // تولید نام فایل
      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userId = supabase.auth.currentUser?.id ?? 'anonymous';
      final s3FileName =
          'chats/$conversationId/voice/${userId}_${timestamp}_$sanitizedFileName';

      // آپلود فایل
      await _s3.putObject(
        bucket: _bucketName,
        key: s3FileName,
        body: fileBytes,
        contentType: _getContentType(fileName),
        acl: ObjectCannedACL.publicRead,
        metadata: {
          'duration': duration.toString(),
          'fileSize': fileBytes.length.toString(),
          'uploadTime': DateTime.now().toIso8601String(),
          'waveform': waveformData.join(','),
        },
      );

      onProgress?.call(1.0);

      final fileUrl =
          'https://storage.389346.ir.cdn.ir/$_bucketName/$s3FileName';

      final result = VoiceUploadResult(
        fileUrl: fileUrl,
        fileName: s3FileName,
        fileSize: fileBytes.length / 1024, // KB
        duration: duration,
        uploadTime: DateTime.now(),
      );

      print('✅ فایل وویس وب با موفقیت آپلود شد: $fileUrl');
      return result;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'voice_upload_web');

      final result = VoiceUploadResult(
        fileUrl: '',
        fileName: fileName,
        fileSize: 0,
        duration: duration,
        uploadTime: DateTime.now(),
        error: UserFriendlyErrorHandler.getFriendlyMessage(e,
            context: 'voice_upload_web'),
      );

      print('❌ خطا در آپلود فایل وویس وب: $e');
      return result;
    }
  }

  /// حذف فایل وویس
  Future<bool> deleteVoiceFile(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final key = uri.pathSegments.sublist(1).join('/');

      await _s3.deleteObject(
        bucket: _bucketName,
        key: key,
      );

      print('✅ فایل وویس حذف شد: $fileUrl');
      return true;
    } catch (e) {
      print('❌ خطا در حذف فایل وویس: $e');
      return false;
    }
  }

  /// تولید نام فایل منحصر به فرد
  String _generateFileName(
      VoiceRecordingData recordingData, String conversationId) {
    final userId = supabase.auth.currentUser?.id ?? 'anonymous';
    final timestamp = recordingData.timestamp.millisecondsSinceEpoch;
    final duration = recordingData.duration;
    return '${userId}_${timestamp}_${duration}s.m4a';
  }

  /// تعیین Content-Type برای فایل‌های صوتی
  String _getContentType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.mp3':
        return 'audio/mpeg';
      case '.aac':
        return 'audio/aac';
      case '.m4a':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      default:
        return 'audio/mp4'; // پیش‌فرض
    }
  }

  /// دریافت اطلاعات فایل وویس
  Future<Map<String, dynamic>?> getVoiceFileInfo(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final key = uri.pathSegments.sublist(1).join('/');

      final response = await _s3.headObject(
        bucket: _bucketName,
        key: key,
      );

      return {
        'size': response.contentLength,
        'lastModified': response.lastModified,
        'contentType': response.contentType,
        'metadata': response.metadata,
      };
    } catch (e) {
      print('❌ خطا در دریافت اطلاعات فایل: $e');
      return null;
    }
  }

  /// پاکسازی منابع
  void dispose() {
    _uploadProgressControllers.clear();
    _uploadCancellationFlags.clear();
    print('🧹 Telegram Voice Upload Service disposed');
  }
}
