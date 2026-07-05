import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/PostImageUploadService.dart';
import '../../../../services/audio_trim_service.dart';
import '../../../../services/local_notification_center.dart';
import '../../../../services/orphaned_media_cleanup_service.dart';
import '../../../../provider/personalized_feed_provider.dart';
import '../providers/posts_provider.dart';
import '../data/go_posts_repository.dart';
import '../../../../services/user_friendly_error_handler.dart';
import 'package:uuid/uuid.dart';

/// Everything [PostUploadNotifier.startUpload] needs, captured once so a
/// failed task can be retried later via [PostUploadNotifier.retryUpload]
/// without the caller having to keep the original arguments around.
class UploadTaskParams {
  final String content;
  final String userId;
  final List<String>? tags;
  final List<String>? mentionedUserIds;
  final File? image;
  final List<File>? images;
  final Uint8List? imageBytes;
  final String? imageName;
  final File? video;
  final Uint8List? videoBytes;
  final String? videoName;
  final File? music;
  final String? musicName;
  final int? musicStartMs;
  final int? musicEndMs;
  final File? videoThumbnail;

  const UploadTaskParams({
    required this.content,
    required this.userId,
    this.tags,
    this.mentionedUserIds,
    this.image,
    this.images,
    this.imageBytes,
    this.imageName,
    this.video,
    this.videoBytes,
    this.videoName,
    this.music,
    this.musicName,
    this.musicStartMs,
    this.musicEndMs,
    this.videoThumbnail,
  });
}

class UploadTask {
  final String id;
  final String kind; // text, image, video, music
  final String status; // 'uploading', 'success', 'failed'
  final double progress;
  final String? errorMessage;
  final File? thumbnail; // For local preview
  final UploadTaskParams _params; // retained so a failed upload can be retried

  UploadTask({
    required this.id,
    this.kind = 'text',
    this.status = 'uploading',
    this.progress = 0.0,
    this.errorMessage,
    this.thumbnail,
    required UploadTaskParams params,
  }) : _params = params;

  UploadTask copyWith({
    String? kind,
    String? status,
    double? progress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UploadTask(
      id: id,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      thumbnail: thumbnail,
      params: _params,
    );
  }
}

class PostUploadNotifier extends StateNotifier<List<UploadTask>> {
  PostUploadNotifier(this._ref) : super([]);

  final Ref _ref;

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
    final params = UploadTaskParams(
      content: content,
      userId: userId,
      tags: tags,
      mentionedUserIds: mentionedUserIds,
      image: image,
      images: images,
      imageBytes: imageBytes,
      imageName: imageName,
      video: video,
      videoBytes: videoBytes,
      videoName: videoName,
      music: music,
      musicName: musicName,
      musicStartMs: musicStartMs,
      musicEndMs: musicEndMs,
      videoThumbnail: videoThumbnail,
    );

    final taskId = _uuid.v4();
    final kind = _kindFor(params);

    state = [
      ...state,
      UploadTask(
        id: taskId,
        kind: kind,
        progress: 0.0,
        thumbnail: image ?? videoThumbnail,
        params: params,
      )
    ];

    unawaited(_showProgressNotification(taskId, kind, 0));
    unawaited(_runUpload(taskId, params));
  }

  /// Re-runs a failed task with its original arguments, reusing the same
  /// task id so it stays in the same spot in the list.
  void retryUpload(String taskId) {
    UploadTask? target;
    for (final t in state) {
      if (t.id == taskId) {
        target = t;
        break;
      }
    }
    if (target == null || target.status != 'failed') return;

    _lastNotifiedProgress.remove(taskId);
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(status: 'uploading', progress: 0.0, clearError: true)
        else
          t
    ];

