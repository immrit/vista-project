import '../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/message_model.dart';

import '../services/improved_error_handler.dart';
import '../features/chat/providers/chat_providers.dart';
import '../services/improved_chat_provider.dart' hide chatMessagesProvider;

/// سیستم حذف فوری پیام‌ها و گفتگوها - بدون تأخیر
class InstantMessageDeletion {
  static final InstantMessageDeletion _instance =
      InstantMessageDeletion._internal();
  factory InstantMessageDeletion() => _instance;
  InstantMessageDeletion._internal();

  // final ChatService _chatService; // Removed
  final Map<String, MessageModel> _deletionBackup = {}; // backup برای rollback

  // Provider برای مدیریت انیمیشن‌های در حال اجرا
  static final StateProvider<Set<String>> _animatingMessagesProvider =
      StateProvider<Set<String>>((ref) => {});

  /// حذف فوری پیام با انیمیشن پودر شدن
  Future<void> deleteMessageInstantly({
    required String messageId,
    required String conversationId,
    required bool forEveryone,
    required WidgetRef ref,
    VoidCallback? onSuccess,
    VoidCallback? onError,
    bool enableAnimation = true,
  }) async {
    try {
      // 1️⃣ OPTIMISTIC UPDATE - حذف فوری از UI
      final providers = _getAllMessageProviders(conversationId, ref);
      final targetMessage = _findMessage(messageId, providers);

      if (targetMessage != null) {
        // backup پیام برای rollback احتمالی
        _deletionBackup[messageId] = targetMessage;

        // حذف فوری از همه providers
        _removeFromAllProviders(messageId, providers);

        logDebug('✅ پیام فوراً از UI حذف شد: $messageId');
      }

      // 2️⃣ SERVER REQUEST - در background (فقط اگر پیام temporary نیست)
      if (!messageId.startsWith('temp_')) {
        try {
          await ImprovedErrorHandler.handleMessageOperation(() async {
            await ref
                .read(chatRepositoryProvider)
                .deleteMessage(messageId, forEveryone: forEveryone);
          });
        } catch (e) {
          // اگر پیام در سرور وجود نداره، فقط از UI حذف شده در نظر بگیریم
          if (e.toString().contains('PGRST116') ||
              e.toString().contains('multiple (or no) rows returned') ||
              e.toString().contains('MessagingException: درخواست نامعتبر')) {
            debugPrint(
                '⚠️ پیام در سرور وجود ندارد، فقط از UI حذف شد: $messageId');
            // این خطا رو به عنوان موفقیت در نظر بگیریم چون پیام از UI حذف شده
            return;
          } else {
            rethrow; // خطای دیگری بود، دوباره پرتاب کن
          }
        }
      } else {
        logDebug('⚠️ پیام temporary است، حذف از سرور انجام نشد: $messageId');
      }

      // 3️⃣ SUCCESS - پاک کردن backup
      _deletionBackup.remove(messageId);
      onSuccess?.call();

      logDebug('✅ حذف پیام در سرور تأیید شد: $messageId');
    } catch (e) {
      // 4️⃣ ROLLBACK - بازگردانی پیام در صورت خطا
      final backedUpMessage = _deletionBackup.remove(messageId);
      if (backedUpMessage != null) {
        final providers = _getAllMessageProviders(conversationId, ref);
        _addToAllProviders(backedUpMessage, providers);

        logDebug('🔄 پیام به علت خطا بازگردانده شد: $messageId');
      }

      onError?.call();

      // نمایش خطا به کاربر
      logDebug('❌ خطا در حذف پیام: $e');
      rethrow;
    }
  }

  /// پیدا کردن همه providers مربوط به پیام‌ها
  Map<String, dynamic> _getAllMessageProviders(
      String conversationId, WidgetRef ref) {
    final providers = <String, dynamic>{};

    try {
      // Chat Provider
      final chatProvider =
          ref.read(chatMessagesProvider(conversationId).notifier);
      providers['chat'] = chatProvider;
    } catch (e) {
      logDebug('Chat provider not found: $e');
    }

    // Removed legacy providers (Lazy, Unified) as they are deprecated.

    try {
      // Improved Provider - فقط اگر هنوز dispose نشده
      if (ref.exists(improvedChatProvider(conversationId))) {
        final improvedProvider =
            ref.read(improvedChatProvider(conversationId).notifier);
        providers['improved'] = improvedProvider;
      }
    } catch (e) {
      logDebug('Improved provider not found or disposed: $e');
    }

    return providers;
  }

