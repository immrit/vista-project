// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageHiveModelAdapter extends TypeAdapter<MessageHiveModel> {
  @override
  final int typeId = 3;

  @override
  MessageHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MessageHiveModel()
      ..id = fields[0] as String
      ..conversationId = fields[1] as String
      ..senderId = fields[2] as String
      ..content = fields[3] as String
      ..createdAt = fields[4] as DateTime
      ..attachmentUrl = fields[5] as String?
      ..attachmentType = fields[6] as String?
      ..isRead = fields[7] as bool
      ..isSent = fields[8] as bool
      ..senderName = fields[9] as String?
      ..senderAvatar = fields[10] as String?
      ..isMe = fields[11] as bool
      ..replyToMessageId = fields[12] as String?
      ..replyToContent = fields[13] as String?
      ..replyToSenderName = fields[14] as String?;
  }

  @override
  void write(BinaryWriter writer, MessageHiveModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.conversationId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.attachmentUrl)
      ..writeByte(6)
      ..write(obj.attachmentType)
      ..writeByte(7)
      ..write(obj.isRead)
      ..writeByte(8)
      ..write(obj.isSent)
      ..writeByte(9)
      ..write(obj.senderName)
      ..writeByte(10)
      ..write(obj.senderAvatar)
      ..writeByte(11)
      ..write(obj.isMe)
      ..writeByte(12)
      ..write(obj.replyToMessageId)
      ..writeByte(13)
      ..write(obj.replyToContent)
      ..writeByte(14)
      ..write(obj.replyToSenderName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
