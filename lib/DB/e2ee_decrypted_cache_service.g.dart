// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'e2ee_decrypted_cache_service.dart';

// ignore_for_file: type=lint
class $DecryptedMessagesTable extends DecryptedMessages
    with TableInfo<$DecryptedMessagesTable, DecryptedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecryptedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _decryptedContentMeta =
      const VerificationMeta('decryptedContent');
  @override
  late final GeneratedColumn<String> decryptedContent = GeneratedColumn<String>(
      'decrypted_content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _decryptedReplyContentMeta =
      const VerificationMeta('decryptedReplyContent');
  @override
  late final GeneratedColumn<String> decryptedReplyContent =
      GeneratedColumn<String>('decrypted_reply_content', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _decryptedAtMeta =
      const VerificationMeta('decryptedAt');
  @override
  late final GeneratedColumn<DateTime> decryptedAt = GeneratedColumn<DateTime>(
      'decrypted_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        messageId,
        conversationId,
        userId,
        decryptedContent,
        decryptedReplyContent,
        decryptedAt,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decrypted_messages';
  @override
  VerificationContext validateIntegrity(Insertable<DecryptedMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('decrypted_content')) {
      context.handle(
          _decryptedContentMeta,
          decryptedContent.isAcceptableOrUnknown(
              data['decrypted_content']!, _decryptedContentMeta));
    } else if (isInserting) {
      context.missing(_decryptedContentMeta);
    }
    if (data.containsKey('decrypted_reply_content')) {
      context.handle(
          _decryptedReplyContentMeta,
          decryptedReplyContent.isAcceptableOrUnknown(
              data['decrypted_reply_content']!, _decryptedReplyContentMeta));
    }
    if (data.containsKey('decrypted_at')) {
      context.handle(
          _decryptedAtMeta,
          decryptedAt.isAcceptableOrUnknown(
              data['decrypted_at']!, _decryptedAtMeta));
    } else if (isInserting) {
      context.missing(_decryptedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, conversationId, userId};
  @override
  DecryptedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DecryptedMessage(
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      decryptedContent: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}decrypted_content'])!,
      decryptedReplyContent: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}decrypted_reply_content']),
      decryptedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}decrypted_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DecryptedMessagesTable createAlias(String alias) {
    return $DecryptedMessagesTable(attachedDatabase, alias);
  }
}

class DecryptedMessage extends DataClass
    implements Insertable<DecryptedMessage> {
  final String messageId;
  final String conversationId;
  final String userId;
  final String decryptedContent;
  final String? decryptedReplyContent;
  final DateTime decryptedAt;
  final DateTime createdAt;
  const DecryptedMessage(
      {required this.messageId,
      required this.conversationId,
      required this.userId,
      required this.decryptedContent,
      this.decryptedReplyContent,
      required this.decryptedAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['user_id'] = Variable<String>(userId);
    map['decrypted_content'] = Variable<String>(decryptedContent);
    if (!nullToAbsent || decryptedReplyContent != null) {
      map['decrypted_reply_content'] = Variable<String>(decryptedReplyContent);
    }
    map['decrypted_at'] = Variable<DateTime>(decryptedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DecryptedMessagesCompanion toCompanion(bool nullToAbsent) {
    return DecryptedMessagesCompanion(
      messageId: Value(messageId),
      conversationId: Value(conversationId),
      userId: Value(userId),
      decryptedContent: Value(decryptedContent),
      decryptedReplyContent: decryptedReplyContent == null && nullToAbsent
          ? const Value.absent()
          : Value(decryptedReplyContent),
      decryptedAt: Value(decryptedAt),
      createdAt: Value(createdAt),
    );
  }

  factory DecryptedMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DecryptedMessage(
      messageId: serializer.fromJson<String>(json['messageId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      userId: serializer.fromJson<String>(json['userId']),
      decryptedContent: serializer.fromJson<String>(json['decryptedContent']),
      decryptedReplyContent:
          serializer.fromJson<String?>(json['decryptedReplyContent']),
      decryptedAt: serializer.fromJson<DateTime>(json['decryptedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'conversationId': serializer.toJson<String>(conversationId),
      'userId': serializer.toJson<String>(userId),
      'decryptedContent': serializer.toJson<String>(decryptedContent),
      'decryptedReplyContent':
          serializer.toJson<String?>(decryptedReplyContent),
      'decryptedAt': serializer.toJson<DateTime>(decryptedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DecryptedMessage copyWith(
          {String? messageId,
          String? conversationId,
          String? userId,
          String? decryptedContent,
          Value<String?> decryptedReplyContent = const Value.absent(),
          DateTime? decryptedAt,
          DateTime? createdAt}) =>
      DecryptedMessage(
        messageId: messageId ?? this.messageId,
        conversationId: conversationId ?? this.conversationId,
        userId: userId ?? this.userId,
        decryptedContent: decryptedContent ?? this.decryptedContent,
        decryptedReplyContent: decryptedReplyContent.present
            ? decryptedReplyContent.value
            : this.decryptedReplyContent,
        decryptedAt: decryptedAt ?? this.decryptedAt,
        createdAt: createdAt ?? this.createdAt,
      );
  DecryptedMessage copyWithCompanion(DecryptedMessagesCompanion data) {
    return DecryptedMessage(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      userId: data.userId.present ? data.userId.value : this.userId,
      decryptedContent: data.decryptedContent.present
          ? data.decryptedContent.value
          : this.decryptedContent,
      decryptedReplyContent: data.decryptedReplyContent.present
          ? data.decryptedReplyContent.value
          : this.decryptedReplyContent,
      decryptedAt:
          data.decryptedAt.present ? data.decryptedAt.value : this.decryptedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DecryptedMessage(')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('userId: $userId, ')
          ..write('decryptedContent: $decryptedContent, ')
          ..write('decryptedReplyContent: $decryptedReplyContent, ')
          ..write('decryptedAt: $decryptedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, conversationId, userId,
      decryptedContent, decryptedReplyContent, decryptedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DecryptedMessage &&
          other.messageId == this.messageId &&
          other.conversationId == this.conversationId &&
          other.userId == this.userId &&
          other.decryptedContent == this.decryptedContent &&
          other.decryptedReplyContent == this.decryptedReplyContent &&
          other.decryptedAt == this.decryptedAt &&
          other.createdAt == this.createdAt);
}

class DecryptedMessagesCompanion extends UpdateCompanion<DecryptedMessage> {
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<String> userId;
  final Value<String> decryptedContent;
  final Value<String?> decryptedReplyContent;
  final Value<DateTime> decryptedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DecryptedMessagesCompanion({
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.userId = const Value.absent(),
    this.decryptedContent = const Value.absent(),
    this.decryptedReplyContent = const Value.absent(),
    this.decryptedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DecryptedMessagesCompanion.insert({
    required String messageId,
    required String conversationId,
    required String userId,
    required String decryptedContent,
    this.decryptedReplyContent = const Value.absent(),
    required DateTime decryptedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : messageId = Value(messageId),
        conversationId = Value(conversationId),
        userId = Value(userId),
        decryptedContent = Value(decryptedContent),
        decryptedAt = Value(decryptedAt),
        createdAt = Value(createdAt);
  static Insertable<DecryptedMessage> custom({
    Expression<String>? messageId,
    Expression<String>? conversationId,
    Expression<String>? userId,
    Expression<String>? decryptedContent,
    Expression<String>? decryptedReplyContent,
    Expression<DateTime>? decryptedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (userId != null) 'user_id': userId,
      if (decryptedContent != null) 'decrypted_content': decryptedContent,
      if (decryptedReplyContent != null)
        'decrypted_reply_content': decryptedReplyContent,
      if (decryptedAt != null) 'decrypted_at': decryptedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DecryptedMessagesCompanion copyWith(
      {Value<String>? messageId,
      Value<String>? conversationId,
      Value<String>? userId,
      Value<String>? decryptedContent,
      Value<String?>? decryptedReplyContent,
      Value<DateTime>? decryptedAt,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return DecryptedMessagesCompanion(
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      decryptedContent: decryptedContent ?? this.decryptedContent,
      decryptedReplyContent:
          decryptedReplyContent ?? this.decryptedReplyContent,
      decryptedAt: decryptedAt ?? this.decryptedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (decryptedContent.present) {
      map['decrypted_content'] = Variable<String>(decryptedContent.value);
    }
    if (decryptedReplyContent.present) {
      map['decrypted_reply_content'] =
          Variable<String>(decryptedReplyContent.value);
    }
    if (decryptedAt.present) {
      map['decrypted_at'] = Variable<DateTime>(decryptedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecryptedMessagesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('userId: $userId, ')
          ..write('decryptedContent: $decryptedContent, ')
          ..write('decryptedReplyContent: $decryptedReplyContent, ')
          ..write('decryptedAt: $decryptedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$E2EEDecryptedCacheDatabase extends GeneratedDatabase {
  _$E2EEDecryptedCacheDatabase(QueryExecutor e) : super(e);
  $E2EEDecryptedCacheDatabaseManager get managers =>
      $E2EEDecryptedCacheDatabaseManager(this);
  late final $DecryptedMessagesTable decryptedMessages =
      $DecryptedMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [decryptedMessages];
}

typedef $$DecryptedMessagesTableCreateCompanionBuilder
    = DecryptedMessagesCompanion Function({
  required String messageId,
  required String conversationId,
  required String userId,
  required String decryptedContent,
  Value<String?> decryptedReplyContent,
  required DateTime decryptedAt,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$DecryptedMessagesTableUpdateCompanionBuilder
    = DecryptedMessagesCompanion Function({
  Value<String> messageId,
  Value<String> conversationId,
  Value<String> userId,
  Value<String> decryptedContent,
  Value<String?> decryptedReplyContent,
  Value<DateTime> decryptedAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$DecryptedMessagesTableFilterComposer
    extends Composer<_$E2EEDecryptedCacheDatabase, $DecryptedMessagesTable> {
  $$DecryptedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get decryptedContent => $composableBuilder(
      column: $table.decryptedContent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get decryptedReplyContent => $composableBuilder(
      column: $table.decryptedReplyContent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get decryptedAt => $composableBuilder(
      column: $table.decryptedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$DecryptedMessagesTableOrderingComposer
    extends Composer<_$E2EEDecryptedCacheDatabase, $DecryptedMessagesTable> {
  $$DecryptedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get decryptedContent => $composableBuilder(
      column: $table.decryptedContent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get decryptedReplyContent => $composableBuilder(
      column: $table.decryptedReplyContent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get decryptedAt => $composableBuilder(
      column: $table.decryptedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$DecryptedMessagesTableAnnotationComposer
    extends Composer<_$E2EEDecryptedCacheDatabase, $DecryptedMessagesTable> {
  $$DecryptedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get decryptedContent => $composableBuilder(
      column: $table.decryptedContent, builder: (column) => column);

  GeneratedColumn<String> get decryptedReplyContent => $composableBuilder(
      column: $table.decryptedReplyContent, builder: (column) => column);

  GeneratedColumn<DateTime> get decryptedAt => $composableBuilder(
      column: $table.decryptedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DecryptedMessagesTableTableManager extends RootTableManager<
    _$E2EEDecryptedCacheDatabase,
    $DecryptedMessagesTable,
    DecryptedMessage,
    $$DecryptedMessagesTableFilterComposer,
    $$DecryptedMessagesTableOrderingComposer,
    $$DecryptedMessagesTableAnnotationComposer,
    $$DecryptedMessagesTableCreateCompanionBuilder,
    $$DecryptedMessagesTableUpdateCompanionBuilder,
    (
      DecryptedMessage,
      BaseReferences<_$E2EEDecryptedCacheDatabase, $DecryptedMessagesTable,
          DecryptedMessage>
    ),
    DecryptedMessage,
    PrefetchHooks Function()> {
  $$DecryptedMessagesTableTableManager(
      _$E2EEDecryptedCacheDatabase db, $DecryptedMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecryptedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecryptedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecryptedMessagesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> messageId = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> decryptedContent = const Value.absent(),
            Value<String?> decryptedReplyContent = const Value.absent(),
            Value<DateTime> decryptedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DecryptedMessagesCompanion(
            messageId: messageId,
            conversationId: conversationId,
            userId: userId,
            decryptedContent: decryptedContent,
            decryptedReplyContent: decryptedReplyContent,
            decryptedAt: decryptedAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String messageId,
            required String conversationId,
            required String userId,
            required String decryptedContent,
            Value<String?> decryptedReplyContent = const Value.absent(),
            required DateTime decryptedAt,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DecryptedMessagesCompanion.insert(
            messageId: messageId,
            conversationId: conversationId,
            userId: userId,
            decryptedContent: decryptedContent,
            decryptedReplyContent: decryptedReplyContent,
            decryptedAt: decryptedAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DecryptedMessagesTableProcessedTableManager = ProcessedTableManager<
    _$E2EEDecryptedCacheDatabase,
    $DecryptedMessagesTable,
    DecryptedMessage,
    $$DecryptedMessagesTableFilterComposer,
    $$DecryptedMessagesTableOrderingComposer,
    $$DecryptedMessagesTableAnnotationComposer,
    $$DecryptedMessagesTableCreateCompanionBuilder,
    $$DecryptedMessagesTableUpdateCompanionBuilder,
    (
      DecryptedMessage,
      BaseReferences<_$E2EEDecryptedCacheDatabase, $DecryptedMessagesTable,
          DecryptedMessage>
    ),
    DecryptedMessage,
    PrefetchHooks Function()>;

class $E2EEDecryptedCacheDatabaseManager {
  final _$E2EEDecryptedCacheDatabase _db;
  $E2EEDecryptedCacheDatabaseManager(this._db);
  $$DecryptedMessagesTableTableManager get decryptedMessages =>
      $$DecryptedMessagesTableTableManager(_db, _db.decryptedMessages);
}
