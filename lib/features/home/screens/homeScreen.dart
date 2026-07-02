// ignore_for_file: unused_element, deprecated_member_use

import 'dart:async';

import 'package:Vista/features/chat/screens/ChatConversationsScreen.dart'
    show ChatConversationsScreen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import 'package:Vista/provider/profile_completion_provider.dart';
import 'package:Vista/features/posts/screens/AddPost.dart';
import 'package:Vista/features/posts/screens/profileScreen.dart';
import 'package:Vista/features/posts/screens/ExploreFeedScreen.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import 'package:Vista/features/services/screens/services_screen.dart';
import 'package:Vista/features/profile/data/profile_repository.dart';
import 'package:Vista/provider/optimized_conversations_provider.dart';
import 'package:Vista/core/security/input_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/auth/widgets/otp_dialog.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../features/auth/providers/auth_controller.dart';
import '../../../provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:Vista/utils/glassmorphism.dart';
import 'package:Vista/core/theme/app_theme.dart';
import 'package:Vista/l10n/generated/app_localizations.dart';
import 'package:Vista/features/posts/widgets/upload_progress_overlay.dart';

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
  bool _isOpeningComposer = false;

  String _currentUserId = '';
  String _currentUsername = 'کاربر';

  late final List<Widget> _persistentTabs = const [
    ExploreFeedScreen(),
    SearchPage(),
    ServicesScreen(),
    ChatConversationsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentUsername = 'کاربر';
    _loadCurrentUser();
    _checkProfileCompletion();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storedUserId = await TokenStorage.getUserId();
      if (storedUserId != null && storedUserId.isNotEmpty && mounted) {
        setState(() => _currentUserId = storedUserId);
      }

      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;

      final user = await AuthRepository().me(accessToken);
      if (!mounted) return;

      final username = user.username?.trim();
      final fullName = user.fullName.trim();
      setState(() {
        _currentUserId = user.id;
        _currentUsername =
            (username != null && username.isNotEmpty) ? username : fullName;
        if (_currentUsername.isEmpty) {
          _currentUsername = 'کاربر';
        }
      });
      if (_currentUsername.startsWith('Ú') && mounted) {
        setState(() => _currentUsername = 'کاربر');
      }
    } catch (_) {
      // The profile tab can still render with the cached/default identity.
    }
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
          // فقط زمانی setup را push کن که home هنوز صفحه فعال است.
          // اگر چیزی روی home آمده باشد (مثلاً چت از طریق نوتیفیکیشن)،
          // نباید صفحه تکمیل پروفایل روی آن باز شود.
          final isHomeCurrent = ModalRoute.of(context)?.isCurrent ?? false;
          if (mounted && isHomeCurrent) {
            Navigator.pushNamed(context, '/profile-setup');
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

        final userId = await TokenStorage.getUserId();
        if (userId == null || userId.isEmpty) return;

        final profile = await ProfileRepository().fetchProfileById(userId);
        {
          final phone = profile['phone_number']?.toString();
          final normalized = phone == null ? null : normalizePhone09(phone);
          if (phone == null || phone.isEmpty || normalized != phone) {
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
                AppLocalizations.of(context)?.verifyPhoneTitle ??
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
                    AppLocalizations.of(context)?.verifyPhoneDesc ??
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
                    AppLocalizations.of(context)?.remindLater ??
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
                          final phone = normalizePhone09(phoneController.text);
                          if (phone == null) {
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
                                .read(authControllerProvider.notifier)
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
                                final userId = await TokenStorage.getUserId();
                                if (userId != null && userId.isNotEmpty) {
                                  await ProfileRepository().updateProfile(
                                    userId,
                                    {'phone_number': phone},
                                  );
                                }

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
                      : Text(
                          AppLocalizations.of(context)?.sendCode ?? 'ارسال کد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int _stackIndexForNav(int navIndex) {
    return navIndex;
  }

  Future<void> _openComposer() async {
    if (_isOpeningComposer || !mounted) return;
    _isOpeningComposer = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AddPublicPostScreen()),
      );
    } finally {
      _isOpeningComposer = false;
    }
  }

  void _onItemTapped(int index) {
    final targetIndex = _stackIndexForNav(index);
    if (targetIndex == _selectedIndex) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = targetIndex;
    });
  }

  Future<void> _goHomeOrExit() async {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }
    final now = DateTime.now();
    if (_lastPressed == null ||
        now.difference(_lastPressed!) > const Duration(seconds: 2)) {
      _lastPressed = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.pressBackAgainToExit ??
                  'برای خروج دوباره دکمه بازگشت را بزنید',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    // خروج از برنامه
    SystemNavigator.pop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final statusBarColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    // اعمال مستقیم رنگ صحیح status bar هنگام ورود به Home
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        systemStatusBarContrastEnforced: false,
        // هاله: در تم روشن سفید، در تم تاریک رنگ scaffold
        systemNavigationBarColor:
            isLight ? Colors.white : theme.scaffoldBackgroundColor,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadConversationsCountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusBarColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor:
            isDark ? theme.scaffoldBackgroundColor : Colors.white,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goHomeOrExit();
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: [
                  ..._persistentTabs,
                  ProfileScreen(
                    key: ValueKey('$_currentUserId:$_currentUsername'),
                    userId: _currentUserId,
                    username: _currentUsername,
                  ),
                ],
              ),
              // نوار پیشرفت آپلود - مشابه اینستاگرام/X
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 0,
                right: 0,
                child: const UploadProgressOverlay(),
              ),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBottomNavWithHalo(
                isDark: isDark,
                unreadCount: unreadCount,
                theme: theme,
              ),
              // UpdateBanner disabled for store build; re-enable for direct/Telegram builds
              // const UpdateBanner(),
            ],
          ),
        ),
      ),
    );
  }

  /// باتم نویگیشن جزیره‌ای + هاله رنگی زیرش (مثل تلگرام جدید)
  Widget _buildBottomNavWithHalo({
    required bool isDark,
    required int unreadCount,
    required ThemeData theme,
  }) {
    final haloColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // ارتفاع تخمینی جزیره
    const islandApproxHeight = 62.0;
    // فاصله جزیره از پایین
    const islandBottomMargin = 28.0;
    // ارتفاع کل ناحیه باتم نویگیشن
    final navBarHeight =
        islandApproxHeight + islandBottomMargin + bottomPadding + 20;
    // ارتفاع هاله که از وسط جزیره به پایین شروع میشه
    final haloHeight =
        (islandApproxHeight / 2) + islandBottomMargin + bottomPadding + 10;

    return SizedBox(
      height: navBarHeight,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // هاله gradient
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: haloHeight,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    haloColor.withValues(alpha: 0.0),
                    haloColor.withValues(alpha: 0.55),
                    haloColor.withValues(alpha: 0.88),
                    haloColor,
                  ],
                  stops: const [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // جزیره اصلی (روی هاله)
          Positioned(
            left: 0,
            right: 0,
            bottom: islandBottomMargin + bottomPadding,
            child: LiquidGlassContainer(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              blur: 30.0,
              opacity: isDark ? 0.05 : 0.1,
              color: isDark ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPremiumNavItem(
                      index: 0,
                      activeIcon: _NavIcons.homeActive,
                      inactiveIcon: _NavIcons.homeInactive,
                      isDark: isDark,
                    ),
                    _buildPremiumNavItem(
                      index: 1,
                      activeIcon: _NavIcons.search,
                      inactiveIcon: _NavIcons.search,
                      isDark: isDark,
                    ),
                    _buildPremiumServicesButton(isDark),
                    _buildPremiumNavItemWithBadge(
                      index: 3,
                      activeIcon: _NavIcons.chatActive,
                      inactiveIcon: _NavIcons.chatInactive,
                      badgeCount: unreadCount,
                      isDark: isDark,
                    ),
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
        ],
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
    final isSelected = _selectedIndex == _stackIndexForNav(index);
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
                  ? AppColors.primary
                  : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
              BlendMode.srcIn,
            ),
            child: Image.asset(
              isSelected ? activeIcon : inactiveIcon,
              width: 26,
              height: 26,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                // Fallback به آیکون پیش‌فرض اگر تصویر بارگذاری نشد
                return Icon(
                  Icons.home_outlined,
                  size: 26,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.grey[600] : Colors.grey[400]),
                );
              },
            ),
          )
              .animate(target: isSelected ? 1 : 0)
              .scaleXY(end: 1.15, duration: 250.ms, curve: Curves.easeOutBack),
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
    final isSelected = _selectedIndex == _stackIndexForNav(index);
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
                  ? AppColors.primary // ✅ رنگ برند برای active
                  : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
              BlendMode.srcIn,
            ),
            child: Image.asset(
              isSelected ? activeIcon : inactiveIcon,
              width: 26,
              height: 26,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 26,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.grey[600] : Colors.grey[400]),
                );
              },
            ),
          )
              .animate(target: isSelected ? 1 : 0)
              .scaleXY(end: 1.15, duration: 250.ms, curve: Curves.easeOutBack),
        ),
      ),
    );
  }

  /// دکمه سرویس‌ها شیک
  Widget _buildPremiumServicesButton(bool isDark) {
    final isSelected = _selectedIndex == _stackIndexForNav(2);
    return GestureDetector(
      onTap: () => _onItemTapped(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient:
              isSelected ? AppColors.primaryGradient : null, // ✅ Gradient برند
          color: isSelected
              ? null
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.grid_view_rounded,
          size: 24,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
      )
          .animate(target: isSelected ? 1 : 0)
          .scaleXY(end: 1.05, duration: 250.ms, curve: Curves.easeOutBack),
    );
  }
}
