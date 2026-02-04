import 'package:Vista/features/chat/screens/ChatConversationsScreen.dart'
    show ChatConversationsScreen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import 'package:Vista/provider/profile_completion_provider.dart';
import 'package:Vista/utils/const.dart';
import 'package:Vista/features/posts/screens/AddPost.dart';
import 'package:Vista/features/posts/screens/profileScreen.dart';
import 'package:Vista/features/posts/screens/ExploreFeedScreen.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import 'package:Vista/provider/chat_provider.dart';
import 'package:Vista/provider/optimized_conversations_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/auth/widgets/otp_dialog.dart';
import '../../../provider/provider.dart';

// ✅ Provider تعداد مکالمه‌های خوانده‌نشده
final unreadConversationsCountProvider = Provider<int>((ref) {
  return ref.watch(totalUnreadCountProvider);
});

/// مسیر آیکون‌های Premium برای Bottom Navigation
class _NavIcons {
  static const String basePath = 'lib/utils/images/bottomnavigation';

  static const String homeActive = '$basePath/home.png';
  static const String homeInactive = '$basePath/home-outline.png';

  static const String search = '$basePath/magnifying-glass.png';

  static const String add = '$basePath/plus.png';

  static const String chatActive = '$basePath/email.png';
  static const String chatInactive = '$basePath/email-outline.png';

  static const String profileActive = '$basePath/user.png';
  static const String profileInactive = '$basePath/user-outline.png';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastPressed;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _checkProfileCompletion();
    _checkPhoneVerification();

    final currentUser = supabase.auth.currentUser;
    final userId = currentUser?.id ?? '';
    final username = currentUser?.userMetadata?['username'] ??
        currentUser?.userMetadata?['full_name'] ??
        'کاربر';