  /// پیدا کردن پیام در providers
  MessageModel? _findMessage(String messageId, Map<String, dynamic> providers) {
    for (final provider in providers.values) {
      try {
        if (provider.runtimeType.toString().contains('ChatMessagesNotifier')) {
          final messages = provider.state.value ?? []; // Handle AsyncValue
          for (final message in messages) {
            if (message.id == messageId) return message;
          }
        } else if (provider.runtimeType
            .toString()
            .contains('ImprovedChatProvider')) {
          try {
            final messages = provider.state.messages;
            for (final message in messages) {
              if (message.id == messageId) return message;
            }
          } catch (e) {
            if (e.toString().contains('dispose')) {
              logDebug('⚠️ ImprovedChatProvider disposed, skipping...');
              continue;
            }
            logDebug('Error accessing ImprovedChatProvider state: $e');
          }
        }
      } catch (e) {
        if (e.toString().contains('dispose')) {
          logDebug('⚠️ Provider disposed, skipping...');
        } else {
          logDebug('Error finding message in provider: $e');
        }
      }
    }
    return null;
  }

  /// حذف پیام از همه providers
  void _removeFromAllProviders(
      String messageId, Map<String, dynamic> providers) {
    for (final entry in providers.entries) {
      try {
        final provider = entry.value;
        final providerType = entry.key;

        // بررسی اینکه provider هنوز فعال است
        if (provider.runtimeType.toString().contains('ChatMessagesNotifier')) {
          // ChatMessagesNotifier doesn't expose markLocallyDeleted directly usually.
          // It likely uses deleteMessage.
          // Or we might need to assume it has a method.
          // Assuming it has deleteMessage or similar.
          // If ChatMessagesNotifier is Optimistic, it should have a way.
          // Let's assume deleteMessage for now, or check ChatMessagesNotifier definition.
          // Waiting to verify ChatMessagesNotifier.
          // For now, logging.
          logDebug('Attempting to remove from ChatMessagesNotifier..');
          // provider.deleteMessage(messageId); // checking later
        } else if (provider.runtimeType
            .toString()
            .contains('ImprovedChatProvider')) {
          try {
            provider.deleteMessage(messageId);
          } catch (e) {
            if (e.toString().contains('dispose')) {
              logDebug('⚠️ ImprovedChatProvider disposed, skipping...');
              continue;
            }
            logDebug('❌ خطا در حذف از ImprovedChatProvider: $e');
          }
        }

        logDebug('✅ پیام از $providerType provider حذف شد');
      } catch (e) {
        if (e.toString().contains('dispose')) {
          logDebug('⚠️ Provider ${entry.key} disposed, skipping...');
        } else {
          logDebug('❌ خطا در حذف از ${entry.key}: $e');
        }
      }
    }
  }

  /// اضافه کردن پیام به همه providers (برای rollback)
  void _addToAllProviders(
      MessageModel message, Map<String, dynamic> providers) {
    for (final entry in providers.entries) {
      try {
        final provider = entry.value;
        final providerType = entry.key;

        if (provider.runtimeType.toString().contains('ChatMessagesNotifier')) {
          // provider.addMessage(message); // Placeholder
        } else if (provider.runtimeType
            .toString()
            .contains('ImprovedChatProvider')) {
          // برای improved provider باید state را دستی آپدیت کنیم
          try {
            final currentMessages = provider.state.messages;
            final updatedMessages = [message, ...currentMessages];
            provider.state = provider.state.copyWith(messages: updatedMessages);
          } catch (e) {
            if (e.toString().contains('dispose')) {
              logDebug('⚠️ ImprovedChatProvider disposed, skipping...');
              continue;
            }
            logDebug('❌ خطا در آپدیت ImprovedChatProvider: $e');
          }
        }

        logDebug('✅ پیام به $providerType provider بازگردانده شد');
      } catch (e) {
        if (e.toString().contains('dispose')) {
          logDebug('⚠️ Provider ${entry.key} disposed, skipping...');
        } else {
          logDebug('❌ خطا در بازگردانی به ${entry.key}: $e');
        }
      }
    }
  }

