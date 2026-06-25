import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/PostImageUploadService.dart';
import '../../../../services/local_notification_center.dart';
import '../../../../services/orphaned_media_cleanup_service.dart';
import '../../auth/providers/auth_controller.dart';
import '../data/go_posts_repository.dart';
import '../../../../services/user_friendly_error_handler.dart';
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
  final _notif = LocalNotificationCenter.plugin;

  // کانال اختصاصی آپلود
  static const _uploadChannelId = 'post_upload_progress';
  static const _uploadChannelName = 'آپلود پست';
  static const _socialChannelId = 'social_notify';

  String _kindLabel(String kind) {
    switch (kind) {
      case 'video':
        return 'ویدیو';
      case 'music':
        return 'موزیک';
      case 'image':
        return 'تصویر';
      default:
        return 'پست';
    }
  }

  int _notifId(String taskId) => taskId.hashCode.abs() % 100000;

  Future<void> _showProgressNotification(
    String taskId,
    String kind,
    int progress,
  ) async {
    if (kIsWeb) return;
    try {
      final label = _kindLabel(kind);
      final id = _notifId(taskId);
      await _notif.show(
        id: id,
        title: 'در حال ارسال $label...',
        body: '$progress٪ آپلود شده',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _uploadChannelId,
            _uploadChannelName,
            channelDescription: 'پیشرفت آپلود محتوای پست',
            importance: Importance.low,
            priority: Priority.low,
            showProgress: true,
            maxProgress: 100,
            progress: progress,
            ongoing: true,
            onlyAlertOnce: true,
            enableVibration: false,
            playSound: false,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: false,
            presentSound: false,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _showCompletionNotification(
    String taskId,
    String kind, {
    required bool success,
    String? errorMessage,
  }) async {
    if (kIsWeb) return;
    try {
      final id = _notifId(taskId);
      final label = _kindLabel(kind);
      // Cancel ongoing progress notification
      await _notif.cancel(id: id);

      await _notif.show(
        id: id + 1,
        title:
            success ? '$label با موفقیت ارسال شد ✓' : 'ارسال $label ناموفق بود',
        body: success
            ? 'پست شما در فید ویستا منتشر شد'
            : (errorMessage ?? 'لطفاً دوباره تلاش کنید'),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _socialChannelId,
            'فعالیت‌های اجتماعی',
            channelDescription: 'اعلان‌های اجتماعی ویستا',
            importance:
                success ? Importance.defaultImportance : Importance.high,
            priority: success ? Priority.defaultPriority : Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: success,
            playSound: success,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: success,
          ),
        ),
      );
    } catch (_) {}
  }

  // آخرین درصدی که نوتیفیکیشن نمایش دادیم (برای جلوگیری از ارسال بیش از حد)
  final Map<String, int> _lastNotifiedProgress = {};

  void _maybeNotifyProgress(String taskId, String kind, double progress) {
    final pct = (progress * 100).round();
    final last = _lastNotifiedProgress[taskId] ?? -1;
    // فقط هر ۱۰٪ یک‌بار اطلاع‌رسانی کن
    if (pct - last >= 10 || pct == 100) {
      _lastNotifiedProgress[taskId] = pct;
      unawaited(_showProgressNotification(taskId, kind, pct));
    }
  }

  String _musicTitleFromFileName(String? fileName) {
    if (fileName == null || fileName.trim().isEmpty) return 'موزیک';
    final trimmed = fileName.trim();
    final dotIndex = trimmed.lastIndexOf('.');
    final withoutExtension =
        dotIndex > 0 ? trimmed.substring(0, dotIndex) : trimmed;
    // Keep the "Artist - Title" dash so the player can split singer from track.
    // Only underscores collapse to spaces; dashes normalize to " - ".
    final normalized = withoutExtension
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s*-\s*'), ' - ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? 'موزیک' : normalized;
  }

  Future<void> startUpload({
    required String content,
    required String userId,
    List<String>? tags,
    List<String>? mentionedUserIds,
    File? image,
    List<File>? images,
    Uint8List? imageBytes,
    String? imageName,
    File? video,
    Uint8List? videoBytes,
    String? videoName,
    File? music,
    String? musicName,
    int? musicStartMs,
    int? musicEndMs,
    File? videoThumbnail,
  }) async {
    final taskId = _uuid.v4();
    final galleryFiles =
        images?.where((f) => f.path.trim().isNotEmpty).toList() ??
            const <File>[];
    final hasImage = image != null ||
        galleryFiles.isNotEmpty ||
        (kIsWeb && imageBytes != null);
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

    // نمایش نوتیفیکیشن شروع آپلود
    unawaited(_showProgressNotification(taskId, kind, 0));

    unawaited(() async {
      final uploadedUrls = <String>[];
      try {
        double completedWeight = 0.0;
        void updateStageProgress(double stageProgress, double stageWeight) {
          final value = (completedWeight + (stageProgress * stageWeight))
              .clamp(0.0, 0.99)
              .toDouble();
          _updateTaskProgress(taskId, value);
          _maybeNotifyProgress(taskId, kind, value);
        }

        // 1. Upload Media
        String? imageUrl;
        final galleryUrls = <String>[];
        String? videoUrl;
        String? musicUrl;

        // Multi-image gallery (mobile carousel): upload each, cover = first.
        if (galleryFiles.isNotEmpty) {
          final perImageWeight = perMediaWeight / galleryFiles.length;
          for (final file in galleryFiles) {
            final url = await PostImageUploadService.uploadPostImage(
              file,
              onProgress: (p) => updateStageProgress(p, perImageWeight),
            );
            if (url != null && url.isNotEmpty) {
              galleryUrls.add(url);
              uploadedUrls.add(url);
            }
            completedWeight += perImageWeight;
            _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
          }
          if (galleryUrls.isNotEmpty) {
            imageUrl = galleryUrls.first; // cover
          }
        }
        // Image Upload
        else if (kIsWeb && imageBytes != null && imageName != null) {
          imageUrl = await PostImageUploadService.uploadPostImageWeb(
            imageBytes,
            imageName,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          if (imageUrl != null && imageUrl.isNotEmpty) {
            uploadedUrls.add(imageUrl);
          }
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        } else if (image != null) {
          imageUrl = await PostImageUploadService.uploadPostImage(
            image,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          if (imageUrl != null && imageUrl.isNotEmpty) {
            uploadedUrls.add(imageUrl);
          }
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        } else if (videoThumbnail != null && !kIsWeb) {
          imageUrl = await PostImageUploadService.uploadPostImage(
            videoThumbnail,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          if (imageUrl != null && imageUrl.isNotEmpty) {
            uploadedUrls.add(imageUrl);
          }
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
          if (videoUrl != null && videoUrl.isNotEmpty) {
            uploadedUrls.add(videoUrl);
          }
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        } else if (video != null) {
          videoUrl = await PostImageUploadService.uploadVideoFile(
            video,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          if (videoUrl != null && videoUrl.isNotEmpty) {
            uploadedUrls.add(videoUrl);
          }
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        }

        // Music Upload
        if (music != null) {
          musicUrl = await PostImageUploadService.uploadMusicFile(
            music,
            onProgress: (p) => updateStageProgress(p, perMediaWeight),
          );
          if (musicUrl.isNotEmpty) {
            uploadedUrls.add(musicUrl);
          }
          completedWeight += perMediaWeight;
          _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
        }

        // 2. Insert into DB
        updateStageProgress(0.2, dbWeight);
        final musicTitle = _musicTitleFromFileName(musicName);

        if (!await TokenStorage.hasValidSession()) {
          throw StateError('User is not authenticated');
        }
        final createdPost = await GoPostsRepository().createPost(
          content: content,
          tags: tags ?? const <String>[],
          imageUrl: imageUrl,
          imageUrls: galleryUrls.length > 1 ? galleryUrls : null,
          videoUrl: videoUrl,
          musicUrl: musicUrl,
          musicTitle: musicUrl != null ? musicTitle : null,
          musicStartMs: musicStartMs,
          musicEndMs: musicEndMs,
        );

        // Tag mentioned users (best-effort; post already created).
        final mentions = mentionedUserIds
                ?.where((id) => id.trim().isNotEmpty)
                .toSet()
                .toList(growable: false) ??
            const <String>[];
        if (mentions.isNotEmpty && createdPost.id.isNotEmpty) {
          try {
            await GoPostsRepository().addPostMentions(
              postId: createdPost.id,
              userIds: mentions,
            );
          } catch (e) {
            debugPrint('Post mentions failed (non-fatal): $e');
          }
        }
        _updateTaskProgress(taskId, 1.0);

        // 3. Mark success, show completion notification, and remove after delay
        _updateTaskStatus(taskId, 'success');
        _lastNotifiedProgress.remove(taskId);
        unawaited(_showCompletionNotification(taskId, kind, success: true));

        // Remove from list after 3.5 seconds so user sees success state
        await Future.delayed(const Duration(milliseconds: 3500));
        state = state.where((t) => t.id != taskId).toList();
      } catch (e) {
        debugPrint('Upload failed: $e');
        unawaited(OrphanedMediaCleanupService.enqueueUrls(
          uploadedUrls,
          source: 'post_upload',
          reason: 'create_post_failed',
        ));
        final errMsg = UserFriendlyErrorHandler.getFriendlyMessage(e,
            context: 'post_upload');
        _updateTaskStatus(taskId, 'failed', errorMessage: errMsg);
        _lastNotifiedProgress.remove(taskId);
        unawaited(_showCompletionNotification(
          taskId,
          kind,
          success: false,
          errorMessage: errMsg,
        ));
      }
    }());
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
