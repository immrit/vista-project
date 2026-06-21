import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/message_model.dart';
import '../domain/chat_render_descriptor.dart';
import '../performance/chat_message_render_window.dart';
import '../performance/chat_scroll_physics.dart';
import '../providers/chat_providers.dart';
import '../services/chat_render_item_builder.dart';
import '../theme/chat_theme.dart';
import 'chat_message_bindings.dart';
import 'chat_message_row.dart';

/// Scrollable message list — uses [ListView.builder] (same pattern as feed)
/// for a lighter scroll path than [CustomScrollView] on Android/Impeller.
class ChatMessageListView extends ConsumerWidget {
  const ChatMessageListView({
    super.key,
    required this.conversationId,
    required this.renderCapListenable,
    required this.overlayRevisionListenable,
    required this.scrollController,
    required this.bottomPadding,
    required this.bindings,
    required this.filterMessage,
    required this.resolveUiContent,
    required this.buildLoadingIndicator,
    required this.buildEmptyState,
    required this.secretSystemNoticeWidgets,
    required this.showSecretNotices,
  });

  final String conversationId;
  final ValueListenable<int> renderCapListenable;
  final ValueListenable<int> overlayRevisionListenable;
  final ScrollController scrollController;
  final double bottomPadding;
  final ChatMessageBindings bindings;
  final bool Function(MessageModel message) filterMessage;
  final List<MessageModel> Function(List<MessageModel> messages)
      resolveUiContent;
  final Widget Function(ChatTheme theme) buildLoadingIndicator;
  final Widget Function(ChatTheme theme) buildEmptyState;
  final List<Widget> secretSystemNoticeWidgets;
  final bool showSecretNotices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.chatTheme;
    final structureVersion = ref.watch(
      chatMessageStoreProvider(conversationId).select(
        (store) => store.structureVersion,
      ),
    );
    final storeState = ref.read(chatMessageStoreProvider(conversationId));

    if (storeState.isEmpty) {
      return buildEmptyState(theme);
    }

    final filtered = storeState.orderedIds
        .map((id) => storeState.byId[id])
        .whereType<MessageModel>()
        .where(filterMessage)
        .toList(growable: false);
    final uiMessages = resolveUiContent(filtered);

    if (uiMessages.isEmpty) {
      return buildEmptyState(theme);
    }

    final messageIndexById = <String, int>{
      for (var i = 0; i < uiMessages.length; i++) uiMessages[i].id: i,
    };

    // PERF: descriptors فقط به (uiMessages, renderCap) وابسته‌اند، نه overlayRevision.
    // قبلاً هر tick از overlayRevision (reaction/edit/...) کل clip+build را دوباره
    // اجرا می‌کرد. memoize با کلید renderCap: تا وقتی build() دوباره اجرا نشده
    // (یعنی uiMessages عوض نشده)، تغییر overlay دیگر descriptors را بازنمی‌سازد.
    final descriptorCache = <int, List<ChatRenderDescriptor>>{};

    return ValueListenableBuilder<int>(
      valueListenable: overlayRevisionListenable,
      builder: (context, overlayRevision, _) {
        return ValueListenableBuilder<int>(
          valueListenable: renderCapListenable,
          builder: (context, renderCap, __) {
            final _ = structureVersion + overlayRevision;

            final descriptors = descriptorCache.putIfAbsent(
              renderCap,
              () => ChatRenderItemBuilder.build(
                ChatMessageRenderWindow.clip(uiMessages, renderCap),
              ),
            );

            if (descriptors.isEmpty) {
              return buildEmptyState(theme);
            }

            final paginationState = ref.watch(
              paginationStateProvider(conversationId),
            );
            final footerCount = 1 +
                (showSecretNotices && secretSystemNoticeWidgets.isNotEmpty
                    ? 1
                    : 0);
            final itemCount = descriptors.length + footerCount;

            return ChatMessageBindingsScope(
              bindings: bindings,
              child: ScrollConfiguration(
                behavior: const ChatScrollBehavior(),
                child: ListView.builder(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(800),
                  controller: scrollController,
                  reverse: true,
                  clipBehavior: Clip.hardEdge,
                  physics: chatListScrollPhysics(context),
                  padding: EdgeInsets.only(bottom: bottomPadding + 10),
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index >= descriptors.length) {
                      return _buildFooter(
                        theme,
                        index - descriptors.length,
                        paginationState.isLoadingMore,
                      );
                    }

                    final descriptor = descriptors[index];
                    final primaryId = descriptor.primaryMessageId;
                    final fullPrimaryIndex = messageIndexById[primaryId] ?? -1;

                    final (isFirstInGroup, isLastInGroup) =
                        fullPrimaryIndex == -1
                            ? (true, true)
                            : _getMessageGroupPosition(
                                uiMessages,
                                fullPrimaryIndex,
                                descriptor.messageIds.length,
                              );

                    final nextDescriptor = index < descriptors.length - 1
                        ? descriptors[index + 1]
                        : null;
                    final nextOldestCreatedAt = nextDescriptor == null
                        ? null
                        : storeState
                            .byId[nextDescriptor.messageIds.last]?.createdAt;

                    final oldestMessage =
                        storeState.byId[descriptor.messageIds.last];
                    final showDateDivider = oldestMessage != null &&
                        bindings.shouldShowDateDivider(
                          oldestMessage.createdAt,
                          nextOldestCreatedAt,
                        );

                    return ChatMessageRow(
                      key: ValueKey(descriptor.primaryMessageId),
                      descriptor: descriptor,
                      layout: ChatMessageRowLayout(
                        isFirstInGroup: isFirstInGroup,
                        isLastInGroup: isLastInGroup,
                        showDateDivider: showDateDivider,
                        showUnreadDivider: bindings.shouldShowUnreadDivider(
                          descriptor.messageIds,
                          index,
                          descriptors.length,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(
    ChatTheme theme,
    int footerIndex,
    bool isLoadingMore,
  ) {
    if (footerIndex == 0) {
      return isLoadingMore
          ? buildLoadingIndicator(theme)
          : const SizedBox(height: 20);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(children: secretSystemNoticeWidgets),
    );
  }

  (bool, bool) _getMessageGroupPosition(
    List<MessageModel> messages,
    int index,
    int spanLength,
  ) {
    if (index < 0 || index >= messages.length) return (true, true);
    final current = messages[index];
    // List is reverse-chronological (index 0 = newest, shown at bottom).
    // "newer" (lower index) is below current; "older" (higher index) is above current.
    // isFirstInGroup = top of group visually = no same-sender ABOVE = check older.
    // isLastInGroup  = bottom of group visually = no same-sender BELOW = check newer.
    final newer = index > 0 ? messages[index - 1] : null;
    final olderIndex = index + spanLength;
    final older = olderIndex < messages.length ? messages[olderIndex] : null;
    final isFirst = older == null || older.senderId != current.senderId;
    final isLast = newer == null || newer.senderId != current.senderId;
    return (isFirst, isLast);
  }
}
