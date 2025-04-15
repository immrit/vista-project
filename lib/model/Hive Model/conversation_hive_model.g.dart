// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConversationHiveModelAdapter extends TypeAdapter<ConversationHiveModel> {
  @override
  final int typeId = 1;

  @override
  ConversationHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConversationHiveModel()
      ..id = fields[0] as String
      ..createdAt = fields[1] as DateTime
      ..updatedAt = fields[2] as DateTime
      ..lastMessage = fields[3] as String?
      ..lastMessageTime = fields[4] as DateTime?
      ..participants =
          (fields[5] as List).cast<ConversationParticipantHiveModel>()
      ..otherUserName = fields[6] as String?
      ..otherUserAvatar = fields[7] as String?
      ..otherUserId = fields[8] as String?
      ..hasUnreadMessages = fields[9] as bool
      ..unreadCount = fields[10] as int;
  }

  @override
  void write(BinaryWriter writer, ConversationHiveModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.updatedAt)
      ..writeByte(3)
      ..write(obj.lastMessage)
      ..writeByte(4)
      ..write(obj.lastMessageTime)
      ..writeByte(5)
      ..write(obj.participants)
      ..writeByte(6)
      ..write(obj.otherUserName)
      ..writeByte(7)
      ..write(obj.otherUserAvatar)
      ..writeByte(8)
      ..write(obj.otherUserId)
      ..writeByte(9)
      ..write(obj.hasUnreadMessages)
      ..writeByte(10)
      ..write(obj.unreadCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConversationParticipantHiveModelAdapter
    extends TypeAdapter<ConversationParticipantHiveModel> {
  @override
  final int typeId = 2;

  @override
  ConversationParticipantHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConversationParticipantHiveModel()
      ..id = fields[0] as String
      ..conversationId = fields[1] as String
      ..userId = fields[2] as String
      ..createdAt = fields[3] as DateTime
      ..lastReadTime = fields[4] as DateTime
      ..isMuted = fields[5] as bool;
  }

  @override
  void write(BinaryWriter writer, ConversationParticipantHiveModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.conversationId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.lastReadTime)
      ..writeByte(5)
      ..write(obj.isMuted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationParticipantHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
