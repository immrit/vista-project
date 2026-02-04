import '../security/logging_utility.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'secure_upload_service.dart';
import 'user_friendly_error_handler.dart';
import '../utils/const.dart';

class ChatAudioUploadService {

  /// Upload chat audio file
  static Future<String?> uploadChatAudio(
    File audioFile,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found');
      }

      final extension = path.extension(audioFile.path).toLowerCase();
      if (!_isValidAudioFormat(extension)) {
        throw Exception('Unsupported audio format');
      }

      final fileName =
          'chats/$conversationId/audio/${supabase.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(audioFile.path)}';

      final Uint8List fileBytes = await audioFile.readAsBytes();
      final contentType = _getAudioContentType(extension);

      final uploadResult = await SecureUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: fileName,
        contentType: contentType,
        onProgress: onProgress,
      );

      final uploadedUrl = uploadResult.url;
      logInfo('Chat audio uploaded: $uploadedUrl');

      if (uploadedUrl.isEmpty) {
        throw Exception('Upload URL is empty');
      }

      return uploadedUrl;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'audio_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'audio_upload'));
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

      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');

      final extension = path.extension(sanitizedFileName).toLowerCase();
      final contentType = _getAudioContentType(extension);

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final s3FileName =
          'chats/$conversationId/audio/${userId}_${timestamp}_$sanitizedFileName';

      final uploadResult = await SecureUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: s3FileName,
        contentType: contentType,
      );

      final uploadedUrl = uploadResult.url;
      logInfo('Web audio upload success: $uploadedUrl');

      return uploadedUrl;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'audio_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'audio_upload'));
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
    const validFormats = ['.mp3', '.aac', '.m4a', '.wav', '.ogg'];
    return validFormats.contains(extension);
  }

  /// Map content type
  static String _getAudioContentType(String extension) {
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
        return 'audio/mpeg';
    }
  }
}