    _tabs = [
      const ExploreFeedScreen(),
      const SearchPage(),
      const AddPublicPostScreen(),
      const ChatConversationsScreen(),
      ProfileScreen(
        userId: userId,
        username: username,
      ),
    ];
  }

  void _checkProfileCompletion() {
    Future.microtask(() async {
      try {
        final isComplete = await ref
            .read(profileCompletionProvider.notifier)
            .checkProfileCompletion()
            .timeout(const Duration(seconds: 2), onTimeout: () => true);
        if (!isComplete && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushNamed(context, '/editeProfile');
          }
        }
      } catch (e) {
        // Ignore errors
      }
    });
  }

  void _checkPhoneVerification() async {
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastSkipped =
            prefs.getInt('last_phone_verification_skipped_time');

        if (lastSkipped != null) {
          final lastSkippedTime =
              DateTime.fromMillisecondsSinceEpoch(lastSkipped);
          final diff = DateTime.now().difference(lastSkippedTime);
          if (diff.inMinutes < 15) {
            return;
          }
        }

        final user = supabase.auth.currentUser;
        if (user == null) return;

        final profile = await supabase
            .from('profiles')
            .select('phone')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          final phone = profile['phone'] as String?;
          if (phone == null || phone.isEmpty) {
            if (mounted) {
              await Future.delayed(const Duration(seconds: 1));
              _showPhoneVerificationDialog();
            }
          }
        }
      } catch (e) {
        // Ignore errors
      }
    });
  }

  void _showPhoneVerificationDialog() {
    if (!mounted) return;

    final phoneController = TextEditingController();
    bool isLoading = false;
    String? errorText;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'تایید شماره موبایل',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'برای ادامه فعالیت و امنیت بیشتر حساب کاربری، لطفاً شماره موبایل خود را تایید کنید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'شماره موبایل (مثال: 0912...)',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      errorText: errorText,
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('last_phone_verification_skipped_time',
                        DateTime.now().millisecondsSinceEpoch);
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'بعداً یادآوری کن',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final phone = phoneController.text.trim();
                          if (phone.isEmpty ||
                              !RegExp(r'^\+?[0-9]{10,13}$').hasMatch(phone)) {
                            setDialogState(() {
                              errorText = 'شماره موبایل نامعتبر است';
                            });
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            errorText = null;
                          });

                          try {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .sendOtp(phone);

                            if (!mounted) return;
                            setDialogState(() {
                              isLoading = false;
                            });

                            Navigator.of(dialogContext).pop();

                            final verified =
                                await showOtpDialog(context, ref, phone);
                            if (verified) {
                              try {
                                await supabase.from('profiles').update({
                                  'phone': phone,
                                }).eq('id', supabase.auth.currentUser!.id);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'شماره موبایل با موفقیت تایید شد')),
                                );
                              } catch (e) {
                                // Ignore update errors
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() {
                                isLoading = false;
                                errorText = 'خطا در ارسال پیامک: $e';
                              });
                            }
                          }
                        },
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        )
                      : const Text('ارسال کد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AddPublicPostScreen()),
      );
    } else {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return false;
    } else {
      final now = DateTime.now();
      if (_lastPressed == null ||
          now.difference(_lastPressed!) > const Duration(seconds: 2)) {
        _lastPressed = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('برای خروج دوباره دکمه بازگشت را بزنید'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(globalChatNotificationProvider);
    final unreadCount = ref.watch(unreadConversationsCountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: IndexedStack(index: _selectedIndex, children: _tabs),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[900]! : Colors.grey[200]!,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Home
                  _buildPremiumNavItem(
                    index: 0,
                    activeIcon: _NavIcons.homeActive,
                    inactiveIcon: _NavIcons.homeInactive,
                    isDark: isDark,
                  ),
                  // Search
                  _buildPremiumNavItem(
                    index: 1,
                    activeIcon: _NavIcons.search,
                    inactiveIcon: _NavIcons.search,
                    isDark: isDark,
                  ),
                  // Add (Center Button)
                  _buildPremiumAddButton(isDark),
                  // Chat with Badge
                  _buildPremiumNavItemWithBadge(
                    index: 3,
                    activeIcon: _NavIcons.chatActive,
                    inactiveIcon: _NavIcons.chatInactive,
                    badgeCount: unreadCount,
                    isDark: isDark,
                  ),
                  // Profile
                  _buildPremiumNavItem(
                    index: 4,
                    activeIcon: _NavIcons.profileActive,
                    inactiveIcon: _NavIcons.profileInactive,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// آیتم ناوبری Premium با آیکون تصویری
  Widget _buildPremiumNavItem({
    required int index,
    required String activeIcon,
    required String inactiveIcon,
    required bool isDark,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
              BlendMode.srcIn,
            ),
            child: Image.asset(
              isSelected ? activeIcon : inactiveIcon,
              width: 26,
              height: 26,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                // Fallback به آیکون پیش‌فرض اگر تصویر بارگذاری نشد
                return Icon(
                  Icons.home_outlined,
                  size: 26,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.grey[600] : Colors.grey[400]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// آیتم ناوبری Premium با بَدج
  Widget _buildPremiumNavItemWithBadge({
    required int index,
    required String activeIcon,
    required String inactiveIcon,
    required int badgeCount,
    required bool isDark,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: badges.Badge(
          showBadge: badgeCount > 0,
          badgeContent: Text(
            badgeCount > 9 ? '۹+' : badgeCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          badgeStyle: const badges.BadgeStyle(
            badgeColor: Colors.red,
            padding: EdgeInsets.all(5),
          ),
          position: badges.BadgePosition.topEnd(top: -8, end: -8),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
              BlendMode.srcIn,
            ),
            child: Image.asset(
              isSelected ? activeIcon : inactiveIcon,
              width: 26,
              height: 26,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 26,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.grey[600] : Colors.grey[400]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// دکمه Add ساده و شیک
  Widget _buildPremiumAddButton(bool isDark) {
    return GestureDetector(
      onTap: () => _onItemTapped(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            isDark ? Colors.black : Colors.white,
            BlendMode.srcIn,
          ),
          child: Image.asset(
            _NavIcons.add,
            width: 24,
            height: 24,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.add_rounded,
                size: 24,
                color: isDark ? Colors.black : Colors.white,
              );
            },
          ),
        ),
      ),
    );
  }
}
