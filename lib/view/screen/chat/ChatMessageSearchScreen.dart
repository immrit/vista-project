import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:rxdart/rxdart.dart';
import '../../../model/message_model.dart';
import '../../../provider/chat_provider.dart';

// Provider for searching messages
final searchMessagesProvider = FutureProvider.autoDispose
    .family<List<MessageModel>, (String, String)>((ref, params) async {
  final conversationId = params.$1;
  final query = params.$2;

  // Don't search for very short queries
  if (query.trim().length < 2) {
    return [];
  }

  final chatService = ref.read(chatServiceProvider);
  return await chatService.searchMessages(conversationId, query);
});

class ChatMessageSearchScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;

  const ChatMessageSearchScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
  });

  @override
  ConsumerState<ChatMessageSearchScreen> createState() =>
      _ChatMessageSearchScreenState();
}

class _ChatMessageSearchScreenState
    extends ConsumerState<ChatMessageSearchScreen> {
  final _searchController = TextEditingController();
  final _querySubject = BehaviorSubject<String>();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _querySubject.add(_searchController.text);
    });

    _querySubject
        .debounceTime(const Duration(milliseconds: 400))
        .listen((query) {
      if (mounted) {
        setState(() {
          _query = query;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _querySubject.close();
    super.dispose();
  }

  // This Debouncer class is not defined in the provided code.
  // It should be defined or imported from a package.
  // For now, I'll define a simple one for demonstration.
  // In a real app, you might use rxdart's debounceTime directly on a StreamController or BehaviorSubject.
  // Since the original code used a Debouncer class, I'll add a minimal one here.
  // However, the fix above using BehaviorSubject and debounceTime is generally preferred.
  // If the original Debouncer class was intended to be used, it needs to be defined.
  // For the purpose of fixing the "Debouncer isn't defined" error,
  // the `_querySubject` approach is a direct replacement for the debouncing logic.
  // The `_debouncer.value = _searchController.text;` line will still cause an error
  // if `_debouncer` is not defined.
  // Given the instruction is to fix "Debouncer isn't defined", the simplest fix is to remove its usage
  // and replace it with a standard RxDart debounce pattern.
  // I'm removing the `_debouncer` field and its usage.

  String _formatDate(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    return '${jalali.year}/${jalali.month}/${jalali.day}';
  }

  // Function to highlight the search query in the text
  Widget _highlightText(String text, String query) {
    if (query.isEmpty) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final style =
        TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color);
    final highlightStyle =
        style.copyWith(backgroundColor: Colors.amber.withOpacity(0.5));

    final spans = <TextSpan>[];
    int start = 0;
    while (start < text.length) {
      final int matchIndex =
          text.toLowerCase().indexOf(query.toLowerCase(), start);
      if (matchIndex == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (matchIndex > start) {
        spans.add(
            TextSpan(text: text.substring(start, matchIndex), style: style));
      }
      spans.add(TextSpan(
          text: text.substring(matchIndex, matchIndex + query.length),
          style: highlightStyle));
      start = matchIndex + query.length;
    }
    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchResults =
        ref.watch(searchMessagesProvider((widget.conversationId, _query)));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'جستجو در پیام‌های ${widget.otherUserName}',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _searchController.clear(),
            )
        ],
      ),
      body: _query.trim().length < 2
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'حداقل ۲ حرف برای جستجو وارد کنید',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
          : searchResults.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('خطا در جستجو: $err')),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text('هیچ نتیجه‌ای برای "$_query" یافت نشد.'),
                  );
                }
                return ListView.separated(
                  itemCount: messages.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return ListTile(
                      title: _highlightText(message.content, _query),
                      subtitle: Text(_formatDate(message.createdAt)),
                      onTap: () {
                        // When a result is tapped, pop the screen and return the message ID
                        Navigator.of(context).pop(message.id);
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
