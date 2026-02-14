import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../utils/const.dart';
import '../../../../services/PostImageUploadService.dart';
import 'package:uuid/uuid.dart';

class UploadTask {
  final String id;
  final String kind; // text, image, video, music
  final String status; // 'uploading', 'success', 'failed'
  final double progress;
  final String? errorMessage;
  final File? thumbnail; // For local preview

  UploadTask({
    required this.id,
    this.kind = 'text',
    this.status = 'uploading',
    this.progress = 0.0,
    this.errorMessage,
    this.thumbnail,
  });

  UploadTask copyWith({
    String? kind,
    String? status,
    double? progress,
    String? errorMessage,
  }) {
    return UploadTask(
      id: id,
      kind: kind ?? this.kind,
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

  String _musicTitleFromFileName(String? fileName) {
    if (fileName == null || fileName.trim().isEmpty) return 'موزیک';
    final trimmed = fileName.trim();
    final dotIndex = trimmed.lastIndexOf('.');
    final withoutExtension =
        dotIndex > 0 ? trimmed.substring(0, dotIndex) : trimmed;
    final normalized = withoutExtension
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? 'موزیک' : normalized;
  }

  Future<void> startUpload({
    required String content,
    required String userId,
    List<String>? tags, // ✅ Added tags support
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
    final hasImage = image != null || (kIsWeb && imageBytes != null);
    final hasVideo = video != null || (kIsWeb && videoBytes != null);
    final hasMusic = music != null;
    final mediaCount = [hasImage, hasVideo, hasMusic].where((v) => v).length;
    final mediaBudget = mediaCount > 0 ? 0.9 : 0.2;
    final dbWeight = 1.0 - mediaBudget;
    final perMediaWeight = mediaCount > 0 ? mediaBudget / mediaCount : 0.0;
    final kind = hasVideo
        ? 'video'
        : hasImage
            ? 'image'
            : hasMusic
                ? 'music'
                : 'text';

    // Add task to state
    state = [
      ...state,
      UploadTask(
        id: taskId,
        kind: kind,
        progress: 0.0,
        thumbnail:
            image ?? videoThumbnail, // Use image or video thumbnail for preview
      )
    ];

    unawaited(() async {
      try {
        double completedWeight = 0.0;
        void updateStageProgress(double stageProgress, double stageWeight) {
          final value = (completedWeight + (stageProgress * stageWeight))
              .clamp(0.0, 0.99)
              .toDouble();
          _updateTaskProgress(taskId, value);
        }

        // 1. Upload Media
        String? imageUrl;
        String? videoUrl;
        String? musicUrl;

        // Image Upload
        if (kIsWeb && imageBytes != null && imageName != null) {
          imageUrl = await PostImageUploadService.uploadPostImageWeb(
            imageBytes,
            imageName,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        } else if (image != null) {
          imageUrl = await PostImageUploadService.uploadPostImage(
            image,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        } else if (videoThumbnail != null && !kIsWeb) {
          imageUrl = await PostImageUploadService.uploadPostImage(
            videoThumbnail,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        }

        // Video Upload
        if (kIsWeb && videoBytes != null && videoName != null) {
          videoUrl = await PostImageUploadService.uploadVideoFileWeb(
            videoBytes,
            videoName,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        } else if (video != null) {
          videoUrl = await PostImageUploadService.uploadVideoFile(
            video,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        }

        // Music Upload
        if (music != null) {
          musicUrl = await PostImageUploadService.uploadMusicFile(
            music,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        }

        // 2. Insert into DB
        updateStageProgress(0.2, dbWeight);
        final postData = {
          'user_id': userId,
          'content': content,
          'tags': tags ?? [], // ✅ Saving tags to Supabase
          if (imageUrl != null) 'image_url': imageUrl,
          if (videoUrl != null) 'video_url': videoUrl,
          if (musicUrl != null) 'music_url': musicUrl,
          if (musicUrl != null) 'title': _musicTitleFromFileName(musicName),
          'created_at': DateTime.now().toIso8601String(),
        };

        try {
          await supabase.from('posts').insert(postData);
        } catch (e) {
          final hasTitleField = postData.containsKey('title');
          final shouldRetryWithoutTitle =
              hasTitleField && e.toString().toLowerCase().contains('title');
          if (!shouldRetryWithoutTitle) rethrow;

          final fallback = Map<String, dynamic>.from(postData)..remove('title');
          await supabase.from('posts').insert(fallback);
        }
        _updateTaskProgress(taskId, 1.0);

        // 3. Mark success and remove after delay
        _updateTaskStatus(taskId, 'success');

        // Remove from list after 3 seconds so user sees success message
        await Future.delayed(const Duration(seconds: 3));
        state = state.where((t) => t.id != taskId).toList();
      } catch (e) {
        debugPrint('Upload failed: $e');
        _updateTaskStatus(
          taskId,
          'failed',
          errorMessage: _friendlyUploadError(e.toString()),
        );
        // Keep failed tasks in list so user can retry or dismiss
      }
    }());
  }

  String _friendlyUploadError(String raw) {
    final cleaned = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (cleaned.isEmpty) return 'آپلود ناموفق بود. لطفا دوباره تلاش کنید.';
    return cleaned;
  }

  void _updateTaskStatus(String id, String status, {String? errorMessage}) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(
            status: status,
            progress: status == 'success' ? 1.0 : task.progress,
            errorMessage: errorMessage,
          )
        else
          task
    ];
  }

  void _updateTaskProgress(String id, double progress) {
    final normalized = progress.clamp(0.0, 1.0).toDouble();
    state = [
      for (final task in state)
        if (task.id == id) task.copyWith(progress: normalized) else task
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
