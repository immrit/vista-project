import 'package:flutter/material.dart';
import '../../../model/publicPostModel.dart';
import '../../../services/current_user_service.dart';

class PostModerationBanner extends StatelessWidget {
  final PublicPostModel post;

  const PostModerationBanner({super.key, required this.post});

  bool get _isModerated => post.editedByVista;

  bool get _isOwner =>
      CurrentUserService.cachedUserId != null &&
      CurrentUserService.cachedUserId == post.userId;

  @override
  Widget build(BuildContext context) {
    if (!_isModerated) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reason = post.moderationReason?.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: isDark ? Colors.amber[300] : Colors.amber[900],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'این پست توسط تیم Vista ویرایش شده است',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.amber[100] : Colors.amber[950],
                    height: 1.35,
                  ),
                ),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: isDark
                          ? Colors.amber[100]?.withValues(alpha: 0.85)
                          : Colors.amber[900]?.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                if (_isOwner) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed(
                        '/appeal',
                        arguments: {'postId': post.id, 'type': 'edit'},
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor:
                            isDark ? Colors.amber[200] : Colors.amber[900],
                      ),
                      icon: const Icon(Icons.gavel_rounded, size: 16),
                      label: const Text(
                        'ثبت اعتراض',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
