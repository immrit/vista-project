// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMessageEntityCollection on Isar {
  IsarCollection<MessageEntity> get messageEntitys => this.collection();
}

const MessageEntitySchema = CollectionSchema(
  name: r'MessageEntity',
  id: 2569526783852321106,
  properties: {
    r'attachmentFileName': PropertySchema(
      id: 0,
      name: r'attachmentFileName',
      type: IsarType.string,
    ),
    r'attachmentMimeType': PropertySchema(
      id: 1,
      name: r'attachmentMimeType',
      type: IsarType.string,
    ),
    r'attachmentSizeBytes': PropertySchema(
      id: 2,
      name: r'attachmentSizeBytes',
      type: IsarType.long,
    ),
    r'attachmentType': PropertySchema(
      id: 3,
      name: r'attachmentType',
      type: IsarType.string,
    ),
    r'attachmentUrl': PropertySchema(
      id: 4,
      name: r'attachmentUrl',
      type: IsarType.string,
    ),
    r'audioAlbum': PropertySchema(
      id: 5,
      name: r'audioAlbum',
      type: IsarType.string,
    ),
    r'audioArtist': PropertySchema(
      id: 6,
      name: r'audioArtist',
      type: IsarType.string,
    ),
    r'audioTitle': PropertySchema(
      id: 7,
      name: r'audioTitle',
      type: IsarType.string,
    ),
    r'audioUrl': PropertySchema(
      id: 8,
      name: r'audioUrl',
      type: IsarType.string,
    ),
    r'content': PropertySchema(
      id: 9,
      name: r'content',
      type: IsarType.string,
    ),
    r'conversationId': PropertySchema(
      id: 10,
      name: r'conversationId',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 11,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'deletedForUserIds': PropertySchema(
      id: 12,
      name: r'deletedForUserIds',
      type: IsarType.stringList,
    ),
    r'deletedGlobally': PropertySchema(
      id: 13,
      name: r'deletedGlobally',
      type: IsarType.bool,
    ),
    r'duration': PropertySchema(
      id: 14,
      name: r'duration',
      type: IsarType.long,
    ),
    r'errorMessage': PropertySchema(
      id: 15,
      name: r'errorMessage',
      type: IsarType.string,
    ),
    r'forwardedFromSenderName': PropertySchema(
      id: 16,
      name: r'forwardedFromSenderName',
      type: IsarType.string,
    ),
    r'id': PropertySchema(
      id: 17,
      name: r'id',
      type: IsarType.string,
    ),
    r'isDelivered': PropertySchema(
      id: 18,
      name: r'isDelivered',
      type: IsarType.bool,
    ),
    r'isFailed': PropertySchema(
      id: 19,
      name: r'isFailed',
      type: IsarType.bool,
    ),
    r'isForwarded': PropertySchema(
      id: 20,
      name: r'isForwarded',
      type: IsarType.bool,
    ),
    r'isMe': PropertySchema(
      id: 21,
      name: r'isMe',
      type: IsarType.bool,
    ),
    r'isPending': PropertySchema(
      id: 22,
      name: r'isPending',
      type: IsarType.bool,
    ),
    r'isRead': PropertySchema(
      id: 23,
      name: r'isRead',
      type: IsarType.bool,
    ),
    r'isSeen': PropertySchema(
      id: 24,
      name: r'isSeen',
      type: IsarType.bool,
    ),
    r'isSent': PropertySchema(
      id: 25,
      name: r'isSent',
      type: IsarType.bool,
    ),
    r'isUploading': PropertySchema(
      id: 26,
      name: r'isUploading',
      type: IsarType.bool,
    ),
    r'localFilePath': PropertySchema(
      id: 27,
      name: r'localFilePath',
      type: IsarType.string,
    ),
    r'localImagePath': PropertySchema(
      id: 28,
      name: r'localImagePath',
      type: IsarType.string,
    ),
    r'messageType': PropertySchema(
      id: 29,
      name: r'messageType',
      type: IsarType.string,
    ),
    r'originalMessageId': PropertySchema(
      id: 30,
      name: r'originalMessageId',
      type: IsarType.string,
    ),
    r'originalSenderId': PropertySchema(
      id: 31,
      name: r'originalSenderId',
      type: IsarType.string,
    ),
    r'reactionsJson': PropertySchema(
      id: 32,
      name: r'reactionsJson',
      type: IsarType.string,
    ),
    r'replyToContent': PropertySchema(
      id: 33,
      name: r'replyToContent',
      type: IsarType.string,
    ),
    r'replyToMessageId': PropertySchema(
      id: 34,
      name: r'replyToMessageId',
      type: IsarType.string,
    ),
    r'replyToSenderName': PropertySchema(
      id: 35,
      name: r'replyToSenderName',
      type: IsarType.string,
    ),
    r'senderId': PropertySchema(
      id: 36,
      name: r'senderId',
      type: IsarType.string,
    ),
    r'sharedPostDataJson': PropertySchema(
      id: 37,
      name: r'sharedPostDataJson',
      type: IsarType.string,
    ),
    r'storyReplyDataJson': PropertySchema(
      id: 38,
      name: r'storyReplyDataJson',
      type: IsarType.string,
    ),
    r'uploadProgress': PropertySchema(
      id: 39,
      name: r'uploadProgress',
      type: IsarType.double,
    )
  },
  estimateSize: _messageEntityEstimateSize,
  serialize: _messageEntitySerialize,
  deserialize: _messageEntityDeserialize,
  deserializeProp: _messageEntityDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'id': IndexSchema(
      id: -3268401673993471357,
      name: r'id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'id',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'conversationId': IndexSchema(
      id: 2945908346256754300,
      name: r'conversationId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conversationId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _messageEntityGetId,
  getLinks: _messageEntityGetLinks,
  attach: _messageEntityAttach,
  version: '3.1.0+1',
);

int _messageEntityEstimateSize(
  MessageEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.attachmentFileName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.attachmentMimeType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.attachmentType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.attachmentUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.audioAlbum;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.audioArtist;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.audioTitle;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.audioUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.content.length * 3;
  bytesCount += 3 + object.conversationId.length * 3;
  {
    final list = object.deletedForUserIds;
    if (list != null) {
      bytesCount += 3 + list.length * 3;
      {
        for (var i = 0; i < list.length; i++) {
          final value = list[i];
          bytesCount += value.length * 3;
        }
      }
    }
  }
  {
    final value = object.errorMessage;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.forwardedFromSenderName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.id.length * 3;
  {
    final value = object.localFilePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.localImagePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.messageType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.originalMessageId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.originalSenderId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.reactionsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.replyToContent;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.replyToMessageId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.replyToSenderName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.senderId.length * 3;
  {
    final value = object.sharedPostDataJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.storyReplyDataJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _messageEntitySerialize(
  MessageEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.attachmentFileName);
  writer.writeString(offsets[1], object.attachmentMimeType);
  writer.writeLong(offsets[2], object.attachmentSizeBytes);
  writer.writeString(offsets[3], object.attachmentType);
  writer.writeString(offsets[4], object.attachmentUrl);
  writer.writeString(offsets[5], object.audioAlbum);
  writer.writeString(offsets[6], object.audioArtist);
  writer.writeString(offsets[7], object.audioTitle);
  writer.writeString(offsets[8], object.audioUrl);
  writer.writeString(offsets[9], object.content);
  writer.writeString(offsets[10], object.conversationId);
  writer.writeDateTime(offsets[11], object.createdAt);
  writer.writeStringList(offsets[12], object.deletedForUserIds);
  writer.writeBool(offsets[13], object.deletedGlobally);
  writer.writeLong(offsets[14], object.duration);
  writer.writeString(offsets[15], object.errorMessage);
  writer.writeString(offsets[16], object.forwardedFromSenderName);
  writer.writeString(offsets[17], object.id);
  writer.writeBool(offsets[18], object.isDelivered);
  writer.writeBool(offsets[19], object.isFailed);
  writer.writeBool(offsets[20], object.isForwarded);
  writer.writeBool(offsets[21], object.isMe);
  writer.writeBool(offsets[22], object.isPending);
  writer.writeBool(offsets[23], object.isRead);
  writer.writeBool(offsets[24], object.isSeen);
  writer.writeBool(offsets[25], object.isSent);
  writer.writeBool(offsets[26], object.isUploading);
  writer.writeString(offsets[27], object.localFilePath);
  writer.writeString(offsets[28], object.localImagePath);
  writer.writeString(offsets[29], object.messageType);
  writer.writeString(offsets[30], object.originalMessageId);
  writer.writeString(offsets[31], object.originalSenderId);
  writer.writeString(offsets[32], object.reactionsJson);
  writer.writeString(offsets[33], object.replyToContent);
  writer.writeString(offsets[34], object.replyToMessageId);
  writer.writeString(offsets[35], object.replyToSenderName);
  writer.writeString(offsets[36], object.senderId);
  writer.writeString(offsets[37], object.sharedPostDataJson);
  writer.writeString(offsets[38], object.storyReplyDataJson);
  writer.writeDouble(offsets[39], object.uploadProgress);
}

MessageEntity _messageEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MessageEntity();
  object.attachmentFileName = reader.readStringOrNull(offsets[0]);
  object.attachmentMimeType = reader.readStringOrNull(offsets[1]);
  object.attachmentSizeBytes = reader.readLongOrNull(offsets[2]);
  object.attachmentType = reader.readStringOrNull(offsets[3]);
  object.attachmentUrl = reader.readStringOrNull(offsets[4]);
  object.audioAlbum = reader.readStringOrNull(offsets[5]);
  object.audioArtist = reader.readStringOrNull(offsets[6]);
  object.audioTitle = reader.readStringOrNull(offsets[7]);
  object.audioUrl = reader.readStringOrNull(offsets[8]);
  object.content = reader.readString(offsets[9]);
  object.conversationId = reader.readString(offsets[10]);
  object.createdAt = reader.readDateTime(offsets[11]);
  object.deletedForUserIds = reader.readStringList(offsets[12]);
  object.deletedGlobally = reader.readBool(offsets[13]);
  object.duration = reader.readLongOrNull(offsets[14]);
  object.errorMessage = reader.readStringOrNull(offsets[15]);
  object.forwardedFromSenderName = reader.readStringOrNull(offsets[16]);
  object.id = reader.readString(offsets[17]);
  object.isDelivered = reader.readBool(offsets[18]);
  object.isFailed = reader.readBoolOrNull(offsets[19]);
  object.isForwarded = reader.readBool(offsets[20]);
  object.isMe = reader.readBool(offsets[21]);
  object.isPending = reader.readBool(offsets[22]);
  object.isRead = reader.readBool(offsets[23]);
  object.isSeen = reader.readBool(offsets[24]);
  object.isSent = reader.readBool(offsets[25]);
  object.isUploading = reader.readBool(offsets[26]);
  object.isarId = id;
  object.localFilePath = reader.readStringOrNull(offsets[27]);
  object.localImagePath = reader.readStringOrNull(offsets[28]);
  object.messageType = reader.readStringOrNull(offsets[29]);
  object.originalMessageId = reader.readStringOrNull(offsets[30]);
  object.originalSenderId = reader.readStringOrNull(offsets[31]);
  object.reactionsJson = reader.readStringOrNull(offsets[32]);
  object.replyToContent = reader.readStringOrNull(offsets[33]);
  object.replyToMessageId = reader.readStringOrNull(offsets[34]);
  object.replyToSenderName = reader.readStringOrNull(offsets[35]);
  object.senderId = reader.readString(offsets[36]);
  object.sharedPostDataJson = reader.readStringOrNull(offsets[37]);
  object.storyReplyDataJson = reader.readStringOrNull(offsets[38]);
  object.uploadProgress = reader.readDoubleOrNull(offsets[39]);
  return object;
}

P _messageEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readDateTime(offset)) as P;
    case 12:
      return (reader.readStringList(offset)) as P;
    case 13:
      return (reader.readBool(offset)) as P;
    case 14:
      return (reader.readLongOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readBool(offset)) as P;
    case 19:
      return (reader.readBoolOrNull(offset)) as P;
    case 20:
      return (reader.readBool(offset)) as P;
    case 21:
      return (reader.readBool(offset)) as P;
    case 22:
      return (reader.readBool(offset)) as P;
    case 23:
      return (reader.readBool(offset)) as P;
    case 24:
      return (reader.readBool(offset)) as P;
    case 25:
      return (reader.readBool(offset)) as P;
    case 26:
      return (reader.readBool(offset)) as P;
    case 27:
      return (reader.readStringOrNull(offset)) as P;
    case 28:
      return (reader.readStringOrNull(offset)) as P;
    case 29:
      return (reader.readStringOrNull(offset)) as P;
    case 30:
      return (reader.readStringOrNull(offset)) as P;
    case 31:
      return (reader.readStringOrNull(offset)) as P;
    case 32:
      return (reader.readStringOrNull(offset)) as P;
    case 33:
      return (reader.readStringOrNull(offset)) as P;
    case 34:
      return (reader.readStringOrNull(offset)) as P;
    case 35:
      return (reader.readStringOrNull(offset)) as P;
    case 36:
      return (reader.readString(offset)) as P;
    case 37:
      return (reader.readStringOrNull(offset)) as P;
    case 38:
      return (reader.readStringOrNull(offset)) as P;
    case 39:
      return (reader.readDoubleOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _messageEntityGetId(MessageEntity object) {
  return object.isarId ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _messageEntityGetLinks(MessageEntity object) {
  return [];
}

void _messageEntityAttach(
    IsarCollection<dynamic> col, Id id, MessageEntity object) {
  object.isarId = id;
}

extension MessageEntityByIndex on IsarCollection<MessageEntity> {
  Future<MessageEntity?> getById(String id) {
    return getByIndex(r'id', [id]);
  }

  MessageEntity? getByIdSync(String id) {
    return getByIndexSync(r'id', [id]);
  }

  Future<bool> deleteById(String id) {
    return deleteByIndex(r'id', [id]);
  }

  bool deleteByIdSync(String id) {
    return deleteByIndexSync(r'id', [id]);
  }

  Future<List<MessageEntity?>> getAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndex(r'id', values);
  }

  List<MessageEntity?> getAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'id', values);
  }

  Future<int> deleteAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'id', values);
  }

  int deleteAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'id', values);
  }

  Future<Id> putById(MessageEntity object) {
    return putByIndex(r'id', object);
  }

  Id putByIdSync(MessageEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllById(List<MessageEntity> objects) {
    return putAllByIndex(r'id', objects);
  }

  List<Id> putAllByIdSync(List<MessageEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'id', objects, saveLinks: saveLinks);
  }
}

