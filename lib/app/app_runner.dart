import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:Vista/app/app_initialization.dart';

// Services

import 'package:Vista/services/deep_link_service.dart' as new_deep_link;
import 'package:Vista/services/PushNotificationService.dart';
import 'package:Vista/services/notification_navigation_service.dart';
import 'package:Vista/services/session_manager_service_v2.dart';

import 'package:Vista/services/auto_lock_service.dart';
import 'package:Vista/services/network_state_service.dart';

import 'package:Vista/DB/profile_cache_service.dart';
import 'package:Vista/services/user_presence_service.dart';
import 'package:Vista/core/data/cache/cache_repository.dart';

// Middlewares
import 'package:Vista/middleware/session_middleware.dart';

// Providers
import 'package:Vista/provider/theme_provider.dart';
import 'package:Vista/provider/app_settings_provider.dart';

// Utils
import 'package:Vista/utils/const.dart';

// Feature Screens (Moved)
import 'package:Vista/features/home/screens/homeScreen.dart';

import 'package:Vista/features/chat/screens/modern_chat_screen.dart';
import 'package:Vista/features/auth/screens/auth_wizard_screen.dart';
import 'package:Vista/features/auth/screens/biometric_login_screen.dart';
import 'package:Vista/features/auth/screens/reset_password_screen.dart';
import 'package:Vista/features/auth/screens/password_reset_code_screen.dart';
import 'package:Vista/features/auth/screens/password_reset_sms_screen.dart';
import 'package:Vista/features/auth/screens/password_recovery_confirm_screen.dart';
import 'package:Vista/features/auth/widgets/session_auth_wrapper.dart'; // Import SessionAuthWrapper
import 'package:Vista/features/onboarding/screens/Onboarding.dart';
import 'package:Vista/features/profile/screens/editeProfile.dart';
import 'package:Vista/features/profile/screens/profile_setup_wizard_screen.dart';
import 'package:Vista/features/settings/screens/Settings.dart';
import 'package:Vista/features/settings/screens/vistaStore/store.dart';
import 'package:Vista/features/posts/screens/ExploreFeedScreen.dart';
import 'package:Vista/features/posts/screens/PostDetailPage.dart';
import 'package:Vista/features/posts/screens/profileScreen.dart';
import 'package:Vista/features/emoji/domain/telegram_emoji_lookup.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';

// Stories Module
import 'package:Vista/features/stories/stories.dart';

/// Notification response handler
Future<void> notificationResponseHandler(NotificationResponse response) async {
  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  debugPrint('🔔 Local Notification Clicked');

  if (response.payload != null && response.payload!.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        NotificationNavigationService.handleLocalNotificationPayload(
          context: context,
          payload: response.payload!,
        );
      }
    });
  }
}