    unawaited(_showProgressNotification(taskId, target.kind, 0));
    unawaited(_runUpload(taskId, target._params));
  }

  String _kindFor(UploadTaskParams p) {
    final galleryFiles =
        p.images?.where((f) => f.path.trim().isNotEmpty).toList() ??
            const <File>[];
    final hasImage = p.image != null ||
        galleryFiles.isNotEmpty ||
        (kIsWeb && p.imageBytes != null);
    final hasVideo = p.video != null || (kIsWeb && p.videoBytes != null);
    final hasMusic = p.music != null;
    return hasVideo
        ? 'video'
        : hasImage
            ? 'image'
            : hasMusic
                ? 'music'
                : 'text';
  }

  Future<void> _runUpload(String taskId, UploadTaskParams p) async {
    final galleryFiles =
        p.images?.where((f) => f.path.trim().isNotEmpty).toList() ??
            const <File>[];
    final hasImage = p.image != null ||
        galleryFiles.isNotEmpty ||
        (kIsWeb && p.imageBytes != null);
    final hasVideo = p.video != null || (kIsWeb && p.videoBytes != null);
    final hasMusic = p.music != null;
    final mediaCount = [hasImage, hasVideo, hasMusic].where((v) => v).length;
    final mediaBudget = mediaCount > 0 ? 0.9 : 0.2;
    final dbWeight = 1.0 - mediaBudget;
    final perMediaWeight = mediaCount > 0 ? mediaBudget / mediaCount : 0.0;
    final kind = _kindFor(p);

    final uploadedUrls = <String>[];
    File? trimmedMusicFile;
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
            onProgress: (prog) => updateStageProgress(prog, perImageWeight),
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
      else if (kIsWeb && p.imageBytes != null && p.imageName != null) {
        imageUrl = await PostImageUploadService.uploadPostImageWeb(
          p.imageBytes!,
          p.imageName!,
          onProgress: (prog) => updateStageProgress(prog, perMediaWeight),
        );
        if (imageUrl != null && imageUrl.isNotEmpty) {
          uploadedUrls.add(imageUrl);
        }
        completedWeight += perMediaWeight;
        _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
      } else if (p.image != null) {
        imageUrl = await PostImageUploadService.uploadPostImage(
          p.image!,
          onProgress: (prog) => updateStageProgress(prog, perMediaWeight),
        );
        if (imageUrl != null && imageUrl.isNotEmpty) {
          uploadedUrls.add(imageUrl);
        }
        completedWeight += perMediaWeight;
        _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
      } else if (p.videoThumbnail != null && !kIsWeb) {
        imageUrl = await PostImageUploadService.uploadPostImage(
          p.videoThumbnail!,
          onProgress: (prog) => updateStageProgress(prog, perMediaWeight),
        );
        if (imageUrl != null && imageUrl.isNotEmpty) {
          uploadedUrls.add(imageUrl);
        }
        completedWeight += perMediaWeight;
        _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
      }

      // Video Upload
      if (kIsWeb && p.videoBytes != null && p.videoName != null) {
        videoUrl = await PostImageUploadService.uploadVideoFileWeb(
          p.videoBytes!,
          p.videoName!,
          onProgress: (prog) => updateStageProgress(prog, perMediaWeight),
        );
        if (videoUrl != null && videoUrl.isNotEmpty) {
          uploadedUrls.add(videoUrl);
        }
        completedWeight += perMediaWeight;
        _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
      } else if (p.video != null) {
        videoUrl = await PostImageUploadService.uploadVideoFile(
          p.video!,
          onProgress: (prog) => updateStageProgress(prog, perMediaWeight),
        );
        if (videoUrl != null && videoUrl.isNotEmpty) {
          uploadedUrls.add(videoUrl);
        }
        completedWeight += perMediaWeight;
        _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
      }

      // Music Upload — trim to the selected clip *before* uploading so the
      // file that leaves the device is the clip, not the full track.
      if (p.music != null) {
        var fileToUpload = p.music!;
        final hasTrimRange = p.musicStartMs != null &&
            p.musicEndMs != null &&
            p.musicEndMs! > p.musicStartMs!;

        if (hasTrimRange) {
          // Small fixed slice of this media's weight budget for the local
          // trim step, so the progress bar visibly moves before the actual
          // upload (which reports its own 0..1 progress) takes over.
          updateStageProgress(0.05, perMediaWeight);
          trimmedMusicFile = await AudioTrimService.trim(
            source: p.music!,
            start: Duration(milliseconds: p.musicStartMs!),
            end: Duration(milliseconds: p.musicEndMs!),
          );
          fileToUpload = trimmedMusicFile;
        }

        musicUrl = await PostImageUploadService.uploadMusicFile(
          fileToUpload,
          onProgress: (prog) => updateStageProgress(
            hasTrimRange ? 0.05 + prog * 0.95 : prog,
            perMediaWeight,
          ),
        );
        if (musicUrl.isNotEmpty) {
          uploadedUrls.add(musicUrl);
        }
        completedWeight += perMediaWeight;
        _updateTaskProgress(taskId, completedWeight.clamp(0.0, 0.99));
      }

      // 2. Insert into DB
      updateStageProgress(0.2, dbWeight);
      final musicTitle = _musicTitleFromFileName(p.musicName);

      if (!await TokenStorage.hasValidSession()) {
        throw StateError('User is not authenticated');
      }
      final createdPost = await GoPostsRepository().createPost(
        content: p.content,
        tags: p.tags ?? const <String>[],
        imageUrl: imageUrl,
        imageUrls: galleryUrls.length > 1 ? galleryUrls : null,
        videoUrl: videoUrl,
        musicUrl: musicUrl,
        musicTitle: musicUrl != null ? musicTitle : null,
        // The uploaded file is already the trimmed clip (starts at 0), so
        // there is no remaining offset to record.
        musicStartMs: musicUrl != null ? 0 : null,
        musicEndMs: null,
      );

      // Tag mentioned users (best-effort; post already created).
      final mentions = p.mentionedUserIds
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

      // Own posts are excluded server-side from both feed queries (explore
      // ranks the viewer's own content out; following only ever returns
      // other authors), so insert it locally to close that gap.
      _ref.read(personalizedFeedProvider.notifier).prependOwnPost(createdPost);
      _ref.read(fetchFollowingPostsProvider.notifier).prependOwnPost(createdPost);

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
    } finally {
      if (trimmedMusicFile != null) {
        unawaited(trimmedMusicFile.delete().catchError((_) => trimmedMusicFile!));
      }
    }
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
  return PostUploadNotifier(ref);
});