extension MessageEntityQueryWhereSort
    on QueryBuilder<MessageEntity, MessageEntity, QWhere> {
  QueryBuilder<MessageEntity, MessageEntity, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }
}

extension MessageEntityQueryWhere
    on QueryBuilder<MessageEntity, MessageEntity, QWhereClause> {
  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause> isarIdEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause>
      isarIdNotEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause>
      isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause> isarIdLessThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause> isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerIsarId,
        includeLower: includeLower,
        upper: upperIsarId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause> idEqualTo(
      String id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'id',
        value: [id],
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause> idNotEqualTo(
      String id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [],
              upper: [id],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [id],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [id],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [],
              upper: [id],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause>
      conversationIdEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'conversationId',
        value: [conversationId],
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause>
      conversationIdNotEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [],
              upper: [conversationId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [conversationId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [conversationId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [],
              upper: [conversationId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause>
      createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause>
      createdAtNotEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause>
      createdAtGreaterThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [createdAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause>
      createdAtLessThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [],
        upper: [createdAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterWhereClause>
      createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [lowerCreatedAt],
        includeLower: includeLower,
        upper: [upperCreatedAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MessageEntityQueryFilter
    on QueryBuilder<MessageEntity, MessageEntity, QFilterCondition> {
  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'attachmentFileName',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'attachmentFileName',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attachmentFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attachmentFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attachmentFileName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'attachmentFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'attachmentFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'attachmentFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'attachmentFileName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentFileName',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentFileNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'attachmentFileName',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'attachmentMimeType',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'attachmentMimeType',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentMimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attachmentMimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attachmentMimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attachmentMimeType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'attachmentMimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'attachmentMimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'attachmentMimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'attachmentMimeType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentMimeType',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentMimeTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'attachmentMimeType',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentSizeBytesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'attachmentSizeBytes',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentSizeBytesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'attachmentSizeBytes',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentSizeBytesEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentSizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentSizeBytesGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attachmentSizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentSizeBytesLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attachmentSizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentSizeBytesBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attachmentSizeBytes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'attachmentType',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'attachmentType',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attachmentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attachmentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attachmentType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'attachmentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'attachmentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'attachmentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'attachmentType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentType',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'attachmentType',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'attachmentUrl',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'attachmentUrl',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attachmentUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attachmentUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attachmentUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'attachmentUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'attachmentUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'attachmentUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'attachmentUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      attachmentUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'attachmentUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'audioAlbum',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'audioAlbum',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioAlbum',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'audioAlbum',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'audioAlbum',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'audioAlbum',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'audioAlbum',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'audioAlbum',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'audioAlbum',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'audioAlbum',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioAlbum',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioAlbumIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'audioAlbum',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'audioArtist',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'audioArtist',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioArtist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'audioArtist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'audioArtist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'audioArtist',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'audioArtist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'audioArtist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'audioArtist',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'audioArtist',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioArtist',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioArtistIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'audioArtist',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'audioTitle',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'audioTitle',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'audioTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'audioTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'audioTitle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'audioTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'audioTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'audioTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'audioTitle',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioTitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'audioTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'audioUrl',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'audioUrl',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'audioUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'audioUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      audioUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'audioUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      contentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      contentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      contentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      contentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'content',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      contentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      contentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      contentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      contentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'content',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'content',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'content',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      conversationIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conversationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      conversationIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      conversationIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conversationId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedForUserIds',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedForUserIds',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedForUserIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deletedForUserIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deletedForUserIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deletedForUserIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deletedForUserIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deletedForUserIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedForUserIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedForUserIds',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedForUserIds',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedForUserIds',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deletedForUserIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deletedForUserIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deletedForUserIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deletedForUserIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deletedForUserIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedForUserIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deletedForUserIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      deletedGloballyEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedGlobally',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      durationIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'duration',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      durationIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'duration',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      durationEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'duration',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      durationGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'duration',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      durationLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'duration',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      durationBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'duration',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'errorMessage',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'errorMessage',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'errorMessage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'errorMessage',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'errorMessage',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      errorMessageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'errorMessage',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'forwardedFromSenderName',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'forwardedFromSenderName',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'forwardedFromSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'forwardedFromSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'forwardedFromSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'forwardedFromSenderName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'forwardedFromSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'forwardedFromSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'forwardedFromSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'forwardedFromSenderName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'forwardedFromSenderName',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      forwardedFromSenderNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'forwardedFromSenderName',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition> idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition> idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition> idContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition> idMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'id',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isDeliveredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDelivered',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isFailedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'isFailed',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isFailedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'isFailed',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isFailedEqualTo(bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isFailed',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isForwardedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isForwarded',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition> isMeEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isMe',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isPendingEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isPending',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isReadEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isRead',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isSeenEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSeen',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isSentEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSent',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isUploadingEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isUploading',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isarIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'isarId',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isarIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'isarId',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isarIdEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isarIdGreaterThan(
    Id? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isarIdLessThan(
    Id? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      isarIdBetween(
    Id? lower,
    Id? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'isarId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'localFilePath',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'localFilePath',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localFilePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localFilePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localFilePath',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localFilePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localFilePath',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'localImagePath',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'localImagePath',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localImagePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localImagePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localImagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      localImagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localImagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'messageType',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'messageType',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'messageType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'messageType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageType',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      messageTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'messageType',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'originalMessageId',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'originalMessageId',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originalMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'originalMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'originalMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'originalMessageId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'originalMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'originalMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'originalMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'originalMessageId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originalMessageId',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalMessageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'originalMessageId',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'originalSenderId',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'originalSenderId',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originalSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'originalSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'originalSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'originalSenderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'originalSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'originalSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'originalSenderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'originalSenderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originalSenderId',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      originalSenderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'originalSenderId',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reactionsJson',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reactionsJson',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reactionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reactionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reactionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reactionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reactionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reactionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reactionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reactionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reactionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      reactionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reactionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'replyToContent',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'replyToContent',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'replyToContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'replyToContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'replyToContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'replyToContent',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'replyToContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'replyToContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'replyToContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'replyToContent',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'replyToContent',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToContentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'replyToContent',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'replyToMessageId',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'replyToMessageId',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'replyToMessageId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'replyToMessageId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'replyToMessageId',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToMessageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'replyToMessageId',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'replyToSenderName',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'replyToSenderName',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'replyToSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'replyToSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'replyToSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'replyToSenderName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'replyToSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'replyToSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'replyToSenderName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'replyToSenderName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'replyToSenderName',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      replyToSenderNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'replyToSenderName',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      senderIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      senderIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      senderIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      senderIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'senderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      senderIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      senderIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      senderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      senderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'senderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      senderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'senderId',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      senderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'senderId',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sharedPostDataJson',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sharedPostDataJson',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sharedPostDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sharedPostDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sharedPostDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sharedPostDataJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sharedPostDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sharedPostDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sharedPostDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sharedPostDataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sharedPostDataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      sharedPostDataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sharedPostDataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'storyReplyDataJson',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'storyReplyDataJson',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storyReplyDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'storyReplyDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'storyReplyDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'storyReplyDataJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'storyReplyDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'storyReplyDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'storyReplyDataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'storyReplyDataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storyReplyDataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      storyReplyDataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'storyReplyDataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      uploadProgressIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'uploadProgress',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      uploadProgressIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'uploadProgress',
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      uploadProgressEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uploadProgress',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      uploadProgressGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uploadProgress',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      uploadProgressLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uploadProgress',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterFilterCondition>
      uploadProgressBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uploadProgress',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }
}

extension MessageEntityQueryObject
    on QueryBuilder<MessageEntity, MessageEntity, QFilterCondition> {}

extension MessageEntityQueryLinks
    on QueryBuilder<MessageEntity, MessageEntity, QFilterCondition> {}

extension MessageEntityQuerySortBy
    on QueryBuilder<MessageEntity, MessageEntity, QSortBy> {
  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAttachmentFileName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentFileName', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAttachmentFileNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentFileName', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAttachmentMimeType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentMimeType', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAttachmentMimeTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentMimeType', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAttachmentSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentSizeBytes', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAttachmentSizeBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentSizeBytes', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAttachmentType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentType', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAttachmentTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentType', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAttachmentUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentUrl', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAttachmentUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentUrl', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByAudioAlbum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioAlbum', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAudioAlbumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioAlbum', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByAudioArtist() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioArtist', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAudioArtistDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioArtist', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByAudioTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioTitle', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAudioTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioTitle', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByAudioUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByAudioUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByDeletedGlobally() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedGlobally', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByDeletedGloballyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedGlobally', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByDuration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'duration', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByDurationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'duration', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByErrorMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByErrorMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByForwardedFromSenderName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forwardedFromSenderName', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByForwardedFromSenderNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forwardedFromSenderName', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsDelivered() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDelivered', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByIsDeliveredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDelivered', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsFailed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFailed', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByIsFailedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFailed', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsForwarded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isForwarded', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByIsForwardedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isForwarded', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsMe() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMe', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsMeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMe', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsPending() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPending', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByIsPendingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPending', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSeen', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsSeenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSeen', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsSent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSent', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsSentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSent', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByIsUploading() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUploading', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByIsUploadingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUploading', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByLocalFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByLocalFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByLocalImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByLocalImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortByMessageType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByMessageTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByOriginalMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalMessageId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByOriginalMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalMessageId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByOriginalSenderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalSenderId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByOriginalSenderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalSenderId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByReactionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reactionsJson', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByReactionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reactionsJson', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByReplyToContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToContent', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByReplyToContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToContent', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByReplyToMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToMessageId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByReplyToMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToMessageId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByReplyToSenderName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToSenderName', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByReplyToSenderNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToSenderName', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> sortBySenderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortBySenderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortBySharedPostDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sharedPostDataJson', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortBySharedPostDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sharedPostDataJson', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByStoryReplyDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyReplyDataJson', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByStoryReplyDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyReplyDataJson', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByUploadProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadProgress', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      sortByUploadProgressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadProgress', Sort.desc);
    });
  }
}

extension MessageEntityQuerySortThenBy
    on QueryBuilder<MessageEntity, MessageEntity, QSortThenBy> {
  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAttachmentFileName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentFileName', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAttachmentFileNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentFileName', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAttachmentMimeType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentMimeType', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAttachmentMimeTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentMimeType', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAttachmentSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentSizeBytes', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAttachmentSizeBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentSizeBytes', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAttachmentType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentType', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAttachmentTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentType', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAttachmentUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentUrl', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAttachmentUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentUrl', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByAudioAlbum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioAlbum', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAudioAlbumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioAlbum', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByAudioArtist() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioArtist', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAudioArtistDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioArtist', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByAudioTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioTitle', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAudioTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioTitle', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByAudioUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByAudioUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByDeletedGlobally() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedGlobally', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByDeletedGloballyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedGlobally', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByDuration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'duration', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByDurationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'duration', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByErrorMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByErrorMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByForwardedFromSenderName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forwardedFromSenderName', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByForwardedFromSenderNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forwardedFromSenderName', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsDelivered() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDelivered', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByIsDeliveredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDelivered', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsFailed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFailed', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByIsFailedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFailed', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsForwarded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isForwarded', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByIsForwardedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isForwarded', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsMe() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMe', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsMeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMe', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsPending() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPending', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByIsPendingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPending', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSeen', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsSeenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSeen', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsSent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSent', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsSentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSent', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsUploading() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUploading', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByIsUploadingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUploading', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByLocalFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByLocalFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByLocalImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByLocalImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenByMessageType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByMessageTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByOriginalMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalMessageId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByOriginalMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalMessageId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByOriginalSenderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalSenderId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByOriginalSenderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalSenderId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByReactionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reactionsJson', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByReactionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reactionsJson', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByReplyToContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToContent', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByReplyToContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToContent', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByReplyToMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToMessageId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByReplyToMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToMessageId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByReplyToSenderName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToSenderName', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByReplyToSenderNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToSenderName', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy> thenBySenderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenBySenderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenBySharedPostDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sharedPostDataJson', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenBySharedPostDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sharedPostDataJson', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByStoryReplyDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyReplyDataJson', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByStoryReplyDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyReplyDataJson', Sort.desc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByUploadProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadProgress', Sort.asc);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QAfterSortBy>
      thenByUploadProgressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadProgress', Sort.desc);
    });
  }
}

extension MessageEntityQueryWhereDistinct
    on QueryBuilder<MessageEntity, MessageEntity, QDistinct> {
  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByAttachmentFileName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attachmentFileName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByAttachmentMimeType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attachmentMimeType',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByAttachmentSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attachmentSizeBytes');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByAttachmentType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attachmentType',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByAttachmentUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attachmentUrl',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByAudioAlbum(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'audioAlbum', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByAudioArtist(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'audioArtist', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByAudioTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'audioTitle', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByAudioUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'audioUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByContent(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conversationId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByDeletedForUserIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedForUserIds');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByDeletedGlobally() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedGlobally');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByDuration() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'duration');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByErrorMessage(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'errorMessage', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByForwardedFromSenderName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'forwardedFromSenderName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctById(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByIsDelivered() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDelivered');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByIsFailed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFailed');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByIsForwarded() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isForwarded');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByIsMe() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isMe');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByIsPending() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPending');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByIsRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRead');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByIsSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSeen');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByIsSent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSent');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByIsUploading() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isUploading');
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByLocalFilePath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localFilePath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByLocalImagePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localImagePath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByMessageType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'messageType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByOriginalMessageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originalMessageId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByOriginalSenderId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originalSenderId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctByReactionsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reactionsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByReplyToContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'replyToContent',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByReplyToMessageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'replyToMessageId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByReplyToSenderName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'replyToSenderName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct> distinctBySenderId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'senderId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctBySharedPostDataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sharedPostDataJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByStoryReplyDataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'storyReplyDataJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MessageEntity, MessageEntity, QDistinct>
      distinctByUploadProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uploadProgress');
    });
  }
}

