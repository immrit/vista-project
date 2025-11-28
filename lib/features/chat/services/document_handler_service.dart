// lib/features/chat/services/document_handler_service.dart
//
// سرویس مدیریت اسناد و فایل‌ها در چت
//
// ویژگی‌ها:
// ✅ آپلود انواع فایل‌ها (PDF, DOC, XLS, ZIP, etc.)
// ✅ دانلود فایل‌ها با progress
// ✅ مدیریت کش فایل‌های دانلود شده
// ✅ تشخیص نوع فایل
// ✅ محدودیت حجم
// ✅ Preview فایل‌ها
//

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../../services/advanced_file_manager.dart';
import '../../../security/logging_utility.dart';

/// نوع فایل‌های پشتیبانی شده
enum DocumentType {
  pdf('PDF', ['pdf'], '📄'),
  word('Word', ['doc', 'docx'], '📝'),
  excel('Excel', ['xls', 'xlsx'], '📊'),
  powerpoint('PowerPoint', ['ppt', 'pptx'], '📽️'),
  text('Text', ['txt', 'md'], '📃'),
  archive('Archive', ['zip', 'rar', '7z'], '🗜️'),
  audio('Audio', ['mp3', 'wav', 'aac', 'm4a'], '🎵'),
  video('Video', ['mp4', 'mov', 'avi', 'mkv'], '🎥'),
  image('Image', ['jpg', 'jpeg', 'png', 'gif', 'webp'], '🖼️'),
  other('Other', [], '📎');

  final String displayName;
  final List<String> extensions;
  final String emoji;

  const DocumentType(this.displayName, this.extensions, this.emoji);

  static DocumentType fromExtension(String ext) {
    final extension = ext.toLowerCase().replaceAll('.', '');
    for (final type in DocumentType.values) {
      if (type.extensions.contains(extension)) {
        return type;
      }
    }
    return DocumentType.other;
  }
}

/// نتیجه آپلود فایل
class DocumentUploadResult {
  final bool success;
  final String? url;
  final String? fileName;
  final int? fileSize;
  final DocumentType? type;
  final String? error;

  const DocumentUploadResult({
    required this.success,
    this.url,
    this.fileName,
    this.fileSize,
    this.type,
    this.error,
  });

  factory DocumentUploadResult.success({
    required String url,
    required String fileName,
    required int fileSize,
    required DocumentType type,
  }) {
    return DocumentUploadResult(
      success: true,
      url: url,
      fileName: fileName,
      fileSize: fileSize,
      type: type,
    );
  }

  factory DocumentUploadResult.failure(String error) {
    return DocumentUploadResult(
      success: false,
      error: error,
    );
  }
}

/// نتیجه دانلود فایل
class DocumentDownloadResult {
  final bool success;
  final String? localPath;
  final String? error;

  const DocumentDownloadResult({
    required this.success,
    this.localPath,
    this.error,
  });

  factory DocumentDownloadResult.success(String localPath) {
    return DocumentDownloadResult(
      success: true,
      localPath: localPath,
    );
  }

  factory DocumentDownloadResult.failure(String error) {
    return DocumentDownloadResult(
      success: false,
      error: error,
    );
  }
}

/// سرویس مدیریت اسناد
class DocumentHandlerService {
  static final DocumentHandlerService _instance = DocumentHandlerService._();
  factory DocumentHandlerService() => _instance;
  DocumentHandlerService._();

  // محدودیت‌ها
  static const int maxFileSizeInBytes = 100 * 1024 * 1024; // 100 MB
  static const int maxFileSizeInMB = 100;

