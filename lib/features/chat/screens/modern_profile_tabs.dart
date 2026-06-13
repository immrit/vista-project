part of 'modern_profile_screen.dart';

extension ModernProfileTabsExt on _VistaChatProfileScreenState {
  Widget _buildMediaSection(bool isDark) {
    final cardColor = isDark ? _darkCard : Colors.white;
    final tabColor = isDark ? Colors.white70 : Colors.grey[700];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // تب‌بار
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: _primaryColor,
            unselectedLabelColor: tabColor,
            indicatorColor: _primaryColor,
            indicatorWeight: 2,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            tabs: const [
              Tab(text: 'پست‌ها'),
              Tab(text: 'رسانه'),
              Tab(text: 'فایل‌ها'),
              Tab(text: 'لینک‌ها'),
              Tab(text: 'صدا'),
              Tab(text: 'GIF'),
              Tab(text: 'گروه‌ها'),
            ],
          ),

          // محتوای تب‌ها
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(isDark),
                _buildMediaTab(isDark),
                _buildFilesTab(isDark),
                _buildLinksTab(isDark),
                _buildVoiceTab(isDark),
                _buildGifsTab(isDark),
                _buildGroupsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final sharedPosts =
            messages.where(_isSharedPostMessage).toList(growable: false);
        if (sharedPosts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.article_outlined,
            text: 'هیچ پستی یافت نشد',
            isDark: isDark,
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                _resolvePostsCrossAxisCount(constraints.maxWidth);

            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: constraints.maxWidth >= 760 ? 0.9 : 0.82,
              ),
              itemCount: sharedPosts.length,
              itemBuilder: (context, index) => _buildSharedPostGridTile(
                _buildSharedPostGridItemData(sharedPosts[index]),
                isDark,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        text: 'خطا در بارگذاری پست‌ها',
        isDark: isDark,
      ),
    );
  }

  /// تب رسانه (تصاویر و ویدیوها)
  Widget _buildMediaTab(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final mediaMessages = messages
            .where((m) =>
                (m.attachmentType == 'image' || m.attachmentType == 'video') &&
                m.attachmentUrl != null)
            .toList();

        if (mediaMessages.isEmpty) {
          return _buildEmptyState(
            icon: Icons.photo_library_outlined,
            text: 'هیچ رسانه‌ای یافت نشد',
            isDark: isDark,
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: mediaMessages.length,
          itemBuilder: (context, index) {
            final message = mediaMessages[index];
            return _buildMediaGridItem(message, index, mediaMessages, isDark);
          },
        );
      },
      loading: () => _buildMediaGridShimmer(),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        text: 'خطا در بارگذاری رسانه‌ها',
        isDark: isDark,
      ),
    );
  }

  int _resolvePostsCrossAxisCount(double width) {
    if (width >= 980) return 4;
    if (width >= 700) return 3;
    return 2;
  }

  bool _isVisualSharedPost(_SharedPostKind kind) {
    return kind == _SharedPostKind.image || kind == _SharedPostKind.video;
  }

  Widget _buildSharedPostGridTile(_SharedPostGridItemData post, bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF2A3646) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSharedPostById(post.postId),
        child: _isVisualSharedPost(post.kind)
            ? _buildSharedPostMediaThumbnailTile(post, isDark)
            : _buildSharedPostTextCardTile(post, isDark),
      ),
    );
  }

  Widget _buildSharedPostMediaThumbnailTile(
      _SharedPostGridItemData post, bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildSharedPostGridPreview(post, isDark),
        Positioned(
          top: 8,
          left: 8,
          child: _buildSharedPostTypeChip(post.kind, true),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDate(post.createdAt),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedPostTextCardTile(
      _SharedPostGridItemData post, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white70 : Colors.black54;
    final quoteBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.author.isNotEmpty ? post.author : 'پست اشتراک‌گذاری‌شده',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSharedPostTypeChip(post.kind, isDark),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: quoteBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                post.preview,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: subtleColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(post.createdAt),
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedPostGridPreview(
      _SharedPostGridItemData post, bool isDark) {
    final fallbackColor =
        isDark ? const Color(0xFF334155) : Colors.blueGrey[50]!;
    final iconColor = isDark ? Colors.white70 : const Color(0xFF546E7A);

    if (post.kind == _SharedPostKind.image ||
        post.kind == _SharedPostKind.video) {
      final mediaUrl = post.kind == _SharedPostKind.video
          ? (post.imageUrl ?? post.videoUrl)
          : post.imageUrl;
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: mediaUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => ColoredBox(color: fallbackColor),
              errorWidget: (_, __, ___) =>
                  Icon(Icons.image_not_supported_outlined, color: iconColor),
            ),
            if (post.kind == _SharedPostKind.video)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.58)
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
          ],
        );
      }
    }

    final bool isMusic = post.kind == _SharedPostKind.music;
    final colors = isMusic
        ? <Color>[
            const Color(0xFF0EA5E9),
            const Color(0xFF2563EB),
          ]
        : <Color>[
            const Color(0xFFFB7185),
            const Color(0xFFF59E0B),
          ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isMusic ? Icons.music_note_rounded : Icons.subject_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const Spacer(),
          Text(
            isMusic ? 'پست موزیک' : 'پست متنی',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedPostTypeChip(_SharedPostKind kind, bool isDark) {
    final icon = _sharedPostTypeIcon(kind);
    final label = _sharedPostTypeLabel(kind);

    final bg = isDark
        ? Colors.white.withValues(alpha: 0.11)
        : _primaryColor.withValues(alpha: 0.08);
    final fg = isDark ? Colors.white70 : _primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _sharedPostTypeIcon(_SharedPostKind kind) {
    switch (kind) {
      case _SharedPostKind.text:
        return Icons.subject_rounded;
      case _SharedPostKind.image:
        return Icons.image_outlined;
      case _SharedPostKind.video:
        return Icons.videocam_outlined;
      case _SharedPostKind.music:
        return Icons.music_note_outlined;
    }
  }

  String _sharedPostTypeLabel(_SharedPostKind kind) {
    switch (kind) {
      case _SharedPostKind.text:
        return 'متن';
      case _SharedPostKind.image:
        return 'عکس';
      case _SharedPostKind.video:
        return 'ویدیو';
      case _SharedPostKind.music:
        return 'موزیک';
    }
  }

  _SharedPostGridItemData _buildSharedPostGridItemData(MessageModel message) {
    final parsedMap = _decodeSharedPostMap(message);
    final model = message.sharedPostData;

    final postId = _firstNonEmpty([
          model?.postId,
          parsedMap?['postId'],
          parsedMap?['post_id'],
          parsedMap?['id'],
        ]) ??
        '';

    final author = _firstNonEmpty([
          model?.postAuthorName,
          parsedMap?['authorName'],
          parsedMap?['postAuthorName'],
          parsedMap?['post_author_name'],
          parsedMap?['full_name'],
          parsedMap?['username'],
        ]) ??
        '';

    final preview = _firstNonEmpty([
          model?.postContent,
          parsedMap?['content'],
          parsedMap?['post_content'],
          parsedMap?['caption'],
          parsedMap?['text'],
        ]) ??
        'برای مشاهده پست لمس کنید';

    final mediaUrls = _extractMediaUrls(parsedMap);
    final imageUrl = _firstNonEmpty([
      model?.postImageUrl,
      parsedMap?['image_url'],
      parsedMap?['post_image_url'],
      parsedMap?['imageUrl'],
      _firstMatching(mediaUrls, _looksLikeImageUrl),
    ]);
    final videoUrl = _firstNonEmpty([
      model?.postVideoUrl,
      parsedMap?['video_url'],
      parsedMap?['post_video_url'],
      parsedMap?['videoUrl'],
      _firstMatching(mediaUrls, _looksLikeVideoUrl),
    ]);
    final musicUrl = _firstNonEmpty([
      parsedMap?['music_url'],
      parsedMap?['post_music_url'],
      parsedMap?['musicUrl'],
      parsedMap?['audio_url'],
      parsedMap?['audioUrl'],
      parsedMap?['song_url'],
      parsedMap?['track_url'],
      _firstMatching(mediaUrls, _looksLikeAudioUrl),
    ]);

    final kind = videoUrl != null
        ? _SharedPostKind.video
        : imageUrl != null
            ? _SharedPostKind.image
            : musicUrl != null
                ? _SharedPostKind.music
                : _SharedPostKind.text;

    return _SharedPostGridItemData(
      postId: postId,
      author: author,
      preview: preview,
      createdAt: message.createdAt,
      kind: kind,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      musicUrl: musicUrl,
    );
  }

  Map<String, dynamic>? _decodeSharedPostMap(MessageModel message) {
    final content = message.content.trim();
    if (!content.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  List<String> _extractMediaUrls(Map<String, dynamic>? map) {
    if (map == null) return const [];
    final raw = map['mediaUrls'] ?? map['media_urls'];
    if (raw is! List) return const [];

    final urls = <String>[];
    for (final item in raw) {
      final normalized = _normalizeUrlValue(item);
      if (normalized != null) {
        urls.add(normalized);
      }
    }
    return urls;
  }

  String? _firstMatching(List<String> items, bool Function(String value) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  String? _firstNonEmpty(Iterable<dynamic> candidates) {
    for (final candidate in candidates) {
      final normalized = _normalizeUrlValue(candidate, allowAnyText: true);
      if (normalized != null) return normalized;
    }
    return null;
  }

  String? _normalizeUrlValue(dynamic value, {bool allowAnyText = false}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    if (allowAnyText) return text;
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }
    return null;
  }

  bool _looksLikeImageUrl(String url) {
    final normalized = url.toLowerCase();
    return normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.png') ||
        normalized.endsWith('.webp') ||
        normalized.endsWith('.gif') ||
        normalized.endsWith('.heic');
  }

  bool _looksLikeVideoUrl(String url) {
    final normalized = url.toLowerCase();
    return normalized.endsWith('.mp4') ||
        normalized.endsWith('.mov') ||
        normalized.endsWith('.mkv') ||
        normalized.endsWith('.webm') ||
        normalized.endsWith('.m4v');
  }

  bool _looksLikeAudioUrl(String url) {
    final normalized = url.toLowerCase();
    return normalized.endsWith('.mp3') ||
        normalized.endsWith('.wav') ||
        normalized.endsWith('.ogg') ||
        normalized.endsWith('.aac') ||
        normalized.endsWith('.m4a') ||
        normalized.endsWith('.flac');
  }

  bool _isSharedPostMessage(MessageModel message) {
    if (message.sharedPostData != null || message.isSharedPost) return true;

    final attachmentType = (message.attachmentType ?? '').toLowerCase();
    if (attachmentType == 'post' || attachmentType == 'shared_post') {
      return true;
    }

    final content = message.content.trim();
    if (!content.startsWith('{')) return false;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        return map['postId'] != null || map['post_id'] != null;
      }
    } catch (_) {}
    return false;
  }

  void _openSharedPostById(String postId) {
    if (postId.isEmpty) {
      _showSnackBar('شناسه پست یافت نشد', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsPage(postId: postId),
      ),
    );
  }

  /// آیتم گرید رسانه
  Widget _buildMediaGridItem(
    MessageModel message,
    int index,
    List<MessageModel> mediaMessages,
    bool isDark,
  ) {
    final isVideo = message.attachmentType == 'video';

    return GestureDetector(
      onTap: () => _showMediaViewer(message, index, mediaMessages),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: message.attachmentUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: Icon(
                Icons.broken_image,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ),
          ),
          if (isVideo)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// تب فایل‌ها
  Widget _buildFilesTab(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final fileMessages = messages
            .where((m) => m.attachmentType == 'file' && m.attachmentUrl != null)
            .toList();

        if (fileMessages.isEmpty) {
          return _buildEmptyState(
            icon: Icons.folder_outlined,
            text: 'هیچ فایلی یافت نشد',
            isDark: isDark,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: fileMessages.length,
          itemBuilder: (context, index) {
            final file = fileMessages[index];
            return _buildFileItem(file, isDark);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        text: 'خطا در بارگذاری فایل‌ها',
        isDark: isDark,
      ),
    );
  }

  /// آیتم فایل
  Widget _buildFileItem(MessageModel file, bool isDark) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.insert_drive_file, color: _primaryColor),
      ),
      title: Text(
        file.attachmentFileName ?? 'فایل',
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatDate(file.createdAt),
        style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey[600], fontSize: 12),
      ),
      trailing: IconButton(
        icon: Icon(Icons.download_outlined,
            color: isDark ? Colors.white60 : Colors.grey[600]),
        onPressed: () {
          _downloadFile(file);
        },
      ),
    );
  }

  /// تب لینک‌ها
  /// تب لینک‌ها
  Widget _buildLinksTab(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final linkEntries = <_MessageLinkEntry>[];
        for (final message in messages) {
          if (_isSharedPostMessage(message)) continue;
          final content = message.content.trim();
          if (content.isEmpty) continue;
          final urls = _extractUrlsFromText(content);
          for (final url in urls) {
            if (_isSharedPostLink(url)) continue;
            linkEntries.add(_MessageLinkEntry(message: message, url: url));
          }
        }

        if (linkEntries.isEmpty) {
          return _buildEmptyState(
            icon: Icons.link_off_outlined,
            text: 'هیچ لینکی یافت نشد',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: linkEntries.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 72,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          itemBuilder: (context, index) {
            final entry = linkEntries[index];
            final msg = entry.message;
            final url = entry.url;
            final description = _removeUrlFromText(msg.content, url);

            return ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.public, color: _primaryColor),
              ),
              title: Text(
                url,
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                description.isEmpty ? 'بدون توضیحات' : description,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _formatDate(msg.createdAt),
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey,
                  fontSize: 10,
                ),
              ),
              onTap: () => _launchExternalUrl(url),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        text: 'خطا در بارگذاری لینک‌ها',
        isDark: isDark,
      ),
    );
  }

  List<String> _extractUrlsFromText(String text) {
    final urlRegex = RegExp(
      r'((https?:\/\/|www\.)[^\s<>()]+|(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s<>()]*)?)',
      caseSensitive: false,
    );

    final unique = <String>{};
    final urls = <String>[];

    for (final match in urlRegex.allMatches(text)) {
      var url = match.group(0)?.trim() ?? '';
      if (url.isEmpty) continue;
      url = url.replaceAll(RegExp(r'[)\],.!?;:]+$'), '');
      if (url.isEmpty) continue;
      if (unique.add(url)) {
        urls.add(url);
      }
    }

    return urls;
  }

  String _removeUrlFromText(String text, String url) {
    final normalizedUrl = RegExp.escape(url);
    final withoutUrl = text.replaceAll(RegExp(normalizedUrl), '').trim();
    return withoutUrl;
  }

  bool _isSharedPostLink(String url) {
    final normalized = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final fullPath = uri.path.toLowerCase();
    final firstSegment =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.first.toLowerCase() : '';
    final hasPostPath = firstSegment == 'post' ||
        firstSegment == 'posts' ||
        firstSegment == 'p' ||
        fullPath.contains('/post/') ||
        fullPath.contains('/posts/');
    final hasPostQuery = uri.queryParameters.containsKey('postId') ||
        uri.queryParameters.containsKey('post_id');
    final vistaPostScheme =
        uri.scheme.toLowerCase() == 'vista' && firstSegment == 'post';
    final isVistaHost = host.contains('vista');

    return vistaPostScheme || (isVistaHost && (hasPostPath || hasPostQuery));
  }

  Future<void> _launchExternalUrl(String url) async {
    final normalized = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      _showSnackBar('لینک معتبر نیست', isError: true);
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        _showSnackBar('امکان باز کردن لینک وجود ندارد', isError: true);
      }
    } catch (_) {
      _showSnackBar('خطا در باز کردن لینک', isError: true);
    }
  }

  /// تب صدا
  Widget _buildVoiceTab(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final voiceMessages = messages
            .where(
                (m) => m.attachmentType == 'voice' && m.attachmentUrl != null)
            .toList();

        if (voiceMessages.isEmpty) {
          return _buildEmptyState(
            icon: Icons.mic_none_outlined,
            text: 'هیچ پیام صوتی یافت نشد',
            isDark: isDark,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: voiceMessages.length,
          itemBuilder: (context, index) {
            final voice = voiceMessages[index];
            return _buildVoiceItem(voice, isDark);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        text: 'خطا در بارگذاری',
        isDark: isDark,
      ),
    );
  }

  /// آیتم پیام صوتی
  Widget _buildVoiceItem(MessageModel voice, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];
    final url = voice.audioUrl ?? voice.attachmentUrl;

    if (url == null) return const SizedBox();

    return StreamBuilder<VoicePlayerState>(
      stream: VoicePlayerService().playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.isPlaying ?? false;
        final isCurrentVoice = state?.voiceId == voice.id;
        final isLoading = state?.isLoading ?? false;

        return ListTile(
          leading: GestureDetector(
            onTap: () {
              VoicePlayerService().playOrPause(voice.id, url);
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: isLoading && isCurrentVoice
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      (isCurrentVoice && isPlaying)
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: _primaryColor,
                    ),
            ),
          ),
          title: Text(
            'پیام صوتی',
            style: TextStyle(color: textColor),
          ),
          subtitle: Text(
            _formatDate(voice.createdAt),
            style: TextStyle(color: subtitleColor, fontSize: 12),
          ),
        );
      },
    );
  }

  /// تب GIF‌ها
  Widget _buildGifsTab(bool isDark) {
    return _buildEmptyState(
      icon: Icons.gif_box_outlined,
      text: 'هیچ GIF یافت نشد',
      isDark: isDark,
    );
  }

  /// تب گروه‌ها
  Widget _buildGroupsTab(bool isDark) {
    return _buildEmptyState(
      icon: Icons.group_outlined,
      text: 'گروه مشترکی یافت نشد',
      isDark: isDark,
    );
  }

  /// وضعیت خالی
  Widget _buildEmptyState({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// نوار عنوان شناور
}
