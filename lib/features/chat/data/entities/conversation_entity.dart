import 'package:isar/isar.dart';
import '../../../../model/conversation_model.dart';
import '../../../../services/telegram_read_receipt_service.dart'; // ✅ Correct import

part 'conversation_entity.g.dart';

@collection
class ConversationEntity {
  Id? isarId;

  @Index(unique: true, replace: true)
  late String id;

  late DateTime createdAt;
  late DateTime updatedAt;

  String? lastMessage;
  DateTime? lastMessageTime;

  // Embedded participants
  List<ParticipantEntity>? participants;

  // Derived/Cached UI fields
  String? otherUserName;
  String? otherUserAvatar;
  String? otherUserId;

  bool hasUnreadMessages = false;
  int unreadCount = 0;
  bool isPinned = false;
  bool isMuted = false;
  bool isArchived = false;

  String? lastMessageType;
  bool isLastMessageFromMe = false;
  String? lastMessageSenderId;
  String? lastMessageDeliveryStatus; // Stored as String

  // Profile data
  bool? allowProfileZoom;
  String? otherUserBio;
  DateTime? otherUserCreatedAt;
  bool? isBlocked;
  bool? isVerified;

  static ConversationEntity fromModel(ConversationModel model) {
    return ConversationEntity()
      ..isarId = fastHash(model.id)
      ..id = model.id
      ..createdAt = model.createdAt
      ..updatedAt = model.updatedAt
      ..lastMessage = model.lastMessage
      ..lastMessageTime = model.lastMessageTime
      ..participants =
          model.participants.map(ParticipantEntity.fromModel).toList()
      ..otherUserName = model.otherUserName
      ..otherUserAvatar = model.otherUserAvatar
      ..otherUserId = model.otherUserId
      ..hasUnreadMessages = model.hasUnreadMessages
      ..unreadCount = model.unreadCount
      ..isPinned = model.isPinned
      ..isMuted = model.isMuted
      ..isArchived = model.isArchived
      ..lastMessageType = model.lastMessageType
      ..isLastMessageFromMe = model.isLastMessageFromMe
      ..lastMessageSenderId = model.lastMessageSenderId
      ..lastMessageDeliveryStatus = model.lastMessageDeliveryStatus.name
      ..allowProfileZoom = model.allowProfileZoom
      ..otherUserBio = model.otherUserBio
      ..otherUserCreatedAt = model.otherUserCreatedAt
      ..isBlocked = model.isBlocked
      ..isVerified = model.isVerified;
  }

  ConversationModel toModel() {
    return ConversationModel(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      participants: participants?.map((p) => p.toModel()).toList() ?? [],
      otherUserName: otherUserName,
      otherUserAvatar: otherUserAvatar,
      otherUserId: otherUserId,
      hasUnreadMessages: hasUnreadMessages,
      unreadCount: unreadCount,
      isPinned: isPinned,
      isMuted: isMuted,
      isArchived: isArchived,
      lastMessageType: lastMessageType,
      isLastMessageFromMe: isLastMessageFromMe,
      lastMessageSenderId: lastMessageSenderId,
      lastMessageDeliveryStatus: _parseStatus(lastMessageDeliveryStatus),
      allowProfileZoom: allowProfileZoom,
      otherUserBio: otherUserBio,
      otherUserCreatedAt: otherUserCreatedAt,
      isBlocked: isBlocked,
      isVerified: isVerified,
    );
  }

  MessageDeliveryStatus _parseStatus(String? status) {
    if (status == null) return MessageDeliveryStatus.sent;
    return MessageDeliveryStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => MessageDeliveryStatus.sent,
    );
  }
}

@embedded
class ParticipantEntity {
  late String id;
  late String conversationId;
  late String userId;
  late DateTime createdAt;
  DateTime? lastReadTime;
  bool isMuted = false;

  static ParticipantEntity fromModel(ConversationParticipantModel model) {
    return ParticipantEntity()
      ..id = model.id
      ..conversationId = model.conversationId
      ..userId = model.userId
      ..createdAt = model.createdAt
      ..lastReadTime = model.lastReadTime
      ..isMuted = model.isMuted;
  }

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

/// FNV-1a 64bit hash algorithm optimized for Dart Strings
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
