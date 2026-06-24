import 'dart:async';
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

class IsarOpenParams {
  final String directoryPath;
  final List<int>? encryptionKey;

  IsarOpenParams({required this.directoryPath, this.encryptionKey});
}

class IsarDatabaseManager {
  static final IsarDatabaseManager _instance = IsarDatabaseManager._internal();
  factory IsarDatabaseManager() => _instance;
  IsarDatabaseManager._internal();

  Isar? _isar;
  Completer<Isar>? _openingCompleter;
  static const String _isarKeyStorageKey = 'isar_encryption_key';
  static const String _isarEncryptionEnabledKey = 'isar_encryption_enabled';
  static const int _maxOpenAttempts = 6;

  Future<Isar> get instance async {
    final cached = _resolveCachedInstance();
    if (cached != null) return cached;

    if (_openingCompleter != null) {
      return _openingCompleter!.future;
    }

    final completer = Completer<Isar>();
    _openingCompleter = completer;

    try {
      final opened = await _init();
      _isar = opened;
      completer.complete(opened);
      return opened;
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      _openingCompleter = null;
    }
  }

  Future<IsarOpenParams> getOpenParams() async {
    final dir = await getApplicationDocumentsDirectory();
    final encryptionKey = await _getEncryptionKey(dir);
    return IsarOpenParams(
      directoryPath: dir.path,
      encryptionKey: encryptionKey,
    );
  }

  static Isar openIsarSynchronously(IsarOpenParams params) {
    final alreadyOpen = Isar.getInstance();
    if (alreadyOpen != null && alreadyOpen.isOpen) {
      return alreadyOpen;
    }

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
      #directory: params.directoryPath,
    };

    if (params.encryptionKey != null) {
      namedArgs[#encryptionKey] = params.encryptionKey;
    }

    try {
      final result = Function.apply(Isar.openSync, [schemas], namedArgs);
      return result as Isar;
    } catch (e) {
      rethrow;
    }
  }

  Isar? _resolveCachedInstance() {
    if (_isar != null && _isar!.isOpen) return _isar;
    final alreadyOpen = Isar.getInstance();
    if (alreadyOpen != null && alreadyOpen.isOpen) {
      _isar = alreadyOpen;
      return alreadyOpen;
    }
    return null;
  }

  Future<Isar> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final encryptionKey = await _getEncryptionKey(dir);
    return _openIsarWithRetry(dir, encryptionKey);
  }

  Future<Isar> _openIsarWithRetry(
    Directory dir,
    List<int>? encryptionKey,
  ) async {
    Object? lastError;

    for (var attempt = 0; attempt < _maxOpenAttempts; attempt++) {
      final cached = _resolveCachedInstance();
      if (cached != null) return cached;

      try {
        return await _openIsarOnce(dir, encryptionKey);
      } on IsarError catch (error) {
        lastError = error;

        final resolved = _resolveCachedInstance();
        if (resolved != null) return resolved;

        if (_isAlreadyOpenError(error)) {
          final reopened = _resolveCachedInstance();
          if (reopened != null) return reopened;
        }

        final isLastAttempt = attempt >= _maxOpenAttempts - 1;
        if (!_isRetryableOpenError(error)) {
          rethrow;
        }
        if (isLastAttempt) {
          await _tryClearStaleLockFiles(dir);
          try {
            return await _openIsarOnce(dir, encryptionKey);
          } on IsarError catch (finalError) {
            lastError = finalError;
            final resolvedAfterCleanup = _resolveCachedInstance();
            if (resolvedAfterCleanup != null) return resolvedAfterCleanup;
            rethrow;
          }
        }

        final delayMs = 35 * (1 << attempt);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    throw lastError ?? IsarError('Failed to open Isar database');
  }

  bool _isRetryableOpenError(IsarError error) {
    final message = error.toString().toLowerCase();
    return message.contains('try again') ||
        message.contains('mdbxerror (11)') ||
        message.contains('resource temporarily unavailable') ||
        message.contains('cannot open environment');
  }

  bool _isAlreadyOpenError(IsarError error) {
    return error.toString().contains('already been opened');
  }

  Future<void> _tryClearStaleLockFiles(Directory dir) async {
    if (!dir.existsSync()) return;
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last.toLowerCase();
        if (name.endsWith('.lock') || name.endsWith('.isar.lock')) {
          try {
            await entity.delete();
          } catch (_) {
            // Best-effort cleanup only.
          }
        }
      }
    } catch (_) {
      // Ignore directory listing failures.
    }
  }

  Future<Isar> _openIsarOnce(Directory dir, List<int>? encryptionKey) async {
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
      if (_isAlreadyOpenError(e)) {
        final alreadyOpen = _resolveCachedInstance();
        if (alreadyOpen != null) return alreadyOpen;
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
