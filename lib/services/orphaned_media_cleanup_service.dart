import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../model/retry_queue_item.dart';
import '../security/logging_utility.dart';
import 'backend_upload_service.dart';
import 'retry_queue_service.dart';

class OrphanedMediaCleanupService {
  OrphanedMediaCleanupService._();

  static const String operation = 'delete_media_object';

  static Future<void> enqueueUrl(
    String? url, {
    String source = 'unknown',
    String reason = 'orphaned_media',
    String conversationId = 'media_cleanup',
  }) async {
    final normalizedUrl = url?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) return;

    final objectKey = BackendUploadService.objectKeyFromUrl(normalizedUrl);
    if (objectKey == null || objectKey.trim().isEmpty) {
      logInfo('Skipping media cleanup for non-managed URL: $normalizedUrl');
      return;
    }

    await enqueueObjectKey(
      objectKey,
      url: normalizedUrl,
      source: source,
      reason: reason,
      conversationId: conversationId,
    );
  }

  static Future<void> enqueueUrls(
    Iterable<String?> urls, {
    String source = 'unknown',
    String reason = 'orphaned_media',
    String conversationId = 'media_cleanup',
  }) async {
    final uniqueUrls = urls
        .map((url) => url?.trim())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toSet();

    for (final url in uniqueUrls) {
      await enqueueUrl(
        url,
        source: source,
        reason: reason,
        conversationId: conversationId,
      );
    }
  }

  static Future<void> enqueueObjectKey(
    String objectKey, {
    String? url,
    String source = 'unknown',
    String reason = 'orphaned_media',
    String conversationId = 'media_cleanup',
  }) async {
    final normalizedKey = objectKey.trim();
    if (normalizedKey.isEmpty) return;

    final id = 'media_delete_${sha1.convert(utf8.encode(normalizedKey))}';
    final item = RetryQueueItem(
      id: id,
      type: RetryOperationType.deleteMessage,
      status: RetryItemStatus.pending,
      priority: RetryPriority.low,
      conversationId:
          conversationId.trim().isEmpty ? 'media_cleanup' : conversationId,
      payload: {
        'operation': operation,
        'object_key': normalizedKey,
        if (url != null && url.trim().isNotEmpty) 'url': url.trim(),
        'source': source,
        'reason': reason,
      },
      createdAt: DateTime.now(),
      maxAttempts: 20,
    );

    await RetryQueueService().enqueue(item);
  }
}
