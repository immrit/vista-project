import 'package:flutter/material.dart';
import '../model/UserModel.dart';
import '../model/publicPostModel.dart';
import '../utils/premium_features_helper.dart';

class PostEditButton extends StatelessWidget {
  final UserModel currentUser;
  final PublicPostModel post;
  final VoidCallback onEdit;

  const PostEditButton({
    super.key,
    required this.currentUser,
    required this.post,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // فقط برای پست‌های خود کاربر نمایش داده شود
    if (!PremiumFeaturesHelper.shouldShowEditButton(currentUser.id, post)) {
      return const SizedBox.shrink();
    }

    final bool hasAccess = PremiumFeaturesHelper.canEditPost(currentUser);

    return InkWell(
      onTap: () {
        if (hasAccess) {
          onEdit();
        } else {
          PremiumFeaturesHelper.showPremiumPromptDialog(
            context,
            feature: 'ویرایش پست',
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasAccess 
              ? Colors.blue.shade50 
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasAccess 
                ? Colors.blue.shade200 
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAccess ? Icons.edit : Icons.lock_outline,
              size: 18,
              color: hasAccess 
                  ? Colors.blue.shade700 
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              'ویرایش',
              style: TextStyle(
                fontSize: 14,
                color: hasAccess 
                    ? Colors.blue.shade700 
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!hasAccess) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.workspace_premium,
                size: 16,
                color: Colors.amber.shade600,
              ),
            ],
          ],
        ),
      ),
    );
  }
}














