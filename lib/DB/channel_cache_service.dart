import 'package:hive/hive.dart';
import 'dart:convert';
import '../model/channel_model.dart';
import '../model/channel_message_model.dart';

class ChannelCacheService {
  static const String _channelsBoxName = 'channels_v2';
  static const String _channelMessagesBoxName = 'channel_messages_v2';
  static const String _channelMembersBoxName = 'channel_members_v2';
  static const String _metadataBoxName = 'cache_metadata_v2';

  // تنظیمات کش
  static const Duration _defaultTTL = Duration(hours: 24);
  static const Duration _messagesTTL = Duration(hours: 6);
  static const int _maxMessagesPerChannel = 100;
  static const int _maxChannelsInCache = 50;

  // Singleton pattern
  static final ChannelCacheService _instance = ChannelCacheService._internal();
  factory ChannelCacheService() => _instance;
  ChannelCacheService._internal();

  Box? _channelsBox;
  Box? _messagesBox;
  Box? _membersBox;
  Box? _metadataBox;

  // مقداردهی اولیه
  Future<void> initialize() async {
    try {
      _channelsBox = await Hive.openBox(_channelsBoxName);
      _messagesBox = await Hive.openBox(_channelMessagesBoxName);
      _membersBox = await Hive.openBox(_channelMembersBoxName);
      _metadataBox = await Hive.openBox(_metadataBoxName);

      // پاکسازی کش‌های منقضی شده
      await _cleanExpiredCache();
    } catch (e) {
      print('خطا در مقداردهی کش: $e');
      // در صورت خطا، کش‌ها را پاک کن
      await _resetAllCaches();
    }
  }

  // دریافت Box با مدیریت خطا
  Future<Box> _getChannelsBox() async {
    if (_channelsBox == null || !_channelsBox!.isOpen) {
      _channelsBox = await Hive.openBox(_channelsBoxName);
    }
    return _channelsBox!;
  }

  Future<Box> _getMessagesBox() async {
    if (_messagesBox == null || !_messagesBox!.isOpen) {
      _messagesBox = await Hive.openBox(_channelMessagesBoxName);
    }
    return _messagesBox!;
  }

  Future<Box> _getMembersBox() async {
    if (_membersBox == null || !_membersBox!.isOpen) {
      _membersBox = await Hive.openBox(_channelMembersBoxName);
    }
    return _membersBox!;
  }

  Future<Box> _getMetadataBox() async {
    if (_metadataBox == null || !_metadataBox!.isOpen) {
      _metadataBox = await Hive.openBox(_metadataBoxName);
    }
    return _metadataBox!;
  }

  // ذخیره metadata برای مدیریت انقضا
  Future<void> _saveMetadata(String key, {Duration? ttl}) async {
    final box = await _getMetadataBox();
    final expiry = DateTime.now().add(ttl ?? _defaultTTL);
    await box.put(key, {
      'cached_at': DateTime.now().toIso8601String(),
      'expires_at': expiry.toIso8601String(),
      'version': 1,
    });
  }

  // بررسی انقضا
  Future<bool> _isExpired(String key) async {
    try {
      final box = await _getMetadataBox();
      final metadata = box.get(key);
      if (metadata == null) return true;

      final expiryStr = metadata['expires_at'] as String?;
      if (expiryStr == null) return true;

      final expiry = DateTime.parse(expiryStr);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      return true; // در صورت خطا، منقضی در نظر بگیر
    }
  }

  // کش کردن کانال با مدیریت حافظه
  Future<void> cacheChannel(ChannelModel channel) async {
    try {
      final box = await _getChannelsBox();

      // مدیریت حداکثر تعداد کانال‌ها
      if (box.length >= _maxChannelsInCache) {
        await _removeOldestChannels(5); // حذف 5 کانال قدیمی
      }

      // ذخیره کانال
      await box.put(channel.id, {
        'data': channel.toJson(),
        'cached_at': DateTime.now().toIso8601String(),
      });

      // ذخیره metadata
      await _saveMetadata('channel_${channel.id}');

      print('کانال ${channel.name} در کش ذخیره شد');
    } catch (e) {
      print('خطا در کش کردن کانال: $e');
    }
  }

