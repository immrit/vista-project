// ignore_for_file: invalid_use_of_protected_member, unused_element
part of 'modern_chat_screen.dart';

extension _ModernChatBubblesExt on _ModernChatScreenState {
  Widget _buildMessagePreviewWidget(MessageModel message, bool isMe) {
    // 1. اگر پیام پست است، ویجت پست را برگردان تا کارت گرافیکی دیده شود نه کد JSON
    if (_isSharedPostMessage(message)) {
      // استفاده از IgnorePointer برای اینکه دکمه‌های پست در حالت پیش‌نمایش کار نکنند
      return IgnorePointer(
        child: _buildPostMessageBubble(message, isMe),
      );
    }

    // 2. برای سایر پیام‌ها همان حباب معمولی
    return ImprovedAnimatedMessageBubble(
      recipientPublicKey:
          widget.args.isSecret ? _otherUserProfile?.publicKey : null,
      isSecretMode: widget.args.isSecret,
      onSwipeToReply: () {
        _setReplyToMessage(message);
      },
      key: ValueKey('preview_${message.id}'),
      messageId: message.id,
      content: message.displayContent,
      isMe: isMe,
      time: message.createdAt,
      status: _getMessageStatus(message),
      attachmentUrl: message.resolvedMediaUrl,
      attachmentType: message.attachmentType,
      attachmentFileName: message.attachmentFileName,
      duration: message.duration,
      replyToContent: message.replyToContent,
      replyToSenderName: message.replyToSenderName,
      replyToMessageId: message.replyToMessageId,
      onStoryReplyTap: (_) {},
      reactions:
          _convertToOldReactionFormat(_reactionNotifierFor(message.id).value),
      showReactionAvatars: widget.args.isGroup,
      // ✅ غیرفعال کردن تعاملات در Preview
      onTap: (context, message) {},
      onLongPress: (context, message) {},
      onDoubleTap: () {},
      onAddReaction: (emoji) {},
      animate: false,
      index: 0,
      isFirstInGroup: true,
      isLastInGroup: true,
      isForwarded: message.isForwarded,
      forwardedFrom: message.forwardedFromSenderName,
      message: message,
    );
  }

  /// ✅ تابع جدید: نمایش جزئیات پیام
  void _showMessageDetails(MessageModel message) {
    if (_isSharedPostMessage(message)) {
      final parsedPostData =
          message.sharedPostData ?? _extractLegacySharedPostData(message);
      final postId = parsedPostData?.postId.trim() ?? '';
      if (postId.isNotEmpty) {
        _navigateToPostScreen(postId);
      } else {
        _showErrorSnackBar('شناسه پست یافت نشد');
      }
      return;
    }

    // تشخیص نوع پیام
    final isDocument = message.attachmentType == 'document' ||
        (message.attachmentType != null &&
            ![
              'gif',
              'image',
              'video',
              'voice',
              'audio',
              'location',
              'contact',
              'post'
            ].contains(message.attachmentType));

    if (isDocument && message.attachmentUrl != null) {
      // نمایش Document Preview
      _showDocumentPreview(message);
    } else if (message.attachmentType == 'location') {
      // Location: از LocationMessageBubble باز می‌شود
      _showSuccessSnackBar('روی مکان کلیک کنید تا در نقشه باز شود');
    } else {
      // نمایش Message Info Screen
      _showMessageInfo(message);
    }
  }

