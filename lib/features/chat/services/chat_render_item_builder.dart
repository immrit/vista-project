import '../../../model/message_model.dart';
import '../domain/chat_render_descriptor.dart';

abstract final class ChatRenderItemBuilder {
  static List<ChatRenderDescriptor> build(List<MessageModel> messages) {
    if (messages.isEmpty) return const [];

    final descriptors = <ChatRenderDescriptor>[];
    var index = 0;

    while (index < messages.length) {
      final current = messages[index];

      if (_isAlbumImageMessage(current)) {
        final groupedIds = <String>[current.id];
        var lookAhead = index + 1;
        final currentGroupId = current.mediaGroupId?.trim();
        final hasExplicitGroupId =
            currentGroupId != null && currentGroupId.isNotEmpty;

        while (lookAhead < messages.length && groupedIds.length < 10) {
          final candidate = messages[lookAhead];
          if (hasExplicitGroupId) {
            final candidateGroupId = candidate.mediaGroupId?.trim();
            if (!_isAlbumImageMessage(candidate) ||
                candidate.senderId != current.senderId ||
                candidateGroupId != currentGroupId) {
              break;
            }
          } else if (!_canAppendToAlbum(
            messages[lookAhead - 1],
            candidate,
            current,
          )) {
            break;
          }
          groupedIds.add(candidate.id);
          lookAhead++;
        }

        if (groupedIds.length > 1) {
          descriptors.add(
            ChatRenderDescriptor(
              key: 'album_${groupedIds.join('_')}',
              primaryIndex: index,
              messageIds: groupedIds,
              isAlbum: true,
            ),
          );
          index = lookAhead;
          continue;
        }
      }

      descriptors.add(
        ChatRenderDescriptor(
          key: current.id,
          primaryIndex: index,
          messageIds: [current.id],
          isAlbum: false,
        ),
      );
      index++;
    }

    return descriptors;
  }

  static bool _isAlbumImageMessage(MessageModel message) {
    final hasMediaSource =
        (message.attachmentUrl?.trim().isNotEmpty ?? false) ||
            (message.localFilePath?.trim().isNotEmpty ?? false) ||
            (message.localImagePath?.trim().isNotEmpty ?? false);
    return hasMediaSource && message.isImage;
  }

  static bool _canAppendToAlbum(
    MessageModel previousMessage,
    MessageModel candidate,
    MessageModel anchor,
  ) {
    if (!_isAlbumImageMessage(candidate)) return false;
    if (candidate.senderId != anchor.senderId) return false;

    final diffWithPrevious =
        previousMessage.createdAt.difference(candidate.createdAt).abs();
    if (diffWithPrevious > const Duration(seconds: 25)) return false;

    final diffWithAnchor =
        anchor.createdAt.difference(candidate.createdAt).abs();
    return diffWithAnchor <= const Duration(seconds: 60);
  }
}
