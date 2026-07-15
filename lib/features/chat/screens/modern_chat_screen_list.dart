// ignore_for_file: invalid_use_of_protected_member, unused_element
part of 'modern_chat_screen.dart';

extension _ModernChatListExt on _ModernChatScreenState {
  Widget _buildMessageList(
    PaginationState paginationState,
    ChatTheme theme, {
    required ValueListenable<double> bottomPaddingListenable,
    required ValueListenable<double> inputHeightListenable,
  }) {
    final messagesAsync = ref.read(chatMessagesProvider(_conversationId));

    if (messagesAsync.isLoading && !messagesAsync.hasValue) {
      return _buildLoadingState(theme);
    }
    if (messagesAsync.hasError && !messagesAsync.hasValue) {
      return _buildErrorState(
        messagesAsync.error.toString(),
        theme,
      );
    }

    return ChatMessageListView(
      conversationId: _conversationId,
      renderCapListenable: _messageRenderCapNotifier,
      overlayRevisionListenable: _listOverlayRevision,
      scrollController: _scrollController,
      bottomPaddingListenable: bottomPaddingListenable,
      inputHeightListenable: inputHeightListenable,
      bindings: _getMessageBindings(theme),
      filterMessage: _isMessageVisibleInList,
      resolveUiContent: _applySecretUiContent,
      buildLoadingIndicator: _buildLoadingIndicator,
      buildEmptyState: _buildEmptyState,
      secretSystemNoticeWidgets: widget.args.isSecret
          ? _secretSystemNotices
              .map(
                (notice) => KeyedSubtree(
                  key: ValueKey(notice.id),
                  child: _buildSecretSystemNoticeBubble(notice),
                ),
              )
              .toList(growable: false)
          : const [],
      showSecretNotices:
          widget.args.isSecret && _secretSystemNotices.isNotEmpty,
    );
  }

  bool _isMessageVisibleInList(MessageModel message) {
    return (!_hiddenMessageIds.contains(message.id) ||
            _deletingMessageIds.contains(message.id)) &&
        message.messageType != 'exchange_key' &&
        message.messageType != 'exchange_key_reply' &&
        message.attachmentType != 'exchange_key' &&
        message.attachmentType != 'exchange_key_reply';
  }

  bool _shouldShowUnreadDividerForIds(
    List<String> messageIds,
    int index,
    int totalRows,
  ) {
    if (_lastReadMessageId == null || _unreadCount <= 0) return false;
    final hasBoundary = messageIds.contains(_lastReadMessageId);
    if (!hasBoundary) return false;
    if (index < totalRows - 1) return true;
    // All loaded messages are unread — show divider on the oldest row.
    return index == totalRows - 1;
  }

  ({
    List<GalleryItem> items,
    Map<String, int> indexByMessageId,
  }) _conversationGalleryFromStore() {
    final store = ref.read(chatMessageStoreProvider(_conversationId));
    final messages = store.orderedIds
        .map((id) => store.byId[id])
        .whereType<MessageModel>()
        .where(_isMessageVisibleInList)
        .toList(growable: false);
    final gallery = _buildConversationImageGallery(
      _applySecretUiContent(messages),
    );
    return (
      items: gallery.items,
      indexByMessageId: gallery.indexByMessageId,
    );
  }

  ChatMessageBindings _getMessageBindings(ChatTheme theme) {
    final store = ref.read(chatMessageStoreProvider(_conversationId));
    final overlayRevision = _listOverlayRevision.value;
    if (_cachedMessageBindings != null &&
        _cachedBindingsOverlayRevision == overlayRevision &&
        _cachedBindingsGalleryStructureVersion == store.structureVersion &&
        _cachedBindingsUnreadCount == _unreadCount) {
      return _cachedMessageBindings!;
    }

    final bindings = _createMessageBindings(
      theme,
      overlayRevision: overlayRevision,
      galleryStructureVersion: store.structureVersion,
    );
    _cachedMessageBindings = bindings;
    _cachedBindingsOverlayRevision = overlayRevision;
    _cachedBindingsGalleryStructureVersion = store.structureVersion;
    _cachedBindingsUnreadCount = _unreadCount;
    return bindings;
  }