  // کش کردن چندین کانال
  Future<void> cacheChannels(List<ChannelModel> channels) async {
    try {
      final box = await _getChannelsBox();
      final batch = <String, dynamic>{};

      for (final channel in channels) {
        batch[channel.id] = {
          'data': channel.toJson(),
          'cached_at': DateTime.now().toIso8601String(),
        };
        await _saveMetadata('channel_${channel.id}');
      }

      await box.putAll(batch);
      print('${channels.length} کانال در کش ذخیره شد');
    } catch (e) {
      print('خطا در کش کردن کانال‌ها: $e');
    }
  }

  // دریافت کانال‌های کش شده با بررسی انقضا
  Future<List<ChannelModel>> getCachedChannels(
      {bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await clearChannelsCache();
        return [];
      }

      final box = await _getChannelsBox();
      final channels = <ChannelModel>[];

      for (final key in box.keys) {
        final channelId = key as String;

        // بررسی انقضا
        if (await _isExpired('channel_$channelId')) {
          await box.delete(channelId);
          continue;
        }

        try {
          final cachedData = box.get(channelId);
          if (cachedData != null && cachedData['data'] != null) {
            final channel = ChannelModel.fromJson(
              Map<String, dynamic>.from(cachedData['data']),
            );
            channels.add(channel);
          }
        } catch (e) {
          print('خطا در پارس کردن کانال $channelId: $e');
          await box.delete(channelId);
        }
      }

      // مرتب‌سازی بر اساس آخرین فعالیت
      channels.sort((a, b) => (b.updatedAt ?? DateTime.now())
          .compareTo(a.updatedAt ?? DateTime.now()));

      return channels;
    } catch (e) {
      print('خطا در دریافت کانال‌های کش شده: $e');
      return [];
    }
  }

  // دریافت یک کانال خاص
  Future<ChannelModel?> getChannel(String channelId) async {
    try {
      // بررسی انقضا
      if (await _isExpired('channel_$channelId')) {
        await _removeChannelFromCache(channelId);
        return null;
      }

      final box = await _getChannelsBox();
      final cachedData = box.get(channelId);

      if (cachedData != null && cachedData['data'] != null) {
        return ChannelModel.fromJson(
          Map<String, dynamic>.from(cachedData['data']),
        );
      }

      return null;
    } catch (e) {
      print('خطا در دریافت کانال $channelId: $e');
      return null;
    }
  }

  // کش کردن پیام با مدیریت حافظه
  Future<void> cacheChannelMessage(
      String channelId, ChannelMessageModel message) async {
    try {
      final box = await _getMessagesBox();
      final messages = await getChannelMessages(channelId);

      // اضافه کردن پیام جدید
      messages.insert(0, message);

      // محدود کردن تعداد پیام‌ها
      if (messages.length > _maxMessagesPerChannel) {
        messages.removeRange(_maxMessagesPerChannel, messages.length);
      }

      // ذخیره پیام‌ها
      await box.put(channelId, {
        'messages': messages.map((m) => m.toJson()).toList(),
        'cached_at': DateTime.now().toIso8601String(),
        'count': messages.length,
      });

      // ذخیره metadata
      await _saveMetadata('messages_$channelId', ttl: _messagesTTL);
    } catch (e) {
      print('خطا در کش کردن پیام: $e');
    }
  }

  // کش کردن چندین پیام
  Future<void> cacheChannelMessages(
      String channelId, List<ChannelMessageModel> newMessages) async {
    try {
      final box = await _getMessagesBox();
      final existingMessages = await getChannelMessages(channelId);

      // ترکیب پیام‌های جدید و موجود
      final allMessages = <ChannelMessageModel>[];
      final messageIds = <String>{};

      // اضافه کردن پیام‌های جدید
      for (final message in newMessages) {
        if (!messageIds.contains(message.id)) {
          allMessages.add(message);
          messageIds.add(message.id);
        }
      }

      // اضافه کردن پیام‌های موجود
      for (final message in existingMessages) {
        if (!messageIds.contains(message.id)) {
          allMessages.add(message);
          messageIds.add(message.id);
        }
      }

      // مرتب‌سازی بر اساس زمان
      allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // محدود کردن تعداد
      if (allMessages.length > _maxMessagesPerChannel) {
        allMessages.removeRange(_maxMessagesPerChannel, allMessages.length);
      }

      // ذخیره
      await box.put(channelId, {
        'messages': allMessages.map((m) => m.toJson()).toList(),
        'cached_at': DateTime.now().toIso8601String(),
        'count': allMessages.length,
      });

      await _saveMetadata('messages_$channelId', ttl: _messagesTTL);

      print('${allMessages.length} پیام برای کانال $channelId کش شد');
    } catch (e) {
      print('خطا در کش کردن پیام‌ها: $e');
    }
  }

  // دریافت پیام‌های کانال
  Future<List<ChannelMessageModel>> getChannelMessages(String channelId) async {
    try {
      // بررسی انقضا
      if (await _isExpired('messages_$channelId')) {
        await _removeMessagesFromCache(channelId);
        return [];
      }

      final box = await _getMessagesBox();
      final cachedData = box.get(channelId);

      if (cachedData != null && cachedData['messages'] != null) {
        final messagesList = cachedData['messages'] as List;
        return messagesList
            .map((json) =>
                ChannelMessageModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }

      return [];
    } catch (e) {
      print('خطا در دریافت پیام‌های کش شده: $e');
      return [];
    }
  }

  // بررسی وجود کش معتبر
  Future<bool> hasValidCache(String type, String id) async {
    return !(await _isExpired('${type}_$id'));
  }

  // آمار کش
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final channelsBox = await _getChannelsBox();
      final messagesBox = await _getMessagesBox();
      final metadataBox = await _getMetadataBox();

      int totalMessages = 0;
      for (final key in messagesBox.keys) {
        final data = messagesBox.get(key);
        if (data != null && data['count'] != null) {
          totalMessages += data['count'] as int;
        }
      }

      return {
        'channels_count': channelsBox.length,
        'cached_conversations': messagesBox.length,
        'total_messages': totalMessages,
        'metadata_entries': metadataBox.length,
        'cache_size_mb': await _calculateCacheSize(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // محاسبه حجم کش (تقریبی)
  Future<double> _calculateCacheSize() async {
    try {
      final boxes = [
        await _getChannelsBox(),
        await _getMessagesBox(),
        await _getMembersBox(),
        await _getMetadataBox(),
      ];

      int totalSize = 0;
      for (final box in boxes) {
        for (final value in box.values) {
          totalSize += jsonEncode(value).length;
        }
      }

      return totalSize / (1024 * 1024); // تبدیل به مگابایت
    } catch (e) {
      return 0.0;
    }
  }

  // پاکسازی کش‌های منقضی شده
  Future<void> _cleanExpiredCache() async {
    try {
      final metadataBox = await _getMetadataBox();
      final expiredKeys = <String>[];

      for (final key in metadataBox.keys) {
        if (await _isExpired(key as String)) {
          expiredKeys.add(key);
        }
      }

      // حذف کش‌های منقضی شده
      for (final key in expiredKeys) {
        await _removeExpiredItem(key);
      }

      if (expiredKeys.isNotEmpty) {
        print('${expiredKeys.length} آیتم منقضی شده از کش حذف شد');
      }
    } catch (e) {
      print('خطا در پاکسازی کش‌های منقضی شده: $e');
    }
  }

  // حذف آیتم منقضی شده
  Future<void> _removeExpiredItem(String metadataKey) async {
    try {
      final parts = metadataKey.split('_');
      if (parts.length >= 2) {
        final type = parts[0];
        final id = parts.sublist(1).join('_');

        switch (type) {
          case 'channel':
            await _removeChannelFromCache(id);
            break;
          case 'messages':
            await _removeMessagesFromCache(id);
            break;
        }
      }

      final metadataBox = await _getMetadataBox();
      await metadataBox.delete(metadataKey);
    } catch (e) {
      print('خطا در حذف آیتم منقضی شده: $e');
    }
  }

  // حذف قدیمی‌ترین کانال‌ها
  Future<void> _removeOldestChannels(int count) async {
    try {
      final box = await _getChannelsBox();
      final channels = <MapEntry<String, DateTime>>[];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null && data['cached_at'] != null) {
          final cachedAt = DateTime.parse(data['cached_at']);
          channels.add(MapEntry(key as String, cachedAt));
        }
      }

      // مرتب‌سازی بر اساس زمان (قدیمی‌ترین اول)
      channels.sort((a, b) => a.value.compareTo(b.value));

      // حذف قدیمی‌ترین‌ها
      for (int i = 0; i < count && i < channels.length; i++) {
        await _removeChannelFromCache(channels[i].key);
      }
    } catch (e) {
      print('خطا در حذف کانال‌های قدیمی: $e');
    }
  }

  // حذف کانال از کش
  Future<void> _removeChannelFromCache(String channelId) async {
    try {
      final channelsBox = await _getChannelsBox();
      final metadataBox = await _getMetadataBox();

      await channelsBox.delete(channelId);
      await metadataBox.delete('channel_$channelId');
    } catch (e) {
      print('خطا در حذف کانال از کش: $e');
    }
  }

  // حذف پیام‌ها از کش
  Future<void> _removeMessagesFromCache(String channelId) async {
    try {
      final messagesBox = await _getMessagesBox();
      final metadataBox = await _getMetadataBox();

      await messagesBox.delete(channelId);
      await metadataBox.delete('messages_$channelId');
    } catch (e) {
      print('خطا در حذف پیام‌ها از کش: $e');
    }
  }

  // پاک کردن کش کانال خاص
  Future<void> clearChannelCache(String channelId) async {
    try {
      await _removeChannelFromCache(channelId);
      await _removeMessagesFromCache(channelId);

      final membersBox = await _getMembersBox();
      await membersBox.delete(channelId);

      print('کش کانال $channelId پاک شد');
    } catch (e) {
      print('خطا در پاک کردن کش کانال: $e');
    }
  }

  // پاک کردن کش کانال‌ها
  Future<void> clearChannelsCache() async {
    try {
      final channelsBox = await _getChannelsBox();
      final metadataBox = await _getMetadataBox();

      // حذف تمام کانال‌ها
      await channelsBox.clear();

      // حذف metadata مربوط به کانال‌ها
      final channelMetadataKeys = metadataBox.keys
          .where((key) => (key as String).startsWith('channel_'))
          .toList();

      for (final key in channelMetadataKeys) {
        await metadataBox.delete(key);
      }

      print('کش تمام کانال‌ها پاک شد');
    } catch (e) {
      print('خطا در پاک کردن کش کانال‌ها: $e');
    }
  }

  // پاک کردن همه کش‌ها
  Future<void> clearAllCache() async {
    try {
      final boxes = [
        await _getChannelsBox(),
        await _getMessagesBox(),
        await _getMembersBox(),
        await _getMetadataBox(),
      ];

      for (final box in boxes) {
        await box.clear();
      }

      print('تمام کش‌ها پاک شد');
    } catch (e) {
      print('خطا در پاک کردن همه کش‌ها: $e');
    }
  }

  // ریست کردن تمام کش‌ها در صورت خطا
  Future<void> _resetAllCaches() async {
    try {
      await Hive.deleteBoxFromDisk(_channelsBoxName);
      await Hive.deleteBoxFromDisk(_channelMessagesBoxName);
      await Hive.deleteBoxFromDisk(_channelMembersBoxName);
      await Hive.deleteBoxFromDisk(_metadataBoxName);

      print('تمام کش‌ها ریست شد');
    } catch (e) {
      print('خطا در ریست کردن کش‌ها: $e');
    }
  }

  Future<void> cacheMessage(ChannelMessageModel message) async {
    await cacheChannelMessage(message.channelId, message);
  }

  // متد جدید 2: clearAll (alias برای clearAllCache)
  Future<void> clearAll() async {
    await clearAllCache();
  }

  // متد جدید 3: getStats (آمار کش)
  Future<Map<String, dynamic>> getStats() async {
    try {
      final channelsBox = await _getChannelsBox();
      final messagesBox = await _getMessagesBox();
      final membersBox = await _getMembersBox();

      int totalMessages = 0;
      for (final key in messagesBox.keys) {
        final cachedData = messagesBox.get(key);
        if (cachedData != null && cachedData['count'] != null) {
          totalMessages += cachedData['count'] as int;
        }
      }

      return {
        'channels_count': channelsBox.length,
        'total_messages': totalMessages,
        'members_count': membersBox.length,
        'cache_size_kb': await _calculateCacheSize(),
      };
    } catch (e) {
      print('خطا در دریافت آمار کش: $e');
      return {
        'channels_count': 0,
        'total_messages': 0,
        'members_count': 0,
        'cache_size_kb': 0,
      };
    }
  }

  // بستن کش‌ها
  Future<void> dispose() async {
    try {
      await _channelsBox?.close();
      await _messagesBox?.close();
      await _membersBox?.close();
      await _metadataBox?.close();
    } catch (e) {
      print('خطا در بستن کش‌ها: $e');
    }
  }
}
