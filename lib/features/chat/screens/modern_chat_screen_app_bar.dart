// ignore_for_file: invalid_use_of_protected_member, unused_element
part of 'modern_chat_screen.dart';

extension _ModernChatAppBarExt on _ModernChatScreenState {
  Widget _buildEmojiPanel(ChatTheme theme) {
    return Material(
      color: theme.inputBackgroundColor,
      child: VistaEmojiPanel(
        controller: _messageController,
        height: _cachedKeyboardHeight,
        onGifSelected: _handleGifSelected,
      ),
    );
  }
  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 APP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildSelectionAppBar(ChatTheme theme) {
    final appBarColor = theme.sendButtonColor;
    return AppBar(
      elevation: 0,
      backgroundColor: appBarColor,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: appBarColor,
        systemStatusBarContrastEnforced: false,
      ),
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        '${_selection.selectedMessageIds.length} انتخاب شده'.toPersianDigit(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // فوروارد
        if (!widget.args.isSecret)
          IconButton(
            icon: const Icon(Icons.forward_rounded, color: Colors.white),
            onPressed: _selection.selectedMessageIds.isEmpty
                ? null
                : _forwardSelectedMessages,
            tooltip: 'فوروارد',
          ),
        // کپی
        if (!widget.args.isSecret)
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white),
            onPressed: _selection.selectedMessageIds.isEmpty
                ? null
                : _copySelectedMessages,
            tooltip: 'کپی',
          ),
        // حذف
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          onPressed: _selection.selectedMessageIds.isEmpty
              ? null
              : _deleteSelectedMessages,
          tooltip: 'حذف',
        ),
      ],
    );
  }

  void _enterSelectionMode(String messageId) {
    _selectionActions.enterSelectionMode(messageId);
  }

  void _enterSelectionModeForMessages(Iterable<String> messageIds) {
    _selectionActions.enterSelectionModeForMessages(messageIds);
  }

  void _exitSelectionMode() {
    _selectionActions.exitSelectionMode();
  }

  void _toggleMessageSelection(String messageId) {
    _selectionActions.toggleMessageSelection(messageId);
  }

  bool _isRenderItemSelected(_ChatRenderItem renderItem) {
    return _selection.containsAll(
      renderItem.messages.map((message) => message.id),
    );
  }

  void _toggleRenderItemSelection(_ChatRenderItem renderItem) {
    _selectionActions.toggleRenderItemSelection(
      renderItem.messages.map((message) => message.id),
    );
  }

  /// ✅ توابع کمکی یکپارچه برای هندل کردن کلیک و لانگ پرس
  void _handleMessageTap(BuildContext itemContext, MessageModel message) {
    if (_selection.isSelectionMode) {
      _toggleMessageSelection(message.id);
      return;
    }

    // Tap opens the context menu unless multi-select is already active.
    _showModernContextMenu(itemContext, message);
  }

  void _handleMessageLongPress(BuildContext itemContext, MessageModel message) {
    HapticFeedback.mediumImpact();
    if (_selection.isSelectionMode) {
      _toggleMessageSelection(message.id);
    } else {
      // Long-press starts multi-select.
      _enterSelectionMode(message.id);
    }
  }

  Future<void> _forwardSelectedMessages() async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('فوروارد در گفتگوی محرمانه غیرفعال است');
      return;
    }
    final result = await ForwardMessageSheet.show(
      context,
      messageIds: _selection.selectedMessageIds.toList(),
    );

    if (result == true) {
      _showSuccessSnackBar('پیام‌ها فوروارد شدند');
      _exitSelectionMode();
    }
  }

  Future<void> _copySelectedMessages() async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('کپی در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (!mounted) return;

    try {
      // گرفتن متن پیام‌های انتخاب شده
      final messagesAsync =
          ref.read(chatMessagesProvider(widget.args.conversationId));
      messagesAsync.whenData((messages) {
        if (!mounted) return;

        final selectedMessages = messages
            .where((m) => _selection.contains(m.id))
            .map((m) => m.content)
            .join('\n\n');

        Clipboard.setData(ClipboardData(text: selectedMessages));
        if (mounted) {
          _showSuccessSnackBar(
              '${_selection.selectedMessageIds.length} پیام کپی شد'
                  .toPersianDigit());
          _exitSelectionMode();
        }
      });
    } catch (e) {
      debugPrint('Error in _copySelectedMessages: $e');
    }
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selection.selectedMessageIds.isEmpty) return;

    // دسترسی به لیست کامل پیام‌ها برای استخراج MessageModel
    final messagesAsync =
        ref.read(chatMessagesProvider(widget.args.conversationId));
    final allMessages = messagesAsync.valueOrNull ?? [];

    // تبدیل ID های انتخاب شده به مدل‌های کامل پیام
    // (این برای سرویس لازم است تا بتواند URL فایل‌ها را برای حذف پیدا کند)
    final List<MessageModel> selectedMessagesList = [];
    final currentUserId = _currentUserId;
    bool allMyMessages = true;

    for (final id in _selection.selectedMessageIds) {
      final msg = allMessages.firstWhere(
        (m) => m.id == id,
        orElse: () => MessageModel.empty(),
      );

      if (msg.id.isNotEmpty) {
        selectedMessagesList.add(msg);
        // بررسی مالکیت
        if (msg.senderId != currentUserId) {
          allMyMessages = false;
        }
      }
    }

    if (selectedMessagesList.isEmpty) return;

    await _confirmAndDeleteMessages(
      selectedMessagesList,
      allMyMessagesOverride: allMyMessages,
      exitSelectionModeOnSuccess: true,
    );
  }

  void _startDeleteAnimation(List<String> messageIds) {
    for (var i = 0; i < messageIds.length; i++) {
      final id = messageIds[i];
      Future.delayed(Duration(milliseconds: i * 36), () {
        if (!mounted) return;
        _deletingMessageIds.add(id);
        _hiddenMessageIds.add(id);
        _bumpListOverlay();
      });
    }
  }

  Future<void> _persistDeleteAfterAnimation({
    required List<String> messageIds,
    required List<MessageModel> messages,
    required bool deleteForEveryone,
  }) async {
    try {
      await _tombstoneService.markDeletedLocallyBatch(
        messageIds: messageIds,
        conversationId: widget.args.conversationId,
        deleteForEveryone: deleteForEveryone,
      );
      await _enqueueDeletedMessageMediaCleanup(
        messages,
        deleteForEveryone: deleteForEveryone,
      );
    } catch (e, s) {
      logError('Failed to persist message tombstones', error: e, stackTrace: s);
    }
    final wait = 260 + (messageIds.length * 36);
    await Future.delayed(Duration(milliseconds: wait));
    if (!mounted) return;
    _deletingMessageIds.removeAll(messageIds);
  }

  Future<void> _confirmAndDeleteMessages(
    List<MessageModel> messages, {
    bool? allMyMessagesOverride,
    bool exitSelectionModeOnSuccess = false,
  }) async {
    final messageMap = <String, MessageModel>{};
    for (final message in messages) {
      if (message.id.trim().isEmpty) continue;
      messageMap[message.id] = message;
    }
    final normalizedMessages = messageMap.values.toList(growable: false);
    if (normalizedMessages.isEmpty) return;

    final currentUserId = _currentUserId;
    final allMyMessages = allMyMessagesOverride ??
        normalizedMessages.every((m) => m.senderId == currentUserId);

    final result = await DeleteMessageDialog.show(
      context,
      isMyMessage: allMyMessages,
      messageCount: normalizedMessages.length,
    );

    if (!result.confirmed) return;

    final messageIds =
        normalizedMessages.map((message) => message.id).toList(growable: false);
    if (exitSelectionModeOnSuccess) {
      _exitSelectionMode();
    }

    _startDeleteAnimation(messageIds);
    logInfo('message_delete_requested: ${messageIds.join(",")}');

    if (result.deleteForEveryone) {
      unawaited(_persistDeleteAfterAnimation(
        messageIds: messageIds,
        messages: normalizedMessages,
        deleteForEveryone: true,
      ));
      if (mounted) {
        _showSuccessSnackBar(
          '${messageIds.length} پیام برای همه حذف شد'.toPersianDigit(),
        );
      }
    } else {
      final batchId = DateTime.now().microsecondsSinceEpoch.toString();
      final deleteTimer = Timer(const Duration(seconds: 4), () {
        _pendingDeleteTimers.remove(batchId);
        unawaited(_persistDeleteAfterAnimation(
          messageIds: messageIds,
          messages: normalizedMessages,
          deleteForEveryone: false,
        ));
        if (mounted) {
          _showSuccessSnackBar(
            '${messageIds.length} پیام حذف شد'.toPersianDigit(),
          );
        }
      });
      _pendingDeleteTimers[batchId] = deleteTimer;

      if (mounted) {
        _showInfoSnackBar(
          '${messageIds.length} پیام برای حذف آماده شد'.toPersianDigit(),
          action: SnackBarAction(
            label: 'بازگردانی',
            onPressed: () {
              final timer = _pendingDeleteTimers.remove(batchId);
              timer?.cancel();
              if (!mounted) return;
              _deletingMessageIds.removeAll(messageIds);
              _hiddenMessageIds.removeAll(messageIds);
              _bumpListOverlay();
            },
          ),
        );
      }
    }
  }

  Future<void> _enqueueDeletedMessageMediaCleanup(
    List<MessageModel> messages, {
    required bool deleteForEveryone,
  }) async {
    final urls = <String>[];
    for (final message in messages) {
      final isLocalOnly = message.isPending ||
          message.isUploading ||
          message.isFailed == true ||
          message.id.startsWith('temp_');
      if (!deleteForEveryone && !isLocalOnly) continue;

      final attachmentUrl = message.attachmentUrl?.trim();
      if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
        urls.add(attachmentUrl);
      }

      final audioUrl = message.audioUrl?.trim();
      if (audioUrl != null && audioUrl.isNotEmpty) {
        urls.add(audioUrl);
      }
    }

    if (urls.isEmpty) return;
    await OrphanedMediaCleanupService.enqueueUrls(
      urls,
      source: 'chat_delete',
      reason: deleteForEveryone
          ? 'message_deleted_for_everyone'
          : 'local_failed_message_discarded',
      conversationId: widget.args.conversationId,
    );
  }

  Widget _buildAppBarTitle(ChatTheme theme) {
    return InkWell(
      onTap: () {
        _navigateToChatDetails();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // آواتار با نقطه آنلاین
            _buildAvatarWithOnlineIndicator(theme),

            const SizedBox(width: 12),

            // نام و وضعیت
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _otherUserProfile?.username ??
                              widget.args.otherUserName,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (widget.args.isSecret)
                        Icon(
                          Icons.lock_rounded, // 🔒 آیکون امنیتی E2EE
                          color:
                              theme.isDark ? Colors.greenAccent : Colors.green,
                          size: 14,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // ✅ وضعیت آنلاین به سبک ویستا - Real-time
                  if (widget.args.isSecret)
                    Row(
                      children: [
                        Icon(
                          _secretAutoDeleteSeconds > 0
                              ? Icons.timer_rounded
                              : Icons.timer_off_outlined,
                          size: 13,
                          color: _secretAutoDeleteSeconds > 0
                              ? Colors.greenAccent
                              : theme.secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _secretAutoDeleteStatusText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _secretAutoDeleteSeconds > 0
                                  ? Colors.greenAccent
                                  : theme.secondaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (widget.args.isGroup)
                    _buildGroupPresenceSummary(theme)
                  else
                    ModernOnlineStatus(
                      userId: widget.args.otherUserId,
                      isTyping: _otherUserTypingNotifier.value,
                      textStyle: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupPresenceSummary(ChatTheme theme) {
    return ChatGroupPresenceSummary(
      members: _groupMembers,
      isLoadingMembers: _isLoadingGroupMembers,
      theme: theme,
    );
  }

  /// آواتار با نشانگر آنلاین
  Widget _buildAvatarWithOnlineIndicator(ChatTheme theme) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          // آواتار اصلی
          _buildAvatar(theme),
          if (!widget.args.isGroup)
            Positioned(
              right: 0,
              bottom: 0,
              child: _buildOnlineDot(),
            ),
        ],
      ),
    );
  }

  /// نقطه آنلاین برای آواتار - ✅ بهینه با Consumer
  Widget _buildOnlineDot() {
    return Consumer(
      builder: (context, ref, _) {
        final presenceAsync = ref.watch(
          userPresenceStreamProvider(widget.args.otherUserId),
        );

        return presenceAsync.maybeWhen(
          data: (state) {
            if (!state.isOnline) return const SizedBox.shrink();

            return OnlineStatusDot(
              status: state.status,
              size: 14,
              borderColor: Theme.of(context).scaffoldBackgroundColor,
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildAvatar(ChatTheme theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.sendButtonColor.withValues(alpha: 0.8),
            theme.sendButtonColor,
          ],
        ),
      ),
      child: widget.args.otherUserAvatar != null
          ? ClipOval(
              child: AvatarAssetUtils.image(
                source: widget.args.otherUserAvatar,
                fit: BoxFit.cover,
                // ✅ بسیار مهم: آواتار ۴۰ پیکسلی نباید عکس ۲۰۰۰ پیکسلی در رم نگه دارد
                memCacheWidth: 100,
                memCacheHeight: 100,
                placeholder: _buildAvatarText(theme),
                fallback: _buildAvatarText(theme),
              ),
            )
          : _buildAvatarText(theme),
    );
  }

  Widget _buildAvatarText(ChatTheme theme) {
    final initial = widget.args.otherUserName.trim().isNotEmpty
        ? widget.args.otherUserName.trim()[0].toUpperCase()
        : '?';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'search':
        setState(() => _isSearchMode = true);
        break;
      case 'start_secret_chat':
        _startSecretChat();
        break;
      case 'secret_timer':
        _pickSecretAutoDeleteTimer();
        break;
      case 'group_manage':
      case 'group_add_members':
        _navigateToChatDetails();
        break;
      case 'group_invite':
        _copyGroupInviteLink();
        break;
      case 'details':
        _navigateToChatDetails();
        break;
      case 'profile':
        _navigateToProfile();
        break;
      case 'block':
        _showBlockDialog();
        break;
      case 'report':
        _showReportDialog();
        break;
      case 'clear':
        _showClearChatDialog();
        break;
      case 'leave_group':
        _leaveGroupFromChat();
        break;
    }
  }

  Future<void> _copyGroupInviteLink() async {
    if (!widget.args.isGroup) return;
    try {
      final invite = await _groupService.getInvite(widget.args.conversationId);
      final inviteCode = invite['invite_code']?.toString();
      if (inviteCode == null || inviteCode.trim().isEmpty) {
        _showErrorSnackBar('لینک دعوت هنوز ساخته نشده است');
        return;
      }
      final inviteLink = 'https://cafevista.ir/group/$inviteCode';
      await Clipboard.setData(ClipboardData(text: inviteLink));
      if (mounted) {
        _showInfoSnackBar('لینک دعوت گروه کپی شد');
      }
    } catch (error) {
      if (mounted) _showErrorSnackBar('برای دریافت لینک دعوت دسترسی ندارید');
    }
  }

  Future<void> _leaveGroupFromChat() async {
    if (!widget.args.isGroup) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خروج از گروه'),
        content: const Text(
          'بعد از خروج، برای برگشت دوباره باید از طریق لینک دعوت یا ادمین وارد شوید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _groupService.leaveGroup(widget.args.conversationId);
      await _chatRepository.refreshConversations();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar(
            'خروج از گروه انجام نشد؛ اگر سازنده هستید از مدیریت گروه استفاده کنید');
      }
    }
  }

  Future<void> _startSecretChat() async {
    if (widget.args.isSecret ||
        widget.args.isGroup ||
        widget.args.otherUserId.isEmpty) {
      return;
    }

    final result = await _chatRepository.createConversation(
      widget.args.otherUserId,
      isSecret: true,
    );

    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      _showErrorSnackBar(result.error ?? 'ایجاد گفتگوی محرمانه انجام نشد');
      return;
    }

    final secretConversation = result.data!;
    final displayName =
        (_otherUserProfile?.username ?? widget.args.otherUserName);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModernChatScreen(
          args: ChatScreenArgs(
            conversationId: secretConversation.id,
            otherUserName: displayName,
            otherUserAvatar:
                _otherUserProfile?.avatarUrl ?? widget.args.otherUserAvatar,
            otherUserId: widget.args.otherUserId,
            isGroup: false,
            isSecret: true,
          ),
        ),
      ),
    );
  }

  void _showClearChatDialog() {
    final theme = context.chatTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: Text(
          'پاک کردن چت',
          style: TextStyle(color: theme.textColor),
        ),
        content: Text(
          'آیا مطمئن هستید؟ این عمل قابل بازگشت نیست.',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              showDeleteConversationDialog(
                context: this.context,
                conversationId: widget.args.conversationId,
                conversationTitle: widget.args.otherUserName,
                isGroupChat: widget.args.isGroup,
                preferredOption: DeleteConversationOption.clearHistory,
                onDeleted: () {
                  ref.invalidate(
                      chatMessagesProvider(widget.args.conversationId));
                },
              );
            },
            child: Text(
              'پاک کردن',
              style: TextStyle(color: theme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📢 STATUS BANNERS
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // 💬 MESSAGE LIST
  // ═══════════════════════════════════════════════════════════════════════════

  void _bumpListOverlay() {
    _listOverlayRevision.value++;
    _cachedMessageBindings = null;
  }

}
