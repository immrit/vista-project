// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_cache_service.dart';

// ignore_for_file: type=lint
class $CachedConversationsTable extends CachedConversations
    with TableInfo<$CachedConversationsTable, CachedConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastMessageMeta =
      const VerificationMeta('lastMessage');
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
      'last_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastMessageTimeMeta =
      const VerificationMeta('lastMessageTime');
  @override
  late final GeneratedColumn<DateTime> lastMessageTime =
      GeneratedColumn<DateTime>('last_message_time', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _otherUserNameMeta =
      const VerificationMeta('otherUserName');
  @override
  late final GeneratedColumn<String> otherUserName = GeneratedColumn<String>(
      'other_user_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _otherUserAvatarMeta =
      const VerificationMeta('otherUserAvatar');
  @override
  late final GeneratedColumn<String> otherUserAvatar = GeneratedColumn<String>(
      'other_user_avatar', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _otherUserIdMeta =
      const VerificationMeta('otherUserId');
  @override
  late final GeneratedColumn<String> otherUserId = GeneratedColumn<String>(
      'other_user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _hasUnreadMessagesMeta =
      const VerificationMeta('hasUnreadMessages');
  @override
  late final GeneratedColumn<bool> hasUnreadMessages = GeneratedColumn<bool>(
      'has_unread_messages', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("has_unread_messages" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _unreadCountMeta =
      const VerificationMeta('unreadCount');
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
      'unread_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        createdAt,
        updatedAt,
        lastMessage,
        lastMessageTime,
        otherUserName,
        otherUserAvatar,
        otherUserId,
        hasUnreadMessages,
        unreadCount
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_conversations';
  @override
  VerificationContext validateIntegrity(Insertable<CachedConversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_message')) {
      context.handle(
          _lastMessageMeta,
          lastMessage.isAcceptableOrUnknown(
              data['last_message']!, _lastMessageMeta));
    }
    if (data.containsKey('last_message_time')) {
      context.handle(
          _lastMessageTimeMeta,
          lastMessageTime.isAcceptableOrUnknown(
              data['last_message_time']!, _lastMessageTimeMeta));
    }
    if (data.containsKey('other_user_name')) {
      context.handle(
          _otherUserNameMeta,
          otherUserName.isAcceptableOrUnknown(
              data['other_user_name']!, _otherUserNameMeta));
    }
    if (data.containsKey('other_user_avatar')) {
      context.handle(
          _otherUserAvatarMeta,
          otherUserAvatar.isAcceptableOrUnknown(
              data['other_user_avatar']!, _otherUserAvatarMeta));
    }
    if (data.containsKey('other_user_id')) {
      context.handle(
          _otherUserIdMeta,
          otherUserId.isAcceptableOrUnknown(
              data['other_user_id']!, _otherUserIdMeta));
    }
    if (data.containsKey('has_unread_messages')) {
      context.handle(
          _hasUnreadMessagesMeta,
          hasUnreadMessages.isAcceptableOrUnknown(
              data['has_unread_messages']!, _hasUnreadMessagesMeta));
    }
    if (data.containsKey('unread_count')) {
      context.handle(
          _unreadCountMeta,
          unreadCount.isAcceptableOrUnknown(
              data['unread_count']!, _unreadCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedConversation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      lastMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_message']),
      lastMessageTime: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_message_time']),
      otherUserName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}other_user_name']),
      otherUserAvatar: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}other_user_avatar']),
      otherUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}other_user_id']),
      hasUnreadMessages: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}has_unread_messages'])!,
      unreadCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unread_count'])!,
    );
  }

  @override
  $CachedConversationsTable createAlias(String alias) {
    return $CachedConversationsTable(attachedDatabase, alias);
  }
}

class CachedConversation extends DataClass
    implements Insertable<CachedConversation> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? otherUserId;
  final bool hasUnreadMessages;
  final int unreadCount;
  const CachedConversation(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      this.lastMessage,
      this.lastMessageTime,
      this.otherUserName,
      this.otherUserAvatar,
      this.otherUserId,
      required this.hasUnreadMessages,
      required this.unreadCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastMessage != null) {
      map['last_message'] = Variable<String>(lastMessage);
    }
    if (!nullToAbsent || lastMessageTime != null) {
      map['last_message_time'] = Variable<DateTime>(lastMessageTime);
    }
    if (!nullToAbsent || otherUserName != null) {
      map['other_user_name'] = Variable<String>(otherUserName);
    }
    if (!nullToAbsent || otherUserAvatar != null) {
      map['other_user_avatar'] = Variable<String>(otherUserAvatar);
    }
    if (!nullToAbsent || otherUserId != null) {
      map['other_user_id'] = Variable<String>(otherUserId);
    }
    map['has_unread_messages'] = Variable<bool>(hasUnreadMessages);
    map['unread_count'] = Variable<int>(unreadCount);
    return map;
  }

  CachedConversationsCompanion toCompanion(bool nullToAbsent) {
    return CachedConversationsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastMessage: lastMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessage),
      lastMessageTime: lastMessageTime == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageTime),
      otherUserName: otherUserName == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUserName),
      otherUserAvatar: otherUserAvatar == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUserAvatar),
      otherUserId: otherUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUserId),
      hasUnreadMessages: Value(hasUnreadMessages),
      unreadCount: Value(unreadCount),
    );
  }

  factory CachedConversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedConversation(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastMessage: serializer.fromJson<String?>(json['lastMessage']),
      lastMessageTime: serializer.fromJson<DateTime?>(json['lastMessageTime']),
      otherUserName: serializer.fromJson<String?>(json['otherUserName']),
      otherUserAvatar: serializer.fromJson<String?>(json['otherUserAvatar']),
      otherUserId: serializer.fromJson<String?>(json['otherUserId']),
      hasUnreadMessages: serializer.fromJson<bool>(json['hasUnreadMessages']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastMessage': serializer.toJson<String?>(lastMessage),
      'lastMessageTime': serializer.toJson<DateTime?>(lastMessageTime),
      'otherUserName': serializer.toJson<String?>(otherUserName),
      'otherUserAvatar': serializer.toJson<String?>(otherUserAvatar),
      'otherUserId': serializer.toJson<String?>(otherUserId),
      'hasUnreadMessages': serializer.toJson<bool>(hasUnreadMessages),
      'unreadCount': serializer.toJson<int>(unreadCount),
    };
  }

  CachedConversation copyWith(
          {String? id,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<String?> lastMessage = const Value.absent(),
          Value<DateTime?> lastMessageTime = const Value.absent(),
          Value<String?> otherUserName = const Value.absent(),
          Value<String?> otherUserAvatar = const Value.absent(),
          Value<String?> otherUserId = const Value.absent(),
          bool? hasUnreadMessages,
          int? unreadCount}) =>
      CachedConversation(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastMessage: lastMessage.present ? lastMessage.value : this.lastMessage,
        lastMessageTime: lastMessageTime.present
            ? lastMessageTime.value
            : this.lastMessageTime,
        otherUserName:
            otherUserName.present ? otherUserName.value : this.otherUserName,
        otherUserAvatar: otherUserAvatar.present
            ? otherUserAvatar.value
            : this.otherUserAvatar,
        otherUserId: otherUserId.present ? otherUserId.value : this.otherUserId,
        hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
        unreadCount: unreadCount ?? this.unreadCount,
      );
  CachedConversation copyWithCompanion(CachedConversationsCompanion data) {
    return CachedConversation(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastMessage:
          data.lastMessage.present ? data.lastMessage.value : this.lastMessage,
      lastMessageTime: data.lastMessageTime.present
          ? data.lastMessageTime.value
          : this.lastMessageTime,
      otherUserName: data.otherUserName.present
          ? data.otherUserName.value
          : this.otherUserName,
      otherUserAvatar: data.otherUserAvatar.present
          ? data.otherUserAvatar.value
          : this.otherUserAvatar,
      otherUserId:
          data.otherUserId.present ? data.otherUserId.value : this.otherUserId,
      hasUnreadMessages: data.hasUnreadMessages.present
          ? data.hasUnreadMessages.value
          : this.hasUnreadMessages,
      unreadCount:
          data.unreadCount.present ? data.unreadCount.value : this.unreadCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedConversation(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastMessageTime: $lastMessageTime, ')
          ..write('otherUserName: $otherUserName, ')
          ..write('otherUserAvatar: $otherUserAvatar, ')
          ..write('otherUserId: $otherUserId, ')
          ..write('hasUnreadMessages: $hasUnreadMessages, ')
          ..write('unreadCount: $unreadCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      createdAt,
      updatedAt,
      lastMessage,
      lastMessageTime,
      otherUserName,
      otherUserAvatar,
      otherUserId,
      hasUnreadMessages,
      unreadCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedConversation &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastMessage == this.lastMessage &&
          other.lastMessageTime == this.lastMessageTime &&
          other.otherUserName == this.otherUserName &&
          other.otherUserAvatar == this.otherUserAvatar &&
          other.otherUserId == this.otherUserId &&
          other.hasUnreadMessages == this.hasUnreadMessages &&
          other.unreadCount == this.unreadCount);
}

class CachedConversationsCompanion extends UpdateCompanion<CachedConversation> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> lastMessage;
  final Value<DateTime?> lastMessageTime;
  final Value<String?> otherUserName;
  final Value<String?> otherUserAvatar;
  final Value<String?> otherUserId;
  final Value<bool> hasUnreadMessages;
  final Value<int> unreadCount;
  final Value<int> rowid;
  const CachedConversationsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastMessageTime = const Value.absent(),
    this.otherUserName = const Value.absent(),
    this.otherUserAvatar = const Value.absent(),
    this.otherUserId = const Value.absent(),
    this.hasUnreadMessages = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedConversationsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastMessage = const Value.absent(),
    this.lastMessageTime = const Value.absent(),
    this.otherUserName = const Value.absent(),
    this.otherUserAvatar = const Value.absent(),
    this.otherUserId = const Value.absent(),
    this.hasUnreadMessages = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<CachedConversation> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? lastMessage,
    Expression<DateTime>? lastMessageTime,
    Expression<String>? otherUserName,
    Expression<String>? otherUserAvatar,
    Expression<String>? otherUserId,
    Expression<bool>? hasUnreadMessages,
    Expression<int>? unreadCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastMessage != null) 'last_message': lastMessage,
      if (lastMessageTime != null) 'last_message_time': lastMessageTime,
      if (otherUserName != null) 'other_user_name': otherUserName,
      if (otherUserAvatar != null) 'other_user_avatar': otherUserAvatar,
      if (otherUserId != null) 'other_user_id': otherUserId,
      if (hasUnreadMessages != null) 'has_unread_messages': hasUnreadMessages,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedConversationsCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String?>? lastMessage,
      Value<DateTime?>? lastMessageTime,
      Value<String?>? otherUserName,
      Value<String?>? otherUserAvatar,
      Value<String?>? otherUserId,
      Value<bool>? hasUnreadMessages,
      Value<int>? unreadCount,
      Value<int>? rowid}) {
    return CachedConversationsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      otherUserId: otherUserId ?? this.otherUserId,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      unreadCount: unreadCount ?? this.unreadCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (lastMessageTime.present) {
      map['last_message_time'] = Variable<DateTime>(lastMessageTime.value);
    }
    if (otherUserName.present) {
      map['other_user_name'] = Variable<String>(otherUserName.value);
    }
    if (otherUserAvatar.present) {
      map['other_user_avatar'] = Variable<String>(otherUserAvatar.value);
    }
    if (otherUserId.present) {
      map['other_user_id'] = Variable<String>(otherUserId.value);
    }
    if (hasUnreadMessages.present) {
      map['has_unread_messages'] = Variable<bool>(hasUnreadMessages.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedConversationsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastMessageTime: $lastMessageTime, ')
          ..write('otherUserName: $otherUserName, ')
          ..write('otherUserAvatar: $otherUserAvatar, ')
          ..write('otherUserId: $otherUserId, ')
          ..write('hasUnreadMessages: $hasUnreadMessages, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ConversationCacheDatabase extends GeneratedDatabase {
  _$ConversationCacheDatabase(QueryExecutor e) : super(e);
  $ConversationCacheDatabaseManager get managers =>
      $ConversationCacheDatabaseManager(this);
  late final $CachedConversationsTable cachedConversations =
      $CachedConversationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedConversations];
}

typedef $$CachedConversationsTableCreateCompanionBuilder
    = CachedConversationsCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<String?> lastMessage,
  Value<DateTime?> lastMessageTime,
  Value<String?> otherUserName,
  Value<String?> otherUserAvatar,
  Value<String?> otherUserId,
  Value<bool> hasUnreadMessages,
  Value<int> unreadCount,
  Value<int> rowid,
});
typedef $$CachedConversationsTableUpdateCompanionBuilder
    = CachedConversationsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String?> lastMessage,
  Value<DateTime?> lastMessageTime,
  Value<String?> otherUserName,
  Value<String?> otherUserAvatar,
  Value<String?> otherUserId,
  Value<bool> hasUnreadMessages,
  Value<int> unreadCount,
  Value<int> rowid,
});

