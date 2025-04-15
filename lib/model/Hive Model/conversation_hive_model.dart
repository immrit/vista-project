// conversation_hive_model.dart
import 'package:hive/hive.dart';
import 'package:Vista/model/conversation_model.dart';

part 'conversation_hive_model.g.dart';

@HiveType(typeId: 1)
class ConversationHiveModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late DateTime createdAt;

  @HiveField(2)
  late DateTime updatedAt;

  @HiveField(3)
  String? lastMessage;

  @HiveField(4)
  DateTime? lastMessageTime;

  @HiveField(5)
  late List<ConversationParticipantHiveModel> participants;

  @HiveField(6)
  String? otherUserName;

  @HiveField(7)
  String? otherUserAvatar;

  @HiveField(8)
  String? otherUserId;

  @HiveField(9)
  late bool hasUnreadMessages;

  @HiveField(10)
  late int unreadCount;

  ConversationHiveModel();

  // تبدیل ConversationModel به ConversationHiveModel
  factory ConversationHiveModel.fromModel(ConversationModel model) {
    final hiveModel = ConversationHiveModel()
      ..id = model.id
      ..createdAt = model.createdAt
      ..updatedAt = model.updatedAt
      ..lastMessage = model.lastMessage
      ..lastMessageTime = model.lastMessageTime
      ..participants = model.participants
          .map((p) => ConversationParticipantHiveModel.fromModel(p))
          .toList()
      ..otherUserName = model.otherUserName
      ..otherUserAvatar = model.otherUserAvatar
      ..otherUserId = model.otherUserId
      ..hasUnreadMessages = model.hasUnreadMessages
      ..unreadCount = model.unreadCount;

    return hiveModel;
  }

  // تبدیل ConversationHiveModel به ConversationModel
  ConversationModel toModel() {
    return ConversationModel(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      participants: participants.map((p) => p.toModel()).toList(),
      otherUserName: otherUserName,
      otherUserAvatar: otherUserAvatar,
      otherUserId: otherUserId,
      hasUnreadMessages: hasUnreadMessages,
      unreadCount: unreadCount,
    );
  }
}

@HiveType(typeId: 2)
class ConversationParticipantHiveModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String conversationId;

  @HiveField(2)
  late String userId;

  @HiveField(3)
  late DateTime createdAt;

  @HiveField(4)
  late DateTime lastReadTime;

  @HiveField(5)
  late bool isMuted;

  ConversationParticipantHiveModel();

  // تبدیل ConversationParticipantModel به ConversationParticipantHiveModel
  factory ConversationParticipantHiveModel.fromModel(
      ConversationParticipantModel model) {
    final hiveModel = ConversationParticipantHiveModel()
      ..id = model.id
      ..conversationId = model.conversationId
      ..userId = model.userId
      ..createdAt = model.createdAt
      ..lastReadTime = model.lastReadTime
      ..isMuted = model.isMuted;

    return hiveModel;
  }

  // تبدیل ConversationParticipantHiveModel به ConversationParticipantModel
  ConversationParticipantModel toModel() {
    return ConversationParticipantModel(
      id: id,
      conversationId: conversationId,
      userId: userId,
      createdAt: createdAt,
      lastReadTime: lastReadTime,
      isMuted: isMuted,
    );
  }
}