  ChatMessageBindings _createMessageBindings(
    ChatTheme theme, {
    required int overlayRevision,
    required int galleryStructureVersion,
  }) {
    final gallery = _conversationGalleryFromStore();
    return ChatMessageBindings(
      conversationId: _conversationId,
      currentUserId: _currentUserId,
      unreadCount: _unreadCount,
      overlayRevision: overlayRevision,
      galleryStructureVersion: galleryStructureVersion,
      conversationGallery: gallery,
      buildBubble: (request) => _buildGroupSenderFrame(
        message: request.message,
        isMe: request.isMe,
        isFirstInGroup: request.isFirstInGroup,
        isLastInGroup: request.isLastInGroup,
        theme: theme,
        child: _buildBubbleContent(
          request.message,
          request.isMe,
          request.index,
          request.isFirstInGroup,
          request.isLastInGroup,
          request.adaptiveEffects,
          selection: request.selection,
          messagesById: request.messagesById,
          conversationGalleryItems: request.conversationGalleryItems,
          conversationGalleryIndexByMessageId:
              request.conversationGalleryIndexByMessageId,
        ),
      ),
      buildAlbumBubble: (request) => _buildGroupSenderFrame(
        message: request.messages.first,
        isMe: request.isMe,
        isFirstInGroup: request.isFirstInGroup,
        isLastInGroup: request.isLastInGroup,
        theme: theme,
        child: _buildAlbumBubbleContent(
          _ChatRenderItem(
            primaryIndex: request.primaryIndex,
            messages: request.messages,
          ),
          request.isMe,
          request.adaptiveEffects,
          selection: request.selection,
          isFirstInGroup: request.isFirstInGroup,
          isLastInGroup: request.isLastInGroup,
          messagesById: request.messagesById,
          conversationGalleryItems: request.conversationGalleryItems,
          conversationGalleryIndexByMessageId:
              request.conversationGalleryIndexByMessageId,
        ),
      ),
      buildLoadingIndicator: () => _buildLoadingIndicator(theme),
      buildEmptyState: () => _buildEmptyState(theme),
      onToggleRenderItemSelection: (messageIds) =>
          _selectionActions.toggleRenderItemSelection(messageIds),
      onEnterSelectionMode: (messageIds) =>
          _selectionActions.enterSelectionModeForMessages(messageIds),
      onScrollToBottom: _scrollToBottom,
      onReplyToMessage: (message) {
        setState(() => _replyToMessage = message);
        _focusNode.requestFocus();
      },
      onDeleteAnimationComplete: (messageIds) {
        if (!mounted) return;
        setState(() {
          for (final id in messageIds) {
            _deletingMessageIds.remove(id);
          }
        });
        _bumpListOverlay();
      },
      isMessageDeleting: (id) => _deletingMessageIds.contains(id),
      isMessageTemporarilyHidden: (id) =>
          _temporarilyHiddenMessages.contains(id),
      shouldShowUnreadDivider: _shouldShowUnreadDividerForIds,
      shouldShowDateDivider: date_divider.shouldShowDateDivider,
      getMessageGroupPosition: (primaryIndex, spanLength) {
        final store = ref.read(chatMessageStoreProvider(_conversationId));
        final messages = <MessageModel>[];
        for (final id in store.orderedIds) {
          final message = store.byId[id];
          if (message != null && _isMessageVisibleInList(message)) {
            messages.add(message);
          }
        }
        final uiMessages = _applySecretUiContent(messages);
        if (primaryIndex < 0 || primaryIndex >= uiMessages.length) {
          return (true, true);
        }
        return _getMessageGroupPosition(
          uiMessages,
          primaryIndex,
          spanLength: spanLength,
        );
      },
    );
  }

