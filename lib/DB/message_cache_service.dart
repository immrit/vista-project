import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../model/message_model.dart';

part 'message_cache_service.g.dart';

// تعریف جدول پیام‌ها
class CachedMessages extends Table {
  TextColumn get id => text()(); // message id (ممکن است temp_ باشد)
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get attachmentUrl => text().nullable()();
  TextColumn get attachmentType => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  BoolColumn get isSent => boolean().withDefault(const Constant(true))();
  TextColumn get senderName => text().nullable()();
  TextColumn get senderAvatar => text().nullable()();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
  TextColumn get replyToMessageId => text().nullable()();
  TextColumn get replyToContent => text().nullable()();
  TextColumn get replyToSenderName => text().nullable()();
  BoolColumn get isPending => boolean().withDefault(const Constant(false))();
  TextColumn get localId => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id, conversationId};
}

// تعریف دیتابیس Drift
@DriftDatabase(tables: [CachedMessages])
class MessageCacheDatabase extends _$MessageCacheDatabase {
  MessageCacheDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // --- اضافه شد: ایندکس برای ستون‌های پرکاربرد ---
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_conversation_id ON cached_messages (conversation_id);');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_created_at ON cached_messages (created_at);');
        },
      );

  // درج یا بروزرسانی پیام
  Future<void> cacheMessage(MessageModel message) async {
    await into(cachedMessages).insertOnConflictUpdate(_toCompanion(message));
  }

  // درج یا بروزرسانی چند پیام
  Future<void> cacheMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        cachedMessages,
        messages.map(_toCompanion).toList(),
      );
    });
  }

  // دریافت پیام‌های یک مکالمه (جدیدترین بالا)
  Future<List<MessageModel>> getConversationMessages(String conversationId,
      {int limit = 50, DateTime? before}) async {
    final query = select(cachedMessages)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)
      ])
      ..limit(limit);

    if (before != null) {
      query.where((tbl) => tbl.createdAt.isSmallerThanValue(before));
    }

    final rows = await query.get();
    return rows.map<MessageModel>(_fromRow).toList();
  }

  // دریافت پیام‌های یک مکالمه بر اساس local_id
  Future<MessageModel?> getMessageByLocalId(
      String conversationId, String localId) async {
    final row = await (select(cachedMessages)
          ..where((tbl) =>
              tbl.conversationId.equals(conversationId) &
              tbl.localId.equals(localId)))
        .getSingleOrNull();
    return row != null ? _fromRow(row) : null;
  }

  // دریافت یک پیام خاص
  Future<MessageModel?> getMessage(
      String conversationId, String messageId) async {
    final row = await (select(cachedMessages)
          ..where((tbl) =>
              tbl.conversationId.equals(conversationId) &
              tbl.id.equals(messageId)))
        .getSingleOrNull();
    return row != null ? _fromRow(row) : null;
  }

  // بروزرسانی وضعیت پیام
  Future<void> updateMessageStatus(
    String conversationId,
    String messageId, {
    bool? isRead,
    bool? isSent,
  }) async {
    final updates = CachedMessagesCompanion(
      isRead: isRead != null ? Value(isRead) : const Value.absent(),
      isSent: isSent != null ? Value(isSent) : const Value.absent(),
    );
    await (update(cachedMessages)
          ..where((tbl) =>
              tbl.conversationId.equals(conversationId) &
              tbl.id.equals(messageId)))
        .write(updates);
  }

  // جایگزینی پیام temp با پیام واقعی
  Future<void> replaceTempMessage(
      String conversationId, String tempId, MessageModel realMessage) async {
    await (delete(cachedMessages)
          ..where((tbl) =>
              tbl.conversationId.equals(conversationId) &
              tbl.id.equals(tempId)))
        .go();
    await cacheMessage(realMessage);
  }

  // علامت‌گذاری پیام temp به عنوان failed
  Future<void> markMessageAsFailed(String conversationId, String tempId) async {
    await (update(cachedMessages)
          ..where((tbl) =>
              tbl.conversationId.equals(conversationId) &
              tbl.id.equals(tempId)))
        .write(const CachedMessagesCompanion(isSent: Value(false)));
  }

  // حذف پیام‌های یک مکالمه
  Future<void> clearConversationMessages(String conversationId) async {
    await (delete(cachedMessages)
          ..where((tbl) => tbl.conversationId.equals(conversationId)))
        .go();
  }

  // حذف یک پیام خاص
  Future<void> clearMessage(String conversationId, String messageId) async {
    await (delete(cachedMessages)
          ..where((tbl) =>
              tbl.conversationId.equals(conversationId) &
              tbl.id.equals(messageId)))
        .go();
  }

  // پاک کردن کل کش
  Future<void> clearAllCache() async {
    await delete(cachedMessages).go();
  }

  // --- اضافه شد: حذف پیام‌های قدیمی‌تر از یک تاریخ ---
  Future<void> deleteMessagesOlderThan(DateTime date) async {
    await (delete(cachedMessages)
          ..where((tbl) => tbl.createdAt.isSmallerThanValue(date)))
        .go();
  }

  // --- اضافه شد: شمارش پیام‌های خوانده‌نشده ---
  Future<int> countUnreadMessages(String conversationId) async {
    final count = await (selectOnly(cachedMessages)
          ..addColumns([cachedMessages.id.count()])
          ..where(cachedMessages.conversationId.equals(conversationId) &
              cachedMessages.isRead.equals(false)))
        .getSingle();
    return count.read(cachedMessages.id.count()) ?? 0;
  }

  // --- اضافه شد: عملیات Transaction ---
  Future<void> performTransaction(Future<void> Function() action) async {
    await transaction(() async {
      await action();
    });
  }
}

