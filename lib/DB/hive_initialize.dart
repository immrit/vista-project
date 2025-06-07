// hive_initialize.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../model/Hive Model/conversation_hive_model.dart';
import '../model/Hive Model/message_hive_model.dart';

class HiveInitialize {
  static bool _adaptersRegistered = false;

  static Future<void> initialize() async {
    // فقط یکبار مقداردهی کن
    if (!kIsWeb) {
      await Hive.initFlutter();
    } else {
      await Hive.initFlutter();
    }

    // ثبت آداپتورها فقط یکبار
    // if (!_adaptersRegistered) {
    //   Hive.registerAdapter(ConversationHiveModelAdapter());
    //   Hive.registerAdapter(ConversationParticipantHiveModelAdapter());
    //   Hive.registerAdapter(MessageHiveModelAdapter());
    //   _adaptersRegistered = true;
    // }

    // // باز کردن باکس‌ها
    // await Hive.openBox<ConversationHiveModel>('conversations');
    // await Hive.openBox<MessageHiveModel>('messages');
  }
}
