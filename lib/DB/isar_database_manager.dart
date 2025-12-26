import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../features/chat/data/entities/message_entity.dart';
import '../features/chat/data/entities/conversation_entity.dart';

import '../DB/entities/recent_search_entity.dart';
import '../DB/entities/app_settings_entity.dart';
import '../DB/entities/deletion_task_entity.dart';

class IsarDatabaseManager {
  static final IsarDatabaseManager _instance = IsarDatabaseManager._internal();
  factory IsarDatabaseManager() => _instance;
  IsarDatabaseManager._internal();

  Isar? _isar;

  Future<Isar> get instance async {
    if (_isar != null) return _isar!;
    _isar = await _init();
    return _isar!;
  }

  Future<Isar> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [
        MessageEntitySchema,
        ConversationEntitySchema,
        RecentSearchEntitySchema,
        AppSettingsEntitySchema,
        DeletionTaskEntitySchema,
      ],
      directory: dir.path,
      inspector: kDebugMode,
    );
    return isar;
  }
}