// اتصال دیتابیس
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'messages_cache.sqlite'));
    if (!dbFile.existsSync()) {
      dbFile.createSync(recursive: true);
    }
    return NativeDatabase(dbFile);
  });
}

// تبدیل MessageModel به Drift Companion
CachedMessagesCompanion _toCompanion(MessageModel m) {
  return CachedMessagesCompanion(
    id: Value(m.id),
    conversationId: Value(m.conversationId),
    senderId: Value(m.senderId),
    content: Value(m.content),
    createdAt: Value(m.createdAt),
    attachmentUrl: Value(m.attachmentUrl),
    attachmentType: Value(m.attachmentType),
    isRead: Value(m.isRead),
    isSent: Value(m.isSent),
    senderName: Value(m.senderName),
    senderAvatar: Value(m.senderAvatar),
    isMe: Value(m.isMe),
    replyToMessageId: Value(m.replyToMessageId),
    replyToContent: Value(m.replyToContent),
    replyToSenderName: Value(m.replyToSenderName),
    isPending: Value(m.isPending),
    localId: Value(m.localId),
    retryCount: Value(m.retryCount),
  );
}

// تبدیل Drift Row به MessageModel
MessageModel _fromRow(CachedMessage row) {
  return MessageModel(
    id: row.id,
    conversationId: row.conversationId,
    senderId: row.senderId,
    content: row.content,
    createdAt: row.createdAt,
    attachmentUrl: row.attachmentUrl,
    attachmentType: row.attachmentType,
    isRead: row.isRead,
    isSent: row.isSent,
    senderName: row.senderName ?? '', // اطمینان از عدم تهی بودن
    senderAvatar: row.senderAvatar,
    isMe: row.isMe,
    replyToMessageId: row.replyToMessageId,
    replyToContent: row.replyToContent,
    replyToSenderName: row.replyToSenderName,
    isPending: row.isPending,
    localId: row.localId,
    retryCount: row.retryCount,
  );
}

// سرویس کش پیام با API مشابه قبلی
class MessageCacheService {
  static final MessageCacheService _instance = MessageCacheService._internal();
  factory MessageCacheService() => _instance;
  MessageCacheService._internal();

  final MessageCacheDatabase _db = MessageCacheDatabase(); // نمونه دیتابیس

  Future<void> cacheMessage(MessageModel message) => _db.cacheMessage(message);
  Future<void> cacheMessages(List<MessageModel> messages) =>
      _db.cacheMessages(messages);
  Future<List<MessageModel>> getConversationMessages(String conversationId,
          {int limit = 50, DateTime? before}) =>
      _db.getConversationMessages(conversationId, limit: limit, before: before);
  Future<MessageModel?> getMessage(String conversationId, String messageId) =>
      _db.getMessage(conversationId, messageId);
  Future<void> updateMessageStatus(String conversationId, String messageId,
          {bool? isRead, bool? isSent}) =>
      _db.updateMessageStatus(conversationId, messageId,
          isRead: isRead, isSent: isSent);
  Future<void> replaceTempMessage(
          String conversationId, String tempId, MessageModel realMessage) =>
      _db.replaceTempMessage(conversationId, tempId, realMessage);
  Future<void> markMessageAsFailed(String conversationId, String tempId) =>
      _db.markMessageAsFailed(conversationId, tempId);
  Future<void> clearConversationMessages(String conversationId) =>
      _db.clearConversationMessages(conversationId);
  Future<void> clearMessage(String conversationId, String messageId) =>
      _db.clearMessage(conversationId, messageId);
  Future<void> clearAllCache() => _db.clearAllCache();
  Future<void> deleteMessagesOlderThan(DateTime date) =>
      _db.deleteMessagesOlderThan(date);
  Future<int> countUnreadMessages(String conversationId) =>
      _db.countUnreadMessages(conversationId);
  Future<void> performTransaction(Future<void> Function() action) =>
      _db.performTransaction(action);
}
