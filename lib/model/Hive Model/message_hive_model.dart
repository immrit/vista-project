// message_hive_model.dart
import 'package:hive/hive.dart';

import '../message_model.dart';

part 'message_hive_model.g.dart';

@HiveType(typeId: 3)
class MessageHiveModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String conversationId;

  @HiveField(2)
  late String senderId;

  @HiveField(3)
  late String content;

  @HiveField(4)
  late DateTime createdAt;

  @HiveField(5)
  String? attachmentUrl;

  @HiveField(6)
  String? attachmentType;

  @HiveField(7)
  late bool isRead;

  @HiveField(8)
  late bool isSent;

  @HiveField(9)
  String? senderName;

  @HiveField(10)
  String? senderAvatar;

  @HiveField(11)
  late bool isMe;

  @HiveField(12)
  String? replyToMessageId;

  @HiveField(13)
  String? replyToContent;

  @HiveField(14)
  String? replyToSenderName;

  MessageHiveModel();

  // تبدیل MessageModel به MessageHiveModel
  factory MessageHiveModel.fromModel(MessageModel model) {
    final hiveModel = MessageHiveModel()
      ..id = model.id
      ..conversationId = model.conversationId
      ..senderId = model.senderId
      ..content = model.content
      ..createdAt = model.createdAt
      ..attachmentUrl = model.attachmentUrl
      ..attachmentType = model.attachmentType
      ..isRead = model.isRead
      ..isSent = model.isSent
      ..senderName = model.senderName
      ..senderAvatar = model.senderAvatar
      ..isMe = model.isMe
      ..replyToMessageId = model.replyToMessageId
      ..replyToContent = model.replyToContent
      ..replyToSenderName = model.replyToSenderName;

    return hiveModel;
  }

  // تبدیل MessageHiveModel به MessageModel
  MessageModel toModel() {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: createdAt,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      isRead: isRead,
      isSent: isSent,
      senderName: senderName,
      senderAvatar: senderAvatar,
      isMe: isMe,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
    );
  }
}
