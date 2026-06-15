import 'package:Vista/security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/model/message_model.dart';

import 'improved_error_handler.dart';
import 'package:Vista/features/chat/providers/chat_providers.dart';
import 'package:Vista/features/chat/providers/chat_messages_provider.dart';

/// سیستم حذف فوری پیام‌ها و گفتگوها - بدون تأخیر
class InstantMessageDeletion {
  static final InstantMessageDeletion _instance =
      InstantMessageDeletion._internal();
  factory InstantMessageDeletion() => _instance;
  InstantMessageDeletion._internal();

  final Map<String, MessageModel> _deletionBackup = {};

  static final StateProvider<Set<String>> _animatingMessagesProvider =
      StateProvider<Set<String>>((ref) => {});

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
      final notifier =
          ref.read(chatMessagesProvider(conversationId).notifier);
      final currentMessages =
          ref.read(chatMessagesProvider(conversationId)).valueOrNull ?? [];
      MessageModel? targetMessage;
      for (final message in currentMessages) {
        if (message.id == messageId) {
          targetMessage = message;
          break;
        }
      }

      if (targetMessage != null) {
        _deletionBackup[messageId] = targetMessage;
        notifier.removeMessageLocally(messageId);
        logDebug('✅ پیام فوراً از UI حذف شد: $messageId');
      }

      if (!messageId.startsWith('temp_')) {
        try {
          await ImprovedErrorHandler.handleMessageOperation(() async {
            await ref
                .read(chatRepositoryProvider)
                .deleteMessage(messageId, forEveryone: forEveryone);
          });
        } catch (e) {
          if (e.toString().contains('PGRST116') ||
              e.toString().contains('multiple (or no) rows returned') ||
              e.toString().contains('MessagingException: درخواست نامعتبر')) {
            debugPrint(
                '⚠️ پیام در سرور وجود ندارد، فقط از UI حذف شد: $messageId');
            return;
          }
          rethrow;
        }
      } else {
        logDebug('⚠️ پیام temporary است، حذف از سرور انجام نشد: $messageId');
      }

      _deletionBackup.remove(messageId);
      onSuccess?.call();
      logDebug('✅ حذف پیام در سرور تأیید شد: $messageId');
    } catch (e) {
      final backedUpMessage = _deletionBackup.remove(messageId);
      if (backedUpMessage != null) {
        ref
            .read(chatMessagesProvider(conversationId).notifier)
            .restoreMessageLocally(backedUpMessage);
        logDebug('🔄 پیام به علت خطا بازگردانده شد: $messageId');
      }

      onError?.call();
      logDebug('❌ خطا در حذف پیام: $e');
      rethrow;
    }
  }

  Future<void> deleteConversationInstantly({
    required String conversationId,
    required WidgetRef ref,
    required bool forEveryone,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    try {
      final notifier =
          ref.read(chatMessagesProvider(conversationId).notifier);
      final currentMessages =
          ref.read(chatMessagesProvider(conversationId)).valueOrNull ?? [];

      _deletionBackup['conversation_$conversationId'] = currentMessages.isNotEmpty
          ? currentMessages.first
          : MessageModel.temporary(
              tempId: 'backup',
              conversationId: conversationId,
              senderId: '',
              content: '');

      notifier.clearMessagesLocally();
      logDebug('✅ گفتگو فوراً از UI پاک شد: $conversationId');

      await ImprovedErrorHandler.handleMessageOperation(() async {
        if (forEveryone) {
          await ref
              .read(chatRepositoryProvider)
              .clearConversation(conversationId, forEveryone: true);
        } else {
          await ref
              .read(chatRepositoryProvider)
              .deleteConversation(conversationId);
        }
      });

      _deletionBackup.remove('conversation_$conversationId');
      onSuccess?.call();
      logDebug('✅ پاک کردن گفتگو در سرور تأیید شد: $conversationId');
    } catch (e) {
      onError?.call();
      logDebug('❌ خطا در پاک کردن گفتگو: $e');
      rethrow;
    }
  }

  void _startAnimation(WidgetRef ref, String messageId) {
    ref.read(_animatingMessagesProvider.notifier).update((state) {
      final newState = Set<String>.from(state);
      newState.add(messageId);
      return newState;
    });
  }

  void _stopAnimation(WidgetRef ref, String messageId) {
    ref.read(_animatingMessagesProvider.notifier).update((state) {
      final newState = Set<String>.from(state);
      newState.remove(messageId);
      return newState;
    });
  }

  bool isAnimating(WidgetRef ref, String messageId) {
    return ref.read(_animatingMessagesProvider).contains(messageId);
  }

  void clearBackup() {
    _deletionBackup.clear();
  }
}

extension AnimationExtension on WidgetRef {
  void startDeletionAnimation(String messageId) {
    InstantMessageDeletion()._startAnimation(this, messageId);
  }

  void stopDeletionAnimation(String messageId) {
    InstantMessageDeletion()._stopAnimation(this, messageId);
  }

  bool isMessageAnimating(String messageId) {
    return InstantMessageDeletion().isAnimating(this, messageId);
  }
}

extension InstantDeletionExtension on WidgetRef {
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

Future<void> showDeleteMessageDialog({
  required BuildContext context,
  required MessageModel message,
  required bool isMyMessage,
  required VoidCallback onDeleted,
  required WidgetRef ref,
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

Future<void> _handleMessageDeletionInstant({
  required BuildContext context,
  required MessageModel message,
  required DeleteMessageOption option,
  required VoidCallback onDeleted,
  required WidgetRef ref,
}) async {
  try {
    final forEveryone = option == DeleteMessageOption.deleteForEveryone;

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
        result = await repository.clearConversation(conversationId,
            forEveryone: false);
        break;
      case DeleteConversationOption.deleteForEveryone:
        result = await repository.clearConversation(conversationId,
            forEveryone: true);
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

void _showSuccessSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ),
  );
}

void _showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );
}

enum DeleteMessageOption {
  deleteForMe,
  deleteForEveryone,
}

enum DeleteConversationOption {
  deleteForMe,
  clearHistory,
  deleteForEveryone,
}

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
