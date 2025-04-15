// hive_initialize.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../model/Hive Model/conversation_hive_model.dart';
import '../model/Hive Model/message_hive_model.dart';

class HiveInitialize {
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // ثبت آداپتورها
    Hive.registerAdapter(ConversationHiveModelAdapter());
    Hive.registerAdapter(ConversationParticipantHiveModelAdapter());
    Hive.registerAdapter(MessageHiveModelAdapter());

    // باز کردن باکس‌ها
    await Hive.openBox<ConversationHiveModel>('conversations');
    await Hive.openBox<MessageHiveModel>('messages');
  }
}