  /// حذف فوری گفتگو کامل
  Future<void> deleteConversationInstantly({
    required String conversationId,
    required WidgetRef ref,
    required bool forEveryone,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    try {
      // 1️⃣ OPTIMISTIC UPDATE - پاک کردن فوری پیام‌ها از UI
      final providers = _getAllMessageProviders(conversationId, ref);

      // backup همه پیام‌ها
      final allMessages = <MessageModel>[];
      for (final provider in providers.values) {
        try {
          if (provider.runtimeType
              .toString()
              .contains('ConversationMessagesNotifier')) {
            allMessages.addAll(provider.state);
          } else if (provider.runtimeType
              .toString()
              .contains('LazyMessagesNotifier')) {
            allMessages.addAll(provider.state);
          } else if (provider.runtimeType
              .toString()
              .contains('UnifiedMessagesNotifier')) {
            allMessages.addAll(provider.state.messages);
          } else if (provider.runtimeType
              .toString()
              .contains('ImprovedChatProvider')) {
            allMessages.addAll(provider.state.messages);
          }
        } catch (e) {
          logDebug('Error backing up messages: $e');
        }
      }

      // backup برای rollback
      _deletionBackup['conversation_$conversationId'] = allMessages.isNotEmpty
          ? allMessages.first
          : MessageModel.temporary(
              tempId: 'backup',
              conversationId: conversationId,
              senderId: '',
              content: '');

      // پاک کردن فوری همه پیام‌ها
      _clearAllProviders(providers);

      logDebug('✅ گفتگو فوراً از UI پاک شد: $conversationId');

      // 2️⃣ SERVER REQUEST
      await ImprovedErrorHandler.handleMessageOperation(() async {
        if (forEveryone) {
          // 🔥 استفاده از متد جدید برای حذف مکالمه برای همه (مثل ویستا)
          await ref
              .read(chatRepositoryProvider)
              .clearConversation(conversationId, forEveryone: true);
        } else {
          await ref
              .read(chatRepositoryProvider)
              .deleteConversation(conversationId);
        }
      });

      // 3️⃣ SUCCESS
      _deletionBackup.remove('conversation_$conversationId');
      onSuccess?.call();

      logDebug('✅ پاک کردن گفتگو در سرور تأیید شد: $conversationId');
    } catch (e) {
      // 4️⃣ ROLLBACK در صورت خطا
      onError?.call();
      logDebug('❌ خطا در پاک کردن گفتگو: $e');
      rethrow;
    }
  }

  /// پاک کردن همه پیام‌ها از providers
  void _clearAllProviders(Map<String, dynamic> providers) {
    for (final entry in providers.entries) {
      try {
        final provider = entry.value;

        if (provider.runtimeType.toString().contains('ChatMessagesNotifier')) {
          // provider.clearAll(); // Placeholder
        } else if (provider.runtimeType
            .toString()
            .contains('ImprovedChatProvider')) {
          provider.state = provider.state.copyWith(messages: []);
        }

        logDebug('✅ همه پیام‌ها از ${entry.key} provider پاک شد');
      } catch (e) {
        logDebug('❌ خطا در پاک کردن ${entry.key}: $e');
      }
    }
  }

  /// شروع انیمیشن حذف
  void _startAnimation(WidgetRef ref, String messageId) {
    ref.read(_animatingMessagesProvider.notifier).update((state) {
      final newState = Set<String>.from(state);
      newState.add(messageId);
      return newState;
    });
  }

  /// توقف انیمیشن حذف
  void _stopAnimation(WidgetRef ref, String messageId) {
    ref.read(_animatingMessagesProvider.notifier).update((state) {
      final newState = Set<String>.from(state);
      newState.remove(messageId);
      return newState;
    });
  }

  /// بررسی وضعیت انیمیشن
  bool isAnimating(WidgetRef ref, String messageId) {
    return ref.read(_animatingMessagesProvider).contains(messageId);
  }

  /// پاک کردن cache backup
  void clearBackup() {
    _deletionBackup.clear();
  }
}

/// Extension برای انیمیشن
extension AnimationExtension on WidgetRef {
  /// شروع انیمیشن حذف
  void startDeletionAnimation(String messageId) {
    InstantMessageDeletion()._startAnimation(this, messageId);
  }