extension MessageEntityQueryProperty
    on QueryBuilder<MessageEntity, MessageEntity, QQueryProperty> {
  QueryBuilder<MessageEntity, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      attachmentFileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachmentFileName');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      attachmentMimeTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachmentMimeType');
    });
  }

  QueryBuilder<MessageEntity, int?, QQueryOperations>
      attachmentSizeBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachmentSizeBytes');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      attachmentTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachmentType');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      attachmentUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachmentUrl');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations> audioAlbumProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'audioAlbum');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations> audioArtistProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'audioArtist');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations> audioTitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'audioTitle');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations> audioUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'audioUrl');
    });
  }

  QueryBuilder<MessageEntity, String, QQueryOperations> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content');
    });
  }

  QueryBuilder<MessageEntity, String, QQueryOperations>
      conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversationId');
    });
  }

  QueryBuilder<MessageEntity, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<MessageEntity, List<String>?, QQueryOperations>
      deletedForUserIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedForUserIds');
    });
  }

  QueryBuilder<MessageEntity, bool, QQueryOperations>
      deletedGloballyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedGlobally');
    });
  }

  QueryBuilder<MessageEntity, int?, QQueryOperations> durationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'duration');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      errorMessageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'errorMessage');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      forwardedFromSenderNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'forwardedFromSenderName');
    });
  }

  QueryBuilder<MessageEntity, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MessageEntity, bool, QQueryOperations> isDeliveredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDelivered');
    });
  }

  QueryBuilder<MessageEntity, bool?, QQueryOperations> isFailedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFailed');
    });
  }

  QueryBuilder<MessageEntity, bool, QQueryOperations> isForwardedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isForwarded');
    });
  }

  QueryBuilder<MessageEntity, bool, QQueryOperations> isMeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isMe');
    });
  }

  QueryBuilder<MessageEntity, bool, QQueryOperations> isPendingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPending');
    });
  }

  QueryBuilder<MessageEntity, bool, QQueryOperations> isReadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRead');
    });
  }

  QueryBuilder<MessageEntity, bool, QQueryOperations> isSeenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSeen');
    });
  }

  QueryBuilder<MessageEntity, bool, QQueryOperations> isSentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSent');
    });
  }

  QueryBuilder<MessageEntity, bool, QQueryOperations> isUploadingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isUploading');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      localFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localFilePath');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      localImagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localImagePath');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations> messageTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'messageType');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      originalMessageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originalMessageId');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      originalSenderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originalSenderId');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      reactionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reactionsJson');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      replyToContentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'replyToContent');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      replyToMessageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'replyToMessageId');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      replyToSenderNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'replyToSenderName');
    });
  }

  QueryBuilder<MessageEntity, String, QQueryOperations> senderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'senderId');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      sharedPostDataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sharedPostDataJson');
    });
  }

  QueryBuilder<MessageEntity, String?, QQueryOperations>
      storyReplyDataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'storyReplyDataJson');
    });
  }

  QueryBuilder<MessageEntity, double?, QQueryOperations>
      uploadProgressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uploadProgress');
    });
  }
}