  Future<void> _openStoryReply(StoryReplyData data) async {
    if (!mounted) return;

    final ownerId = data.storyOwnerId.trim().isNotEmpty
        ? data.storyOwnerId.trim()
        : widget.args.otherUserId.trim();
    if (ownerId.isEmpty) {
      _showErrorSnackBar('اطلاعات استوری ناقص است');
      return;
    }

    // نمایش لودینگ کوتاه برای جلوگیری از دوبار کلیک
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repository = ref.read(storyRepositoryProvider);

      final storyResult = await repository.getStoryById(data.storyId);
      if (!storyResult.isSuccess || storyResult.data == null) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _showErrorSnackBar('این استوری در دسترس نیست');
        }
        return;
      }

      final story = storyResult.data!;
      if (story.isExpired) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _showErrorSnackBar('این استوری منقضی شده است');
        }
        return;
      }

      List<Story> stories = [];
      final userStoriesResult = await repository.getUserStories(ownerId);
      if (userStoriesResult.isSuccess && userStoriesResult.data != null) {
        stories = userStoriesResult.data!;
      }

      if (stories.isEmpty) {
        stories = [story];
      }

      var index = stories.indexWhere((s) => s.id == story.id);
      if (index == -1) {
        stories = [story, ...stories];
        index = 0;
      }

      final storyUser =
          _buildStoryUserForReply(data, stories, ownerId: ownerId);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryPlayerScreen(
              users: [storyUser],
              initialUserIndex: 0,
              initialStoryIndex: index,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorSnackBar('خطا در باز کردن استوری');
      }
    }
  }

  StoryUser _buildStoryUserForReply(
    StoryReplyData data,
    List<Story> stories, {
    String? ownerId,
  }) {
    final resolvedOwnerId = (ownerId ?? data.storyOwnerId).trim();
    ProfileModel? profile;
    if (resolvedOwnerId == _currentUserId) {
      profile = _currentUserProfile;
    } else if (resolvedOwnerId == widget.args.otherUserId) {
      profile = _otherUserProfile;
    }

    StoryVerificationType verificationType = StoryVerificationType.none;
    if (profile != null) {
      switch (profile.verificationType) {
        case VerificationType.blueTick:
          verificationType = StoryVerificationType.blue;
          break;
        case VerificationType.goldTick:
          verificationType = StoryVerificationType.gold;
          break;
        case VerificationType.blackTick:
          verificationType = StoryVerificationType.black;
          break;
        case VerificationType.none:
          verificationType = StoryVerificationType.none;
          break;
      }
    }

    final username = data.storyOwnerUsername.isNotEmpty
        ? data.storyOwnerUsername
        : (profile?.username ?? widget.args.otherUserName);

    return StoryUser(
      id: resolvedOwnerId.isNotEmpty
          ? resolvedOwnerId
          : widget.args.otherUserId,
      username: username,
      avatarUrl: profile?.avatarUrl ??
          data.storyOwnerAvatarUrl ??
          widget.args.otherUserAvatar,
      isVerified: profile?.isVerified ?? false,
      isPremium: profile?.hasPremiumPrivileges ?? false,
      verificationType: verificationType,
      stories: stories,
      lastStoryAt:
          stories.isNotEmpty ? stories.last.createdAt : data.storyCreatedAt,
    );
  }

  void _showReactionDetailSheet(MessageModel message) {
    if (!mounted) return;
    final rawReactions =
        _convertToOldReactionFormat(_reactionNotifierFor(message.id).value);
    if (rawReactions.isEmpty) return;
    showReactionsDetailSheet(
      context: context,
      reactions: rawReactions,
      theme: context.chatTheme,
    );
  }

  void _onAddReaction(MessageModel message, String emoji) {
    if (!mounted) return;

    HapticFeedback.lightImpact();
    try {
      ref.read(chatActionControllerProvider.notifier).toggleReaction(
            messageId: message.id,
            conversationId: widget.args.conversationId,
            emoji: emoji,
          );
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
    }
  }

  void _showMessageOptions(MessageModel message) {
    final theme = context.chatTheme;
    final isMe = message.senderId == _currentUserId;
    final isGif = message.attachmentType == 'gif'; // ✅ تشخیص GIF

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ✅ Quick Reactions (برای همه پیام‌ها به جز GIF)
              if (!isGif)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['❤️', '👍', '😂', '😮', '😢', '🙏']
                        .map((emoji) => _buildQuickReaction(emoji, message))
                        .toList(),
                  ),
                ),

              if (!isGif) const Divider(),

              // ✅ گزینه‌های مخصوص GIF
              if (isGif && !widget.args.isSecret) ...[
                _buildOptionTile(
                  icon: Icons.gif_box_outlined,
                  label: 'ذخیره GIF',
                  onTap: () {
                    Navigator.pop(context);
                    _saveGif(message);
                  },
                ),
                const Divider(),
              ],

              // گزینه‌های عمومی
              _buildOptionTile(
                icon: Icons.reply_rounded,
                label: 'پاسخ',
                onTap: () {
                  Navigator.pop(context);
                  _setReplyToMessage(message);
                  _focusNode.requestFocus();
                },
              ),

              // ✅ کپی فقط برای پیام‌های متنی (نه GIF)
              if (!widget.args.isSecret && !isGif && message.content.isNotEmpty)
                _buildOptionTile(
                  icon: Icons.copy_rounded,
                  label: 'کپی',
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.content));
                    _showSuccessSnackBar('کپی شد');
                  },
                ),

              if (!widget.args.isSecret)
                _buildOptionTile(
                  icon: Icons.forward_rounded,
                  label: 'فوروارد',
                  onTap: () {
                    Navigator.pop(context);
                    _forwardMessage(message);
                  },
                ),
              _buildOptionTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'انتخاب',
                onTap: () {
                  Navigator.pop(context);
                  _enterSelectionMode(message.id);
                },
              ),

              // ویرایش فقط برای پیام‌های متنی خودم (نه GIF)
              if (isMe && !isGif && message.attachmentUrl == null)
                _buildOptionTile(
                  icon: _canEditMessages
                      ? Icons.edit_rounded
                      : Icons.lock_outline,
                  label: 'ویرایش',
                  color: _canEditMessages ? null : Colors.amber,
                  onTap: () {
                    Navigator.pop(context);
                    if (_canEditMessages) {
                      _editMessage(message);
                    } else {
                      _showUpgradeDialog();
                    }
                  },
                ),

              // حذف
              _buildOptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'حذف',
                color: theme.errorColor,
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReaction(String emoji, MessageModel message) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _onAddReaction(message, emoji);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.chatTheme.dividerColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = context.chatTheme;
    final tileColor = color ?? theme.textColor;

    return ListTile(
      leading: Icon(icon, color: tileColor),
      title: Text(
        label,
        style: TextStyle(color: tileColor),
      ),
      onTap: onTap,
    );
  }

  Future<void> _deleteMessage(MessageModel message) async {
    await _confirmAndDeleteMessages(
      [message],
      allMyMessagesOverride: message.senderId == _currentUserId,
    );
  }

  /// ویرایش پیام — حالت inline مثل Telegram X
  void _editMessage(MessageModel message) {
    if (message.isPending || message.isUploading) {
      _showErrorSnackBar('تا پایان ارسال پیام، ویرایش امکان‌پذیر نیست');
      return;
    }
    _startEditMessage(message);
  }

  /// فوروارد پیام
  Future<void> _forwardMessage(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('فوروارد در گفتگوی محرمانه غیرفعال است');
      return;
    }
    await _forwardMessagesByIds([message.id]);
  }

  Future<void> _forwardMessagesByIds(List<String> messageIds) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('فوروارد در گفتگوی محرمانه غیرفعال است');
      return;
    }
    final ids = messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return;

    final result = await ForwardMessageSheet.show(
      context,
      messageIds: ids,
    );

    if (result == true) {
      _showSuccessSnackBar(
        ids.length > 1 ? 'پیام‌ها فوروارد شدند' : 'پیام فوروارد شد',
      );
    }
  }

  /// ذخیره GIF در گالری
  Future<void> _saveGif(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک گیف یافت نشد');
      return;
    }

    try {
      // نمایش loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text('در حال دانلود...'),
              ],
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }

      // دانلود GIF
      final dio = Dio();
      final response = await dio.get(
        message.attachmentUrl!,
        options: Options(responseType: ResponseType.bytes),
      );

      // ذخیره بایت‌ها در فایل موقت
      final tempDir = await getTemporaryDirectory();
      final fileName = 'gif_${DateTime.now().millisecondsSinceEpoch}.gif';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(Uint8List.fromList(response.data));

      // ذخیره در گالری
      await Gal.putImage(tempFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSuccessSnackBar('گیف در گالری ذخیره شد');
      }
    } catch (e) {
      debugPrint('Error saving GIF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showErrorSnackBar('خطا در ذخیره گیف');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 💾 SAVE MEDIA (متدهای کمکی)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveImageAlbum(List<MessageModel> messages) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (messages.isEmpty) {
      _showErrorSnackBar('عکسی برای ذخیره یافت نشد');
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('در حال آماده‌سازی آلبوم...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    var savedCount = 0;
    var failedCount = 0;

    for (final message in messages) {
      final source = _resolveAlbumMediaSource(message);
      if (source.isEmpty) {
        failedCount++;
        continue;
      }

      try {
        final file = await _resolveImageFileForGallerySave(source);
        if (file == null) {
          failedCount++;
          continue;
        }

        await Gal.putImage(file.path);
        savedCount++;
      } catch (_) {
        failedCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (savedCount > 0) {
        _showSuccessSnackBar(
          failedCount > 0
              ? '$savedCount عکس ذخیره شد، $failedCount مورد ناموفق بود'
              : '$savedCount عکس در گالری ذخیره شد',
        );
      } else {
        _showErrorSnackBar('ذخیره آلبوم انجام نشد');
      }
    }
  }

  Future<File?> _resolveImageFileForGallerySave(String source) async {
    if (!_isNetworkMediaSource(source)) {
      final localFile = File(source);
      if (await localFile.exists()) return localFile;
      return null;
    }

    final response = await Dio().get(
      source,
      options: Options(responseType: ResponseType.bytes),
    );

    final tempDir = await getTemporaryDirectory();
    final ext = p.extension(source).replaceFirst('.', '').toLowerCase();
    final normalizedExt = ext.isEmpty ? 'jpg' : ext;
    final fileName =
        'album_${DateTime.now().microsecondsSinceEpoch}.$normalizedExt';
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(Uint8List.fromList(response.data));
    return tempFile;
  }

  /// ذخیره عکس
  Future<void> _saveImage(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک تصویر یافت نشد');
      return;
    }
    await _saveMediaToGallery(message.attachmentUrl!, 'image', 'عکس');
  }

  /// ذخیره ویدیو
  Future<void> _saveVideo(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک ویدیو یافت نشد');
      return;
    }
    await _saveMediaToGallery(message.attachmentUrl!, 'video', 'ویدیو');
  }

  /// ذخیره صدا
  Future<void> _saveVoice(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک صدا یافت نشد');
      return;
    }
    // برای صدا از downloadFile استفاده می‌کنیم
    await _downloadFile(message);
  }

  /// دانلود فایل
  Future<void> _downloadFile(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج فایل در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک فایل یافت نشد');
      return;
    }

    try {
      // نمایش loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('در حال دانلود...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // دانلود فایل
      final response = await Dio().get(
        message.attachmentUrl!,
        options: Options(responseType: ResponseType.bytes),
      );

      // ذخیره در Downloads
      final fileName = message.attachmentFileName ??
          'file_${DateTime.now().millisecondsSinceEpoch}';

      // استفاده از path_provider
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.data);

      if (mounted) {
        _showSuccessSnackBar('فایل در $filePath ذخیره شد');
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      if (mounted) {
        _showErrorSnackBar(e);
      }
    }
  }

  /// متد کمکی برای ذخیره رسانه در گالری
  Future<void> _saveMediaToGallery(
      String url, String type, String typeName) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
    try {
      // نمایش loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('در حال دانلود...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }

      // دانلود
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      // ذخیره بایت‌ها در فایل موقت
      final tempDir = await getTemporaryDirectory();
      final extension = type == 'image' ? 'jpg' : 'png';
      final fileName =
          '${type}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(Uint8List.fromList(response.data));

      // ذخیره در گالری
      await Gal.putImage(tempFile.path);

      if (mounted) {
        _showSuccessSnackBar('$typeName در گالری ذخیره شد');
      }
    } catch (e) {
      debugPrint('Error saving media: $e');
      if (mounted) {
        _showErrorSnackBar(e);
      }
    }
  }

  Widget _buildSecretSystemNoticeBubble(_SecretSystemNotice notice) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3D2F).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded,
                  color: Colors.greenAccent, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${notice.text}  ${notice.createdAt.hour.toString().padLeft(2, '0')}:${notice.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📢 SNACKBARS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showSuccessSnackBar(String message) {
    UserFriendlyErrorUtils.showSuccessSnackBar(context, message);
  }

  void _showErrorSnackBar(dynamic error) {
    UserFriendlyErrorUtils.showErrorSnackBar(context, error);
  }

  void _showInfoSnackBar(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomMargin = 80.0 + bottomInset;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: bottomMargin, left: 16, right: 16),
        content: Text(text),
        duration: const Duration(seconds: 4),
        action: action,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚫 BLOCK & REPORT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBlockedBanner(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.red.withValues(alpha: 0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.block, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            _isCurrentUserBlocked
                ? 'شما توسط ${widget.args.otherUserName} مسدود شده‌اید'
                : 'شما ${widget.args.otherUserName} را مسدود کرده‌اید',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBlockDialog() async {
    final result = await BlockReportBottomSheet.show(
      context: context,
      userId: widget.args.otherUserId,
      userName: widget.args.otherUserName,
      isCurrentlyBlocked: _isOtherUserBlocked,
      type: _isOtherUserBlocked ? ModerationType.unblock : ModerationType.block,
    );

    if (result == true) {
      await _checkBlockStatus();
    }
  }

  Future<void> _showReportDialog() async {
    final result = await BlockReportBottomSheet.show(
      context: context,
      userId: widget.args.otherUserId,
      userName: widget.args.otherUserName,
      type: ModerationType.report,
    );

    if (result == true) {
      // گزارش ارسال شد
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎭 REACTION PICKER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReactionPickerOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _reactionPickerMessageId = null;
            _reactionPickerPosition = null;
          });
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Backdrop
            Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
            // Reaction Picker
            ModernReactionPicker(
              position: _reactionPickerPosition!,
              showAbove: _reactionPickerPosition!.dy > 200,
              onReactionSelected: (emoji) async {
                if (_reactionPickerMessageId != null) {
                  await ref
                      .read(chatActionControllerProvider.notifier)
                      .toggleReaction(
                        messageId: _reactionPickerMessageId!,
                        conversationId: widget.args.conversationId,
                        emoji: emoji,
                      );
                }
                setState(() {
                  _reactionPickerMessageId = null;
                  _reactionPickerPosition = null;
                });
              },
              onClose: () {
                setState(() {
                  _reactionPickerMessageId = null;
                  _reactionPickerPosition = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 👤 PROFILE NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  void _navigateToProfile() {
    ContentNavigation.pushProfile(
      context,
      userId: widget.args.otherUserId,
      username: widget.args.otherUserName,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📱 POST MESSAGE BUBBLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// ساخت ویجت پست برای پیام‌های پست
  Widget _buildPostMessageBubble(MessageModel message, bool isMe) {
    try {
      final postData =
          message.sharedPostData ?? _extractLegacySharedPostData(message);

      if (postData == null) {
        // Fallback به پیام متنی معمولی
        return ImprovedAnimatedMessageBubble(
          recipientPublicKey:
              widget.args.isSecret ? _otherUserProfile?.publicKey : null,
          isSecretMode: widget.args.isSecret,
          onSwipeToReply: () {
            _setReplyToMessage(message);
          },
          key: ValueKey(message.id),
          messageId: message.id,
          content: message.content,
          isMe: isMe,
          time: message.createdAt,
          status: _getMessageStatus(message),
          animate: false,
          index: 0,
          isFirstInGroup: true,
          isLastInGroup: true,
          isForwarded: message.isForwarded,
          forwardedFrom: message.forwardedFromSenderName,
          onTap: (ctx, msg) => _handleMessageTap(ctx, msg),
          onLongPress: (ctx, msg) => _handleMessageLongPress(ctx, msg),
        );
      }

      // ✅ Extract اطلاعات پست از SharedPostData
      final postId = postData.postId.isNotEmpty ? postData.postId : message.id;
      final authorName = postData.postAuthorName.isNotEmpty
          ? postData.postAuthorName
          : (isMe ? 'شما' : widget.args.otherUserName);
      final authorAvatar = postData.postAuthorAvatar;
      final authorUsername = postData.postAuthorUsername;
      final postContent = postData.postContent;
      final mediaUrls = _extractSharedPostMediaUrls(message, postData);
      final likesCount = postData.likeCount;
      final commentsCount = postData.commentCount;
      final postCreatedAt = postData.postCreatedAt;
      final verificationType = postData.verificationType;
      final isVerified = postData.isVerified;
      final role = postData.role;
      final hashtags = null; // SharedPostData فعلاً hashtags ندارد
      void handlePostTap(BuildContext postContext) {
        if (_selection.isSelectionMode) {
          _toggleMessageSelection(message.id);
        } else {
          _showModernContextMenu(postContext, message);
        }
      }

      void handlePostLongPress() {
        HapticFeedback.mediumImpact();
        if (_selection.isSelectionMode) {
          _toggleMessageSelection(message.id);
        } else {
          _enterSelectionMode(message.id);
        }
      }

      // ✅ ساختار جدید برای کنترل کامل کلیک‌ها
      return Builder(
        builder: (postContext) => Stack(
          alignment: isMe
              ? AlignmentDirectional.topEnd
              : AlignmentDirectional.topStart,
          children: [
            // ویجت پست
            GestureDetector(
              // اولویت کلیک با ماست
              onTap: () => handlePostTap(postContext),
              onLongPress: handlePostLongPress,
              child: AbsorbPointer(
                // اگر در حالت انتخاب هستیم، اجازه نده دکمه‌های داخلی پست (لایک و...) کار کنند
                absorbing: _selection.isSelectionMode,
                child: SocialStylePostCard(
                  postId: postId,
                  authorName: authorName,
                  authorAvatar: authorAvatar,
                  authorUsername: authorUsername,
                  content: postContent,
                  mediaUrls: mediaUrls,
                  likesCount: likesCount,
                  commentsCount: commentsCount,
                  createdAt: postCreatedAt,
                  sentAt: message.createdAt,
                  isMine: isMe,
                  isVerified: isVerified,
                  verificationType: verificationType,
                  role: role,
                  hashtags: hashtags,
                  status: _getMessageStatus(message),
                  // callbacks داخلی را هم به همان هندلرها وصل می‌کنیم تا tap حتماً کار کند
                  onTap: () => handlePostTap(postContext),
                  onViewPost: () => _navigateToPostScreen(postId),
                  onLongPress: handlePostLongPress,
                  onShare: () async {
                    if (!_selection.isSelectionMode) {
                      final result = await ForwardMessageSheet.show(
                        context,
                        messageIds: [message.id],
                      );
                      if (result == true) {
                        _showSuccessSnackBar('پست ارسال شد');
                      }
                    }
                  },
                ),
              ),
            ),

            // ✅ لایه آبی رنگ (Selection Overlay) روی پست
            if (_selection.contains(message.id))
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.chatTheme.sendButtonColor.withValues(
                        alpha: 0.3), // کمی پررنگ تر برای دیده شدن روی عکس
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.chatTheme.sendButtonColor,
                      width: 3,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 48,
                      shadows: [Shadow(blurRadius: 5, color: Colors.black45)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error parsing post message: $e');
      // در صورت خطا، از ImprovedAnimatedMessageBubble استفاده کن
      return ImprovedAnimatedMessageBubble(
        recipientPublicKey:
            widget.args.isSecret ? _otherUserProfile?.publicKey : null,
        isSecretMode: widget.args.isSecret,
        onSwipeToReply: () {
          _setReplyToMessage(message);
        },
        key: ValueKey(message.id),
        messageId: message.id,
        content: message.content,
        isMe: isMe,
        time: message.createdAt,
        status: _getMessageStatus(message),
        animate: false,
        index: 0,
        isFirstInGroup: true,
        isLastInGroup: true,
        isForwarded: message.isForwarded,
        forwardedFrom: message.forwardedFromSenderName,
        onTap: (ctx, msg) => _handleMessageTap(ctx, msg),
        onLongPress: (ctx, msg) => _handleMessageLongPress(ctx, msg),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// اسکرول به پیام خاص
  Future<void> _scrollToLatestPinnedMessage() async {
    try {
      final actionsService = ref.read(messageActionsServiceProvider);
      final pinned = await actionsService.getPinnedMessages(
        widget.args.conversationId,
      );
      if (!mounted || pinned.isEmpty) return;
      final latest = pinned.last;
      final id = latest['message_id']?.toString() ?? latest['id']?.toString();
      _scrollToMessage(id);
    } catch (_) {}
  }

  void _scrollToMessage(String? messageId) {
    if (messageId == null) return;

    void highlight() {
      if (!mounted) return;
      setState(() => _highlightedMessageId = messageId);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _highlightedMessageId = null);
        }
      });
    }

    void ensureVisible(GlobalKey key) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
      highlight();
    }

    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      ensureVisible(key!);
      return;
    }

    final index =
        _allLatestUiMessages.indexWhere((message) => message.id == messageId);
    if (index == -1) {
      _showErrorSnackBar('پیام در دسترس نیست');
      return;
    }

    final neededCap = ChatMessageRenderWindow.capToIncludeIndex(index);
    if (neededCap > _messageRenderCapNotifier.value) {
      _messageRenderCapNotifier.value = neededCap;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final retryKey = _messageKeys[messageId];
      if (retryKey?.currentContext != null) {
        ensureVisible(retryKey!);
        return;
      }
      _showErrorSnackBar('پیام در دسترس نیست');
    });
  }

  /// متد کمکی برای تمیز شدن کد بالا
  Widget _buildBubbleContent(
    MessageModel message,
    bool isMe,
    int index,
    bool isFirstInGroup,
    bool isLastInGroup,
    AdaptiveEffectsState adaptiveEffects, {
    required ChatSelectionState selection,
    required Map<String, MessageModel> messagesById,
    List<GalleryItem>? conversationGalleryItems,
    Map<String, int>? conversationGalleryIndexByMessageId,
  }) {
    final isHighlighted = _highlightedMessageId == message.id;
    final isSelected = selection.contains(message.id);
    final bubbleEffectsLevel = adaptiveEffects.motionTokensEnabled
        ? adaptiveEffects.effectsLevel
        : ChatEffectsLevel.high;

    final shouldAnimateEntry = _suppressInitialEntryAnims
        ? false
        : switch (adaptiveEffects.chatEntryMode) {
            ChatEntryAnimationMode.off => false,
            ChatEntryAnimationMode.minimal => index < 2 && !_isNearTop,
            ChatEntryAnimationMode.full => index < 5 && !_isNearTop,
          };
    final replyPreview = _resolveReplyPreviewForMessage(message, messagesById);

    Widget buildBubble(List<reaction_models.MessageReaction> messageReactions) {
      return ImprovedAnimatedMessageBubble(
        recipientPublicKey:
            widget.args.isSecret ? _otherUserProfile?.publicKey : null,
        isSecretMode: widget.args.isSecret,
        key: _messageKeys[message.id] ??= GlobalKey(),
        messageId: message.id,
        content: message.displayContent,
        isMe: isMe,
        time: message.createdAt,
        status: _getMessageStatus(message),
        senderName: _resolveMessageSenderName(message),
        showSenderNameInBubble: false,
        compactWithAvatar: widget.args.isGroup && !isMe,
        showReactionAvatars: widget.args.isGroup,
        attachmentUrl: message.resolvedMediaUrl,
        attachmentType: message.attachmentType,
        attachmentFileName: message.attachmentFileName,
        replyToContent: replyPreview.content,
        replyToSenderName: replyPreview.senderName,
        replyToMessageId: message.replyToMessageId,
        onReplyTap: _isSyntheticNoteReplyId(message.replyToMessageId)
            ? null
            : () => _scrollToMessage(message.replyToMessageId),
        onStoryReplyTap: _openStoryReply,
        duration: message.duration,
        reactions: _convertToOldReactionFormat(messageReactions),
        onTap: (ctx, msg) => _handleMessageTap(ctx, msg),
        onLongPress: (ctx, msg) => _handleMessageLongPress(ctx, msg),
        onDoubleTap: () => _onMessageDoubleTap(message),
        onAddReaction: (emoji) => _onAddReaction(message, emoji),
        onReactionDetailTap: () => _showReactionDetailSheet(message),
        animate: shouldAnimateEntry &&
            adaptiveEffects.enableMessageEntryAnimation &&
            !adaptiveEffects.isFastScrolling,
        effectsLevel: bubbleEffectsLevel,
        index: index,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
        isForwarded: message.isForwarded,
        forwardedFrom: message.forwardedFromSenderName,
        onRetryUpload: message.isFailed == true
            ? () => _retryFailedMessage(message)
            : null,
        conversationGalleryItems: conversationGalleryItems,
        initialGalleryIndex: conversationGalleryIndexByMessageId?[message.id],
        message: message,
        isEdited: message.isEdited,
      );
    }

    final bubbleContent = _isSharedPostMessage(message)
        ? Builder(
            builder: (postContext) => _buildPostMessageBubble(message, isMe),
          )
        : adaptiveEffects.isFastScrolling
            ? buildBubble(_reactionNotifierFor(message.id).value)
            : ValueListenableBuilder<List<reaction_models.MessageReaction>>(
                valueListenable: _reactionNotifierFor(message.id),
                builder: (context, messageReactions, _) {
                  return buildBubble(messageReactions);
                },
              );

    if (!isHighlighted && !isSelected) {
      return bubbleContent;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isHighlighted
            ? context.chatTheme.sendButtonColor.withValues(alpha: 0.2)
            : context.chatTheme.sendButtonColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: bubbleContent,
    );
  }

  Widget _buildAlbumBubbleContent(
    _ChatRenderItem renderItem,
    bool isMe,
    AdaptiveEffectsState adaptiveEffects, {
    required ChatSelectionState selection,
    required bool isFirstInGroup,
    required bool isLastInGroup,
    required Map<String, MessageModel> messagesById,
    List<GalleryItem>? conversationGalleryItems,
    Map<String, int>? conversationGalleryIndexByMessageId,
  }) {
    final primaryMessage = renderItem.primaryMessage;
    final albumItems = _extractAlbumMediaItems(renderItem.messages);
    if (albumItems.length < 2) {
      return _buildBubbleContent(
        primaryMessage,
        isMe,
        renderItem.primaryIndex,
        isFirstInGroup,
        isLastInGroup,
        adaptiveEffects,
        selection: selection,
        messagesById: messagesById,
        conversationGalleryItems: conversationGalleryItems,
        conversationGalleryIndexByMessageId:
            conversationGalleryIndexByMessageId,
      );
    }

    final captionMessage = renderItem.messages.firstWhere(
      (m) => m.content.trim().isNotEmpty,
      orElse: () => primaryMessage,
    );
    final hasHighlightedMessage = _highlightedMessageId != null &&
        renderItem.messages.any((m) => m.id == _highlightedMessageId);
    final isSelected =
        selection.isSelectionMode && _isRenderItemSelected(renderItem);
    final albumKey = _messageKeys[primaryMessage.id] ??= GlobalKey();
    for (final item in renderItem.messages) {
      _messageKeys[item.id] ??= albumKey;
    }

    final bubble = _ChatMediaAlbumBubble(
      key: albumKey,
      albumItems: albumItems,
      statusMessage: primaryMessage,
      isMe: isMe,
      caption: captionMessage.content.trim().isNotEmpty
          ? captionMessage.content.trim()
          : null,
      onImageTap: (index) {
        if (_selection.isSelectionMode) {
          _toggleRenderItemSelection(renderItem);
          return;
        }
        _showModernContextMenu(
          albumKey.currentContext ?? context,
          primaryMessage,
          groupedMessagesOverride: renderItem.messages,
        );
      },
    );

    if (!hasHighlightedMessage && !isSelected) {
      return bubble;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: hasHighlightedMessage
            ? context.chatTheme.sendButtonColor.withValues(alpha: 0.2)
            : context.chatTheme.sendButtonColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: bubble,
    );
  }

  void _openAlbumViewer(
    List<_AlbumMediaItem> albumItems,
    int initialIndex, {
    List<GalleryItem>? conversationGalleryItems,
    Map<String, int>? conversationGalleryIndexByMessageId,
  }) {
    if (!mounted || albumItems.isEmpty) return;

    final albumGalleryItems = albumItems
        .map(
          (item) => GalleryItem(
            imageUrl: item.source,
            caption: item.message.content.trim().isNotEmpty
                ? item.message.content
                : null,
            heroTag: '${item.message.id}_${item.source.hashCode}',
          ),
        )
        .toList(growable: false);
    if (albumGalleryItems.isEmpty) return;

    final safeAlbumIndex = initialIndex < 0
        ? 0
        : (initialIndex >= albumGalleryItems.length
            ? albumGalleryItems.length - 1
            : initialIndex);

    final selectedMessageId = albumItems[safeAlbumIndex].message.id;
    final canUseConversationGallery = conversationGalleryItems != null &&
        conversationGalleryItems.isNotEmpty &&
        conversationGalleryIndexByMessageId != null &&
        conversationGalleryIndexByMessageId.containsKey(selectedMessageId);

    final galleryItems = canUseConversationGallery
        ? conversationGalleryItems
        : albumGalleryItems;
    final safeInitialIndex = canUseConversationGallery
        ? conversationGalleryIndexByMessageId[selectedMessageId]!
        : safeAlbumIndex;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => FullScreenImageViewer(
          galleryItems: galleryItems,
          initialIndex: safeInitialIndex,
          isSecretMode: widget.args.isSecret,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  bool _isSharedPostMessage(MessageModel message) {
    if (message.sharedPostData != null || message.isSharedPost) return true;

    final attachmentType = (message.attachmentType ?? '').toLowerCase().trim();
    if (attachmentType == 'post' || attachmentType == 'shared_post') {
      return true;
    }

    final messageType = (message.messageType ?? '').toLowerCase().trim();
    if (messageType == 'post' ||
        messageType == 'shared_post' ||
        messageType == 'sharedpost') {
      return true;
    }

    return _extractLegacySharedPostData(message) != null;
  }

  SharedPostData? _extractLegacySharedPostData(MessageModel message) {
    final raw = message.content.trim();
    if (raw.isEmpty || !raw.startsWith('{')) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);

      final postId =
          (map['postId'] ?? map['post_id'] ?? map['id'] ?? '').toString();
      if (postId.isEmpty) {
        return null;
      }

      int parseInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? 0;
      }

      bool parseBool(dynamic value) {
        if (value is bool) return value;
        final v = value?.toString().toLowerCase().trim();
        return v == 'true' || v == '1' || v == 'yes' || v == 'on';
      }

      DateTime parseDate(dynamic value) {
        if (value is DateTime) return value;
        final parsed = DateTime.tryParse(value?.toString() ?? '');
        return parsed ?? message.createdAt;
      }

      final mediaUrls = <String>[];
      final mediaRaw = map['mediaUrls'] ?? map['media_urls'];
      if (mediaRaw is List) {
        for (final item in mediaRaw) {
          final url = item?.toString().trim() ?? '';
          if (url.isNotEmpty) {
            mediaUrls.add(url);
          }
        }
      }

      final postImageUrl = (map['post_image_url'] ??
              map['postImageUrl'] ??
              (mediaUrls.isNotEmpty ? mediaUrls.first : null))
          ?.toString();

      final postVideoUrl =
          (map['post_video_url'] ?? map['postVideoUrl'])?.toString();

      return SharedPostData(
        postId: postId,
        postContent: (map['post_content'] ?? map['content'] ?? '').toString(),
        postImageUrl: (postImageUrl?.trim().isNotEmpty ?? false)
            ? postImageUrl!.trim()
            : null,
        postVideoUrl: (postVideoUrl?.trim().isNotEmpty ?? false)
            ? postVideoUrl!.trim()
            : null,
        postAuthorName:
            (map['post_author_name'] ?? map['authorName'] ?? '').toString(),
        postAuthorUsername:
            (map['post_author_username'] ?? map['authorUsername'] ?? '')
                .toString(),
        postAuthorAvatar:
            (map['post_author_avatar'] ?? map['authorAvatar'])?.toString(),
        postCreatedAt:
            parseDate(map['post_created_at'] ?? map['createdAt'] ?? ''),
        likeCount: parseInt(map['like_count'] ?? map['likesCount']),
        commentCount: parseInt(map['comment_count'] ?? map['commentsCount']),
        isVerified: parseBool(map['is_verified']),
        verificationType:
            (map['verification_type'] ?? map['verificationType'] ?? 'none')
                .toString(),
        role: map['role']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  List<String>? _extractSharedPostMediaUrls(
    MessageModel message,
    SharedPostData postData,
  ) {
    final urls = <String>{};

    final image = postData.postImageUrl?.trim() ?? '';
    if (image.isNotEmpty) {
      urls.add(image);
    }

    final video = postData.postVideoUrl?.trim() ?? '';
    if (video.isNotEmpty) {
      urls.add(video);
    }

    final raw = message.content.trim();
    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final mediaRaw = map['mediaUrls'] ?? map['media_urls'];
          if (mediaRaw is List) {
            for (final item in mediaRaw) {
              final url = item?.toString().trim() ?? '';
              if (url.isNotEmpty) {
                urls.add(url);
              }
            }
          }
        }
      } catch (_) {}
    }

    if (urls.isEmpty) return null;
    return urls.toList(growable: false);
  }

  /// Navigate to post screen
  void _navigateToPostScreen(String postId) {
    if (postId.isEmpty) {
      _showErrorSnackBar('شناسه پست یافت نشد');
      return;
    }

    ContentNavigation.pushPostDetail(context, postId: postId);
  }
}
