import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../utils/const.dart';
import '../../../../services/PostImageUploadService.dart';
import 'package:uuid/uuid.dart';

class UploadTask {
  final String id;
  final String status; // 'uploading', 'success', 'failed'
  final double progress;
  final String? errorMessage;
  final File? thumbnail; // For local preview

  UploadTask({
    required this.id,
    this.status = 'uploading',
    this.progress = 0.0,
    this.errorMessage,
    this.thumbnail,
  });

  UploadTask copyWith({
    String? status,
    double? progress,
    String? errorMessage,
  }) {
    return UploadTask(
      id: id,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      thumbnail: thumbnail,
    );
  }
}

class PostUploadNotifier extends StateNotifier<List<UploadTask>> {
  PostUploadNotifier() : super([]);

  final _uuid = const Uuid();

  Future<void> startUpload({
    required String content,
    required String userId,
    File? image,
    Uint8List? imageBytes,
    String? imageName,
    File? video,
    Uint8List? videoBytes,
    String? videoName,
    File? music,
    String? musicName,
    File? videoThumbnail,
  }) async {
    final taskId = _uuid.v4();

    // Add task to state
    state = [
      ...state,
      UploadTask(
        id: taskId,
        thumbnail:
            image ?? videoThumbnail, // Use image or video thumbnail for preview
      )
    ];

    try {
      // 1. Upload Media
      String? imageUrl;
      String? videoUrl;
      String? musicUrl;

      // Image Upload
      if (kIsWeb && imageBytes != null && imageName != null) {
        imageUrl = await PostImageUploadService.uploadPostImageWeb(
            imageBytes, imageName);
      } else if (image != null) {
        imageUrl = await PostImageUploadService.uploadPostImage(image);
      } else if (videoThumbnail != null && !kIsWeb) {
        imageUrl = await PostImageUploadService.uploadPostImage(videoThumbnail);
      }

      // Video Upload
      if (kIsWeb && videoBytes != null && videoName != null) {
        videoUrl = await PostImageUploadService.uploadVideoFileWeb(
            videoBytes, videoName);
      } else if (video != null) {
        videoUrl = await PostImageUploadService.uploadVideoFile(video);
      }

      // Music Upload
      if (music != null) {
        musicUrl = await PostImageUploadService.uploadMusicFile(music);
      }

      // 2. Insert into DB
      final postData = {
        'user_id': userId,
        'content': content,
        if (imageUrl != null) 'image_url': imageUrl,
        if (videoUrl != null) 'video_url': videoUrl,
        if (musicUrl != null) 'music_url': musicUrl,
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('posts').insert(postData);

      // 3. Mark success and remove after delay
      _updateTaskStatus(taskId, 'success');

      // Remove from list after 3 seconds so user sees success message
      await Future.delayed(const Duration(seconds: 3));
      state = state.where((t) => t.id != taskId).toList();
    } catch (e) {
      debugPrint('Upload failed: $e');
      _updateTaskStatus(taskId, 'failed', errorMessage: e.toString());
      // Keep failed tasks in list so user can retry or dismiss
    }
  }

  void _updateTaskStatus(String id, String status, {String? errorMessage}) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(status: status, errorMessage: errorMessage)
        else
          task
    ];
  }

  void dismissTask(String id) {
    state = state.where((t) => t.id != id).toList();
  }
}

final postUploadProvider =
    StateNotifierProvider<PostUploadNotifier, List<UploadTask>>((ref) {
  return PostUploadNotifier();
});