  /// تشخیص موقعیت پیام در گروه
  ///
  /// پیام‌های متوالی از یک فرستنده گروه‌بندی میشن
  /// Returns: (isFirstInGroup, isLastInGroup)
  (bool, bool) _getMessageGroupPosition(
    List<MessageModel> messages,
    int index, {
    int spanLength = 1,
  }) {
    final currentNewestMessage = messages[index];
    final endIndex =
        (index + spanLength - 1).clamp(index, messages.length - 1).toInt();
    final currentOldestMessage = messages[endIndex];

    // چون لیست reverse است:
    // - index کمتر = پیام جدیدتر (پایین صفحه)
    // - index بیشتر = پیام قدیمی‌تر (بالای صفحه)
    final hasBelow = index > 0;
    final belowMessage = hasBelow ? messages[index - 1] : null;
    final aboveIndex = endIndex + 1;
    final hasAbove = aboveIndex < messages.length;
    final aboveMessage = hasAbove ? messages[aboveIndex] : null;

    final bool sameAsAbove = hasAbove &&
        TimeUtils.isInSameGroup(
          currentOldestMessage.createdAt,
          aboveMessage!.createdAt,
          currentOldestMessage.senderId,
          aboveMessage.senderId,
        );

    final bool sameAsBelow = hasBelow &&
        TimeUtils.isInSameGroup(
          belowMessage!.createdAt,
          currentNewestMessage.createdAt,
          belowMessage.senderId,
          currentNewestMessage.senderId,
        );

    final isFirstInGroup = !sameAsAbove;
    final isLastInGroup = !sameAsBelow;

    return (isFirstInGroup, isLastInGroup);
  }