class AppRunner {
  static void run() {
    runApp(ProviderScope(child: const RootApp()));
  }
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initDeferred();
  }

  Future<void> _initDeferred() async {
    await AppInitialization.loadDeferredServices();
    _checkInitialNotification();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _checkInitialNotification() async {
    try {
      final flutterLocalNotificationsPlugin =
          AppInitialization.flutterLocalNotificationsPlugin;
      final details = await flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        // handle local notification launch
        final payload = details!.notificationResponse?.payload;
        if (payload != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 1000), () {
              final context = navigatorKey.currentContext;
              if (context != null) {
                NotificationNavigationService.handleLocalNotificationPayload(
                    context: context, payload: payload);
              }
            });
          });
          return;
        }
      }

      if (Firebase.apps.isNotEmpty) {
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 1000), () {
              final context = navigatorKey.currentContext;
              if (context != null) {
                NotificationNavigationService.handleFCMPayload(
                    context: context, data: initialMessage.data);
              }
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking initial notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'lib/utils/images/vistalogo.png',
                  height: 200,
                ),
                const SizedBox(height: 30),
                LoadingAnimationWidget.progressiveDots(
                  color: Colors.white,
                  size: 50,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const MyApp();
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  late final AppLinks _appLinks;
  StreamSubscription? _linkSubscription;
  Timer? _sessionCheckTimer;
  bool _isLoading = false;
  bool _pushServiceInitialized = false;

  final Size viewPort = const Size(428, 926);

  @override
  void dispose() {
    _sessionCheckTimer?.cancel();
    _linkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    try {
      SessionManagerServiceV2().onSessionTerminated = null;
    } catch (_) {}
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(TelegramEmojiLookup.instance.load());
    WidgetsBinding.instance.addObserver(this);
    _appLinks = AppLinks();
    _setupDeepLinkHandling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePushServiceOnce();
    });
    unawaited(_bootstrapAuthenticatedUser());

    _startSessionMonitoring();
    _setupNetworkStateListener();
    _setupSessionTerminationHandler();
  }

  Future<void> _initializePushServiceOnce() async {
    if (!mounted || _pushServiceInitialized) return;
    _pushServiceInitialized = true;
    try {
      await ref.read(pushNotificationServiceProvider).init(context);
    } catch (_) {}
  }

  Future<void> _bootstrapAuthenticatedUser() async {
    try {
      final hasTokenSession = await TokenStorage.hasValidSession();
      if (!hasTokenSession) return;

      final userId = await TokenStorage.getUserId();
      final sessionManager = SessionManagerServiceV2();
      await sessionManager.initialize();
      await sessionManager.ensureSessionRegistered();
      await sessionManager.verifyCurrentSession(forceServer: false);
      sessionManager.updateLocationAndIP();
      UserPresenceService().initialize();
      if (userId != null && userId.isNotEmpty) {
        try {
          ProfileCacheService().cacheProfileAndPosts(userId);
        } catch (_) {}
      }
      await _setupFCMTokenForUser();
    } catch (e) {
      debugPrint('Error bootstrapping backend auth session: $e');
    }
  }

  Future<void> _handleUserSignOut() async {
    if (mounted && navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!)
          .pushNamedAndRemoveUntil('/auth', (route) => false);
    }
  }

  Future<void> _handlePotentialSessionExpiry() async {
    final sessionManager = SessionManagerServiceV2();
    try {
      final hasTokenSession = await TokenStorage.hasValidSession();
      if (!hasTokenSession) return;
      final state =
          await sessionManager.verifyCurrentSession(forceServer: false);
      if (state == SessionVerificationState.invalid) {
        await _handleUserSignOut();
      }
    } catch (_) {}
  }

  Future<void> _setupFCMTokenForUser() async {
    try {
      if (Firebase.apps.isEmpty) return;
      await FirebaseMessaging.instance.requestPermission();
      await FirebaseMessaging.instance.getAPNSToken();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ref.read(pushNotificationServiceProvider).saveToken(token: token);
      }
    } catch (_) {}
  }

  void _startSessionMonitoring() {
    _sessionCheckTimer =
        Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _handlePotentialSessionExpiry();
    });
  }

  void _setupNetworkStateListener() {
    try {
      NetworkStateService().stateStream.listen((state) {
        if (state.isConnected) {
          Future.delayed(const Duration(seconds: 2), () {
            try {
              SessionManagerServiceV2().onNetworkRestored();
            } catch (_) {}
          });
        }
      });
    } catch (_) {}
  }

  void _setupSessionTerminationHandler() {
    SessionManagerServiceV2().onSessionTerminated = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWizardScreen()),
            (r) => false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('نشست شما توسط دستگاه دیگری خاتمه یافت')));
      });
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AutoLockService().recordUserActivity();
      AutoLockService().refreshSettings();
      SessionManagerServiceV2().onAppResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AutoLockService().recordUserActivity();
      SessionManagerServiceV2().onAppPaused();
    }
  }

  void _setupDeepLinkHandling() {
    _processInitialLink();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _processDeepLink(uri);
    });
  }

  Future<void> _processInitialLink() async {
    try {
      final link = await _appLinks.getInitialLink();
      if (link != null) _processDeepLink(link);
    } catch (_) {}
  }

  void _processDeepLink(Uri uri) {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      new_deep_link.DeepLinkService().handleDeepLink(uri, navigatorKey);
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(dynamicThemeProvider);
    final colorBlindMatrix = ref.watch(colorBlindMatrixProvider);

    return ScreenUtilInit(
      designSize: Size(viewPort.width, viewPort.height),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return OverlaySupport.global(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Vista',
            debugShowCheckedModeBanner: false,
            theme: theme,
            builder: (context, child) {
              final safeChild = child ?? const SizedBox.shrink();
              if (colorBlindMatrix == null) return safeChild;
              return ColorFiltered(
                colorFilter: ColorFilter.matrix(colorBlindMatrix),
                child: safeChild,
              );
            },
            home: const SessionAuthWrapper(), // Use SessionAuthWrapper
            initialRoute: '/',
            routes: {
              '/home': (context) =>
                  const SessionMiddleware(child: HomeScreen()),
              '/onboarding': (context) => const Onboarding(),
              '/auth': (context) => const AuthWizardScreen(),
              '/profile-setup': (context) =>
                  const SessionMiddleware(child: ProfileSetupWizardScreen()),
              '/reset-password': (context) => const ResetPasswordScreen(),
              '/reset-password-code': (context) =>
                  const PasswordResetCodeScreen(),
              '/reset-password-sms': (context) =>
                  const PasswordResetSmsScreen(),
              '/reset-password-confirm': (context) =>
                  const PasswordRecoveryConfirmScreen(),
              '/biometric-login': (context) => BiometricLoginScreen(
                    onSuccess: () =>
                        Navigator.pushReplacementNamed(context, '/home'),
                    onFallback: () =>
                        Navigator.pushReplacementNamed(context, '/auth'),
                  ),
              '/editeProfile': (context) =>
                  const SessionMiddleware(child: EditProfile()),
              '/settings': (context) =>
                  const SessionMiddleware(child: Settings()),
              '/feed': (context) =>
                  const SessionMiddleware(child: ExploreFeedScreen()),
              '/verification-store': (context) => VerificationBadgeStore(),
              '/post-detail': (context) {
                final args = ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
                final postId = args?['postId'];
                if (postId != null) {
                  return SessionMiddleware(
                      child: PostDetailsPage(postId: postId));
                }
                return const Scaffold();
              },
              '/profile': (context) {
                final args = ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
                final username = args?['username'];
                if (username != null) {
                  return SessionMiddleware(
                      child: ProfileScreen(username: username, userId: ''));
                }
                return const Scaffold();
              },
              // <-- نام صحیح ویجت خود را اینجا جایگزین کنید

              '/chat': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                String? conversationId;
                String? otherUserId;
                String? username;
                String? avatarUrl;
                if (args is String) {
                  conversationId = args;
                } else if (args is Map<String, dynamic>) {
                  conversationId = args['conversationId'];
                  otherUserId = args['otherUserId'];
                  username = args['username'];
                  avatarUrl = args['avatarUrl'];
                }
                if (conversationId != null) {
                  final conversation =
                      CacheRepository().getConversationSync(conversationId);
                  final effectiveOtherUserId =
                      otherUserId ?? conversation?.otherUserId ?? '';
                  // If otherUserId is empty (e.g. deep-link group invite), treat as group.
                  final effectiveIsGroup =
                      conversation?.isGroup ?? effectiveOtherUserId.isEmpty;
                  return SessionMiddleware(
                    child: ModernChatScreen(
                      args: ChatScreenArgs(
                        conversationId: conversationId,
                        otherUserId: effectiveOtherUserId,
                        otherUserName: username ??
                            conversation?.otherUserName ??
                            'Unknown',
                        otherUserAvatar:
                            avatarUrl ?? conversation?.otherUserAvatar,
                        isGroup: effectiveIsGroup,
                      ),
                    ),
                  );
                }
                return const Scaffold(
                  body: Center(child: Text('Invalid arguments')),
                );
              },

              // Story Routes
              '/story/create': (context) => const SessionMiddleware(
                    child: StoryCreationScreen(),
                  ),
              '/story/view': (context) {
                final args = ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
                if (args != null) {
                  final users = args['users'] as List<StoryUser>?;
                  final initialIndex = args['initialIndex'] as int? ?? 0;
                  final initialStoryIndex =
                      args['initialStoryIndex'] as int? ?? 0;
                  if (users != null && users.isNotEmpty) {
                    return SessionMiddleware(
                      child: StoryPlayerScreen(
                        users: users,
                        initialUserIndex: initialIndex,
                        initialStoryIndex: initialStoryIndex,
                      ),
                    );
                  }
                }
                return const Scaffold();
              },
            },
          ),
        );
      },
    );
  }
}
