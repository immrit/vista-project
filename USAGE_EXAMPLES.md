# نمونه‌های استفاده از سیستم حذف پیام بهینه‌شده 📚

## مثال 1: حذف یک پیام (بسیط)

```dart
// در ChatScreen یا هر جای دیگر

onDelete: (messageId) async {
  try {
    // استفاده از Provider
    await ref
        .read(chatScreenProvider(params).notifier)
        .deleteMessage(messageId, forEveryone: false);
    
    // نمایش پیام موفقیت
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('پیام حذف شد')),
    );
  } catch (e) {
    // نمایش پیام خطا
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطا: $e'), backgroundColor: Colors.red),
    );
  }
}
```

## مثال 2: حذف برای همه کاربران

```dart
// تنها صاحب پیام می‌تواند این کار را انجام دهد

onDeleteForEveryone: (messageId) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('حذف برای همه'),
      content: Text('این پیام برای تمام کاربران حذف خواهد شد'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('انصراف'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('حذف', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  ) ?? false;

  if (confirm) {
    try {
      await ref
          .read(chatScreenProvider(params).notifier)
          .deleteMessage(messageId, forEveryone: true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('پیام برای همه حذف شد')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## مثال 3: حذف چندین پیام (Multi-select)

```dart
// Select mode: انتخاب چندین پیام

final selectedMessages = <String>[];

// حذف تمام انتخاب‌شده‌ها
onDeleteSelected: () async {
  if (selectedMessages.isEmpty) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('حذف پیام‌ها'),
      content: Text('${selectedMessages.length} پیام حذف خواهد شد'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('انصراف'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('حذف', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  ) ?? false;

  if (confirm) {
    try {
      await ref
          .read(chatScreenProvider(params).notifier)
          .deleteMultipleMessages(selectedMessages, forEveryone: false);
      
      setState(() => selectedMessages.clear());
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedMessages.length} پیام حذف شد'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## مثال 4: پاک‌سازی تمام پیام‌های مکالمه

```dart
// Clear All Messages

onClearConversation: () async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('پاک‌سازی تمام پیام‌ها'),
      content: Text('تمام پیام‌های این مکالمه برای همیشه حذف خواهند شد'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('انصراف'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('پاک کن', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  ) ?? false;

  if (confirm) {
    // نمایش loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // شروع پاک‌سازی (بدون منتظر ماندن)
      ref.read(chatScreenProvider(params).notifier).clearAllMessages();

      // بسته‌شدن loading indicator
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمام پیام‌ها حذف می‌شوند...'),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## مثال 5: نمایش وضعیت حذف

```dart
// نمایش progress برای حذف‌های دسته‌ای

class DeletionStatusWidget extends ConsumerWidget {
  final String conversationId;

  const DeletionStatusWidget({
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletionService = OptimizedMessageDeletionService();

    return StreamBuilder<Map<String, SyncStatus>>(
      stream: deletionService.deletionStatusStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox.shrink();
        }

        final statusMap = snapshot.data!;
        final pendingCount = statusMap.values
            .where((s) => s == SyncStatus.pending)
            .length;
        final syncingCount = statusMap.values
            .where((s) => s == SyncStatus.syncing)
            .length;
        final syncedCount = statusMap.values
            .where((s) => s == SyncStatus.synced)
            .length;
        final failedCount = statusMap.values
            .where((s) => s == SyncStatus.failed)
            .length;

        return Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syncingCount > 0)
                LinearProgressIndicator(
                  value: syncedCount / (syncedCount + syncingCount + pendingCount),
                ),
              if (pendingCount > 0)
                Text('$pendingCount پیام منتظر حذف...',
                    style: TextStyle(fontSize: 12, color: Colors.orange)),
              if (failedCount > 0)
                Text('$failedCount پیام ناموفق',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
            ],
          ),
        );
      },
    );
  }
}
```

## مثال 6: مدیریت مموری

```dart
// استفاده از MemoryCleanupService

// در App initialization:
Future<void> initializeApp() async {
  // Initialize cleanup service
  final cleanupService = MemoryCleanupService();
  await cleanupService.initialize();

  // اگر لازم باشد دستی پاک کنید
  // await cleanupService.performCleanup();
}

// دریافت وضعیت مموری:
Future<void> checkMemoryStatus() async {
  final cleanupService = MemoryCleanupService();
  final status = await cleanupService.getMemoryStatus();

  print('Conversations: ${status['conversationCount']}');
  print('Total Messages: ${status['totalMessages']}');
}

