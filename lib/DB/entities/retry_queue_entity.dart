import 'dart:convert';
import 'package:isar/isar.dart';
import '../../model/retry_queue_item.dart';

part 'retry_queue_entity.g.dart';

@collection
class RetryQueueEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String itemId;

  @enumerated
  late RetryOperationType type;

  @enumerated
  late RetryItemStatus status;

  @enumerated
  late RetryPriority priority;

  late int attemptCount;
  late int maxAttempts;

  @Index()
  late String conversationId;

  late String payloadJson;

  late DateTime createdAt;
  DateTime? lastAttemptAt;
  String? errorMessage;

  // تبدیل به مدل
  RetryQueueItem toModel() {
    return RetryQueueItem(
      id: itemId,
      type: type,
      status: status,
      priority: priority,
      attemptCount: attemptCount,
      maxAttempts: maxAttempts,
      conversationId: conversationId,
      payload: jsonDecode(payloadJson) as Map<String, dynamic>,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt,
      errorMessage: errorMessage,
    );
  }

  // ساخت از مدل
  static RetryQueueEntity fromModel(RetryQueueItem model) {
    return RetryQueueEntity()
      ..itemId = model.id
      ..type = model.type
      ..status = model.status
      ..priority = model.priority
      ..attemptCount = model.attemptCount
      ..maxAttempts = model.maxAttempts
      ..conversationId = model.conversationId
      ..payloadJson = jsonEncode(model.payload)
      ..createdAt = model.createdAt
      ..lastAttemptAt = model.lastAttemptAt
      ..errorMessage = model.errorMessage;
  }
}
