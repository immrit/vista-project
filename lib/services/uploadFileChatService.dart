import '../security/logging_utility.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'secure_upload_service.dart';
import 'user_friendly_error_handler.dart';
import '../utils/const.dart';
import 'upload_object_key_service.dart';

class ChatFileUploadService {
  static const int _maxBytes = 50 * 1024 * 1024;

  static Future<String?> uploadChatPdfFile(
    File file,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await file.exists()) {
        throw Exception('File not found');
      }
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

      final fileSize = fileBytes.length;
      if (fileSize > _maxBytes) {
        throw Exception('PDF size must be at most 50MB');
      }
      if (fileSize < 1024) {
        throw Exception('PDF file is too small');
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final objectKey = UploadObjectKeyService.buildChatObjectKey(
        conversationId: conversationId,
        folder: 'documents',
        userId: userId,
        extension: extension,
      );

      final uploadedUrl = await _uploadWithContentTypeFallback(
        bytes: fileBytes,
        objectKey: objectKey,
        contentTypes: const ['application/pdf'],
        onProgress: onProgress,
      );

      if (uploadedUrl.isEmpty) {
        throw Exception('Upload URL is empty');
      }

      logInfo('Chat PDF uploaded: $uploadedUrl');
      return uploadedUrl;
    } catch (e, st) {
      logError('PDF upload failed', error: e, stackTrace: st);
      UserFriendlyErrorHandler.logError(
        e,
        context: 'file_upload',
        stackTrace: st,
      );
      final friendly = UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'file_upload');
      throw Exception('$friendly | technical: ${e.runtimeType}: $e');
    }
  }

  static Future<String?> uploadChatBinaryFile(
    File file,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await file.exists()) {
        throw Exception('File not found');
      }
      await _waitForReadableFile(file);

      final fileBytes = await file.readAsBytes();
      final fileSize = fileBytes.length;
      if (fileSize > _maxBytes) {
        throw Exception('File size must be at most 50MB');
      }

      var extension = path.extension(file.path).toLowerCase();
      if (extension.isEmpty) {
        extension = _inferExtensionFromBytes(fileBytes);
      }
      if (extension.isEmpty) {
        extension = '.bin';
      }
      final userId = supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final folder = _folderForExtension(extension);
      final objectKey = UploadObjectKeyService.buildChatObjectKey(
        conversationId: conversationId,
        folder: folder,
        userId: userId,
        extension: extension,
      );

      final contentTypes = _guessContentTypes(extension);
      final uploadedUrl = await _uploadWithContentTypeFallback(
        bytes: fileBytes,
        objectKey: objectKey,
        contentTypes: contentTypes,
        onProgress: onProgress,
      );

      if (uploadedUrl.isEmpty) {
        throw Exception('Upload URL is empty');
      }

      logInfo('Chat file uploaded: $uploadedUrl');
      return uploadedUrl;
    } catch (e, st) {
      logError('Binary file upload failed', error: e, stackTrace: st);
      UserFriendlyErrorHandler.logError(
        e,
        context: 'file_upload',
        stackTrace: st,
      );
      final friendly = UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'file_upload');
      throw Exception('$friendly | technical: ${e.runtimeType}: $e');
    }
  }

  static Future<String?> uploadChatPdfFileWeb(
    Uint8List fileBytes,
    String fileName,
    String conversationId,
  ) async {
    try {
      final lower = fileName.toLowerCase();
      if (!lower.endsWith('.pdf')) {
        throw Exception('Only PDF is supported');
      }
      if (fileBytes.length > _maxBytes) {
        throw Exception('PDF size must be at most 50MB');
      }
      if (fileBytes.length < 1024) {
        throw Exception('PDF file is too small');
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final objectKey = UploadObjectKeyService.buildChatObjectKey(
        conversationId: conversationId,
        folder: 'documents',
        userId: userId,
        extension: '.pdf',
      );

      final uploadedUrl = await _uploadWithContentTypeFallback(
        bytes: fileBytes,
        objectKey: objectKey,
        contentTypes: const ['application/pdf'],
      );

      if (uploadedUrl.isEmpty) {
        throw Exception('Upload URL is empty');
      }

      logInfo('Web PDF upload success: $uploadedUrl');
      return uploadedUrl;
    } catch (e, st) {
      logError('Web PDF upload failed', error: e, stackTrace: st);
      UserFriendlyErrorHandler.logError(
        e,
        context: 'file_upload',
        stackTrace: st,
      );
      final friendly = UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'file_upload');
      throw Exception('$friendly | technical: ${e.runtimeType}: $e');
    }
  }

  static Future<bool> deleteChatFile(String fileUrl) async {
    try {
      final deleted = await SecureUploadService.deleteByUrl(fileUrl);
      if (!deleted) {
        throw Exception('Delete failed');
      }
      return true;
    } catch (e, st) {
      logWarning('Error deleting chat file', error: e, stackTrace: st);
      return false;
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
      case '.heic':
      case '.heif':
        return const ['image/heic', 'image/heif'];
      case '.mp4':
        return const ['video/mp4'];
      case '.mp3':
        return const ['audio/mpeg'];
      case '.m4a':
        return const ['audio/mp4', 'audio/x-m4a', 'audio/aac'];
      case '.wav':
        return const ['audio/wav', 'audio/x-wav'];
      case '.aac':
        return const ['audio/aac', 'audio/mp4'];
      case '.ogg':
        return const ['audio/ogg'];
      case '.flac':
        return const ['audio/flac', 'audio/x-flac'];
      case '.txt':
        return const ['text/plain'];
      case '.csv':
        return const ['text/csv'];
      case '.json':
        return const ['application/json'];
      case '.doc':
        return const ['application/msword'];
      case '.docx':
        return const [
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        ];
      case '.xls':
        return const ['application/vnd.ms-excel'];
      case '.xlsx':
        return const [
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ];
      case '.ppt':
        return const ['application/vnd.ms-powerpoint'];
      case '.pptx':
        return const [
          'application/vnd.openxmlformats-officedocument.presentationml.presentation'
        ];
      case '.zip':
        return const ['application/zip'];
      case '.rar':
        return const ['application/vnd.rar'];
      case '.7z':
        return const ['application/x-7z-compressed'];
      case '.pdf':
        return const ['application/pdf'];
      default:
        return const ['application/octet-stream'];
    }
  }

  static Future<String> _uploadWithContentTypeFallback({
    required Uint8List bytes,
    required String objectKey,
    required List<String> contentTypes,
    void Function(double progress)? onProgress,
  }) async {
    Object? lastError;
    StackTrace? lastStack;

    for (final contentType in contentTypes) {
      try {
        final result = await SecureUploadService.uploadBytes(
          bytes: bytes,
          objectKey: objectKey,
          contentType: contentType,
          onProgress: onProgress,
        );
        return result.url;
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        logWarning(
          'Upload attempt failed (contentType=$contentType, key=$objectKey)',
          error: e,
          stackTrace: st,
        );
      }
    }

    logError(
      'All upload content-type attempts failed',
      error: lastError,
      stackTrace: lastStack,
    );
    throw Exception(lastError ?? 'Upload failed');
  }

  static String _inferExtensionFromBytes(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return '.pdf';
    }

    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45) {
      return '.wav';
    }

    if (bytes.length >= 4 &&
        bytes[0] == 0x4F &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53) {
      return '.ogg';
    }

    if (bytes.length >= 4 &&
        bytes[0] == 0x66 &&
        bytes[1] == 0x4C &&
        bytes[2] == 0x61 &&
        bytes[3] == 0x43) {
      return '.flac';
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      return '.mp3';
    }

    if (bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0) {
      return '.aac';
    }

    if (bytes.length >= 8 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      if (bytes.length >= 12) {
        final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
        if (brand == 'heic' ||
            brand == 'heix' ||
            brand == 'hevc' ||
            brand == 'heif' ||
            brand == 'mif1') {
          return '.heic';
        }
      }
      return '.m4a';
    }

    return '';
  }

  static Future<void> _waitForReadableFile(File file) async {
    const attempts = 8;
    const pause = Duration(milliseconds: 150);
    for (var i = 0; i < attempts; i++) {
      if (await file.exists()) {
        final length = await file.length();
        if (length > 0) {
          return;
        }
      }
      await Future.delayed(pause);
    }
    throw Exception('File is empty or not ready');
  }
}