  /// آپلود فایل
  ///
  /// [file] - فایل مورد نظر
  /// [conversationId] - شناسه مکالمه
  /// [onProgress] - callback برای نمایش پیشرفت
  ///
  /// Returns: نتیجه آپلود
  Future<DocumentUploadResult> uploadDocument({
    required File file,
    required String conversationId,
    Function(double)? onProgress,
  }) async {
    try {
      logInfo('📤 Starting document upload: ${file.path}');

      // بررسی وجود فایل
      if (!await file.exists()) {
        return DocumentUploadResult.failure('فایل وجود ندارد');
      }

      // بررسی حجم فایل
      final fileSize = await file.length();
      if (fileSize > maxFileSizeInBytes) {
        return DocumentUploadResult.failure(
          'حجم فایل بیش از $maxFileSizeInMB مگابایت است',
        );
      }

      // تشخیص نوع فایل
      final fileName = path.basename(file.path);
      final extension = path.extension(file.path);
      final documentType = DocumentType.fromExtension(extension);

      logInfo('   File: $fileName');
      logInfo('   Size: ${_formatBytes(fileSize)}');
      logInfo('   Type: ${documentType.displayName}');

      // آپلود با استفاده از AdvancedFileManager
      final uploadedUrl = await AdvancedFileManager.instance.uploadFile(
        file,
        conversationId,
        fileType: 'document',
        onProgress: onProgress,
      );

      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        return DocumentUploadResult.failure('خطا در آپلود فایل');
      }

      logInfo('✅ Document uploaded successfully: $uploadedUrl');

      return DocumentUploadResult.success(
        url: uploadedUrl,
        fileName: fileName,
        fileSize: fileSize,
        type: documentType,
      );
    } catch (e, stackTrace) {
      logInfo('❌ Error uploading document: $e\n$stackTrace');
      return DocumentUploadResult.failure('خطا در آپلود: ${e.toString()}');
    }
  }

  /// دانلود فایل
  ///
  /// [url] - URL فایل
  /// [fileName] - نام فایل
  /// [onProgress] - callback برای نمایش پیشرفت
  ///
  /// Returns: نتیجه دانلود با مسیر محلی
  Future<DocumentDownloadResult> downloadDocument({
    required String url,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    try {
      logInfo('📥 Starting document download: $fileName');

      // بررسی کش - آیا قبلاً دانلود شده؟
      final cachedPath = await _getCachedDocumentPath(fileName);
      if (cachedPath != null) {
        logInfo('📦 Document found in cache: $cachedPath');
        return DocumentDownloadResult.success(cachedPath);
      }

      // دانلود فایل
      if (kIsWeb) {
        // در وب، فقط URL را برگردان
        return DocumentDownloadResult.success(url);
      }

      // دانلود برای موبایل/دسکتاپ
      final appDir = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${appDir.path}/documents');
      
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }

      final filePath = '${documentsDir.path}/$fileName';
      final file = File(filePath);

      // اگر فایل قبلاً وجود داره، همون رو برگردون
      if (await file.exists()) {
        logInfo('📦 Document already exists: $filePath');
        return DocumentDownloadResult.success(filePath);
      }

      logInfo('🌐 Downloading from: $url');

      // دانلود با نمایش پیشرفت
      final response = await http.Client().send(
        http.Request('GET', Uri.parse(url)),
      );

      if (response.statusCode != 200) {
        return DocumentDownloadResult.failure(
          'خطا در دانلود: ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      final sink = file.openWrite();
      
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (totalBytes > 0 && onProgress != null) {
          onProgress(downloadedBytes / totalBytes);
        }
      }

      await sink.close();

      logInfo('✅ Document downloaded: $filePath');
      return DocumentDownloadResult.success(filePath);
    } catch (e, stackTrace) {
      logInfo('❌ Error downloading document: $e\n$stackTrace');
      return DocumentDownloadResult.failure('خطا در دانلود: ${e.toString()}');
    }
  }

  /// بررسی آیا فایل در کش وجود دارد
  Future<String?> _getCachedDocumentPath(String fileName) async {
    try {
      if (kIsWeb) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/documents/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// حذف فایل از کش
  Future<bool> deleteFromCache(String fileName) async {
    try {
      if (kIsWeb) return false;

      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/documents/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        logInfo('🗑️ Document deleted from cache: $fileName');
        return true;
      }
      return false;
    } catch (e) {
      logInfo('❌ Error deleting document: $e');
      return false;
    }
  }

  /// پاک کردن کل کش اسناد
  Future<void> clearDocumentsCache() async {
    try {
      if (kIsWeb) return;

      final appDir = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${appDir.path}/documents');

      if (await documentsDir.exists()) {
        await documentsDir.delete(recursive: true);
        logInfo('🗑️ Documents cache cleared');
      }
    } catch (e) {
      logInfo('❌ Error clearing documents cache: $e');
    }
  }

  /// محاسبه حجم کش
  Future<int> getCacheSize() async {
    try {
      if (kIsWeb) return 0;

      final appDir = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${appDir.path}/documents');

      if (!await documentsDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in documentsDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// فرمت کردن حجم فایل
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// دریافت نام فرمت شده برای نمایش
  String getFormattedSize(int bytes) => _formatBytes(bytes);

  /// تشخیص آیا فایل قابل Preview است
  bool canPreview(DocumentType type) {
    return type == DocumentType.image ||
        type == DocumentType.pdf ||
        type == DocumentType.text;
  }

  /// دریافت آیکون برای نوع فایل
  String getIconForType(DocumentType type) => type.emoji;
}


