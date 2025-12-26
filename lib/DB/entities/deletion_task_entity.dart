import 'package:isar/isar.dart';

part 'deletion_task_entity.g.dart';

@collection
class DeletionTaskEntity {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String messageId;

  late String conversationId;

  late int deletionMode; // 0: me, 1: everyone

  String? s3Key;

  late int retryCount;

  @Index()
  late int nextAttempt; // timestamp in millis

  late int timestamp; // creation timestamp
}