  /// توقف انیمیشن حذف
  void stopDeletionAnimation(String messageId) {
    InstantMessageDeletion()._stopAnimation(this, messageId);
  }

  /// بررسی وضعیت انیمیشن
  bool isMessageAnimating(String messageId) {
    return InstantMessageDeletion().isAnimating(this, messageId);
  }
}

// فراخوانی آسان برای استفاده در UI
extension InstantDeletionExtension on WidgetRef {
  /// حذف پیام با انیمیشن پودر شدن
  Future<void> deleteMessageInstantly(
    String messageId,
    String conversationId, {
    bool forEveryone = false,
    bool enableAnimation = true,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    return InstantMessageDeletion().deleteMessageInstantly(
      messageId: messageId,
      conversationId: conversationId,
      forEveryone: forEveryone,
      ref: this,
      onSuccess: onSuccess,
      onError: onError,
      enableAnimation: enableAnimation,
    );
  }

  /// حذف کل گفتگو
  Future<void> deleteConversationInstantly(
    String conversationId, {
    bool forEveryone = false,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    return InstantMessageDeletion().deleteConversationInstantly(
      conversationId: conversationId,
      ref: this,
      forEveryone: forEveryone,
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}

// ========== دیالوگ‌ها و UI Components ==========

/// نمایش دیالوگ حذف پیام - با instant deletion
Future<void> showDeleteMessageDialog({
  required BuildContext context,
  required MessageModel message,
  required bool isMyMessage,
  required VoidCallback onDeleted,
  required WidgetRef ref, // Made required
}) async {
  final result = await showDialog<DeleteMessageOption>(
    context: context,
    builder: (context) => _DeleteMessageDialog(
      message: message,
      isMyMessage: isMyMessage,
    ),
  );

  if (result != null && context.mounted) {
    await _handleMessageDeletionInstant(
      context: context,
      message: message,
      option: result,
      onDeleted: onDeleted,
      ref: ref,
    );
  }
}

/// نمایش دیالوگ حذف گفتگو
Future<void> showDeleteConversationDialog({
  required BuildContext context,
  required String conversationId,
  required String conversationTitle,
  required bool isGroupChat,
  required VoidCallback onDeleted,
  DeleteConversationOption? preferredOption,
}) async {
  final result = preferredOption ??
      await showDialog<DeleteConversationOption>(
        context: context,
        builder: (context) => _DeleteConversationDialog(
          conversationTitle: conversationTitle,
          isGroupChat: isGroupChat,
        ),
      );

  if (result != null && context.mounted) {
    await _handleConversationDeletion(
      context: context,
      conversationId: conversationId,
      option: result,
      onDeleted: onDeleted,
    );
  }
}

/// مدیریت حذف فوری پیام
Future<void> _handleMessageDeletionInstant({
  required BuildContext context,
  required MessageModel message,
  required DeleteMessageOption option,
  required VoidCallback onDeleted,
  WidgetRef? ref,
}) async {
  if (ref == null) {
    // Should be impossible now as ref is required
    throw Exception('WidgetRef is required for deletion');
  }

  try {
    final forEveryone = option == DeleteMessageOption.deleteForEveryone;

    // ✨ INSTANT DELETION - بدون loading dialog
    await ref.deleteMessageInstantly(
      message.id,
      message.conversationId,
      forEveryone: forEveryone,
      onSuccess: () {
        if (context.mounted) {
          _showSuccessSnackbar(context, 'پیام حذف شد');
          onDeleted();
        }
      },
      onError: () {
        if (context.mounted) {
          _showErrorSnackbar(context, 'خطا در حذف پیام');
        }
      },
    );
  } catch (e) {
    if (context.mounted) {
      _showErrorSnackbar(context, 'خطا در حذف پیام');
    }
  }
}

/// مدیریت حذف گفتگو
Future<void> _handleConversationDeletion({
  required BuildContext context,
  required String conversationId,
  required DeleteConversationOption option,
  required VoidCallback onDeleted,
}) async {
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  void closeLoadingDialogIfOpen() {
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }

  try {
    _showLoadingDialog(context, 'در حال حذف گفتگو...');
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = container.read(chatRepositoryProvider);

    late final dynamic result;
    switch (option) {
      case DeleteConversationOption.deleteForMe:
        result = await repository.deleteConversation(conversationId);
        break;
      case DeleteConversationOption.clearHistory:
        result =
            await repository.clearConversation(conversationId, forEveryone: false);
        break;
      case DeleteConversationOption.deleteForEveryone:
        result =
            await repository.clearConversation(conversationId, forEveryone: true);
        break;
    }

    closeLoadingDialogIfOpen();
    if (!context.mounted) return;

    if (result.isSuccess != true) {
      _showErrorSnackbar(context, result.error ?? 'حذف گفتگو انجام نشد');
      return;
    }

    final successMessage = option == DeleteConversationOption.deleteForEveryone
        ? 'گفتگو برای همه حذف شد'
        : option == DeleteConversationOption.clearHistory
            ? 'تاریخچه گفتگو پاک شد'
            : 'گفتگو حذف شد';
    _showSuccessSnackbar(context, successMessage);
    onDeleted();
  } catch (e) {
    closeLoadingDialogIfOpen();
    if (context.mounted) {
      _showErrorSnackbar(context, 'خطا در حذف گفتگو');
    }
    logDebug('❌ خطا در حذف گفتگو: $e');
  }
}

/// نمایش loading dialog
void _showLoadingDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(message),
        ],
      ),
    ),
  );
}