  Widget _buildGroupSenderFrame({
    required MessageModel message,
    required bool isMe,
    required bool isFirstInGroup,
    required bool isLastInGroup,
    required ChatTheme theme,
    required Widget child,
  }) {
    if (!widget.args.isGroup || isMe) return child;

    final senderName = _resolveMessageSenderName(message);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 38,
          child: isLastInGroup
              ? Padding(
                  padding:
                      const EdgeInsetsDirectional.only(start: 4, bottom: 6),
                  child: _buildGroupSenderAvatar(message, senderName, theme),
                )
              : const SizedBox.shrink(),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFirstInGroup)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openGroupSenderProfile(message),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 14,
                      end: 12,
                      top: 2,
                      bottom: 1,
                    ),
                    child: Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.sendButtonColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              child,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupSenderAvatar(
    MessageModel message,
    String senderName,
    ChatTheme theme,
  ) {
    final avatarUrl = _resolveMessageSenderAvatar(message);
    final initial =
        senderName.trim().isNotEmpty ? senderName.trim()[0].toUpperCase() : '?';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openGroupSenderProfile(message),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.sendButtonColor.withValues(alpha: 0.72),
              theme.sendButtonColor.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: avatarUrl != null
            ? ClipOval(
                child: AvatarAssetUtils.image(
                  source: avatarUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 96,
                  memCacheHeight: 96,
                  placeholder: _buildGroupSenderInitial(initial),
                  fallback: _buildGroupSenderInitial(initial),
                ),
              )
            : _buildGroupSenderInitial(initial),
      ),
    );
  }

  Widget _buildGroupSenderInitial(String initial) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _resolveMessageSenderName(MessageModel message) {
    final memberName = _groupMemberById[message.senderId]?.displayName.trim();
    if (memberName != null && memberName.isNotEmpty) return memberName;

    final cachedProfile =
        UserProfileService().getCachedProfile(message.senderId);
    if (cachedProfile != null) {
      final name = cachedProfile['username']?.trim() ??
          cachedProfile['full_name']?.trim();
      if (name != null && name.isNotEmpty) return name;
    }

    final messageName = message.senderName?.trim();
    if (messageName != null && messageName.isNotEmpty) return messageName;

    return 'کاربر';
  }

  String? _resolveMessageSenderAvatar(MessageModel message) {
    final memberAvatar = AvatarAssetUtils.resolveUrl(
      _groupMemberById[message.senderId]?.avatarUrl,
    );
    if (memberAvatar != null) return memberAvatar;

    final cachedProfile =
        UserProfileService().getCachedProfile(message.senderId);
    if (cachedProfile != null) {
      final avatar = AvatarAssetUtils.resolveUrl(cachedProfile['avatar_url']);
      if (avatar != null) return avatar;
    }

    return AvatarAssetUtils.resolveUrl(message.senderAvatar);
  }

  String _resolveReactionUserName(String userId, [String? fallbackName]) {
    final fallback = fallbackName?.trim() ?? '';
    if (fallback.isNotEmpty && fallback != 'کاربر') return fallback;

    if (userId == _currentUserId) {
      final profile = _currentUserProfile;
      if (profile != null) {
        if (profile.username.trim().isNotEmpty) return profile.username.trim();
        if (profile.fullName.trim().isNotEmpty) return profile.fullName.trim();
      }
    }

    if (!widget.args.isGroup && userId == widget.args.otherUserId) {
      final otherName = widget.args.otherUserName.trim();
      if (otherName.isNotEmpty && otherName != 'کاربر') return otherName;
      final otherProfile = _otherUserProfile;
      if (otherProfile != null) {
        if (otherProfile.username.trim().isNotEmpty) {
          return otherProfile.username.trim();
        }
        if (otherProfile.fullName.trim().isNotEmpty) {
          return otherProfile.fullName.trim();
        }
      }
    }

    final memberName = _groupMemberById[userId]?.displayName.trim();
    if (memberName != null && memberName.isNotEmpty && memberName != 'کاربر') {
      return memberName;
    }

    final cachedProfile = UserProfileService().getCachedProfile(userId);
    if (cachedProfile != null) {
      final username = cachedProfile['username']?.trim();
      if (username != null && username.isNotEmpty) return username;
      final fullName = cachedProfile['full_name']?.trim();
      if (fullName != null && fullName.isNotEmpty) return fullName;
    }

    return fallback.isNotEmpty ? fallback : 'کاربر';
  }

  String? _resolveReactionUserAvatar(String userId, [String? fallbackAvatar]) {
    final resolvedFallback = AvatarAssetUtils.resolveUrl(fallbackAvatar);
    if (resolvedFallback != null) return resolvedFallback;

    if (userId == _currentUserId) {
      final avatar =
          AvatarAssetUtils.resolveUrl(_currentUserProfile?.avatarUrl);
      if (avatar != null) return avatar;
    }

    if (!widget.args.isGroup && userId == widget.args.otherUserId) {
      final avatar = AvatarAssetUtils.resolveUrl(
        _otherUserProfile?.avatarUrl ?? widget.args.otherUserAvatar,
      );
      if (avatar != null) return avatar;
    }

    final memberAvatar =
        AvatarAssetUtils.resolveUrl(_groupMemberById[userId]?.avatarUrl);
    if (memberAvatar != null) return memberAvatar;

    final cachedProfile = UserProfileService().getCachedProfile(userId);
    if (cachedProfile != null) {
      final avatar = AvatarAssetUtils.resolveUrl(cachedProfile['avatar_url']);
      if (avatar != null) return avatar;
    }

    return null;
  }

  reaction_models.MessageReaction _enrichReaction(
    reaction_models.MessageReaction reaction,
  ) {
    final userName =
        _resolveReactionUserName(reaction.userId, reaction.userName);
    final userAvatar =
        _resolveReactionUserAvatar(reaction.userId, reaction.userAvatar);
    if (userName == reaction.userName && userAvatar == reaction.userAvatar) {
      return reaction;
    }
    return reaction.copyWith(userName: userName, userAvatar: userAvatar);
  }

  List<reaction_models.MessageReaction> _enrichReactions(
    List<reaction_models.MessageReaction> reactions,
  ) {
    if (reactions.isEmpty) return const [];
    return reactions.map(_enrichReaction).toList(growable: false);
  }

  Future<void> _prefetchMissingReactionProfiles(
    Iterable<reaction_models.MessageReaction> reactions,
  ) async {
    final pendingIds = <String>{};
    for (final reaction in reactions) {
      final userId = reaction.userId.trim();
      if (userId.isEmpty) continue;
      final resolvedName = _resolveReactionUserName(userId, reaction.userName);
      if (resolvedName == 'کاربر') {
        pendingIds.add(userId);
      }
    }
    if (pendingIds.isEmpty) return;

    var changed = false;
    for (final userId in pendingIds) {
      try {
        final profile = await ProfileCacheService().getProfile(userId);
        if (!mounted) return;
        changed = true;

        if (widget.args.isGroup) {
          final existing = _groupMemberById[userId];
          _groupMemberById[userId] = GroupMemberItem(
            userId: userId,
            username: profile.username.isNotEmpty
                ? profile.username
                : (existing?.username ?? ''),
            fullName: profile.fullName.isNotEmpty
                ? profile.fullName
                : existing?.fullName,
            avatarUrl: AvatarAssetUtils.resolveUrl(profile.avatarUrl) ??
                existing?.avatarUrl,
            isAdmin: existing?.isAdmin ?? false,
            joinedAt: existing?.joinedAt,
          );
        }
      } catch (_) {
        // Best-effort profile hydration for reaction labels.
      }
    }

    if (!changed || !mounted) return;

    setState(() {
      for (final notifier in _messageReactionNotifiers.values) {
        notifier.value = _enrichReactions(notifier.value);
      }
    });
  }

  Future<void> _prefetchMissingGroupSenderAvatars(
    List<MessageModel> messages,
  ) async {
    final pendingIds = <String>{};
    for (final message in messages) {
      if (message.isMe || message.senderId.trim().isEmpty) continue;
      if (_resolveMessageSenderAvatar(message) != null) continue;
      pendingIds.add(message.senderId);
    }
    if (pendingIds.isEmpty) return;

    for (final userId in pendingIds) {
      try {
        final profile = await ProfileCacheService().getProfile(userId);
        if (!mounted) return;
        final avatar = AvatarAssetUtils.resolveUrl(profile.avatarUrl);
        if (avatar == null || avatar.isEmpty) continue;

        setState(() {
          final existing = _groupMemberById[userId];
          _groupMemberById[userId] = GroupMemberItem(
            userId: userId,
            username: existing?.username ?? profile.username,
            fullName: existing?.fullName ?? profile.fullName,
            avatarUrl: avatar,
            isAdmin: existing?.isAdmin ?? false,
            joinedAt: existing?.joinedAt,
          );
        });
      } catch (_) {
        // Best-effort avatar hydration; initials fallback remains available.
      }
    }
  }

  void _openGroupSenderProfile(MessageModel message) {
    final userId = message.senderId.trim();
    if (userId.isEmpty) return;

    Navigator.of(context).push(
      ProfileRoute(
        userId: userId,
        username: _resolveMessageSenderName(message),
      ),
    );
  }

  MessageStatus _getMessageStatus(MessageModel message) {
    if (!message.isMe) return MessageStatus.sent;
    if (message.isPending) return MessageStatus.pending;
    if (message.isFailed == true) return MessageStatus.failed;
    if (message.isReadByPeer) return MessageStatus.read;
    if (message.isDelivered) return MessageStatus.delivered;
    if (message.isSent) return MessageStatus.sent;
    return MessageStatus.pending;
  }

  /// بارگذاری واکنش‌ها برای پیام‌های فعلی
  Future<void> _loadReactionsForMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;

    try {
      final windowMessages = _selectReactionWindow(messages);
      if (windowMessages.isEmpty) return;

      final messageIds =
          windowMessages.map((m) => m.id).toList(growable: false);
      final reactionsMap =
          await _reactionsService.getMultipleMessageReactions(messageIds);

      if (!mounted) return;
      final allReactions = <reaction_models.MessageReaction>[];
      for (final message in windowMessages) {
        final enriched = _enrichReactions(reactionsMap[message.id] ?? const []);
        _reactionNotifierFor(message.id).value = enriched;
        allReactions.addAll(enriched);
      }
      unawaited(_prefetchMissingReactionProfiles(allReactions));
    } catch (e) {
      debugPrint('❌ Error loading reactions: $e');
    }
  }

  /// راه‌اندازی real-time stream برای واکنش‌ها
  void _setupReactionsStream(List<MessageModel> messages) {
    if (messages.isEmpty) return;

    // فقط برای 20 پیام آخر stream ایجاد می‌کنیم (برای بهینه‌سازی)
    final windowMessages = _selectReactionWindow(messages);
    if (windowMessages.isEmpty) return;
    final messageIds = windowMessages.map((m) => m.id).toSet();

    // 1. لغو subscriptionهای قدیمی که دیگر نیاز نیستند
    final idsToRemove = _reactionsSubscriptions.keys
        .where((id) => !messageIds.contains(id))
        .toList();

    for (final id in idsToRemove) {
      _reactionsSubscriptions[id]?.cancel();
      _reactionsSubscriptions.remove(id);
      final notifier = _messageReactionNotifiers.remove(id);
      notifier?.dispose();
    }

    // 2. ایجاد subscription برای پیام‌های جدید
    final idsToPrime = <String>[];
    for (final messageId in messageIds) {
      if (!_reactionsSubscriptions.containsKey(messageId)) {
        idsToPrime.add(messageId);
        _reactionsSubscriptions[messageId] = _reactionsService
            .watchMessageReactions(messageId)
            .listen((reactions) {
          if (!mounted) return;
          _reactionNotifierFor(messageId).value = _enrichReactions(reactions);
        });
      }
    }
    if (idsToPrime.isNotEmpty) {
      _primeReactionWindow(idsToPrime);
    }
  }

  void _primeReactionWindow(List<String> messageIds) {
    unawaited(() async {
      try {
        final reactionsMap =
            await _reactionsService.getMultipleMessageReactions(messageIds);
        if (!mounted) return;
        final allReactions = <reaction_models.MessageReaction>[];
        for (final messageId in messageIds) {
          final enriched =
              _enrichReactions(reactionsMap[messageId] ?? const []);
          _reactionNotifierFor(messageId).value = enriched;
          allReactions.addAll(enriched);
        }
        unawaited(_prefetchMissingReactionProfiles(allReactions));
      } catch (e) {
        debugPrint('❌ Error priming reaction window: $e');
      }
    }());
  }

  ValueNotifier<List<reaction_models.MessageReaction>> _reactionNotifierFor(
      String messageId) {
    return _messageReactionNotifiers.putIfAbsent(
      messageId,
      () => ValueNotifier<List<reaction_models.MessageReaction>>(const []),
    );
  }

  /// تبدیل reaction_models.MessageReaction به فرمت قدیمی برای AnimatedMessageBubble
  List<MessageReaction> _convertToOldReactionFormat(
      List<reaction_models.MessageReaction> reactions) {
    if (reactions.isEmpty) return [];

    // گروه‌بندی بر اساس emoji
    final Map<String, List<reaction_models.MessageReaction>> grouped = {};
    for (final reaction in reactions) {
      grouped.putIfAbsent(reaction.emoji, () => []).add(reaction);
    }

    return grouped.entries.map((entry) {
      final reactors = entry.value
          .map(
            (reaction) => ReactionReactorInfo(
              userId: reaction.userId,
              userName: _resolveReactionUserName(
                reaction.userId,
                reaction.userName,
              ),
              userAvatar: _resolveReactionUserAvatar(
                reaction.userId,
                reaction.userAvatar,
              ),
            ),
          )
          .toList(growable: false);
      final userIds = entry.value.map((r) => r.userId).toList();
      return MessageReaction(
        emoji: entry.key,
        count: entry.value.length,
        userIds: userIds,
        reactors: reactors,
        isMyReaction: userIds.contains(_currentUserId),
      );
    }).toList();
  }

  Widget _buildLoadingIndicator(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.sendButtonColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ChatTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: theme.secondaryTextColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'شروع گفتگو با ${widget.args.otherUserName}',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اولین پیام رو ارسال کنید!',
            style: TextStyle(
              color: theme.secondaryTextColor.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ChatTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.sendButtonColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'در حال بارگذاری...',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, ChatTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'خطا در بارگذاری پیام‌ها',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(
                    chatMessagesProvider(widget.args.conversationId));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.sendButtonColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🖊️ INPUT AREA
  // ═══════════════════════════════════════════════════════════════════════════

}
