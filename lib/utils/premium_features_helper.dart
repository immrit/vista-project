import 'package:flutter/material.dart';
import '../model/UserModel.dart';
import '../model/publicPostModel.dart';

class PremiumFeaturesHelper {
  /// بررسی دسترسی به ویرایش پست
  static bool canEditPost(UserModel currentUser) {
    return currentUser.hasGoldBadge || currentUser.hasBlueBadge;
  }

  /// نمایش دیالوگ ترغیب به خرید تیک طلایی
  static void showPremiumPromptDialog(
    BuildContext context, {
    String feature = 'ویرایش پست',
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.amber.shade50,
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // آیکون تیک طلایی با انیمیشن
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade400,
                      Colors.amber.shade700,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              // عنوان
              const Text(
                'قابلیت ویژه ویستا پریمیوم',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // توضیحات
              Text(
                'برای دسترسی به $feature، نیاز به تیک طلایی یا آبی دارید.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // مزایای پریمیوم
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(Icons.edit, 'ویرایش نامحدود پست‌ها'),
                    const SizedBox(height: 8),
                    _buildFeatureRow(Icons.verified, 'دریافت تیک طلایی'),
                    const SizedBox(height: 8),
                    _buildFeatureRow(Icons.star, 'دسترسی به قابلیت‌های ویژه'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // دکمه‌ها
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'بعداً',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // هدایت به صفحه ویستا پریمیوم در تنظیمات
                        Navigator.pushNamed(context, '/verification-store');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'دریافت تیک طلایی',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.amber.shade700),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  /// بررسی مالکیت پست
  static bool isPostOwner(String currentUserId, PublicPostModel post) {
    return currentUserId == post.userId;
  }

  /// بررسی امکان نمایش دکمه ویرایش
  static bool shouldShowEditButton(
    String currentUserId,
    PublicPostModel post,
  ) {
    return isPostOwner(currentUserId, post);
  }
}


