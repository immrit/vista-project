import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/publicPostModel.dart';
import '../data/go_posts_repository.dart';

/// Screen where a user objects to (or justifies) content that Vista moderation
/// removed or edited. Reached by tapping the moderation notification
/// (deeplink `vista://appeal/<postId>?type=removed|edit`) or the appeal button
/// on the post moderation banner.
class AppealScreen extends ConsumerStatefulWidget {
  const AppealScreen({
    super.key,
    required this.postId,
    this.type = 'edit',
  });

  /// Post that was moderated.
  final String postId;

  /// `removed` (post deleted/archived) or `edit` (content edited by Vista).
  final String type;

  @override
  ConsumerState<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends ConsumerState<AppealScreen> {
  final _repo = GoPostsRepository();
  final _controller = TextEditingController();

  PublicPostModel? _post;
  bool _loadingPost = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _loadError;

  bool get _isRemoved => widget.type == 'removed';

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    try {
      final post = await _repo.getPost(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _loadingPost = false;
      });
    } catch (_) {
      // Removed posts may no longer be fetchable — appeal still allowed.
      if (!mounted) return;
      setState(() {
        _loadingPost = false;
        _loadError = 'محتوای اصلی در دسترس نیست';
      });
    }
  }

  Future<void> _submit() async {
    final reason = _controller.text.trim();
    if (reason.length < 10) {
      _snack('توضیح اعتراض باید حداقل ۱۰ کاراکتر باشد', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await _repo.appealPost(postId: widget.postId, reason: reason);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final status = e.response?.statusCode;
      if (status == 409) {
        _snack('اعتراض قبلی شما هنوز در حال بررسی است', error: true);
        setState(() => _submitted = true);
      } else if (status == 404) {
        _snack('پست مشمول اعتراض یافت نشد', error: true);
      } else {
        _snack('خطا در ثبت اعتراض. دوباره تلاش کنید', error: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('خطا در ثبت اعتراض. دوباره تلاش کنید', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ثبت اعتراض'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _submitted
            ? _buildSuccess(theme)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildContextCard(theme, isDark),
                    const SizedBox(height: 20),
                    Text(
                      _isRemoved
                          ? 'چرا فکر می‌کنید حذف این پست نادرست بوده است؟'
                          : 'چرا فکر می‌کنید ویرایش این پست نادرست بوده است؟',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      maxLines: 6,
                      maxLength: 2000,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText:
                            'توضیح دهید که چرا محتوای شما با قوانین Vista مغایرت نداشته یا توجیه خود را بنویسید...',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.gavel_rounded, size: 20),
                      label: Text(_submitting ? 'در حال ارسال...' : 'ارسال اعتراض'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'اعتراض شما توسط تیم Vista بررسی می‌شود. در صورت تأیید، محتوای حذف‌شده بازگردانده خواهد شد.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildContextCard(ThemeData theme, bool isDark) {
    final reason = _post?.moderationReason?.trim();
    final amberBg = isDark
        ? Colors.amber.withValues(alpha: 0.12)
        : Colors.amber.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: amberBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isRemoved ? Icons.delete_outline : Icons.edit_note_rounded,
            color: isDark ? Colors.amber[300] : Colors.amber[900],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRemoved
                      ? 'پست شما توسط تیم Vista حذف شد'
                      : 'پست شما توسط تیم Vista ویرایش شد',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.amber[100] : Colors.amber[950],
                  ),
                ),
                if (_loadingPost) ...[
                  const SizedBox(height: 6),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ] else if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'دلیل: $reason',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark
                          ? Colors.amber[100]?.withValues(alpha: 0.9)
                          : Colors.amber[900]?.withValues(alpha: 0.9),
                    ),
                  ),
                ] else if (_loadError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _loadError!,
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 72, color: Colors.green.shade400),
            const SizedBox(height: 16),
            Text(
              'اعتراض شما ثبت شد',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'تیم Vista اعتراض شما را بررسی و نتیجه را به شما اطلاع می‌دهد.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('بازگشت'),
            ),
          ],
        ),
      ),
    );
  }
}
