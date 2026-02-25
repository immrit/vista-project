import 'package:flutter/material.dart';
import '../model/UserModel.dart';
import '../model/publicPostModel.dart';

class PremiumFeaturesHelper {
  /// بررسی دسترسی به ویرایش پست
  static bool canEditPost(UserModel currentUser) {
    return currentUser.hasGoldBadge || currentUser.hasBlueBadge;
  }

  /// بررسی دسترسی به استوری ۴۸ ساعته
  static bool canPostLongDurationStory(UserModel currentUser) {
    return currentUser.hasGoldBadge || currentUser.hasBlueBadge;
  }

  /// نمایش دیالوگ ترغیب به خرید تیک طلایی (طراحی مشابه ویستا)
  static void showPremiumPromptDialog(
    BuildContext context, {
    String feature = 'استوری ۴۸ ساعته',
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2A2A2A), // Dark grey
                Color(0xFF1F1F1F), // Darker grey
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Image/Icon Section (Mocking the visual style)
              Stack(
                alignment: Alignment.center,
                children: [
                  // Background glow
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8774E1).withOpacity(0.2),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                  ),
                  // Premium Icon (Star/Check)
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB66DFF), Color(0xFF8774E1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8774E1).withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  // Close Button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'الماس ویستا',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Vazir',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'با دریافت الماس ویستا، به قابلیت‌های ویژه‌ای مثل $feature و تیک طلایی دسترسی پیدا کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.5,
                        fontFamily: 'Vazir',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Feature List (Simplified)
                    _buildFeatureItem(Icons.timelapse, 'استوری‌های ۴۸ ساعته'),
                    const SizedBox(height: 12),
                    _buildFeatureItem(Icons.verified, 'نشان تایید طلایی'),
                    const SizedBox(height: 12),
                    _buildFeatureItem(Icons.edit_note, 'ویرایش نامحدود پست'),

                    const SizedBox(height: 24),

                    // Subscribe Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/verification-store');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8774E1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'دریافت اشتراک الماس',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Vazir',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF8774E1).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF8774E1), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontFamily: 'Vazir',
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

