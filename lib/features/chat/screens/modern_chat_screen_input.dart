// ignore_for_file: invalid_use_of_protected_member, unused_element
part of 'modern_chat_screen.dart';

extension _ModernChatInputExt on _ModernChatScreenState {
  Widget _buildInputDockHalo({
    required double gapHeight,
    required double inputHeight,
    required bool keyboardVisible,
    required bool reduceEffects,
  }) {
    final materialTheme = Theme.of(context);
    final isDark = materialTheme.brightness == Brightness.dark;
    final haloColor = isDark
        ? Color.lerp(materialTheme.scaffoldBackgroundColor, Colors.white, 0.08)!
        : Colors.white;
    final visibleReservedHeight = keyboardVisible ? 0.0 : gapHeight;
    final haloBottom = keyboardVisible ? gapHeight : 0.0;
    final haloHeight = (visibleReservedHeight + (inputHeight * 0.56))
        .clamp(48.0, 420.0)
        .toDouble();
    final gradientAlphas =
        isDark ? const [0.0, 0.08, 0.16, 0.24] : const [0.0, 0.14, 0.24, 0.36];
    final haloDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          haloColor.withValues(alpha: gradientAlphas[0]),
          haloColor.withValues(alpha: gradientAlphas[1]),
          haloColor.withValues(alpha: gradientAlphas[2]),
          haloColor.withValues(alpha: gradientAlphas[3]),
        ],
        stops: const [0.0, 0.38, 0.72, 1.0],
      ),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: haloBottom,
      height: haloHeight,
      // No BackdropFilter: it sampled + blurred the scrolling messages behind it
      // every frame (its backdrop changes constantly while the list moves), which
      // was the chat's dominant raster cost — DevTools showed ~42ms/frame, ALL
      // jank on the GPU/raster thread. The gradient halo alone gives the same
      // soft fade over the input dock without the per-frame blur pass.
      child: IgnorePointer(
        child: DecoratedBox(decoration: haloDecoration),
      ),
    );
  }

  Widget _buildMessageRequestOverlay(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'درخواست پیام',
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'اگر درخواست را قبول کنید، این شخص می‌تواند به شما پیام دهد و متوجه خوانده شدن پیام‌هایش می‌شود.',
            style: TextStyle(
              color: theme.textColor.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _handleMessageRequest('accept'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: theme.myBubbleColor,
                  ),
                  child: const Text('قبول درخواست'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _handleMessageRequest('reject'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('رد درخواست و حذف گفتگو'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _handleMessageRequest('block'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('گزارش و بلاک کردن'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleMessageRequest(String action) async {
    try {
      if (action == 'accept') {
        await ref
            .read(chatRepositoryProvider)
            .acceptMessageRequest(widget.args.conversationId);
      } else if (action == 'reject') {
        await ref
            .read(chatRepositoryProvider)
            .rejectMessageRequest(widget.args.conversationId);
        if (mounted) Navigator.of(context).pop();
        return;
      } else if (action == 'block') {
        await ref
            .read(chatRepositoryProvider)
            .rejectMessageRequest(widget.args.conversationId);
        await _moderationService.blockUser(widget.args.otherUserId);
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // Refresh to hide the overlay and show input
      ref.invalidate(optimizedConversationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در انجام عملیات: $e')),
        );
      }
    }
  }

  Widget _buildInputArea(
    ChatTheme theme, {
    required bool reduceEffects,
    required bool allowHeavyEffects,
    required double blurSigma,
  }) {
    return AnimatedChatInput(
      controller: _messageController,
      focusNode: _focusNode,
      onSend: _editToMessage != null ? _saveEditedMessage : _sendMessage,
      onAttachment: _handleAttachment,
      onVoice: _handleVoice,
      onScheduleMessage: _scheduleMessage,
      onChanged: _onTextChanged,
      onGifSelected: _handleGifSelected,
      replyToContent: _editToMessage == null ? _activeReplyContent : null,
      replyToSenderName: _editToMessage == null ? _activeReplySenderName : null,
      onCancelReply: _clearReplyContext,
      editPreviewContent: _activeEditPreviewContent,
      editPreviewTitle: 'ویرایش پیام',
      onCancelEdit: () => _clearEditContext(restoreDraft: true),
      isEditing: _editToMessage != null,
      hint: _editToMessage != null ? 'ویرایش پیام...' : null,
      onVoiceRecorded: _handleVoiceRecorded,
      onAutocomplete: _handleAutocomplete,
      onHeightChanged: _onInputHeightChanged,
      onEmojiPickerToggled: _onEmojiPanelToggled,
      isEmojiPanelOpen: _showEmojiPanel,
      reduceEffects: reduceEffects,
      allowHeavyEffects: allowHeavyEffects,
      blurSigma: blurSigma,
      voicePreset: reduceEffects
          ? VoiceInputPreset.soft
          : (allowHeavyEffects
              ? VoiceInputPreset.strict
              : VoiceInputPreset.balanced),
    );
  }

  /// Handle voice recording
  Future<void> _handleVoiceRecorded(File audioFile, int duration) async {
    if (!mounted) return;

    final attachmentService = ChatAttachmentService();
    final chatRepository = ref.read(chatRepositoryProvider);
    final localId = const Uuid().v4();
    final fileName = p.basename(audioFile.path);
    final fileSize = await audioFile.length();
    final mimeType = _guessMimeTypeFromPath(audioFile.path);

    // محاسبه دقیق مدت زمان
    final durationResult = await _voiceService.getAudioDuration(audioFile);
    final finalDuration =
        durationResult.success ? durationResult.durationInSeconds : duration;

    final pending = await chatRepository.createPendingMessage(
      conversationId: widget.args.conversationId,
      content: '',
      localId: localId,
      attachmentType: 'voice',
      attachmentFileName: fileName,
      attachmentMimeType: mimeType,
      attachmentSizeBytes: fileSize,
      localFilePath: audioFile.path,
      duration: finalDuration,
    );
    if (!pending.isSuccess) {
      if (mounted) {
        _showErrorSnackBar(pending.error ?? 'خطا در ایجاد پیام موقت');
      }
      return;
    }
    _scrollToBottom();

    final result = await attachmentService.uploadVoiceMessage(
      audioFile: audioFile,
      conversationId: widget.args.conversationId,
      duration: finalDuration ?? 0,
      onProgress: (progress) {
        unawaited(chatRepository.updateUploadProgress(localId, progress));
      },
    );

    if (!mounted) return;

    if (!result.success || result.url == null || result.url!.isEmpty) {
      final shortError =
          _shortUploadError(result.error, fallback: 'Voice upload failed');
      await chatRepository.markUploadFailed(
        localId,
        errorMessage: shortError,
      );
      if (mounted) {
        _showErrorSnackBar(shortError);
      }
      return;
    }
    await chatRepository.updateUploadProgress(localId, 1.0);

    final params = SendMessageParams(
      conversationId: widget.args.conversationId,
      content: '',
      attachmentUrl: result.url,
      attachmentType: 'voice',
      attachmentFileName: result.fileName ?? fileName,
      attachmentMimeType: mimeType,
      attachmentSizeBytes: fileSize,
      duration: finalDuration,
      replyToMessageId: _resolveReplyToMessageId(
        replyTo: _replyToMessage,
        pendingReply: _pendingReplyContext,
      ),
      replyToContent: _activeReplyContent,
      replyToSenderName: _activeReplySenderName,
      replyToKind: _resolveReplyToKind(
        replyTo: _replyToMessage,
        pendingReply: _pendingReplyContext,
      ),
      recipientPublicKey:
          widget.args.isSecret ? _otherUserProfile?.publicKey : null,
    );

    try {
      final sendResult =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                id: localId,
                conversationId: params.conversationId,
                content: params.content,
                attachmentUrl: params.attachmentUrl,
                attachmentType: params.attachmentType,
                attachmentFileName: params.attachmentFileName,
                attachmentMimeType: params.attachmentMimeType,
                attachmentSizeBytes: params.attachmentSizeBytes,
                audioTitle: params.audioTitle,
                audioArtist: params.audioArtist,
                audioAlbum: params.audioAlbum,
                duration: params.duration,
                replyToMessageId: params.replyToMessageId,
                replyToContent: params.replyToContent,
                replyToSenderName: params.replyToSenderName,
                replyToKind: params.replyToKind,
                recipientPublicKey:
                    widget.args.isSecret ? params.recipientPublicKey : null,
                requireEncryption: widget.args.isSecret,
              );
      if (!sendResult.isSuccess) {
        await chatRepository.markUploadFailed(
          localId,
          errorMessage: sendResult.error ?? 'ارسال پیام صوتی ناموفق بود',
        );
      }
      await _registerCompletedLocalUpload(
        messageId: localId,
        url: result.url!,
        localPath: audioFile.path,
        fileName: params.attachmentFileName ?? fileName,
      );
      if (mounted) {
        _scrollToBottom();
      }
    } catch (e) {
      final shortError = _shortUploadError(e.toString(),
          fallback: 'Voice message send failed');
      await chatRepository.markUploadFailed(
        localId,
        errorMessage: shortError,
      );
      debugPrint('Error sending voice message: $e');
      if (mounted) {
        _showErrorSnackBar(shortError);
      }
    }
  }

  /// Handle ارسال GIF
  Future<void> _handleGifSelected(String gifUrl) async {
    if (!mounted || gifUrl.isEmpty) return;

    debugPrint('🎞️ ModernChatScreen: Sending GIF: $gifUrl');

    try {
      final replyTo = _replyToMessage;
      final pendingReply = _pendingReplyContext;
      final params = SendMessageParams(
        conversationId: widget.args.conversationId,
        content: '', // محتوای خالی برای GIF
        attachmentUrl: gifUrl,
        attachmentType: 'gif', // نوع attachment
        replyToMessageId: _resolveReplyToMessageId(
            replyTo: replyTo, pendingReply: pendingReply),
        replyToContent: _resolveReplyContentForSend(
          replyTo: replyTo,
          pendingReply: pendingReply,
        ),
        replyToSenderName: _resolveReplySenderNameForSend(
          replyTo: replyTo,
          pendingReply: pendingReply,
        ),
        replyToKind:
            _resolveReplyToKind(replyTo: replyTo, pendingReply: pendingReply),
        recipientPublicKey:
            widget.args.isSecret ? _otherUserProfile?.publicKey : null,
      );

      final result =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                conversationId: params.conversationId,
                content: params.content,
                attachmentUrl: params.attachmentUrl,
                attachmentType: params.attachmentType,
                replyToMessageId: params.replyToMessageId,
                replyToContent: params.replyToContent,
                replyToSenderName: params.replyToSenderName,
                replyToKind: params.replyToKind,
                recipientPublicKey:
                    widget.args.isSecret ? params.recipientPublicKey : null,
                requireEncryption: widget.args.isSecret,
              );

      if (!mounted) return;

      if (result.isSuccess) {
        // پاک کردن reply اگر وجود داشت
        if (_replyToMessage != null || _pendingReplyContext != null) {
          _clearReplyContext();
        }

        // Scroll به پایین
        _scrollToBottom();

        // ✅ آپدیت آخرین پیام برای sync تیک در لیست مکالمات
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _registerLastMessage();
        });

        _showSuccessSnackBar('گیف ارسال شد');
      } else {
        _showErrorSnackBar(result.error ?? 'خطا در ارسال گیف');
      }
    } catch (e) {
      debugPrint('❌ Error sending GIF: $e');
      if (mounted) {
        _showErrorSnackBar('خطا در ارسال گیف');
      }
    }
  }

  void _onTextChanged(String text) {
    if (!mounted) return;
    final userId = _currentUserId;
    if (userId == null) return;

    final hasText = text.trim().isNotEmpty;
    _typingDebounceTimer?.cancel();

    if (!hasText) {
      try {
        _typingService.stopTyping(widget.args.conversationId, userId);
      } catch (e) {
        debugPrint('Error stopping typing: $e');
      }
      return;
    }

    // Start typing immediately for responsive indicator on the other side.
    try {
      _typingService.startTyping(widget.args.conversationId, userId);
    } catch (e) {
      debugPrint('Error starting typing: $e');
    }
  }

  /// Handle autocomplete triggers (@mention or #hashtag)
  void _handleAutocomplete(String? query, String type) {
    if (!mounted) return;

    if (query == null || query.isEmpty) {
      return;
    }

    // For now, we'll just store the query - in a full implementation
    // you would fetch user suggestions here
    debugPrint('Autocomplete: type=$type, query=$query');
  }

  Future<void> _scheduleMessage() async {
    if (!mounted) return;
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'زمان‌بندی ارسال پیام',
      cancelText: 'لغو',
      confirmText: 'مرحله بعد',
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 1))),
      cancelText: 'لغو',
      confirmText: 'ثبت',
      helpText: 'انتخاب ساعت',
    );
    if (!mounted || time == null) return;

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!scheduledAt.isAfter(now)) {
      _showErrorSnackBar('زمان ارسال باید در آینده باشد');
      return;
    }

    final delay = scheduledAt.difference(now);
    final replyTo = _replyToMessage;
    final pendingReply = _pendingReplyContext;

    _messageController.clear();
    if (mounted) _clearReplyContext();

    final timer = Timer(delay, () async {
      if (!mounted) return;
      try {
        final result =
            await ref.read(chatActionControllerProvider.notifier).sendMessage(
                  conversationId: widget.args.conversationId,
                  content: content,
                  replyToMessageId: _resolveReplyToMessageId(
                    replyTo: replyTo,
                    pendingReply: pendingReply,
                  ),
                  replyToContent: _resolveReplyContentForSend(
                    replyTo: replyTo,
                    pendingReply: pendingReply,
                  ),
                  replyToSenderName: _resolveReplySenderNameForSend(
                    replyTo: replyTo,
                    pendingReply: pendingReply,
                  ),
                  replyToKind: _resolveReplyToKind(
                    replyTo: replyTo,
                    pendingReply: pendingReply,
                  ),
                  recipientPublicKey: widget.args.isSecret
                      ? _otherUserProfile?.publicKey
                      : null,
                  requireEncryption: widget.args.isSecret,
                );
        if (!mounted) return;
        if (result.isSuccess) {
          _scrollToBottom();
        } else {
          _showErrorSnackBar(result.error ?? 'ارسال زمان‌بندی‌شده ناموفق بود');
        }
      } catch (_) {
        if (mounted) {
          _showErrorSnackBar('خطا در ارسال زمان‌بندی‌شده');
        }
      }
    });
    _scheduledSendTimers.add(timer);
    _showSuccessSnackBar(
      'پیام برای ${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')} زمان‌بندی شد',
    );
  }

  /// Creates the conversation for a brand-new chat exactly once, even if several
  /// sends fire before the first one finishes. Concurrent callers await the same
  /// future and land in the same conversation instead of minting duplicates.
  Future<ChatResult<ConversationModel>> _ensureConversationCreated() {
    final existing = _pendingConvCreation;
    if (existing != null) return existing;

    final future = _chatRepository.createConversation(
      widget.args.otherUserId,
      isSecret: widget.args.isSecret,
    );
    _pendingConvCreation = future;
    // Keep a successful result cached for the screen's lifetime; clear on failure
    // so a later send can retry the creation.
    future.then((r) {
      if (!r.isSuccess) _pendingConvCreation = null;
    }).catchError((_) {
      _pendingConvCreation = null;
    });
    return future;
  }

  Future<void> _sendMessage() async {
    if (!mounted) return;

    var fullContent = _messageController.text.trim();
    if (fullContent.isEmpty) return;

    _messageController.clear();

    final replyTo = _replyToMessage;
    final pendingReply = _pendingReplyContext;
    if (mounted) _clearReplyContext();

    // اسپلیت کردن پیام‌های طولانی (مثل تلگرام)
    final int limit = 4096;
    final List<String> chunks = [];
    for (int i = 0; i < fullContent.length; i += limit) {
      chunks.add(fullContent.substring(
          i, i + limit > fullContent.length ? fullContent.length : i + limit));
    }

    try {
      String targetConvId = widget.args.conversationId;
      bool wasEmpty = targetConvId.isEmpty;
      bool shouldPushReplacement = false;

      for (int i = 0; i < chunks.length; i++) {
        final content = chunks[i];
        String? secretRecipientPublicKey;

        if (widget.args.isSecret) {
          final prefs = await SharedPreferences.getInstance();
          final peerPubB64 =
              prefs.getString('e2e_peer_pub_${widget.args.conversationId}');
          if (peerPubB64 == null) {
            _showErrorSnackBar(
                'درحال تبادل کلید امنیتی با مخاطب هستیم... لطفاً کمی صبر کنید');
            return;
          }

          // Encryption is centralized in the repository so text, attachment,
          // reply, retry, and optimistic reconciliation use one envelope.
          secretRecipientPublicKey = peerPubB64;
        }

        if (wasEmpty && i == 0) {
          final convResult = await _ensureConversationCreated();
          if (!convResult.isSuccess || convResult.data == null) {
            _showErrorSnackBar(convResult.error ?? 'خطا در ایجاد گفتگو');
            return;
          }
          targetConvId = convResult.data!.id;
          shouldPushReplacement = true;
        }

        final params = SendMessageParams(
          conversationId: targetConvId,
          content: content,
          replyToMessageId: i == 0
              ? _resolveReplyToMessageId(
                  replyTo: replyTo, pendingReply: pendingReply)
              : null,
          replyToContent: i == 0
              ? _resolveReplyContentForSend(
                  replyTo: replyTo,
                  pendingReply: pendingReply,
                )
              : null,
          replyToSenderName: i == 0
              ? _resolveReplySenderNameForSend(
                  replyTo: replyTo,
                  pendingReply: pendingReply,
                )
              : null,
          replyToKind: i == 0
              ? _resolveReplyToKind(
                  replyTo: replyTo, pendingReply: pendingReply)
              : null,
          recipientPublicKey: secretRecipientPublicKey,
        );

        if (!mounted) return;

        final result =
            await ref.read(chatActionControllerProvider.notifier).sendMessage(
                  conversationId: params.conversationId,
                  content: params.content,
                  replyToMessageId: params.replyToMessageId,
                  replyToContent: params.replyToContent,
                  replyToSenderName: params.replyToSenderName,
                  replyToKind: params.replyToKind,
                  recipientPublicKey:
                      widget.args.isSecret ? params.recipientPublicKey : null,
                  requireEncryption: widget.args.isSecret,
                );

        if (!mounted) return;

        if (!result.isSuccess) {
          _showErrorSnackBar(result.error ?? 'خطا در ارسال پیام');
          return;
        }

        // فاصله کوتاه بین پیام‌ها برای حفظ ترتیب
        if (chunks.length > 1 && i < chunks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // بعد از ارسال تمام بخش‌ها
      if (shouldPushReplacement && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ModernChatScreen(
              args: ChatScreenArgs(
                conversationId: targetConvId,
                otherUserId: widget.args.otherUserId,
                otherUserName: widget.args.otherUserName,
                otherUserAvatar: widget.args.otherUserAvatar,
                isGroup: widget.args.isGroup,
                isSecret: widget.args.isSecret,
              ),
            ),
          ),
        );
        return;
      }

      // Scroll to bottom after sending
      _scrollToBottom();

      // ✅ آپدیت آخرین پیام برای sync تیک در لیست مکالمات
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _registerLastMessage();
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        _showErrorSnackBar('خطا در ارسال پیام');
      }
    }
  }

  void _handleAttachment() {
    HapticFeedback.lightImpact();
    ChatAttachmentSheet.show(
      context,
      onSelected: _handleAttachmentSelected,
      currentUserProfile: _currentUserProfile,
    );
  }

  Future<void> _handleAttachmentSelected(AttachmentSelection selection) async {
    if (!mounted) return;
    if (selection.files.isEmpty) return;

    final sendMode = switch (selection.type) {
      ChatAttachmentType.gallery => ChatSendMode.gallery,
      ChatAttachmentType.camera => ChatSendMode.camera,
      ChatAttachmentType.file => ChatSendMode.file,
    };

    final attachmentService = ChatAttachmentService();
    final chatRepository = ref.read(chatRepositoryProvider);
    if (_currentUserId == null) {
      _showErrorSnackBar('User id not found');
      return;
    }

    final isAlbumSend =
        sendMode == ChatSendMode.gallery && selection.files.length > 1;
    final baseCaption = selection.caption ?? '';
    final mediaGroupId = isAlbumSend ? const Uuid().v4() : null;

    String targetConvId = widget.args.conversationId;
    bool wasEmpty = targetConvId.isEmpty;

    if (wasEmpty) {
      final convResult = await _ensureConversationCreated();
      if (!convResult.isSuccess || convResult.data == null) {
        _showErrorSnackBar(convResult.error ?? 'خطا در ایجاد گفتگو');
        return;
      }
      targetConvId = convResult.data!.id;
    }

    for (var index = 0; index < selection.files.length; index++) {
      final selected = selection.files[index];
      if (!mounted) break;
      final file = selected.file;
      final messageCaption = (isAlbumSend && index > 0) ? '' : baseCaption;

      final validation = _uploadPolicyService.validateFile(
        file: file,
        profile: _currentUserProfile,
        mode: sendMode,
      );
      if (!validation.isAllowed) {
        _showErrorSnackBar(validation.error ?? 'File is not allowed');
        continue;
      }

      final attachmentType = _resolveAttachmentType(
        sendMode: sendMode,
        file: file,
        policyType: validation.attachmentType,
      );
      final localId = const Uuid().v4();
      final fileName = selected.displayFileName.trim().isNotEmpty
          ? selected.displayFileName.trim()
          : p.basename(file.path);
      final fileSizeBytes = selected.sizeBytes ?? await file.length();
      String? attachmentMimeType =
          selected.mimeType ?? _guessMimeTypeFromPath(file.path);
      int? durationSeconds;
      String? audioTitle = selected.audioTitle;
      String? audioArtist = selected.audioArtist;
      String? audioAlbum = selected.audioAlbum;

      if (attachmentType == 'audio') {
        final metadata = await _audioMetadataService.extract(
          file: file,
          displayFileName: fileName,
          mimeTypeHint: attachmentMimeType,
          sizeBytesHint: fileSizeBytes,
        );
        attachmentMimeType = metadata.mimeType ?? attachmentMimeType;
        durationSeconds = metadata.durationSeconds;
        audioTitle = audioTitle ?? metadata.title;
        audioArtist = audioArtist ?? metadata.artist;
        audioAlbum = audioAlbum ?? metadata.album;

        if (durationSeconds == null) {
          final durationResult = await _voiceService.getAudioDuration(file);
          if (durationResult.success) {
            durationSeconds = durationResult.durationInSeconds;
          }
        }
      }

      final pending = await chatRepository.createPendingMessage(
        conversationId: targetConvId,
        content: messageCaption,
        localId: localId,
        attachmentType: attachmentType,
        attachmentFileName: fileName,
        attachmentMimeType: attachmentMimeType,
        attachmentSizeBytes: fileSizeBytes,
        audioTitle: audioTitle,
        audioArtist: audioArtist,
        audioAlbum: audioAlbum,
        localFilePath: file.path,
        duration: durationSeconds,
        mediaGroupId: mediaGroupId,
      );
      if (!pending.isSuccess) {
        _showErrorSnackBar(pending.error ?? 'Failed to create pending message');
        continue;
      }
      _scrollToBottom();

      final uploadResult = await _uploadWithProgress(
        file: file,
        type: attachmentType,
        service: attachmentService,
        localMessageId: localId,
      );

      if (!uploadResult.success ||
          uploadResult.url == null ||
          uploadResult.url!.isEmpty) {
        final shortError =
            _shortUploadError(uploadResult.error, fallback: 'Upload failed');
        await chatRepository.markUploadFailed(
          localId,
          errorMessage: shortError,
        );
        if (mounted) {
          _showErrorSnackBar(shortError);
        }
        continue;
      }
      await chatRepository.updateUploadProgress(localId, 1.0);

      final result =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                id: localId,
                conversationId: targetConvId,
                content: messageCaption,
                attachmentUrl: uploadResult.url,
                attachmentType: attachmentType,
                attachmentFileName: fileName,
                attachmentMimeType: attachmentMimeType,
                attachmentSizeBytes: fileSizeBytes,
                audioTitle: audioTitle,
                audioArtist: audioArtist,
                audioAlbum: audioAlbum,
                duration: durationSeconds,
                mediaGroupId: mediaGroupId,
                recipientPublicKey:
                    widget.args.isSecret ? _otherUserProfile?.publicKey : null,
                requireEncryption: widget.args.isSecret,
              );
      if (!result.isSuccess) {
        await chatRepository.markUploadFailed(
          localId,
          errorMessage: result.error ?? 'Message send failed after upload',
        );
      } else {
        await _registerCompletedLocalUpload(
          messageId: localId,
          url: uploadResult.url!,
          localPath: file.path,
          fileName: fileName,
        );
      }
    }

    if (wasEmpty && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ModernChatScreen(
            args: ChatScreenArgs(
              conversationId: targetConvId,
              otherUserId: widget.args.otherUserId,
              otherUserName: widget.args.otherUserName,
              otherUserAvatar: widget.args.otherUserAvatar,
              isGroup: widget.args.isGroup,
              isSecret: widget.args.isSecret,
            ),
          ),
        ),
      );
    }
  }

  String _resolveAttachmentType({
    required ChatSendMode sendMode,
    required File file,
    String? policyType,
    String? existingType,
  }) {
    return _attachmentTypeResolver.resolve(
      sendMode: sendMode,
      file: file,
      policyType: policyType,
      existingType: existingType,
    );
  }

  Future<AttachmentResult> _uploadWithProgress(
      {required File file,
      required String type,
      required ChatAttachmentService service,
      required String localMessageId}) async {
    try {
      AttachmentResult result;
      final chatRepository = ref.read(chatRepositoryProvider);
      void onProgress(double progress) {
        unawaited(
            chatRepository.updateUploadProgress(localMessageId, progress));
      }

      switch (type) {
        case 'image':
          result = await service.uploadImage(
            file: file,
            conversationId: widget.args.conversationId,
            onProgress: onProgress,
          );
          break;
        case 'audio':
          result = await service.uploadAudioFile(
            audioFile: file,
            conversationId: widget.args.conversationId,
            onProgress: onProgress,
          );
          break;
        case 'voice':
          result = await service.uploadAudioFile(
            audioFile: file,
            conversationId: widget.args.conversationId,
            onProgress: onProgress,
          );
          break;
        default:
          result = await service.uploadFile(
            file: file,
            conversationId: widget.args.conversationId,
            onProgress: onProgress,
          );
          break;
      }

      return result;
    } catch (e) {
      debugPrint('Upload error: $e');
      final technical = '${e.runtimeType}: $e';
      final stage =
          RegExp(r'stage=([a-zA-Z0-9_]+)').firstMatch(technical)?.group(1);
      final code = RegExp(r'code=([A-Z0-9_]+)').firstMatch(technical)?.group(1);
      return AttachmentResult(
        success: false,
        type: _attachmentTypeFromWireType(type),
        error: _shortUploadError(e.toString(), fallback: 'Upload failed'),
        errorStage: stage,
        errorCode: code,
        technicalError: technical,
      );
    }
  }

  void _handleVoice() {
    HapticFeedback.mediumImpact();
    _showErrorSnackBar('برای ضبط صدا، دکمه میکروفون را نگه دارید');
  }

  Future<void> _retryFailedMessage(MessageModel message) async {
    if (message.isFailed != true) return;

    final hasAttachmentData =
        (message.attachmentType?.trim().isNotEmpty ?? false) ||
            (message.localFilePath?.isNotEmpty ?? false) ||
            (message.attachmentUrl?.isNotEmpty ?? false);

    if (hasAttachmentData) {
      await _retryFailedUpload(message);
      return;
    }

    final chatRepository = ref.read(chatRepositoryProvider);
    final resend =
        await ref.read(chatActionControllerProvider.notifier).sendMessage(
              id: message.id,
              conversationId: message.conversationId,
              content: message.content,
              replyToMessageId: message.replyToMessageId,
              replyToContent: message.replyToContent,
              replyToSenderName: message.replyToSenderName,
              replyToKind: _isSyntheticNoteReplyId(message.replyToMessageId)
                  ? 'note'
                  : null,
              recipientPublicKey:
                  widget.args.isSecret ? _otherUserProfile?.publicKey : null,
              requireEncryption: widget.args.isSecret,
            );

    if (!resend.isSuccess) {
      await chatRepository.markUploadFailed(
        message.id,
        errorMessage: resend.error ?? 'Message resend failed',
      );
      if (mounted) {
        _showErrorSnackBar('ارسال مجدد ناموفق بود');
      }
    }
  }

  Future<void> _retryFailedUpload(MessageModel message) async {
    final chatRepository = ref.read(chatRepositoryProvider);
    final hasCanonicalType =
        AttachmentTypeResolver.isCanonicalType(message.attachmentType);
    final existingAttachmentUrl = message.attachmentUrl?.trim();
    if (existingAttachmentUrl != null && existingAttachmentUrl.isNotEmpty) {
      await chatRepository.updateUploadProgress(message.id, 1.0);
      final preservedType = hasCanonicalType
          ? message.attachmentType
          : _attachmentTypeResolver.canonicalizeFromType(
              message.attachmentType,
            );
      final resendType = preservedType ?? 'document';
      final resend =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                id: message.id,
                conversationId: message.conversationId,
                content: message.content,
                attachmentUrl: existingAttachmentUrl,
                attachmentType: resendType,
                attachmentFileName: message.attachmentFileName,
                attachmentMimeType: message.attachmentMimeType,
                attachmentSizeBytes: message.attachmentSizeBytes,
                audioTitle: message.audioTitle,
                audioArtist: message.audioArtist,
                audioAlbum: message.audioAlbum,
                duration: message.duration,
                mediaGroupId: message.mediaGroupId,
                replyToMessageId: message.replyToMessageId,
                replyToContent: message.replyToContent,
                replyToSenderName: message.replyToSenderName,
                replyToKind: _isSyntheticNoteReplyId(message.replyToMessageId)
                    ? 'note'
                    : null,
                recipientPublicKey:
                    widget.args.isSecret ? _otherUserProfile?.publicKey : null,
                requireEncryption: widget.args.isSecret,
              );
      if (!resend.isSuccess) {
        await chatRepository.markUploadFailed(
          message.id,
          errorMessage: resend.error ?? 'Message resend failed',
        );
      } else if (message.localFilePath != null &&
          message.localFilePath!.isNotEmpty &&
          File(message.localFilePath!).existsSync()) {
        await _registerCompletedLocalUpload(
          messageId: message.id,
          url: existingAttachmentUrl,
          localPath: message.localFilePath!,
          fileName:
              message.attachmentFileName ?? p.basename(message.localFilePath!),
        );
      }
      return;
    }

    final localPath = message.localFilePath;
    if (localPath == null || localPath.isEmpty) {
      _showErrorSnackBar('Local file not found for retry');
      return;
    }

    final file = File(localPath);
    if (!await file.exists()) {
      _showErrorSnackBar('Selected file is missing on device');
      return;
    }

    final attachmentService = ChatAttachmentService();
    await chatRepository.updateUploadProgress(message.id, 0.0);

    final normalizedType = hasCanonicalType
        ? message.attachmentType!
        : _resolveAttachmentType(
            sendMode: ChatSendMode.file,
            file: file,
            existingType: message.attachmentType,
          );
    final uploadResult = await _uploadWithProgress(
      file: file,
      type: normalizedType,
      service: attachmentService,
      localMessageId: message.id,
    );

    if (!uploadResult.success ||
        uploadResult.url == null ||
        uploadResult.url!.isEmpty) {
      final shortError =
          _shortUploadError(uploadResult.error, fallback: 'Retry failed');
      await chatRepository.markUploadFailed(
        message.id,
        errorMessage: shortError,
      );
      if (mounted) {
        _showErrorSnackBar(shortError);
      }
      return;
    }

    final result = await ref
        .read(chatActionControllerProvider.notifier)
        .sendMessage(
          id: message.id,
          conversationId: message.conversationId,
          content: message.content,
          attachmentUrl: uploadResult.url,
          attachmentType: normalizedType,
          attachmentFileName:
              message.attachmentFileName ?? p.basename(file.path),
          attachmentMimeType:
              message.attachmentMimeType ?? _guessMimeTypeFromPath(file.path),
          attachmentSizeBytes:
              message.attachmentSizeBytes ?? await file.length(),
          audioTitle: message.audioTitle,
          audioArtist: message.audioArtist,
          audioAlbum: message.audioAlbum,
          duration: message.duration,
          mediaGroupId: message.mediaGroupId,
          replyToMessageId: message.replyToMessageId,
          replyToContent: message.replyToContent,
          replyToSenderName: message.replyToSenderName,
          replyToKind:
              _isSyntheticNoteReplyId(message.replyToMessageId) ? 'note' : null,
          recipientPublicKey:
              widget.args.isSecret ? _otherUserProfile?.publicKey : null,
          requireEncryption: widget.args.isSecret,
        );

    if (!result.isSuccess) {
      await chatRepository.markUploadFailed(
        message.id,
        errorMessage: result.error ?? 'Message send failed after retry',
      );
    } else {
      await _registerCompletedLocalUpload(
        messageId: message.id,
        url: uploadResult.url!,
        localPath: file.path,
        fileName: message.attachmentFileName ?? p.basename(file.path),
      );
    }
  }

  AttachmentType _attachmentTypeFromWireType(String type) {
    switch (type) {
      case 'image':
        return AttachmentType.image;
      case 'audio':
        return AttachmentType.audio;
      case 'voice':
        return AttachmentType.voice;
      default:
        return AttachmentType.file;
    }
  }

  String? _guessMimeTypeFromPath(String filePath) {
    final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      default:
        return null;
    }
  }

  Future<void> _registerCompletedLocalUpload({
    required String messageId,
    required String url,
    required String localPath,
    required String fileName,
  }) async {
    try {
      await _chatTransferManager.registerCompletedLocalUpload(
        messageId: messageId,
        url: url,
        localPath: localPath,
        fileName: fileName,
      );
    } catch (e, s) {
      logWarning(
        'registerCompletedLocalUpload failed for $messageId',
        error: e,
        stackTrace: s,
      );
    }
  }

  String _shortUploadError(String? raw, {required String fallback}) {
    if (raw == null || raw.trim().isEmpty) {
      return fallback;
    }

    var text = raw.trim();
    if (text.startsWith('Exception:')) {
      text = text.substring('Exception:'.length).trim();
    }

    // const marker = '| technical:';
    // final markerIndex = text.indexOf(marker);
    // if (markerIndex >= 0) {
    //   text = text.substring(0, markerIndex).trim();
    // }

    return text.isEmpty ? fallback : text;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 👆 MESSAGE INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Navigate to Chat Details Screen
  void _navigateToChatDetails() async {
    // اگر گروه است به صفحه جزئیات گروه برو
    if (widget.args.isGroup || widget.args.otherUserId.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ModernGroupProfileScreen(
            conversationId: widget.args.conversationId,
          ),
        ),
      );
      return;
    }

    // چت خصوصی
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => VistaChatProfileScreen(
          conversationId: widget.args.conversationId,
          otherUserId: widget.args.otherUserId,
          otherUserName: widget.args.otherUserName,
          otherUserAvatar: widget.args.otherUserAvatar,
        ),
      ),
    );

    // اگر از جستجو برگشت و messageId داشت، به آن پیام اسکرول کن
    if (result != null && mounted) {
      _scrollToMessage(result);
    }
  }

  /// Show Document Preview
  void _showDocumentPreview(MessageModel message) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentPreviewScreen(
          documentUrl: message.attachmentUrl!,
          documentName: message.attachmentFileName ?? 'document',
          documentType: message.attachmentType ?? 'file',
        ),
      ),
    );
  }

  /// Show Message Info
  void _showMessageInfo(MessageModel message) {
    if (_currentUserId == null) return;

    final reactions = _enrichReactions(_reactionNotifierFor(message.id).value);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessageInfoScreen(
          message: message,
          currentUserId: _currentUserId!,
          reactions: reactions,
        ),
      ),
    );
  }

  /// ✅ تغییر: Long Press → ورود به حالت Selection
  /// این متد دیگر استفاده نمی‌شود - onLongPress مستقیماً از ImprovedAnimatedMessageBubble صدا زده می‌شود

  /// ✅ Double Tap → Like سریع (بدون تغییر)
  void _onMessageDoubleTap(MessageModel message) {
    _onAddReaction(message, '❤️');
  }

  /// ✅ تابع جدید: نمایش Context Menu به سبک ویستا
  void _showModernContextMenu(
    BuildContext bubbleContext,
    MessageModel message, {
    List<MessageModel>? groupedMessagesOverride,
  }) async {
    // برای باز شدن منو، فقط فوکوس را آزاد می‌کنیم و از hide اجباری کیبورد اجتناب می‌کنیم.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 60));

    // چک کردن mounted بعد از delay
    if (!mounted || !bubbleContext.mounted) return;

    final groupedMessages = <MessageModel>[
      if (groupedMessagesOverride != null)
        ...groupedMessagesOverride
      else
        message,
    ];
    final groupedMap = <String, MessageModel>{};
    for (final groupedMessage in groupedMessages) {
      if (groupedMessage.id.trim().isEmpty) continue;
      groupedMap[groupedMessage.id] = groupedMessage;
    }
    final normalizedGroup =
        groupedMap.isNotEmpty ? groupedMap.values.toList() : [message];
    final groupedIds =
        normalizedGroup.map((groupedMessage) => groupedMessage.id).toList();
    final isAlbumContext = groupedIds.length > 1;

    // 2. گرفتن مختصات دقیق حباب پیام از روی Context
    final RenderBox? renderBox = bubbleContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      // fallback به BottomSheet قدیمی
      if (isAlbumContext) {
        _enterSelectionModeForMessages(groupedIds);
        return;
      }
      _showMessageOptions(message);
      return;
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final Rect messageRect =
        Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

    final theme = context.chatTheme;
    final isMe = message.senderId == _currentUserId;
    final isGif = message.attachmentType == 'gif';
    final isImage = message.attachmentType == 'image';
    final isVideo = message.attachmentType == 'video';
    final isVoice =
        message.attachmentType == 'voice' || message.attachmentType == 'audio';
    final isSharedPost = _isSharedPostMessage(message);
    final albumImageMessages = isAlbumContext
        ? normalizedGroup.where(_isAlbumImageMessage).toList(growable: false)
        : const <MessageModel>[];
    final albumHasOnlyImages =
        isAlbumContext && albumImageMessages.length == normalizedGroup.length;
    final albumItems = albumHasOnlyImages
        ? _extractAlbumMediaItems(albumImageMessages)
        : const <_AlbumMediaItem>[];
    final hasAttachmentUrl =
        (message.attachmentUrl?.trim().isNotEmpty ?? false);
    final isDocument = hasAttachmentUrl &&
        message.attachmentType != null &&
        ![
          'text',
          'gif',
          'image',
          'video',
          'voice',
          'audio',
          'location',
          'contact',
          'post',
          'shared_post',
        ].contains(message.attachmentType);

    // 2. ساخت ویجت برای نمایش در Overlay
    final previewWidget = _buildMessagePreviewWidget(message, isMe);

    // 3. مخفی کردن پیام اصلی در لیست
    _temporarilyHiddenMessages.add(message.id);
    _bumpListOverlay();

    // 4. ساخت آیتم‌های منو
    final items = <ModernContextMenuItem>[
      // ارسال مجدد (در صورت خطا)
      if (isMe &&
          message.statusNotifier.value == MessageDeliveryStatus.failed) ...[
        ModernContextMenuItem(
          icon: Icons.refresh_rounded,
          label: 'ارسال مجدد',
          color: Colors.orange,
          onTap: () {
            ref
                .read(chatActionControllerProvider.notifier)
                .resendMessage(message);
          },
        ),
        const ModernContextMenuItem.divider(),
      ],

      // Reply
      ModernContextMenuItem(
        icon: Icons.reply_rounded,
        label: 'پاسخ',
        onTap: () {
          _setReplyToMessage(message);
          _focusNode.requestFocus();
        },
      ),

      // Copy (فقط برای متن)
      if (!widget.args.isSecret &&
          !isGif &&
          !isImage &&
          !isVideo &&
          !isVoice &&
          !isSharedPost &&
          message.content.isNotEmpty)
        ModernContextMenuItem(
          icon: Icons.copy_rounded,
          label: 'کپی متن',
          onTap: () {
            Clipboard.setData(ClipboardData(text: message.content));
            _showSuccessSnackBar('متن کپی شد');
          },
        ),

      // گزینه‌های مخصوص GIF
      if (isGif && !widget.args.isSecret) ...[
        ModernContextMenuItem(
          icon: Icons.gif_box_outlined,
          label: 'ذخیره GIF',
          onTap: () => _saveGif(message),
        ),
        const ModernContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص عکس/آلبوم
      if (albumHasOnlyImages && !widget.args.isSecret) ...[
        if (albumItems.isNotEmpty)
          ModernContextMenuItem(
            icon: Icons.photo_library_outlined,
            label: 'مشاهده آلبوم',
            onTap: () => _openAlbumViewer(albumItems, 0),
          ),
        ModernContextMenuItem(
          icon: Icons.collections_rounded,
          label: 'ذخیره آلبوم',
          onTap: () => _saveImageAlbum(albumImageMessages),
        ),
        const ModernContextMenuItem.divider(),
      ] else if (isImage && !widget.args.isSecret) ...[
        ModernContextMenuItem(
          icon: Icons.download_rounded,
          label: 'ذخیره عکس',
          onTap: () => _saveImage(message),
        ),
        const ModernContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص ویدیو
      if (isVideo && !widget.args.isSecret) ...[
        ModernContextMenuItem(
          icon: Icons.download_rounded,
          label: 'ذخیره ویدیو',
          onTap: () => _saveVideo(message),
        ),
        const ModernContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص صدا
      if (isVoice && !widget.args.isSecret) ...[
        ModernContextMenuItem(
          icon: Icons.download_rounded,
          label: 'ذخیره صدا',
          onTap: () => _saveVoice(message),
        ),
        const ModernContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص فایل
      if (isDocument && !widget.args.isSecret) ...[
        ModernContextMenuItem(
          icon: Icons.download_rounded,
          label: 'دانلود فایل',
          onTap: () => _downloadFile(message),
        ),
        const ModernContextMenuItem.divider(),
      ],

      if (isSharedPost) ...[
        ModernContextMenuItem(
          icon: Icons.open_in_new_rounded,
          label: 'باز کردن پست',
          onTap: () => _showMessageDetails(message),
        ),
        const ModernContextMenuItem.divider(),
      ],

      // Forward
      if (!widget.args.isSecret)
        ModernContextMenuItem(
          icon: Icons.forward_rounded,
          label: 'فوروارد',
          onTap: () => _forwardMessagesByIds(groupedIds),
        ),

      // ✅ جزئیات پیام (گزینه جدید)
      ModernContextMenuItem(
        icon: Icons.info_outline_rounded,
        label: 'جزئیات پیام',
        onTap: () => _showMessageDetails(message),
      ),

      // Edit (فقط برای پیام‌های متنی خودم)
      if (isMe &&
          !isGif &&
          !isImage &&
          !isVideo &&
          !isVoice &&
          message.attachmentUrl == null)
        ModernContextMenuItem(
          icon: _canEditMessages ? Icons.edit_rounded : Icons.lock_outline,
          label: 'ویرایش',
          color: _canEditMessages ? null : Colors.amber,
          onTap: () {
            if (_canEditMessages) {
              _editMessage(message);
            } else {
              _showUpgradeDialog();
            }
          },
        ),

      const ModernContextMenuItem.divider(),

      // Select
      ModernContextMenuItem(
        icon: Icons.check_circle_outline_rounded,
        label: 'انتخاب چندتایی',
        onTap: () => _enterSelectionModeForMessages(groupedIds),
      ),

      // Delete
      ModernContextMenuItem(
        icon: Icons.delete_outline_rounded,
        label: 'حذف',
        color: theme.errorColor,
        onTap: () => isAlbumContext
            ? _confirmAndDeleteMessages(
                normalizedGroup,
                allMyMessagesOverride:
                    normalizedGroup.every((m) => m.senderId == _currentUserId),
              )
            : _deleteMessage(message),
      ),
    ];

    // 5. نمایش منو
    ModernContextMenu.show(
      context: context,
      messageWidget: previewWidget,
      messageRect: messageRect, // پاس دادن مختصات
      isMyMessage: isMe,
      items: items,
      // ✅ استفاده از لیست کامل ایموجی‌ها (از kDefaultReactions)
      // برای GIF، صدا و فایل ری‌اکشن نمایش داده نمی‌شود
      quickReactions: (isGif || isVoice || isDocument || isAlbumContext)
          ? null
          : kDefaultReactions,
      onReactionSelected: (emoji) => _onAddReaction(message, emoji),
      onDismiss: () {
        // 6. وقتی منو بسته شد، پیام اصلی را برگردان
        if (mounted) {
          _temporarilyHiddenMessages.remove(message.id);
          _bumpListOverlay();
        }
      },
    );
  }

  /// ✅ اصلاح شده: ساخت Widget پیام برای Preview
  /// اگر پیام پست است، کارت گرافیکی پست را نمایش می‌دهد (نه کد JSON)
}