// پاک‌سازی مکالمه خاص:
onClearConversationCache: (conversationId) async {
  final cleanupService = MemoryCleanupService();
  await cleanupService.cleanupConversation(conversationId);
}

// پاک‌سازی تمام کش (Logout):
onLogout: () async {
  final cleanupService = MemoryCleanupService();
  await cleanupService.clearAllCache();
  // سپس logout عملیات را ادامه دهید
}
```

## مثال 7: استفاده مستقیم از سرویس

```dart
// اگر بدون Provider استفاده کنید

final deletionService = OptimizedMessageDeletionService();

// حذف یک پیام
await deletionService.deleteMessage(
  messageId: 'msg_123',
  conversationId: 'conv_456',
  mode: DeletionMode.me,
  optimisticDelete: true,
);

// حذف دسته‌ای
await deletionService.deleteMultipleMessages(
  conversationId: 'conv_456',
  messageIds: ['msg_1', 'msg_2', 'msg_3', 'msg_4', 'msg_5'],
  mode: DeletionMode.me,
);

// دریافت تعداد حذف‌های معلق
final pendingCount = deletionService.pendingDeletionCount;
print('Pending deletions: $pendingCount');

// ردیابی وضعیت
deletionService.deletionStatusStream.listen((statusMap) {
  for (final entry in statusMap.entries) {
    print('${entry.key}: ${entry.value.name}');
  }
});

// Cleanup
deletionService.dispose();
```

## مثال 8: Error Handling

```dart
// مدیریت خطاهای سفارشی

Future<void> deleteWithCustomHandling(String messageId) async {
  try {
    await ref
        .read(chatScreenProvider(params).notifier)
        .deleteMessage(messageId, forEveryone: false);
  } on TimeoutException {
    // خطای timeout
    showErrorDialog('زمان درخواست پایان یافت');
  } on SocketException {
    // خطای اتصال
    showErrorDialog('اتصال اینترنت قطع است');
  } on FormatException {
    // خطای داده
    showErrorDialog('داده‌های نامعتبر دریافت شد');
  } catch (e) {
    // خطای عمومی
    showErrorDialog('خطای نامشخص: $e');
  }
}
```

## مثال 9: Animation

```dart
// نمایش animation برای حذف

class DeletionAnimationWidget extends StatefulWidget {
  final String messageId;
  final VoidCallback onDelete;

  const DeletionAnimationWidget({
    required this.messageId,
    required this.onDelete,
  });

  @override
  State<DeletionAnimationWidget> createState() =>
      _DeletionAnimationWidgetState();
}

class _DeletionAnimationWidgetState extends State<DeletionAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void triggerDeletion() {
    _controller.forward().then((_) {
      widget.onDelete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: FadeTransition(
        opacity: _animation,
        child: Container(
          // Message UI
        ),
      ),
    );
  }
}
```

## مثال 10: Batch Delete with Progress

```dart
// حذف دسته‌ای با نمایش Progress

Future<void> deleteBatchWithProgress(List<String> messageIds) async {
  int completed = 0;
  final total = messageIds.length;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future.microtask(() async {
          try {
            await ref
                .read(chatScreenProvider(params).notifier)
                .deleteMultipleMessages(
                  messageIds,
                  forEveryone: false,
                );
            completed = total;
            setState(() {});
          } catch (e) {
            Navigator.pop(context);
            showErrorSnackBar('خطا: $e');
          }
        });

        return AlertDialog(
          title: Text('حذف پیام‌ها'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: total > 0 ? completed / total : 0,
              ),
              SizedBox(height: 16),
              Text('$completed / $total'),
            ],
          ),
          actions: [
            if (completed == total)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('بستن'),
              ),
          ],
        );
      },
    ),
  );
}
```

---

## نکات عملی

### ✅ نکات مهم

1. **همیشه await کنید** - حذف‌ها async هستند
2. **Error handling** - لازم است try-catch استفاده شود
3. **UI Feedback** - کاربر باید بفهمد چه اتفاقی می‌افتد
4. **Confirmation** - برای حذف‌های مهم تایید بگیرید

### ⚠️ احتیاط

- حذف‌ها ممکن است تأخیر داشته باشند (deferring)
- Network issues می‌توانند موجب شکست شوند
- Cleanup خودکار ممکن است پیام‌های قدیم را حذف کند

---

## خلاصه

استفاده از سیستم جدید حذف پیام‌ها:

- ✅ سریع‌تر
- ✅ کارآمد‌تر
- ✅ ایمن‌تر
- ✅ بهتر مدیریت شده
