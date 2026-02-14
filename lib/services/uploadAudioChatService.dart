import '../security/logging_utility.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'secure_upload_service.dart';
import 'user_friendly_error_handler.dart';
import '../utils/const.dart';
import 'upload_object_key_service.dart';

class ChatAudioUploadService {
  /// Upload chat audio file
  static Future<String?> uploadChatAudio(
    File audioFile,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    _PreparedAudioFile? preparedFile;
    try {
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found');
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
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

      final Uint8List fileBytes = await preparedFile.file.readAsBytes();
      final contentTypes = _resolveAudioContentTypes(preparedFile.extension);

      Object? lastError;
      for (final contentType in contentTypes) {
        try {
          final uploadResult = await SecureUploadService.uploadBytes(
            bytes: fileBytes,
            objectKey: objectKey,
            contentType: contentType,
            onProgress: onProgress,
          );

          final uploadedUrl = uploadResult.url;
          logInfo('Chat audio uploaded: $uploadedUrl');

          if (uploadedUrl.isEmpty) {
            throw Exception('Upload URL is empty');
          }

          return uploadedUrl;
        } catch (e, st) {
          lastError = e;
          logWarning(
            'Chat audio upload attempt failed (contentType=$contentType)',
            error: e,
            stackTrace: st,
          );
        }
      }

      throw Exception(lastError ?? 'Audio upload failed');
    } catch (e, st) {
      logError(
        'Chat audio upload failed',
        error: e,
        stackTrace: st,
      );
      UserFriendlyErrorHandler.logError(
        e,
        context: 'audio_upload',
        stackTrace: st,
      );
      final friendly = UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'audio_upload');
      throw Exception('$friendly | technical: ${e.runtimeType}: $e');
    } finally {
      if (preparedFile?.deleteAfterUpload == true) {
        try {
          await preparedFile!.file.delete();
        } catch (_) {
          // best-effort cleanup
        }
      }
    }
  }

  /// Upload chat audio file (web)
  static Future<String> uploadChatAudioWeb(
    Uint8List fileBytes,
    String fileName,
    String conversationId,
  ) async {
    try {
      logInfo('Starting web audio upload...');

      final extension = path.extension(fileName).toLowerCase().trim().isEmpty
          ? '.m4a'
          : path.extension(fileName).toLowerCase().trim();

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

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
          final uploadResult = await SecureUploadService.uploadBytes(
            bytes: fileBytes,
            objectKey: objectKey,
            contentType: contentType,
          );

          final uploadedUrl = uploadResult.url;
          logInfo('Web audio upload success: $uploadedUrl');
          return uploadedUrl;
        } catch (e, st) {
          lastError = e;
          logWarning(
            'Web audio upload attempt failed (contentType=$contentType)',
            error: e,
            stackTrace: st,
          );
        }
      }
      throw Exception(lastError ?? 'Audio upload failed');
    } catch (e, st) {
      UserFriendlyErrorHandler.logError(
        e,
        context: 'audio_upload',
        stackTrace: st,
      );
      final friendly = UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'audio_upload');
      throw Exception('$friendly | technical: ${e.runtimeType}: $e');
    }
  }

  /// Delete chat audio file
  static Future<bool> deleteChatAudio(String fileUrl) async {
    try {
      final deleted = await SecureUploadService.deleteByUrl(fileUrl);
      if (!deleted) {
        throw Exception('Delete failed');
      }
      return true;
    } catch (e) {
      logInfo('Error deleting chat audio: $e');
      return false;
    }
  }

  /// Validate audio format
  static bool _isValidAudioFormat(String extension) {
    const validFormats = ['.mp3', '.aac', '.m4a', '.wav', '.ogg', '.flac'];
    return validFormats.contains(extension);
  }

  static Future<_PreparedAudioFile> _prepareAudioFile(File audioFile) async {
    final extension = path.extension(audioFile.path).toLowerCase().trim();
    if (extension.isNotEmpty) {
      return _PreparedAudioFile(
        file: audioFile,
        extension: extension,
        deleteAfterUpload: false,
      );
    }

    final tempPath = path.join(
      Directory.systemTemp.path,
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    final copied = await audioFile.copy(tempPath);
    return _PreparedAudioFile(
      file: copied,
      extension: '.m4a',
      deleteAfterUpload: true,
    );
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

    throw Exception('Audio file is empty or not ready');
  }

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
}

class _PreparedAudioFile {
  final File file;
  final String extension;
  final bool deleteAfterUpload;

  const _PreparedAudioFile({
    required this.file,
    required this.extension,
    required this.deleteAfterUpload,
  });
}
