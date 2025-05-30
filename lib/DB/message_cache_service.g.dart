// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_cache_service.dart';

// ignore_for_file: type=lint
class $CachedMessagesTable extends CachedMessages
    with TableInfo<$CachedMessagesTable, CachedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _attachmentUrlMeta =
      const VerificationMeta('attachmentUrl');
  @override
  late final GeneratedColumn<String> attachmentUrl = GeneratedColumn<String>(
      'attachment_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attachmentTypeMeta =
      const VerificationMeta('attachmentType');
  @override
  late final GeneratedColumn<String> attachmentType = GeneratedColumn<String>(
      'attachment_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
      'is_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_read" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isSentMeta = const VerificationMeta('isSent');
  @override
  late final GeneratedColumn<bool> isSent = GeneratedColumn<bool>(
      'is_sent', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_sent" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _senderNameMeta =
      const VerificationMeta('senderName');
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
      'sender_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _senderAvatarMeta =
      const VerificationMeta('senderAvatar');
  @override
  late final GeneratedColumn<String> senderAvatar = GeneratedColumn<String>(
      'sender_avatar', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isMeMeta = const VerificationMeta('isMe');
  @override
  late final GeneratedColumn<bool> isMe = GeneratedColumn<bool>(
      'is_me', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_me" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _replyToMessageIdMeta =
      const VerificationMeta('replyToMessageId');
  @override
  late final GeneratedColumn<String> replyToMessageId = GeneratedColumn<String>(
      'reply_to_message_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _replyToContentMeta =
      const VerificationMeta('replyToContent');
  @override
  late final GeneratedColumn<String> replyToContent = GeneratedColumn<String>(
      'reply_to_content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _replyToSenderNameMeta =
      const VerificationMeta('replyToSenderName');
  @override
  late final GeneratedColumn<String> replyToSenderName =
      GeneratedColumn<String>('reply_to_sender_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isPendingMeta =
      const VerificationMeta('isPending');
  @override
  late final GeneratedColumn<bool> isPending = GeneratedColumn<bool>(
      'is_pending', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pending" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _localIdMeta =
      const VerificationMeta('localId');
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
      'local_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        senderId,
        content,
        createdAt,
        attachmentUrl,
        attachmentType,
        isRead,
        isSent,
        senderName,
        senderAvatar,
        isMe,
        replyToMessageId,
        replyToContent,
        replyToSenderName,
        isPending,
        localId,
        retryCount
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_messages';
  @override
  VerificationContext validateIntegrity(Insertable<CachedMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attachment_url')) {
      context.handle(
          _attachmentUrlMeta,
          attachmentUrl.isAcceptableOrUnknown(
              data['attachment_url']!, _attachmentUrlMeta));
    }
    if (data.containsKey('attachment_type')) {
      context.handle(
          _attachmentTypeMeta,
          attachmentType.isAcceptableOrUnknown(
              data['attachment_type']!, _attachmentTypeMeta));
    }
    if (data.containsKey('is_read')) {
      context.handle(_isReadMeta,
          isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta));
    }
    if (data.containsKey('is_sent')) {
      context.handle(_isSentMeta,
          isSent.isAcceptableOrUnknown(data['is_sent']!, _isSentMeta));
    }
    if (data.containsKey('sender_name')) {
      context.handle(
          _senderNameMeta,
          senderName.isAcceptableOrUnknown(
              data['sender_name']!, _senderNameMeta));
    }
    if (data.containsKey('sender_avatar')) {
      context.handle(
          _senderAvatarMeta,
          senderAvatar.isAcceptableOrUnknown(
              data['sender_avatar']!, _senderAvatarMeta));
    }
    if (data.containsKey('is_me')) {
      context.handle(
          _isMeMeta, isMe.isAcceptableOrUnknown(data['is_me']!, _isMeMeta));
    }
    if (data.containsKey('reply_to_message_id')) {
      context.handle(
          _replyToMessageIdMeta,
          replyToMessageId.isAcceptableOrUnknown(
              data['reply_to_message_id']!, _replyToMessageIdMeta));
    }
    if (data.containsKey('reply_to_content')) {
      context.handle(
          _replyToContentMeta,
          replyToContent.isAcceptableOrUnknown(
              data['reply_to_content']!, _replyToContentMeta));
    }
    if (data.containsKey('reply_to_sender_name')) {
      context.handle(
          _replyToSenderNameMeta,
          replyToSenderName.isAcceptableOrUnknown(
              data['reply_to_sender_name']!, _replyToSenderNameMeta));
    }
    if (data.containsKey('is_pending')) {
      context.handle(_isPendingMeta,
          isPending.isAcceptableOrUnknown(data['is_pending']!, _isPendingMeta));
    }
    if (data.containsKey('local_id')) {
      context.handle(_localIdMeta,
          localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, conversationId};
  @override
  CachedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      attachmentUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attachment_url']),
      attachmentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attachment_type']),
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
      isSent: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_sent'])!,
      senderName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_name']),
      senderAvatar: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_avatar']),
      isMe: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_me'])!,
      replyToMessageId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reply_to_message_id']),
      replyToContent: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reply_to_content']),
      replyToSenderName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reply_to_sender_name']),
      isPending: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pending'])!,
      localId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_id']),
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
    );
  }

  @override
  $CachedMessagesTable createAlias(String alias) {
    return $CachedMessagesTable(attachedDatabase, alias);
  }
}

class CachedMessage extends DataClass implements Insertable<CachedMessage> {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentType;
  final bool isRead;
  final bool isSent;
  final String? senderName;
  final String? senderAvatar;
  final bool isMe;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;
  final bool isPending;
  final String? localId;
  final int retryCount;
  const CachedMessage(
      {required this.id,
      required this.conversationId,
      required this.senderId,
      required this.content,
      required this.createdAt,
      this.attachmentUrl,
      this.attachmentType,
      required this.isRead,
      required this.isSent,
      this.senderName,
      this.senderAvatar,
      required this.isMe,
      this.replyToMessageId,
      this.replyToContent,
      this.replyToSenderName,
      required this.isPending,
      this.localId,
      required this.retryCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_id'] = Variable<String>(senderId);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || attachmentUrl != null) {
      map['attachment_url'] = Variable<String>(attachmentUrl);
    }
    if (!nullToAbsent || attachmentType != null) {
      map['attachment_type'] = Variable<String>(attachmentType);
    }
    map['is_read'] = Variable<bool>(isRead);
    map['is_sent'] = Variable<bool>(isSent);
    if (!nullToAbsent || senderName != null) {
      map['sender_name'] = Variable<String>(senderName);
    }
    if (!nullToAbsent || senderAvatar != null) {
      map['sender_avatar'] = Variable<String>(senderAvatar);
    }
    map['is_me'] = Variable<bool>(isMe);
    if (!nullToAbsent || replyToMessageId != null) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId);
    }
    if (!nullToAbsent || replyToContent != null) {
      map['reply_to_content'] = Variable<String>(replyToContent);
    }
    if (!nullToAbsent || replyToSenderName != null) {
      map['reply_to_sender_name'] = Variable<String>(replyToSenderName);
    }
    map['is_pending'] = Variable<bool>(isPending);
    if (!nullToAbsent || localId != null) {
      map['local_id'] = Variable<String>(localId);
    }
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  CachedMessagesCompanion toCompanion(bool nullToAbsent) {
    return CachedMessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      content: Value(content),
      createdAt: Value(createdAt),
      attachmentUrl: attachmentUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentUrl),
      attachmentType: attachmentType == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentType),
      isRead: Value(isRead),
      isSent: Value(isSent),
      senderName: senderName == null && nullToAbsent
          ? const Value.absent()
          : Value(senderName),
      senderAvatar: senderAvatar == null && nullToAbsent
          ? const Value.absent()
          : Value(senderAvatar),
      isMe: Value(isMe),
      replyToMessageId: replyToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToMessageId),
      replyToContent: replyToContent == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToContent),
      replyToSenderName: replyToSenderName == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToSenderName),
      isPending: Value(isPending),
      localId: localId == null && nullToAbsent
          ? const Value.absent()
          : Value(localId),
      retryCount: Value(retryCount),
    );
  }

  factory CachedMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMessage(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attachmentUrl: serializer.fromJson<String?>(json['attachmentUrl']),
      attachmentType: serializer.fromJson<String?>(json['attachmentType']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      isSent: serializer.fromJson<bool>(json['isSent']),
      senderName: serializer.fromJson<String?>(json['senderName']),
      senderAvatar: serializer.fromJson<String?>(json['senderAvatar']),
      isMe: serializer.fromJson<bool>(json['isMe']),
      replyToMessageId: serializer.fromJson<String?>(json['replyToMessageId']),
      replyToContent: serializer.fromJson<String?>(json['replyToContent']),
      replyToSenderName:
          serializer.fromJson<String?>(json['replyToSenderName']),
      isPending: serializer.fromJson<bool>(json['isPending']),
      localId: serializer.fromJson<String?>(json['localId']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderId': serializer.toJson<String>(senderId),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attachmentUrl': serializer.toJson<String?>(attachmentUrl),
      'attachmentType': serializer.toJson<String?>(attachmentType),
      'isRead': serializer.toJson<bool>(isRead),
      'isSent': serializer.toJson<bool>(isSent),
      'senderName': serializer.toJson<String?>(senderName),
      'senderAvatar': serializer.toJson<String?>(senderAvatar),
      'isMe': serializer.toJson<bool>(isMe),
      'replyToMessageId': serializer.toJson<String?>(replyToMessageId),
      'replyToContent': serializer.toJson<String?>(replyToContent),
      'replyToSenderName': serializer.toJson<String?>(replyToSenderName),
      'isPending': serializer.toJson<bool>(isPending),
      'localId': serializer.toJson<String?>(localId),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  CachedMessage copyWith(
          {String? id,
          String? conversationId,
          String? senderId,
          String? content,
          DateTime? createdAt,
          Value<String?> attachmentUrl = const Value.absent(),
          Value<String?> attachmentType = const Value.absent(),
          bool? isRead,
          bool? isSent,
          Value<String?> senderName = const Value.absent(),
          Value<String?> senderAvatar = const Value.absent(),
          bool? isMe,
          Value<String?> replyToMessageId = const Value.absent(),
          Value<String?> replyToContent = const Value.absent(),
          Value<String?> replyToSenderName = const Value.absent(),
          bool? isPending,
          Value<String?> localId = const Value.absent(),
          int? retryCount}) =>
      CachedMessage(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        senderId: senderId ?? this.senderId,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        attachmentUrl:
            attachmentUrl.present ? attachmentUrl.value : this.attachmentUrl,
        attachmentType:
            attachmentType.present ? attachmentType.value : this.attachmentType,
        isRead: isRead ?? this.isRead,
        isSent: isSent ?? this.isSent,
        senderName: senderName.present ? senderName.value : this.senderName,
        senderAvatar:
            senderAvatar.present ? senderAvatar.value : this.senderAvatar,
        isMe: isMe ?? this.isMe,
        replyToMessageId: replyToMessageId.present
            ? replyToMessageId.value
            : this.replyToMessageId,
        replyToContent:
            replyToContent.present ? replyToContent.value : this.replyToContent,
        replyToSenderName: replyToSenderName.present
            ? replyToSenderName.value
            : this.replyToSenderName,
        isPending: isPending ?? this.isPending,
        localId: localId.present ? localId.value : this.localId,
        retryCount: retryCount ?? this.retryCount,
      );
  CachedMessage copyWithCompanion(CachedMessagesCompanion data) {
    return CachedMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attachmentUrl: data.attachmentUrl.present
          ? data.attachmentUrl.value
          : this.attachmentUrl,
      attachmentType: data.attachmentType.present
          ? data.attachmentType.value
          : this.attachmentType,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      isSent: data.isSent.present ? data.isSent.value : this.isSent,
      senderName:
          data.senderName.present ? data.senderName.value : this.senderName,
      senderAvatar: data.senderAvatar.present
          ? data.senderAvatar.value
          : this.senderAvatar,
      isMe: data.isMe.present ? data.isMe.value : this.isMe,
      replyToMessageId: data.replyToMessageId.present
          ? data.replyToMessageId.value
          : this.replyToMessageId,
      replyToContent: data.replyToContent.present
          ? data.replyToContent.value
          : this.replyToContent,
      replyToSenderName: data.replyToSenderName.present
          ? data.replyToSenderName.value
          : this.replyToSenderName,
      isPending: data.isPending.present ? data.isPending.value : this.isPending,
      localId: data.localId.present ? data.localId.value : this.localId,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessage(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('attachmentUrl: $attachmentUrl, ')
          ..write('attachmentType: $attachmentType, ')
          ..write('isRead: $isRead, ')
          ..write('isSent: $isSent, ')
          ..write('senderName: $senderName, ')
          ..write('senderAvatar: $senderAvatar, ')
          ..write('isMe: $isMe, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('replyToContent: $replyToContent, ')
          ..write('replyToSenderName: $replyToSenderName, ')
          ..write('isPending: $isPending, ')
          ..write('localId: $localId, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      conversationId,
      senderId,
      content,
      createdAt,
      attachmentUrl,
      attachmentType,
      isRead,
      isSent,
      senderName,
      senderAvatar,
      isMe,
      replyToMessageId,
      replyToContent,
      replyToSenderName,
      isPending,
      localId,
      retryCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMessage &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.attachmentUrl == this.attachmentUrl &&
          other.attachmentType == this.attachmentType &&
          other.isRead == this.isRead &&
          other.isSent == this.isSent &&
          other.senderName == this.senderName &&
          other.senderAvatar == this.senderAvatar &&
          other.isMe == this.isMe &&
          other.replyToMessageId == this.replyToMessageId &&
          other.replyToContent == this.replyToContent &&
          other.replyToSenderName == this.replyToSenderName &&
          other.isPending == this.isPending &&
          other.localId == this.localId &&
          other.retryCount == this.retryCount);
}

class CachedMessagesCompanion extends UpdateCompanion<CachedMessage> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> senderId;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<String?> attachmentUrl;
  final Value<String?> attachmentType;
  final Value<bool> isRead;
  final Value<bool> isSent;
  final Value<String?> senderName;
  final Value<String?> senderAvatar;
  final Value<bool> isMe;
  final Value<String?> replyToMessageId;
  final Value<String?> replyToContent;
  final Value<String?> replyToSenderName;
  final Value<bool> isPending;
  final Value<String?> localId;
  final Value<int> retryCount;
  final Value<int> rowid;
  const CachedMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attachmentUrl = const Value.absent(),
    this.attachmentType = const Value.absent(),
    this.isRead = const Value.absent(),
    this.isSent = const Value.absent(),
    this.senderName = const Value.absent(),
    this.senderAvatar = const Value.absent(),
    this.isMe = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.replyToContent = const Value.absent(),
    this.replyToSenderName = const Value.absent(),
    this.isPending = const Value.absent(),
    this.localId = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMessagesCompanion.insert({
    required String id,
    required String conversationId,
    required String senderId,
    required String content,
    required DateTime createdAt,
    this.attachmentUrl = const Value.absent(),
    this.attachmentType = const Value.absent(),
    this.isRead = const Value.absent(),
    this.isSent = const Value.absent(),
    this.senderName = const Value.absent(),
    this.senderAvatar = const Value.absent(),
    this.isMe = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.replyToContent = const Value.absent(),
    this.replyToSenderName = const Value.absent(),
    this.isPending = const Value.absent(),
    this.localId = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        conversationId = Value(conversationId),
        senderId = Value(senderId),
        content = Value(content),
        createdAt = Value(createdAt);
  static Insertable<CachedMessage> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? senderId,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<String>? attachmentUrl,
    Expression<String>? attachmentType,
    Expression<bool>? isRead,
    Expression<bool>? isSent,
    Expression<String>? senderName,
    Expression<String>? senderAvatar,
    Expression<bool>? isMe,
    Expression<String>? replyToMessageId,
    Expression<String>? replyToContent,
    Expression<String>? replyToSenderName,
    Expression<bool>? isPending,
    Expression<String>? localId,
    Expression<int>? retryCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (attachmentType != null) 'attachment_type': attachmentType,
      if (isRead != null) 'is_read': isRead,
      if (isSent != null) 'is_sent': isSent,
      if (senderName != null) 'sender_name': senderName,
      if (senderAvatar != null) 'sender_avatar': senderAvatar,
      if (isMe != null) 'is_me': isMe,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (replyToContent != null) 'reply_to_content': replyToContent,
      if (replyToSenderName != null) 'reply_to_sender_name': replyToSenderName,
      if (isPending != null) 'is_pending': isPending,
      if (localId != null) 'local_id': localId,
      if (retryCount != null) 'retry_count': retryCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? conversationId,
      Value<String>? senderId,
      Value<String>? content,
      Value<DateTime>? createdAt,
      Value<String?>? attachmentUrl,
      Value<String?>? attachmentType,
      Value<bool>? isRead,
      Value<bool>? isSent,
      Value<String?>? senderName,
      Value<String?>? senderAvatar,
      Value<bool>? isMe,
      Value<String?>? replyToMessageId,
      Value<String?>? replyToContent,
      Value<String?>? replyToSenderName,
      Value<bool>? isPending,
      Value<String?>? localId,
      Value<int>? retryCount,
      Value<int>? rowid}) {
    return CachedMessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      isRead: isRead ?? this.isRead,
      isSent: isSent ?? this.isSent,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      isMe: isMe ?? this.isMe,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      isPending: isPending ?? this.isPending,
      localId: localId ?? this.localId,
      retryCount: retryCount ?? this.retryCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attachmentUrl.present) {
      map['attachment_url'] = Variable<String>(attachmentUrl.value);
    }
    if (attachmentType.present) {
      map['attachment_type'] = Variable<String>(attachmentType.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (isSent.present) {
      map['is_sent'] = Variable<bool>(isSent.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (senderAvatar.present) {
      map['sender_avatar'] = Variable<String>(senderAvatar.value);
    }
    if (isMe.present) {
      map['is_me'] = Variable<bool>(isMe.value);
    }
    if (replyToMessageId.present) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId.value);
    }
    if (replyToContent.present) {
      map['reply_to_content'] = Variable<String>(replyToContent.value);
    }
    if (replyToSenderName.present) {
      map['reply_to_sender_name'] = Variable<String>(replyToSenderName.value);
    }
    if (isPending.present) {
      map['is_pending'] = Variable<bool>(isPending.value);
    }
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('attachmentUrl: $attachmentUrl, ')
          ..write('attachmentType: $attachmentType, ')
          ..write('isRead: $isRead, ')
          ..write('isSent: $isSent, ')
          ..write('senderName: $senderName, ')
          ..write('senderAvatar: $senderAvatar, ')
          ..write('isMe: $isMe, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('replyToContent: $replyToContent, ')
          ..write('replyToSenderName: $replyToSenderName, ')
          ..write('isPending: $isPending, ')
          ..write('localId: $localId, ')
          ..write('retryCount: $retryCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MessageCacheDatabase extends GeneratedDatabase {
  _$MessageCacheDatabase(QueryExecutor e) : super(e);
  $MessageCacheDatabaseManager get managers =>
      $MessageCacheDatabaseManager(this);
  late final $CachedMessagesTable cachedMessages = $CachedMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedMessages];
}

typedef $$CachedMessagesTableCreateCompanionBuilder = CachedMessagesCompanion
    Function({
  required String id,
  required String conversationId,
  required String senderId,
  required String content,
  required DateTime createdAt,
  Value<String?> attachmentUrl,
  Value<String?> attachmentType,
  Value<bool> isRead,
  Value<bool> isSent,
  Value<String?> senderName,
  Value<String?> senderAvatar,
  Value<bool> isMe,
  Value<String?> replyToMessageId,
  Value<String?> replyToContent,
  Value<String?> replyToSenderName,
  Value<bool> isPending,
  Value<String?> localId,
  Value<int> retryCount,
  Value<int> rowid,
});
typedef $$CachedMessagesTableUpdateCompanionBuilder = CachedMessagesCompanion
    Function({
  Value<String> id,
  Value<String> conversationId,
  Value<String> senderId,
  Value<String> content,
  Value<DateTime> createdAt,
  Value<String?> attachmentUrl,
  Value<String?> attachmentType,
  Value<bool> isRead,
  Value<bool> isSent,
  Value<String?> senderName,
  Value<String?> senderAvatar,
  Value<bool> isMe,
  Value<String?> replyToMessageId,
  Value<String?> replyToContent,
  Value<String?> replyToSenderName,
  Value<bool> isPending,
  Value<String?> localId,
  Value<int> retryCount,
  Value<int> rowid,
});

class $$CachedMessagesTableFilterComposer
    extends Composer<_$MessageCacheDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentUrl => $composableBuilder(
      column: $table.attachmentUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentType => $composableBuilder(
      column: $table.attachmentType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSent => $composableBuilder(
      column: $table.isSent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderAvatar => $composableBuilder(
      column: $table.senderAvatar, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMe => $composableBuilder(
      column: $table.isMe, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replyToMessageId => $composableBuilder(
      column: $table.replyToMessageId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replyToContent => $composableBuilder(
      column: $table.replyToContent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replyToSenderName => $composableBuilder(
      column: $table.replyToSenderName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPending => $composableBuilder(
      column: $table.isPending, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));
}

class $$CachedMessagesTableOrderingComposer
    extends Composer<_$MessageCacheDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentUrl => $composableBuilder(
      column: $table.attachmentUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentType => $composableBuilder(
      column: $table.attachmentType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSent => $composableBuilder(
      column: $table.isSent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderAvatar => $composableBuilder(
      column: $table.senderAvatar,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMe => $composableBuilder(
      column: $table.isMe, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replyToMessageId => $composableBuilder(
      column: $table.replyToMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replyToContent => $composableBuilder(
      column: $table.replyToContent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replyToSenderName => $composableBuilder(
      column: $table.replyToSenderName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPending => $composableBuilder(
      column: $table.isPending, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));
}

class $$CachedMessagesTableAnnotationComposer
    extends Composer<_$MessageCacheDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get attachmentUrl => $composableBuilder(
      column: $table.attachmentUrl, builder: (column) => column);

  GeneratedColumn<String> get attachmentType => $composableBuilder(
      column: $table.attachmentType, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<bool> get isSent =>
      $composableBuilder(column: $table.isSent, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => column);

  GeneratedColumn<String> get senderAvatar => $composableBuilder(
      column: $table.senderAvatar, builder: (column) => column);

  GeneratedColumn<bool> get isMe =>
      $composableBuilder(column: $table.isMe, builder: (column) => column);

  GeneratedColumn<String> get replyToMessageId => $composableBuilder(
      column: $table.replyToMessageId, builder: (column) => column);

  GeneratedColumn<String> get replyToContent => $composableBuilder(
      column: $table.replyToContent, builder: (column) => column);

  GeneratedColumn<String> get replyToSenderName => $composableBuilder(
      column: $table.replyToSenderName, builder: (column) => column);

  GeneratedColumn<bool> get isPending =>
      $composableBuilder(column: $table.isPending, builder: (column) => column);

  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);
}

class $$CachedMessagesTableTableManager extends RootTableManager<
    _$MessageCacheDatabase,
    $CachedMessagesTable,
    CachedMessage,
    $$CachedMessagesTableFilterComposer,
    $$CachedMessagesTableOrderingComposer,
    $$CachedMessagesTableAnnotationComposer,
    $$CachedMessagesTableCreateCompanionBuilder,
    $$CachedMessagesTableUpdateCompanionBuilder,
    (
      CachedMessage,
      BaseReferences<_$MessageCacheDatabase, $CachedMessagesTable,
          CachedMessage>
    ),
    CachedMessage,
    PrefetchHooks Function()> {
  $$CachedMessagesTableTableManager(
      _$MessageCacheDatabase db, $CachedMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> senderId = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> attachmentUrl = const Value.absent(),
            Value<String?> attachmentType = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<bool> isSent = const Value.absent(),
            Value<String?> senderName = const Value.absent(),
            Value<String?> senderAvatar = const Value.absent(),
            Value<bool> isMe = const Value.absent(),
            Value<String?> replyToMessageId = const Value.absent(),
            Value<String?> replyToContent = const Value.absent(),
            Value<String?> replyToSenderName = const Value.absent(),
            Value<bool> isPending = const Value.absent(),
            Value<String?> localId = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMessagesCompanion(
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
            isPending: isPending,
            localId: localId,
            retryCount: retryCount,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String conversationId,
            required String senderId,
            required String content,
            required DateTime createdAt,
            Value<String?> attachmentUrl = const Value.absent(),
            Value<String?> attachmentType = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<bool> isSent = const Value.absent(),
            Value<String?> senderName = const Value.absent(),
            Value<String?> senderAvatar = const Value.absent(),
            Value<bool> isMe = const Value.absent(),
            Value<String?> replyToMessageId = const Value.absent(),
            Value<String?> replyToContent = const Value.absent(),
            Value<String?> replyToSenderName = const Value.absent(),
            Value<bool> isPending = const Value.absent(),
            Value<String?> localId = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMessagesCompanion.insert(
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
            isPending: isPending,
            localId: localId,
            retryCount: retryCount,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedMessagesTableProcessedTableManager = ProcessedTableManager<
    _$MessageCacheDatabase,
    $CachedMessagesTable,
    CachedMessage,
    $$CachedMessagesTableFilterComposer,
    $$CachedMessagesTableOrderingComposer,
    $$CachedMessagesTableAnnotationComposer,
    $$CachedMessagesTableCreateCompanionBuilder,
    $$CachedMessagesTableUpdateCompanionBuilder,
    (
      CachedMessage,
      BaseReferences<_$MessageCacheDatabase, $CachedMessagesTable,
          CachedMessage>
    ),
    CachedMessage,
    PrefetchHooks Function()>;

class $MessageCacheDatabaseManager {
  final _$MessageCacheDatabase _db;
  $MessageCacheDatabaseManager(this._db);
  $$CachedMessagesTableTableManager get cachedMessages =>
      $$CachedMessagesTableTableManager(_db, _db.cachedMessages);
}
