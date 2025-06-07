// ChatSettingsScreen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../provider/chat_provider.dart'; // برای دسترسی به deleteOldMessagesProvider

class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات چت'),
        elevation: 0.5,
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl, // راست‌چین کردن کل محتوای صفحه
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildStorageManagementCard(context, ref, theme),
            // در آینده می‌توانید گزینه‌های بیشتری به این صفحه اضافه کنید
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, right: 8.0),
      child: Text(
        // این متن به دلیل Directionality والد، خودکار راست‌چین می‌شود
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildStorageManagementCard(
      BuildContext context, WidgetRef ref, ThemeData theme) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // گردی بیشتر
        side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16), // پدینگ بیشتر
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.cleaning_services_outlined,
                color: theme.colorScheme.primary,
                size: 26,
              ),
            ),
            title: Text(
              'پاکسازی حافظه پنهان پیام‌ها',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'آزاد کردن فضا با پاک کردن پیام‌های قدیمی‌تر از یک ماه از حافظه دستگاه. این عمل تأثیری بر پیام‌های روی سرور ندارد.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  height: 1.4,
                ),
              ),
            ),
            onTap: () => _showDeleteOldMessagesDialog(context, ref),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: theme.hintColor.withOpacity(0.7),
            ),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 20,
            endIndent: 20,
            color: theme.dividerColor.withOpacity(0.2),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: _buildCacheInfoDisplay(context, ref, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheInfoDisplay(
      BuildContext context, WidgetRef ref, ThemeData theme) {
    final cacheSizeAsync = ref.watch(chatCacheSizeProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "فضای اشغال شده توسط کش:",
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w500),
        ),
        cacheSizeAsync.when(
          data: (size) => Text(
            size,
            style: theme.textTheme.titleSmall?.copyWith(
                color: (size == "خالی" ||
                        size.startsWith("خطا") ||
                        size == "نامشخص")
                    ? theme.hintColor.withOpacity(0.9)
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
          loading: () => SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
          ),
          error: (err, stack) {
            print("Error in chatCacheSizeProvider UI rendering: $err\n$stack");
            return Text(
              'خطای پرووایدر',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            );
          },
        ),
      ],
    );
  }

  void _showDeleteOldMessagesDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          textDirection: TextDirection.rtl, // اطمینان از راست‌چین بودن عنوان
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('تایید پاکسازی'),
          ],
        ),
        content: const Text(
          'با این کار، اطلاعات پیام‌هایی که بیش از یک ماه از زمان آن‌ها گذشته است، از حافظه پنهان (کش) این دستگاه پاک می‌شوند تا فضای ذخیره‌سازی آزاد شود.\n\nتوجه:\n• این عمل فقط اطلاعات کش شده روی این دستگاه را پاک می‌کند.\n• خودِ پیام‌ها در سرور و برای طرف مقابل دست نخورده باقی می‌مانند.\n• این عمل برای آزاد کردن فضا مفید است و قابل بازگشت نیست (برای اطلاعات کش شده).\n\nآیا ادامه می‌دهید؟',
          textDirection: TextDirection.rtl, // راست‌چین کردن متن محتوا
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('پاکسازی',
                style: TextStyle(color: Colors.red.shade700)), // تغییر متن دکمه
          ),
        ],
      ),
    );

    if (confirm == true) {
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
      try {
        // نمایش یک لودینگ موقت
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              textDirection: TextDirection.rtl, // راست‌چین کردن محتوای SnackBar
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 16),
                Text('در حال پاکسازی حافظه پنهان...'),
              ],
            ),
            duration: Duration(seconds: 3), // مدت زمان مناسب
          ),
        );
        await ref.read(deleteOldMessagesProvider(oneMonthAgo).future);
        // بستن اسنک‌بار لودینگ و نمایش پیام موفقیت
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Directionality(
              // راست‌چین کردن متن SnackBar
              textDirection: TextDirection.rtl,
              child: Text('حافظه پنهان پیام‌های قدیمی با موفقیت پاکسازی شد.'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              // راست‌چین کردن متن SnackBar
              textDirection: TextDirection.rtl,
              child: Text('خطا در پاکسازی حافظه پنهان: $e'),
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      } finally {
        // پس از اتمام عملیات (موفق یا ناموفق)، حجم کش را رفرش کن
        if (context.mounted) {
          ref.refresh(chatCacheSizeProvider);
        }
      }
    }
  }
}