class $$CachedConversationsTableFilterComposer
    extends Composer<_$ConversationCacheDatabase, $CachedConversationsTable> {
  $$CachedConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastMessageTime => $composableBuilder(
      column: $table.lastMessageTime,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherUserName => $composableBuilder(
      column: $table.otherUserName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherUserAvatar => $composableBuilder(
      column: $table.otherUserAvatar,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherUserId => $composableBuilder(
      column: $table.otherUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hasUnreadMessages => $composableBuilder(
      column: $table.hasUnreadMessages,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnFilters(column));
}

class $$CachedConversationsTableOrderingComposer
    extends Composer<_$ConversationCacheDatabase, $CachedConversationsTable> {
  $$CachedConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastMessageTime => $composableBuilder(
      column: $table.lastMessageTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherUserName => $composableBuilder(
      column: $table.otherUserName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherUserAvatar => $composableBuilder(
      column: $table.otherUserAvatar,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherUserId => $composableBuilder(
      column: $table.otherUserId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hasUnreadMessages => $composableBuilder(
      column: $table.hasUnreadMessages,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnOrderings(column));
}

class $$CachedConversationsTableAnnotationComposer
    extends Composer<_$ConversationCacheDatabase, $CachedConversationsTable> {
  $$CachedConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => column);

  GeneratedColumn<DateTime> get lastMessageTime => $composableBuilder(
      column: $table.lastMessageTime, builder: (column) => column);

  GeneratedColumn<String> get otherUserName => $composableBuilder(
      column: $table.otherUserName, builder: (column) => column);

  GeneratedColumn<String> get otherUserAvatar => $composableBuilder(
      column: $table.otherUserAvatar, builder: (column) => column);

  GeneratedColumn<String> get otherUserId => $composableBuilder(
      column: $table.otherUserId, builder: (column) => column);

  GeneratedColumn<bool> get hasUnreadMessages => $composableBuilder(
      column: $table.hasUnreadMessages, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => column);
}

class $$CachedConversationsTableTableManager extends RootTableManager<
    _$ConversationCacheDatabase,
    $CachedConversationsTable,
    CachedConversation,
    $$CachedConversationsTableFilterComposer,
    $$CachedConversationsTableOrderingComposer,
    $$CachedConversationsTableAnnotationComposer,
    $$CachedConversationsTableCreateCompanionBuilder,
    $$CachedConversationsTableUpdateCompanionBuilder,
    (
      CachedConversation,
      BaseReferences<_$ConversationCacheDatabase, $CachedConversationsTable,
          CachedConversation>
    ),
    CachedConversation,
    PrefetchHooks Function()> {
  $$CachedConversationsTableTableManager(
      _$ConversationCacheDatabase db, $CachedConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedConversationsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedConversationsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> lastMessage = const Value.absent(),
            Value<DateTime?> lastMessageTime = const Value.absent(),
            Value<String?> otherUserName = const Value.absent(),
            Value<String?> otherUserAvatar = const Value.absent(),
            Value<String?> otherUserId = const Value.absent(),
            Value<bool> hasUnreadMessages = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedConversationsCompanion(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            otherUserName: otherUserName,
            otherUserAvatar: otherUserAvatar,
            otherUserId: otherUserId,
            hasUnreadMessages: hasUnreadMessages,
            unreadCount: unreadCount,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<String?> lastMessage = const Value.absent(),
            Value<DateTime?> lastMessageTime = const Value.absent(),
            Value<String?> otherUserName = const Value.absent(),
            Value<String?> otherUserAvatar = const Value.absent(),
            Value<String?> otherUserId = const Value.absent(),
            Value<bool> hasUnreadMessages = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedConversationsCompanion.insert(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            otherUserName: otherUserName,
            otherUserAvatar: otherUserAvatar,
            otherUserId: otherUserId,
            hasUnreadMessages: hasUnreadMessages,
            unreadCount: unreadCount,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedConversationsTableProcessedTableManager = ProcessedTableManager<
    _$ConversationCacheDatabase,
    $CachedConversationsTable,
    CachedConversation,
    $$CachedConversationsTableFilterComposer,
    $$CachedConversationsTableOrderingComposer,
    $$CachedConversationsTableAnnotationComposer,
    $$CachedConversationsTableCreateCompanionBuilder,
    $$CachedConversationsTableUpdateCompanionBuilder,
    (
      CachedConversation,
      BaseReferences<_$ConversationCacheDatabase, $CachedConversationsTable,
          CachedConversation>
    ),
    CachedConversation,
    PrefetchHooks Function()>;

class $ConversationCacheDatabaseManager {
  final _$ConversationCacheDatabase _db;
  $ConversationCacheDatabaseManager(this._db);
  $$CachedConversationsTableTableManager get cachedConversations =>
      $$CachedConversationsTableTableManager(_db, _db.cachedConversations);
}