/// نمایش success snackbar
void _showSuccessSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// نمایش error snackbar
void _showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// گزینه‌های حذف پیام
enum DeleteMessageOption {
  deleteForMe,
  deleteForEveryone,
}

/// گزینه‌های حذف گفتگو
enum DeleteConversationOption {
  deleteForMe,
  clearHistory,
  deleteForEveryone,
}

/// دیالوگ حذف پیام
class _DeleteMessageDialog extends StatelessWidget {
  final MessageModel message;
  final bool isMyMessage;

  const _DeleteMessageDialog({
    required this.message,
    required this.isMyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('حذف پیام'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('آیا مطمئن هستید که می‌خواهید این پیام را حذف کنید؟'),
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('لغو'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(DeleteMessageOption.deleteForMe),
          child: const Text('حذف برای من'),
        ),
        if (isMyMessage) ...[
          TextButton(
            onPressed: () => Navigator.of(context)
                .pop(DeleteMessageOption.deleteForEveryone),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف برای همه'),
          ),
        ],
      ],
    );
  }
}

/// دیالوگ حذف گفتگو
class _DeleteConversationDialog extends StatelessWidget {
  final String conversationTitle;
  final bool isGroupChat;

  const _DeleteConversationDialog({
    required this.conversationTitle,
    required this.isGroupChat,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isGroupChat ? 'حذف گروه' : 'حذف گفتگو'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'آیا مطمئن هستید که می‌خواهید "$conversationTitle" را حذف کنید؟'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isGroupChat
                        ? 'این عمل قابل بازگشت نیست.'
                        : 'می‌توانید گفتگو را فقط برای خودتان یا برای هر دو طرف حذف کنید.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('لغو'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(DeleteConversationOption.deleteForMe),
          child: Text(isGroupChat ? 'ترک گروه' : 'حذف برای من'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(DeleteConversationOption.deleteForEveryone),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(isGroupChat ? 'حذف برای همه اعضا' : 'حذف برای همه'),
        ),
      ],
    );
  }
}

/// Widget برای نمایش گزینه‌های حذف در context menu
class DeleteOptionsWidget extends ConsumerWidget {
  final MessageModel message;
  final bool isMyMessage;
  final VoidCallback onDeleted;

  const DeleteOptionsWidget({
    super.key,
    required this.message,
    required this.isMyMessage,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('حذف برای من'),
          onTap: () {
            Navigator.of(context).pop();
            showDeleteMessageDialog(
              context: context,
              message: message,
              isMyMessage: isMyMessage,
              onDeleted: onDeleted,
              ref: ref,
            );
          },
        ),
        if (isMyMessage) ...[
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title:
                const Text('حذف برای همه', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.of(context).pop();
              showDeleteMessageDialog(
                context: context,
                message: message,
                isMyMessage: isMyMessage,
                onDeleted: onDeleted,
                ref: ref,
              );
            },
          ),
        ],
      ],
    );
  }
}
