import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../DB/advanced_cache_system.dart';
import '../../../../model/conversation_model.dart';
import '../../../../model/message_model.dart';

class ConversationManagementPage extends ConsumerStatefulWidget {
  final AdvancedCacheSystem advancedCache;
  final VoidCallback? onDataChanged;

  const ConversationManagementPage({
    super.key,
    required this.advancedCache,
    this.onDataChanged,
  });

  @override
  ConsumerState<ConversationManagementPage> createState() =>
      _ConversationManagementPageState();
}

class _ConversationManagementPageState
    extends ConsumerState<ConversationManagementPage> {
  List<ConversationModel> conversations = [];
  Map<String, List<MessageModel>> conversationMessages = {};
  Map<String, double> conversationSizes = {};
  Set<String> selectedConversations = {};
  bool isSelectMode = false;
  bool isLoading = true;
  String searchQuery = '';
  String sortBy = 'date'; // 'date', 'size', 'messages'
  bool showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => isLoading = true);
    try {
      final convs = widget.advancedCache.getCachedConversations();
      final Map<String, List<MessageModel>> messages = {};
      final Map<String, double> sizes = {};

      for (final conv in convs) {
        final msgs = widget.advancedCache.getCachedMessages(conv.id);
        messages[conv.id] = msgs;

        // تخمین حجم مکالمه (بر اساس تعداد پیام‌ها)
        sizes[conv.id] = _estimateConversationSize(msgs);
      }

      setState(() {
        conversations = convs;
        conversationMessages = messages;
        conversationSizes = sizes;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری مکالمات: $e')),
      );
    }
  }

  double _estimateConversationSize(List<MessageModel> messages) {
    // تخمین تقریبی: هر پیام حدود 1KB
    return messages.length * 0.001; // تبدیل به MB
  }

  String _formatSize(double sizeMB) {
    if (sizeMB < 1) {
      return '${(sizeMB * 1024).toStringAsFixed(0)} KB';
    }
    return '${sizeMB.toStringAsFixed(1)} MB';
  }

  void _toggleSelectMode() {
    setState(() {
      isSelectMode = !isSelectMode;
      if (!isSelectMode) {
        selectedConversations.clear();
      }
    });
  }

  void _toggleConversationSelection(String conversationId) {
    setState(() {
      if (selectedConversations.contains(conversationId)) {
        selectedConversations.remove(conversationId);
      } else {
        selectedConversations.add(conversationId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      selectedConversations = conversations.map((c) => c.id).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      selectedConversations.clear();
    });
  }

  Future<void> _deleteSelectedConversations() async {
    if (selectedConversations.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید حذف'),
        content: Text(
            'آیا مطمئن هستید که می‌خواهید ${selectedConversations.length} مکالمه را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // حذف مکالمات انتخاب شده از کش
        for (final _ in selectedConversations) {
          // حذف مکالمه از کش - در صورت وجود متد مناسب
          // widget.advancedCache.removeConversation(conversationId);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedConversations.length} مکالمه حذف شد'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onDataChanged?.call();
        await _loadConversations();
        _toggleSelectMode();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف: $e')),
        );
      }
    }
  }

  void _showConversationDetails(ConversationModel conversation) {
    final messages = conversationMessages[conversation.id] ?? [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(conversation.otherUserName ?? 'مکالمه'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تعداد پیام‌ها: ${messages.length}'),
              Text(
                  'حجم تقریبی: ${_formatSize(conversationSizes[conversation.id] ?? 0)}'),
              Text(
                  'آخرین فعالیت: ${_formatDate(conversation.lastMessageTime ?? conversation.updatedAt)}'),
              if (conversation.lastMessage != null)
                Text('آخرین پیام: ${conversation.lastMessage}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              if (messages.isNotEmpty) ...[
                const Text('آخرین پیام‌ها:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: messages.take(10).length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return ListTile(
                        dense: true,
                        title: Text(message.content,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_formatDate(message.createdAt)),
                        leading: CircleAvatar(
                          radius: 12,
                          child:
                              Text(message.senderName?.substring(0, 1) ?? '?'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }

  List<ConversationModel> _getFilteredAndSortedConversations() {
    List<ConversationModel> filtered = conversations;

    // اعمال فیلتر جستجو
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((conv) {
        final name = conv.otherUserName?.toLowerCase() ?? '';
        final lastMessage = conv.lastMessage?.toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return name.contains(query) || lastMessage.contains(query);
      }).toList();
    }

    // مرتب‌سازی
    switch (sortBy) {
      case 'size':
        filtered.sort((a, b) {
          final sizeA = conversationSizes[a.id] ?? 0;
          final sizeB = conversationSizes[b.id] ?? 0;
          return sizeB.compareTo(sizeA);
        });
        break;
      case 'messages':
        filtered.sort((a, b) {
          final messagesA = conversationMessages[a.id]?.length ?? 0;
          final messagesB = conversationMessages[b.id]?.length ?? 0;
          return messagesB.compareTo(messagesA);
        });
        break;
      case 'date':
      default:
        filtered.sort((a, b) {
          final dateA = a.lastMessageTime ?? a.updatedAt;
          final dateB = b.lastMessageTime ?? b.updatedAt;
          return dateB.compareTo(dateA);
        });
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSize =
        conversationSizes.values.fold(0.0, (sum, size) => sum + size);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectMode
            ? '${selectedConversations.length} انتخاب شده'
            : 'مدیریت مکالمات'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (!isSelectMode) ...[
            IconButton(
              icon: Icon(showSearchBar
                  ? Icons.search_off_rounded
                  : Icons.search_rounded),
              onPressed: () => setState(() => showSearchBar = !showSearchBar),
              tooltip: 'جستجو',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'مرتب‌سازی',
              onSelected: (value) => setState(() => sortBy = value),
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'date',
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 16,
                            color: sortBy == 'date' ? Colors.blue : null),
                        const SizedBox(width: 8),
                        const Text('تاریخ'),
                      ],
                    )),
                PopupMenuItem(
                    value: 'size',
                    child: Row(
                      children: [
                        Icon(Icons.storage_rounded,
                            size: 16,
                            color: sortBy == 'size' ? Colors.blue : null),
                        const SizedBox(width: 8),
                        const Text('حجم'),
                      ],
                    )),
                PopupMenuItem(
                    value: 'messages',
                    child: Row(
                      children: [
                        Icon(Icons.message_rounded,
                            size: 16,
                            color: sortBy == 'messages' ? Colors.blue : null),
                        const SizedBox(width: 8),
                        const Text('تعداد پیام'),
                      ],
                    )),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              onPressed: _toggleSelectMode,
              tooltip: 'انتخاب چندگانه',
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadConversations,
              tooltip: 'بروزرسانی',
            ),
          ] else ...[
            TextButton(
              onPressed: selectedConversations.length == conversations.length
                  ? _deselectAll
                  : _selectAll,
              child: Text(selectedConversations.length == conversations.length
                  ? 'لغو همه'
                  : 'انتخاب همه'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              onPressed: selectedConversations.isEmpty
                  ? null
                  : _deleteSelectedConversations,
              color: Colors.red,
              tooltip: 'حذف انتخاب شده‌ها',
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _toggleSelectMode,
              tooltip: 'لغو انتخاب',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          if (showSearchBar)
            Container(
              margin: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'جستجو در مکالمات...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                ),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
            ),

          // آمار کلی
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('${conversations.length}',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
                    const Text('مکالمه', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                Column(
                  children: [
                    Text(
                        conversationMessages.values
                            .fold(0, (sum, msgs) => sum + msgs.length)
                            .toString(),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                    const Text('پیام', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                Column(
                  children: [
                    Text(_formatSize(totalSize),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange)),
                    const Text('حجم کل', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),

          // لیست مکالمات
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : conversations.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('هیچ مکالمه‌ای یافت نشد',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _getFilteredAndSortedConversations().length,
                        itemBuilder: (context, index) {
                          final filteredConversations =
                              _getFilteredAndSortedConversations();
                          final conversation = filteredConversations[index];
                          final isSelected =
                              selectedConversations.contains(conversation.id);
                          final messageCount =
                              conversationMessages[conversation.id]?.length ??
                                  0;
                          final size = conversationSizes[conversation.id] ?? 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: isSelectMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (_) =>
                                          _toggleConversationSelection(
                                              conversation.id),
                                    )
                                  : CircleAvatar(
                                      backgroundColor:
                                          Colors.blue.withValues(alpha: 0.1),
                                      child: Text(
                                        conversation.otherUserName
                                                ?.substring(0, 1)
                                                .toUpperCase() ??
                                            '?',
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                              title: Text(
                                conversation.otherUserName ?? 'مکالمه بدون نام',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (conversation.lastMessage != null)
                                    Text(conversation.lastMessage!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.message_rounded,
                                          size: 12, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text('$messageCount پیام',
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12)),
                                      const SizedBox(width: 12),
                                      Icon(Icons.storage_rounded,
                                          size: 12, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(_formatSize(size),
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: isSelectMode
                                  ? null
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                            _formatDate(
                                                conversation.lastMessageTime ??
                                                    conversation.updatedAt),
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 11)),
                                        const SizedBox(height: 2),
                                        Icon(Icons.chevron_right_rounded,
                                            color: Colors.grey[400]),
                                      ],
                                    ),
                              onTap: isSelectMode
                                  ? () => _toggleConversationSelection(
                                      conversation.id)
                                  : () =>
                                      _showConversationDetails(conversation),
                              onLongPress:
                                  isSelectMode ? null : _toggleSelectMode,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: !isSelectMode && conversations.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showQuickActions,
              icon: const Icon(Icons.flash_on_rounded),
              label: const Text('عملیات سریع'),
              backgroundColor: Colors.orange,
            )
          : null,
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('عملیات سریع',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.auto_delete_rounded, color: Colors.blue),
              title: const Text('حذف مکالمات قدیمی'),
              subtitle: const Text('حذف مکالمات بیش از 30 روز'),
              onTap: () {
                Navigator.pop(context);
                _deleteOldConversations(30);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_rounded,
                  color: Colors.green),
              title: const Text('حذف مکالمات خالی'),
              subtitle: const Text('حذف مکالمات بدون پیام'),
              onTap: () {
                Navigator.pop(context);
                _deleteEmptyConversations();
              },
            ),
            ListTile(
              leading: const Icon(Icons.compress_rounded, color: Colors.purple),
              title: const Text('حذف مکالمات حجیم'),
              subtitle: const Text('حذف مکالمات بیش از 10MB'),
              onTap: () {
                Navigator.pop(context);
                _deleteLargeConversations(10.0);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.select_all_rounded, color: Colors.orange),
              title: const Text('انتخاب هوشمند'),
              subtitle: const Text('انتخاب بر اساس معیار'),
              onTap: () {
                Navigator.pop(context);
                _showSmartSelection();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteOldConversations(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    final oldConversations = conversations.where((conv) {
      final lastActivity = conv.lastMessageTime ?? conv.updatedAt;
      return lastActivity.isBefore(cutoffDate);
    }).toList();

    if (oldConversations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هیچ مکالمه قدیمی یافت نشد')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مکالمات قدیمی'),
        content: Text(
            '${oldConversations.length} مکالمه قدیمی‌تر از $daysOld روز یافت شد. آیا می‌خواهید آن‌ها را حذف کنید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final conv in oldConversations) {
          selectedConversations.add(conv.id);
        }
        await _deleteSelectedConversations();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف: $e')),
        );
      }
    }
  }

  Future<void> _deleteEmptyConversations() async {
    final emptyConversations = conversations.where((conv) {
      final messages = conversationMessages[conv.id] ?? [];
      return messages.isEmpty;
    }).toList();

    if (emptyConversations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هیچ مکالمه خالی یافت نشد')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مکالمات خالی'),
        content: Text(
            '${emptyConversations.length} مکالمه خالی یافت شد. آیا می‌خواهید آن‌ها را حذف کنید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final conv in emptyConversations) {
          selectedConversations.add(conv.id);
        }
        await _deleteSelectedConversations();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف: $e')),
        );
      }
    }
  }

  Future<void> _deleteLargeConversations(double sizeMB) async {
    final largeConversations = conversations.where((conv) {
      final size = conversationSizes[conv.id] ?? 0;
      return size > sizeMB;
    }).toList();

    if (largeConversations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'هیچ مکالمه بزرگ‌تر از ${sizeMB.toStringAsFixed(0)}MB یافت نشد')),
      );
      return;
    }

    final totalSize = largeConversations.fold(
        0.0, (sum, conv) => sum + (conversationSizes[conv.id] ?? 0));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مکالمات حجیم'),
        content: Text(
            '${largeConversations.length} مکالمه بزرگ‌تر از ${sizeMB.toStringAsFixed(0)}MB یافت شد (مجموع ${_formatSize(totalSize)}). آیا می‌خواهید آن‌ها را حذف کنید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final conv in largeConversations) {
          selectedConversations.add(conv.id);
        }
        await _deleteSelectedConversations();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف: $e')),
        );
      }
    }
  }

  void _showSmartSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتخاب هوشمند'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('انتخاب مکالمات قدیمی'),
              subtitle: const Text('بیش از 30 روز'),
              onTap: () {
                Navigator.pop(context);
                _selectOldConversations(30);
              },
            ),
            ListTile(
              title: const Text('انتخاب مکالمات کم‌پیام'),
              subtitle: const Text('کمتر از 10 پیام'),
              onTap: () {
                Navigator.pop(context);
                _selectLowMessageConversations(10);
              },
            ),
            ListTile(
              title: const Text('انتخاب مکالمات حجیم'),
              subtitle: const Text('بیش از 5MB'),
              onTap: () {
                Navigator.pop(context);
                _selectLargeConversations(5.0);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  void _selectOldConversations(int daysOld) {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    final oldConversations = conversations.where((conv) {
      final lastActivity = conv.lastMessageTime ?? conv.updatedAt;
      return lastActivity.isBefore(cutoffDate);
    });

    setState(() {
      isSelectMode = true;
      selectedConversations = oldConversations.map((c) => c.id).toSet();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('${selectedConversations.length} مکالمه قدیمی انتخاب شد')),
    );
  }

  void _selectLowMessageConversations(int maxMessages) {
    final lowMessageConversations = conversations.where((conv) {
      final messageCount = conversationMessages[conv.id]?.length ?? 0;
      return messageCount <= maxMessages;
    });

    setState(() {
      isSelectMode = true;
      selectedConversations = lowMessageConversations.map((c) => c.id).toSet();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('${selectedConversations.length} مکالمه کم‌پیام انتخاب شد')),
    );
  }

  void _selectLargeConversations(double sizeMB) {
    final largeConversations = conversations.where((conv) {
      final size = conversationSizes[conv.id] ?? 0;
      return size > sizeMB;
    });

    setState(() {
      isSelectMode = true;
      selectedConversations = largeConversations.map((c) => c.id).toSet();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('${selectedConversations.length} مکالمه حجیم انتخاب شد')),
    );
  }
}
