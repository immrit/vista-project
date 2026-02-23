import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../features/chat/data/entities/message_entity.dart';
import '../features/chat/data/entities/conversation_entity.dart';
import '../features/profile/data/entities/profile_entity.dart';
import '../features/posts/data/entities/post_entity.dart';
import '../security/secure_kv_store.dart';

import '../DB/entities/recent_search_entity.dart';
import '../DB/entities/app_settings_entity.dart';
import '../DB/entities/deletion_task_entity.dart';
import '../DB/entities/retry_queue_entity.dart';

class IsarDatabaseManager {
  static final IsarDatabaseManager _instance = IsarDatabaseManager._internal();
  factory IsarDatabaseManager() => _instance;
  IsarDatabaseManager._internal();

  Isar? _isar;
  Future<Isar>? _openingFuture;
  static const String _isarKeyStorageKey = 'isar_encryption_key';
  static const String _isarEncryptionEnabledKey = 'isar_encryption_enabled';

  Future<Isar> get instance async {
    if (_isar != null && _isar!.isOpen) {
      return _isar!;
    }

    final alreadyOpen = Isar.getInstance();
    if (alreadyOpen != null && alreadyOpen.isOpen) {
      _isar = alreadyOpen;
      return alreadyOpen;
    }

    if (_openingFuture != null) {
      return _openingFuture!;
    }

    _openingFuture = _init();
    try {
      final opened = await _openingFuture!;
      _isar = opened;
      return opened;
    } finally {
      _openingFuture = null;
    }
  }

  Future<Isar> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final encryptionKey = await _getEncryptionKey(dir);
    return _openIsar(dir, encryptionKey);
  }

  Future<Isar> _openIsar(Directory dir, List<int>? encryptionKey) async {
    final schemas = [
      MessageEntitySchema,
      ConversationEntitySchema,
      RecentSearchEntitySchema,
      AppSettingsEntitySchema,
      DeletionTaskEntitySchema,
      ProfileEntitySchema,
      PostEntitySchema,
      RetryQueueEntitySchema,
    ];

    final namedArgs = <Symbol, dynamic>{
      #directory: dir.path,
      #inspector: kDebugMode,
    };

    if (encryptionKey != null) {
      namedArgs[#encryptionKey] = encryptionKey;
    }

    try {
      final result = await Function.apply(Isar.open, [schemas], namedArgs);
      return result as Isar;
    } on IsarError catch (e) {
      // Guard against concurrent open attempts returning
      // "Instance has already been opened."
      if (e.toString().contains('already been opened')) {
        final alreadyOpen = Isar.getInstance();
        if (alreadyOpen != null && alreadyOpen.isOpen) {
          return alreadyOpen;
        }
      }
      rethrow;
    } on NoSuchMethodError {
      if (namedArgs.containsKey(#encryptionKey)) {
        namedArgs.remove(#encryptionKey);
        final result = await Function.apply(Isar.open, [schemas], namedArgs);
        return result as Isar;
      }
      rethrow;
    } on ArgumentError {
      if (namedArgs.containsKey(#encryptionKey)) {
        namedArgs.remove(#encryptionKey);
        final result = await Function.apply(Isar.open, [schemas], namedArgs);
        return result as Isar;
      }
      rethrow;
    }
  }

  Future<List<int>?> _getEncryptionKey(Directory dir) async {
    try {
      final enabled = await SecureKeyValueStore.read(_isarEncryptionEnabledKey);
      final existingKeyB64 = await SecureKeyValueStore.read(_isarKeyStorageKey);

      if (existingKeyB64 != null && existingKeyB64.isNotEmpty) {
        return base64.decode(existingKeyB64);
      }

      final hasDb = _doesIsarDbExist(dir);
      if (hasDb && enabled != 'true') {
        // Existing unencrypted DB: avoid breaking users.
        // A safe migration can be added later to re-encrypt.
        return null;
      }

      // New install or explicit enable: generate key.
      final keyBytes = _generateRandomKeyBytes(32);
      await SecureKeyValueStore.write(
          _isarKeyStorageKey, base64.encode(keyBytes));
      await SecureKeyValueStore.write(_isarEncryptionEnabledKey, 'true');
      return keyBytes;
    } catch (_) {
      return null;
    }
  }

  bool _doesIsarDbExist(Directory dir) {
    if (!dir.existsSync()) return false;
    final entries = dir.listSync();
    return entries.any((e) {
      if (e is File) {
        return e.path.endsWith('.isar') || e.path.endsWith('.isar.lock');
      }
      return false;
    });
  }

  List<int> _generateRandomKeyBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
