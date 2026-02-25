import '../security/logging_utility.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Utility functions for database file operations
/// These functions are simplified for web compatibility

/// Get message cache database file (returns null for web)
Future<File?> getMessageCacheDbFile() async {
  if (kIsWeb) {
    return null; // No file system access on web
  }
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'messages_cache.sqlite'));
}

/// Get conversation cache database file (returns null for web)
Future<File?> getConversationCacheDbFile() async {
  if (kIsWeb) {
    return null; // No file system access on web
  }
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'conversations.sqlite'));
}

/// Delete message cache database file (no-op for web)
Future<void> deleteMessageCacheDbFile() async {
  if (kIsWeb) {
    logInfo('[Database] Message cache file deletion skipped on web');
    return;
  }
  final file = await getMessageCacheDbFile();
  if (file != null && await file.exists()) {
    await file.delete();
    // Also delete WAL and SHM files
    final wal = File('${file.path}-wal');
    final shm = File('${file.path}-shm');
    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();
  }
}

/// Delete conversation cache database file (no-op for web)
Future<void> deleteConversationCacheDbFile() async {
  if (kIsWeb) {
    logInfo('[Database] Conversation cache file deletion skipped on web');
    return;
  }
  final file = await getConversationCacheDbFile();
  if (file != null && await file.exists()) {
    await file.delete();
    // Also delete WAL and SHM files
    final wal = File('${file.path}-wal');
    final shm = File('${file.path}-shm');
    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();
  }
}


