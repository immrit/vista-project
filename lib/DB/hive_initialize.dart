// hive_initialize.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
