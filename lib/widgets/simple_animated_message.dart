import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/message_model.dart';
import '../services/instant_message_deletion.dart';

/// نسخه ساده‌شده برای استفاده آسان انیمیشن حذف
class SimpleAnimatedMessage extends ConsumerWidget {
  final MessageModel message;
  final Widget child;
  final VoidCallback? onDeleted;

  const SimpleAnimatedMessage({
    super.key,
    required this.message,
    required this.child,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _showDeleteMenu(context, ref),
      child: child,
    );
  }

  void _showDeleteMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'حذف پیام',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // گزینه حذف با انیمیشن
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.purple),
              title: const Text('حذف با انیمیشن پودر شدن'),
              subtitle: const Text('انیمیشن زیبای محو شدن'),
              onTap: () {
                Navigator.pop(context);
                _deleteWithAnimation(ref);
              },
            ),
            
            // گزینه حذف بدون انیمیشن
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('حذف فوری'),
              subtitle: const Text('بدون انیمیشن'),
              onTap: () {
                Navigator.pop(context);
                _deleteWithoutAnimation(ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// حذف با انیمیشن
  void _deleteWithAnimation(WidgetRef ref) async {
    try {
      await ref.deleteMessageInstantly(
        message.id,
        message.conversationId,
        enableAnimation: true,
        onSuccess: () {
          onDeleted?.call();
          debugPrint('✅ پیام با انیمیشن حذف شد!');
        },
        onError: () {
          debugPrint('❌ خطا در حذف پیام');
        },
      );
    } catch (e) {
      debugPrint('خطا در حذف انیمیشنی: $e');
    }
  }

  /// حذف بدون انیمیشن
  void _deleteWithoutAnimation(WidgetRef ref) async {
    try {
      await ref.deleteMessageInstantly(
        message.id,
        message.conversationId,
        enableAnimation: false,
        onSuccess: () {
          onDeleted?.call();
          debugPrint('✅ پیام فوراً حذف شد!');
        },
        onError: () {
          debugPrint('❌ خطا در حذف پیام');
        },
      );
    } catch (e) {
      debugPrint('خطا در حذف فوری: $e');
    }
  }
}

/// مثال خیلی ساده
class QuickAnimationDemo extends StatelessWidget {
  const QuickAnimationDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('انیمیشن پودر شدن')),
      body: ProviderScope(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '🎬 روی پیام‌ها long press کنید',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  final message = MessageModel.temporary(
                    tempId: 'demo_$index',
                    conversationId: 'demo',
                    senderId: 'user',
                    content: 'پیام شماره ${index + 1} - من رو حذف کن! 🎭',
                  );

                  return SimpleAnimatedMessage(
                    message: message,
                    onDeleted: () => print('پیام $index حذف شد'),
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(message.content),
                        subtitle: const Text('Long press برای حذف'),
                        leading: const Icon(Icons.message),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
