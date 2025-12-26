import 'dart:convert';
import 'package:isar/isar.dart';
import '../../../../model/message_model.dart';

part 'message_entity.g.dart';

@collection
class MessageEntity {
  Id? isarId;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String conversationId;

  late String senderId;
  late String content;

  @Index()
  late DateTime createdAt;

  bool isMe = false;
  bool isRead = false;
  bool isSent = false;
  bool isDelivered = false; // Added
  bool isSeen = false; // Added
  bool isPending = false;
  bool? isFailed = false; // Nullable in model

  // Attachments
  String? attachmentUrl;
  String? audioUrl; // Added
  String? attachmentType;
  String? attachmentFileName;
  int? duration;
  String? localImagePath; // Added
  String? localFilePath; // Added

  // Reply
  String? replyToMessageId;
  String? replyToSenderName;
  String? replyToContent;

  // Forward
  bool isForwarded = false; // Added
  String? originalSenderId; // Added
  String? forwardedFromSenderName; // Added
  String? originalMessageId; // Added

  // Meta
  String? messageType; // Added
  String? reactionsJson;
  String? sharedPostDataJson;

  // Deletion
  bool deletedGlobally = false; // Added
  List<String>? deletedForUserIds; // Added

  String? errorMessage; // Added

  static MessageEntity fromModel(MessageModel model) {
    final entity = MessageEntity()
      ..isarId = fastHash(model.id)
      ..id = model.id
      ..conversationId = model.conversationId
      ..senderId = model.senderId
      ..content = model.content
      ..createdAt = model.createdAt
      ..isMe = model.isMe
      ..isRead = model.isRead
      ..isSent = model.isSent
      ..isDelivered = model.isDelivered
      ..isSeen = model.isSeen
      ..isPending = model.isPending
      ..isFailed = model.isFailed
      ..attachmentUrl = model.attachmentUrl
      ..audioUrl = model.audioUrl
      ..attachmentType = model.attachmentType
      ..attachmentFileName = model.attachmentFileName
      ..duration = model.duration
      ..localImagePath = model.localImagePath
      ..localFilePath = model.localFilePath
      ..replyToMessageId = model.replyToMessageId
      ..replyToSenderName = model.replyToSenderName
      ..replyToContent = model.replyToContent
      ..isForwarded = model.isForwarded
      ..originalSenderId = model.originalSenderId
      ..forwardedFromSenderName = model.forwardedFromSenderName
      ..originalMessageId = model.originalMessageId
      ..messageType = model.messageType
      ..deletedGlobally = model.deletedGlobally
      ..deletedForUserIds = model.deletedForUserIds
      ..errorMessage = model.errorMessage;

    if (model.reactions.isNotEmpty) {
      entity.reactionsJson = jsonEncode(model.reactions);
    }

    if (model.sharedPostData != null) {
      entity.sharedPostDataJson = jsonEncode(model.sharedPostData!.toJson());
    }

    return entity;
  }

  MessageModel toModel() {
    Map<String, List<String>> reactions = {};
    if (reactionsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(reactionsJson!);
        reactions = decoded
            .map((key, value) => MapEntry(key, List<String>.from(value)));
      } catch (e) {
        // quiet
      }
    }

    SharedPostData? sharedPostData;
    if (sharedPostDataJson != null) {
      try {
        sharedPostData =
            SharedPostData.fromJson(jsonDecode(sharedPostDataJson!));
      } catch (e) {
        // quiet
      }
    }

    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: createdAt,
      isMe: isMe,
      isRead: isRead,
      isSent: isSent,
      isDelivered: isDelivered,
      isSeen: isSeen,
      isPending: isPending,
      isFailed: isFailed,
      attachmentUrl: attachmentUrl,
      audioUrl: audioUrl,
      attachmentType: attachmentType,
      attachmentFileName: attachmentFileName,
      duration: duration,
      localImagePath: localImagePath,
      localFilePath: localFilePath,
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
      isForwarded: isForwarded,
      originalSenderId: originalSenderId,
      forwardedFromSenderName: forwardedFromSenderName,
      originalMessageId: originalMessageId,
      messageType: messageType,
      deletedGlobally: deletedGlobally,
      deletedForUserIds: deletedForUserIds ?? [],
      errorMessage: errorMessage,
      reactions: reactions,
      sharedPostData: sharedPostData,
    );
  }
}

int fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}
