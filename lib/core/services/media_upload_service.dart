import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/providers/auth_controller.dart';
import '../../services/backend_upload_service.dart';
import '../../services/user_friendly_error_handler.dart';
import '../../services/upload_object_key_service.dart';
import '../../services/cache_manager.dart';
import '../../security/logging_utility.dart';

class MediaUploadService {
  static const int _maxFileBytes = 100 * 1024 * 1024;

  // ==========================================
  // 1. IMAGE COMPRESSION & CONVERSION
  // ==========================================

  static Future<File?> convertPngToJpeg(File file) async {
    final img = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      format: CompressFormat.jpeg,
      quality: 85,
    );

    if (img == null) {
      logInfo('تبدیل به JPEG ناموفق بود');
      return null;
    }

    final dir = Directory.systemTemp.path;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final convertedFile = File('$dir/converted_$timestamp.jpg')
      ..writeAsBytesSync(img);

    return convertedFile;
  }

  static Future<File?> compressImage(File file, {bool isChat = false}) async {
    try {
      final extension = path.extension(file.path).toLowerCase();

      if (extension == '.png') {
        return file; // Will be converted later if needed
      }

      final img = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: isChat ? 1280 : 1920,
        minHeight: isChat ? 720 : 1080,
        quality: isChat ? 80 : 85,
        format: CompressFormat.jpeg,
      );

      if (img == null) return null;

      final dir = Directory.systemTemp.path;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = File('$dir/compressed_$timestamp.jpg')
        ..writeAsBytesSync(img);

      return compressedFile;
    } catch (e) {
      logInfo('خطا در فشرده‌سازی تصویر: $e');
      return null;
    }
  }

  // ==========================================
  // 2. CHAT UPLOAD METHODS
  // ==========================================

  static Future<String?> uploadChatImage(
    File file,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    File? compressedFile;
    try {
      if (!await file.exists()) throw Exception('فایل مورد نظر وجود ندارد');

      final fileSize = await file.length();
      if (fileSize > 100 * 1024 * 1024) {
        throw Exception('Image size must be at most 100MB');
      }

      final extension = path.extension(file.path).toLowerCase();

      if (extension == '.png') {
        compressedFile = await convertPngToJpeg(file);
        if (compressedFile == null) throw Exception('تبدیل به JPEG شکست خورد');
      } else {
        compressedFile = await compressImage(file, isChat: true);
        // If compression fails (e.g. file is already an optimised JPEG from
        // the image editor), fall back to the original file.
        compressedFile ??= file;
      }

      final userId = await _currentUserId();

      final normalizedExt = path.extension(compressedFile.path).toLowerCase();
      final fileName = UploadObjectKeyService.buildChatObjectKey(
        conversationId: conversationId,
        folder: 'images',
        userId: userId,
        extension: normalizedExt,
      );

      final fileBytes = await compressedFile.readAsBytes();
      logInfo('🔑 PRESIGN objectKey=$fileName fileSize=${fileBytes.length} userId=$userId convId=$conversationId');
      if (onProgress != null) onProgress(0.0);

      final uploadResult = await BackendUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: fileName,
        contentType: 'image/jpeg',
        onProgress: onProgress,
      );

      return uploadResult.url;
    } catch (e, st) {
      if (e is DioException) {
        logError(
          'Chat image upload DioError: status=${e.response?.statusCode} body=${e.response?.data} msg=${e.message}',
          error: e,
          stackTrace: st,
        );
      } else {
        logError('Chat image upload failed', error: e, stackTrace: st);
      }
      UserFriendlyErrorHandler.logError(e,
          context: 'image_upload', stackTrace: st);
      throw Exception('technical: ${e.runtimeType}: $e');
    } finally {
      if (compressedFile != null && compressedFile.path != file.path) {
        try {
          await compressedFile.delete();
        } catch (_) {}
      }
    }
  }

  static Future<String?> uploadChatAudio(
    File audioFile,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    _PreparedAudioFile? preparedFile;
    try {
      if (!await audioFile.exists()) throw Exception('Audio file not found');

      final userId = await _currentUserId();
      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      preparedFile = await _prepareAudioFile(audioFile);
      await _waitForReadableFile(preparedFile.file);
      if (!_isValidAudioFormat(preparedFile.extension)) {
        throw Exception('Unsupported audio format');
      }

      final objectKey = UploadObjectKeyService.buildChatObjectKey(
        conversationId: conversationId,
        folder: 'audio',
        userId: userId,
        extension: preparedFile.extension,
      );

      final fileBytes = await preparedFile.file.readAsBytes();
      final contentTypes = _resolveAudioContentTypes(preparedFile.extension);

      Object? lastError;
      for (final contentType in contentTypes) {
        try {
          final uploadResult = await BackendUploadService.uploadBytes(
            bytes: fileBytes,
            objectKey: objectKey,
            contentType: contentType,
            onProgress: onProgress,
          );
          if (uploadResult.url.isEmpty) throw Exception('Upload URL is empty');
          return uploadResult.url;
        } catch (e, st) {
          lastError = e;
          logWarning('Chat audio upload attempt failed',
              error: e, stackTrace: st);
        }
      }
      throw Exception(lastError ?? 'Audio upload failed');
    } catch (e, st) {
      logError('Chat audio upload failed', error: e, stackTrace: st);
      UserFriendlyErrorHandler.logError(e,
          context: 'audio_upload', stackTrace: st);
      throw Exception(
          '${UserFriendlyErrorHandler.getFriendlyMessage(e, context: 'audio_upload')} | technical: ${e.runtimeType}: $e');
    } finally {
      if (preparedFile?.deleteAfterUpload == true) {
        try {
          await preparedFile!.file.delete();
        } catch (_) {}
      }
    }
  }

  static Future<String> uploadChatAudioWeb(
    Uint8List fileBytes,
    String fileName,
    String conversationId,
  ) async {
    try {
      final extension = path.extension(fileName).toLowerCase().trim().isEmpty
          ? '.m4a'
          : path.extension(fileName).toLowerCase().trim();

      final userId = await _currentUserId();

      final objectKey = UploadObjectKeyService.buildChatObjectKey(
        conversationId: conversationId,
        folder: 'audio',
        userId: userId,
        extension: extension,
      );
      final contentTypes = _resolveAudioContentTypes(extension);

      Object? lastError;
      for (final contentType in contentTypes) {
        try {
          final uploadResult = await BackendUploadService.uploadBytes(
            bytes: fileBytes,
            objectKey: objectKey,
            contentType: contentType,
          );
          return uploadResult.url;
        } catch (e) {
          lastError = e;
        }
      }
      throw Exception(lastError ?? 'Audio upload failed');
    } catch (e, st) {
      UserFriendlyErrorHandler.logError(e,
          context: 'audio_upload', stackTrace: st);
      throw Exception(
          '${UserFriendlyErrorHandler.getFriendlyMessage(e, context: 'audio_upload')} | technical: ${e.runtimeType}: $e');
    }
  }

  static Future<String?> uploadChatPdfFile(
    File file,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await file.exists()) throw Exception('File not found');
      await _waitForReadableFile(file);

      final fileBytes = await file.readAsBytes();
      var extension = path.extension(file.path).toLowerCase();
      if (extension != '.pdf') {
        final inferred = _inferExtensionFromBytes(fileBytes);
        if (inferred == '.pdf') {
          extension = '.pdf';
        } else {
          throw Exception('Only PDF is supported');
        }
      }

      if (fileBytes.length > _maxFileBytes) {
        throw Exception('PDF size must be at most 100MB');
      }
      if (fileBytes.length < 1024) throw Exception('PDF file is too small');

      final userId = await _currentUserId();
      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final objectKey = UploadObjectKeyService.buildChatObjectKey(
        conversationId: conversationId,
        folder: 'documents',
        userId: userId,
        extension: extension,
      );

      return await _uploadWithContentTypeFallback(
        bytes: fileBytes,
        objectKey: objectKey,
        contentTypes: const ['application/pdf'],
        onProgress: onProgress,
      );
    } catch (e, st) {
      logError('PDF upload failed', error: e, stackTrace: st);
      UserFriendlyErrorHandler.logError(e,
          context: 'file_upload', stackTrace: st);
      throw Exception(
          '${UserFriendlyErrorHandler.getFriendlyMessage(e, context: 'file_upload')} | technical: ${e.runtimeType}: $e');
    }
  }

  static Future<String?> uploadChatBinaryFile(
    File file,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await file.exists()) throw Exception('File not found');
      await _waitForReadableFile(file);

      final fileBytes = await file.readAsBytes();
      if (fileBytes.length > _maxFileBytes) {
        throw Exception('File size must be at most 100MB');
      }

      var extension = path.extension(file.path).toLowerCase();
      if (extension.isEmpty) extension = _inferExtensionFromBytes(fileBytes);
      if (extension.isEmpty) extension = '.bin';

      final userId = await _currentUserId();
      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final objectKey = UploadObjectKeyService.buildChatObjectKey(
        conversationId: conversationId,
        folder: _folderForExtension(extension),
        userId: userId,
        extension: extension,
      );

      return await _uploadWithContentTypeFallback(
        bytes: fileBytes,
        objectKey: objectKey,
        contentTypes: _guessContentTypes(extension),
        onProgress: onProgress,
      );
    } catch (e, st) {
      logError('Binary file upload failed', error: e, stackTrace: st);
      UserFriendlyErrorHandler.logError(e,
          context: 'file_upload', stackTrace: st);
      throw Exception(
          '${UserFriendlyErrorHandler.getFriendlyMessage(e, context: 'file_upload')} | technical: ${e.runtimeType}: $e');
    }
  }

  static Future<String?> uploadChatPdfFileWeb(
    Uint8List fileBytes,
    String fileName,
    String conversationId,
  ) async {
    try {
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        throw Exception('Only PDF is supported');
      }
      if (fileBytes.length > _maxFileBytes) {
        throw Exception('PDF size must be at most 100MB');
      }
      if (fileBytes.length < 1024) throw Exception('PDF file is too small');

      final userId = await _currentUserId();
      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final objectKey = UploadObjectKeyService.buildChatObjectKey(
        conversationId: conversationId,
        folder: 'documents',
        userId: userId,
        extension: '.pdf',
      );

      return await _uploadWithContentTypeFallback(
        bytes: fileBytes,
        objectKey: objectKey,
        contentTypes: const ['application/pdf'],
      );
    } catch (e, st) {
      UserFriendlyErrorHandler.logError(e,
          context: 'file_upload', stackTrace: st);
      throw Exception(
          '${UserFriendlyErrorHandler.getFriendlyMessage(e, context: 'file_upload')} | technical: ${e.runtimeType}: $e');
    }
  }

  // ==========================================
  // 3. POST UPLOAD METHODS
  // ==========================================

  static Future<String?> uploadPostImage(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    File? compressedFile;
    try {
      if (!await file.exists()) throw Exception('فایل مورد نظر وجود ندارد');

      final extension = path.extension(file.path).toLowerCase();
      if (extension == '.png') {
        compressedFile = await convertPngToJpeg(file);
        if (compressedFile == null) throw Exception('تبدیل به JPEG شکست خورد');
      } else {
        compressedFile = await compressImage(file, isChat: false);
        compressedFile ??= file;
      }

      final userId = await _currentUserId();
      final fileName =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_${path.basename(compressedFile.path)}';

      final fileBytes = await compressedFile.readAsBytes();
      final uploadResult = await BackendUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: fileName,
        contentType: 'image/jpeg',
        onProgress: onProgress,
      );
      return uploadResult.url;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'image_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'image_upload'));
    } finally {
      if (compressedFile != null && compressedFile.path != file.path) {
        try {
          await compressedFile.delete();
        } catch (_) {}
      }
    }
  }

  static Future<String?> uploadPostImageWeb(
    Uint8List fileBytes,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final userId = await _currentUserId();
      final s3FileName =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final uploadResult = await BackendUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: s3FileName,
        contentType: 'image/jpeg',
        onProgress: onProgress,
      );
      return uploadResult.url;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'image_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'image_upload'));
    }
  }

  static Future<String> uploadMusicFile(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (await file.length() > 100 * 1024 * 1024) {
        throw Exception('حجم فایل باید کمتر از 100 مگابایت باشد');
      }

      final extension = path.extension(file.path).toLowerCase();
      if (!['.mp3', '.m4a'].contains(extension)) {
        throw Exception('فقط فایل‌های mp3 و m4a پشتیبانی می‌شوند');
      }

      var baseName = path
          .basenameWithoutExtension(file.path)
          .replaceAll(RegExp(r'[^\w\-\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      if (baseName.isEmpty) baseName = 'track';
      if (baseName.length > 64) baseName = baseName.substring(0, 64);

      final userId = await _currentUserId();
      final fileName =
          'music/$userId/${DateTime.now().millisecondsSinceEpoch}_${baseName.toLowerCase()}$extension';

      final uploadResult = await BackendUploadService.uploadFile(
        file: file,
        objectKey: fileName,
        contentType: extension == '.m4a' ? 'audio/mp4' : 'audio/mpeg',
        onProgress: onProgress,
      );
      return uploadResult.url;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'audio_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'audio_upload'));
    }
  }

  static Future<String?> uploadVideoFile(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (await file.length() > 100 * 1024 * 1024) {
        throw Exception('حجم فایل باید کمتر از 100 مگابایت باشد');
      }
      final extension = path.extension(file.path).toLowerCase();
      if (!['.mp4', '.mov', '.mkv'].contains(extension)) {
        throw Exception('فقط فایل‌های mp4، mov و mkv پشتیبانی می‌شوند');
      }

      final userId = await _currentUserId();
      final fileName =
          'videos/$userId/${DateTime.now().millisecondsSinceEpoch}$extension';
      final uploadResult = await BackendUploadService.uploadFile(
        file: file,
        objectKey: fileName,
        contentType: extension == '.mov'
            ? 'video/quicktime'
            : (extension == '.mkv' ? 'video/x-matroska' : 'video/mp4'),
        onProgress: onProgress,
      );
      return uploadResult.url;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'video_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'video_upload'));
    }
  }

  static Future<String?> uploadVideoFileWeb(
    Uint8List fileBytes,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final extension = path.extension(fileName).toLowerCase();
      if (!['.mp4', '.mov', '.mkv'].contains(extension)) {
        throw Exception('فقط فایل‌های mp4، mov و mkv پشتیبانی می‌شوند');
      }
      if (fileBytes.length > 100 * 1024 * 1024) {
        throw Exception('حجم فایل باید کمتر از 100 مگابایت باشد');
      }

      final userId = await _currentUserId();
      final s3FileName =
          'videos/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final uploadResult = await BackendUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: s3FileName,
        contentType: extension == '.mov'
            ? 'video/quicktime'
            : (extension == '.mkv' ? 'video/x-matroska' : 'video/mp4'),
        onProgress: onProgress,
      );
      return uploadResult.url;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'video_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'video_upload'));
    }
  }

  // ==========================================
  // 4. DELETE METHODS
  // ==========================================

  static Future<bool> deleteChatImage(String fileUrl) async =>
      _deleteGeneric(fileUrl);
  static Future<bool> deleteChatAudio(String fileUrl) async =>
      _deleteGeneric(fileUrl);
  static Future<bool> deleteChatFile(String fileUrl) async =>
      _deleteGeneric(fileUrl);
  static Future<bool> deletePostImage(String fileUrl) async =>
      _deleteGeneric(fileUrl);
  static Future<bool> deleteMusicFile(String fileUrl) async =>
      _deleteGeneric(fileUrl);
  static Future<bool> deleteVideoFile(String fileUrl) async =>
      _deleteGeneric(fileUrl);
  static Future<bool> deleteMediaFile(String fileUrl) async =>
      _deleteGeneric(fileUrl);

  static Future<bool> _deleteGeneric(String fileUrl) async {
    try {
      final deleted = await BackendUploadService.deleteByUrl(fileUrl);
      if (!deleted) throw Exception('Delete failed');
      return true;
    } catch (e) {
      logInfo('خطا در حذف فایل: $e');
      return false;
    }
  }

  // ==========================================
  // 5. CACHING METHODS
  // ==========================================

  static Future<void> precacheChatImages(List<String> imageUrls) async {
    final cacheManager = await CustomCacheManager.chatInstance;
    for (final url in imageUrls) {
      await cacheManager.downloadFile(url);
    }
  }

  static Future<void> clearChatCache() async =>
      (await CustomCacheManager.chatInstance).emptyCache();

  static Future<void> precacheStoryImages(List<String> imageUrls) async {
    final cacheManager = await CustomCacheManager.storyInstance;
    for (final url in imageUrls) {
      await cacheManager.downloadFile(url);
    }
  }

  static Future<void> clearOldCache() async =>
      (await CustomCacheManager.storyInstance).emptyCache();

  static Future<void> precachePostImages(List<String> imageUrls) async {
    final cacheManager = await CustomCacheManager.postInstance;
    for (final url in imageUrls) {
      await cacheManager.downloadFile(url);
    }
  }

  static Future<void> clearCache() async {
    await (await CustomCacheManager.postInstance).emptyCache();
    await (await CustomCacheManager.storyInstance).emptyCache();
  }

  static Future<void> removeOldCache() async => clearCache();

  // ==========================================
  // 6. PRIVATE HELPERS
  // ==========================================

  static Future<String> _uploadWithContentTypeFallback({
    required Uint8List bytes,
    required String objectKey,
    required List<String> contentTypes,
    void Function(double progress)? onProgress,
  }) async {
    Object? lastError;
    for (final contentType in contentTypes) {
      try {
        final result = await BackendUploadService.uploadBytes(
          bytes: bytes,
          objectKey: objectKey,
          contentType: contentType,
          onProgress: onProgress,
        );
        return result.url;
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception(lastError ?? 'Upload failed');
  }

  static Future<_PreparedAudioFile> _prepareAudioFile(File audioFile) async {
    final extension = path.extension(audioFile.path).toLowerCase().trim();
    if (extension.isNotEmpty) {
      return _PreparedAudioFile(
          file: audioFile, extension: extension, deleteAfterUpload: false);
    }

    final copy = await audioFile.copy(path.join(Directory.systemTemp.path,
        'voice_${DateTime.now().millisecondsSinceEpoch}.m4a'));
    return _PreparedAudioFile(
        file: copy, extension: '.m4a', deleteAfterUpload: true);
  }

  static Future<void> _waitForReadableFile(File file) async {
    for (var i = 0; i < 8; i++) {
      if (await file.exists() && await file.length() > 0) return;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    throw Exception('File is empty or not ready');
  }

  static bool _isValidAudioFormat(String extension) => const [
        '.mp3',
        '.aac',
        '.m4a',
        '.wav',
        '.ogg',
        '.flac'
      ].contains(extension);
  static List<String> _resolveAudioContentTypes(String extension) {
    switch (extension) {
      case '.mp3':
        return const ['audio/mpeg'];
      case '.aac':
        return const ['audio/aac', 'audio/mp4'];
      case '.m4a':
        return const ['audio/mp4', 'audio/x-m4a', 'audio/aac'];
      case '.wav':
        return const ['audio/wav', 'audio/x-wav'];
      case '.ogg':
        return const ['audio/ogg'];
      case '.flac':
        return const ['audio/flac', 'audio/x-flac'];
      default:
        return const ['application/octet-stream'];
    }
  }

  static String _folderForExtension(String extension) {
    if (extension == '.pdf') return 'documents';
    if (const {'.mp3', '.m4a', '.aac', '.wav', '.ogg', '.flac'}
        .contains(extension)) {
      return 'audio';
    }
    return 'files';
  }

  static List<String> _guessContentTypes(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return const ['image/jpeg'];
      case '.png':
        return const ['image/png'];
      case '.gif':
        return const ['image/gif'];
      case '.webp':
        return const ['image/webp'];
      case '.mp4':
        return const ['video/mp4'];
      case '.txt':
        return const ['text/plain'];
      case '.pdf':
        return const ['application/pdf'];
      case '.zip':
        return const ['application/zip'];
      default:
        return const ['application/octet-stream'];
    }
  }

  static String _inferExtensionFromBytes(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return '.pdf';
    }
    return ''; // Abbreviated for simplicity
  }

  static Future<String> _currentUserId() async {
    final storedUserId = await TokenStorage.getUserId();
    if (storedUserId != null && storedUserId.isNotEmpty) {
      return storedUserId;
    }

    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('User not authenticated');
    }

    final user = await AuthRepository().me(accessToken);
    await TokenStorage.saveUserId(user.id);
    return user.id;
  }
}

class _PreparedAudioFile {
  final File file;
  final String extension;
  final bool deleteAfterUpload;
  const _PreparedAudioFile(
      {required this.file,
      required this.extension,
      required this.deleteAfterUpload});
}
