import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:Vista/services/share_receiver_service.dart';

import 'package:Vista/services/auto_lock_service.dart';
import 'package:Vista/services/network_state_service.dart';
import 'package:Vista/services/system_status_service.dart';
import 'package:Vista/services/system_ui_bar_service.dart';
import 'package:Vista/services/location_permission_prompt_service.dart';

import 'package:Vista/DB/profile_cache_service.dart';
import 'package:Vista/services/user_presence_service.dart';
import 'package:Vista/core/data/cache/cache_repository.dart';

// Middlewares
import 'package:Vista/middleware/session_middleware.dart';

// Providers
import 'package:Vista/provider/theme_provider.dart';
import 'package:Vista/provider/app_settings_provider.dart';
import 'package:Vista/provider/locale_provider.dart';
import 'package:Vista/provider/optimized_conversations_provider.dart';

// Utils
import 'package:Vista/utils/const.dart';
import 'package:Vista/utils/themes.dart';
import 'package:Vista/utils/vista_motion.dart';

// Localization
import 'package:Vista/l10n/generated/app_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

// Feature Screens (Moved)
import 'package:Vista/features/home/screens/homeScreen.dart';

import 'package:Vista/features/chat/screens/modern_chat_screen.dart';
import 'package:Vista/features/auth/screens/auth_wizard_screen.dart';
import 'package:Vista/features/auth/screens/biometric_login_screen.dart';
import 'package:Vista/features/auth/screens/reset_password_screen.dart';
import 'package:Vista/features/auth/screens/password_reset_code_screen.dart';
import 'package:Vista/features/auth/screens/password_reset_sms_screen.dart';
import 'package:Vista/features/auth/screens/password_recovery_confirm_screen.dart';
import 'package:Vista/features/auth/screens/password_set_screen.dart';
import 'package:Vista/features/auth/screens/mandatory_password_screen.dart';
import 'package:Vista/features/auth/widgets/session_auth_wrapper.dart'; // Import SessionAuthWrapper
import 'package:Vista/features/onboarding/screens/Onboarding.dart';
import 'package:Vista/features/profile/screens/editeProfile.dart';
import 'package:Vista/features/profile/screens/profile_setup_wizard_screen.dart';
import 'package:Vista/features/settings/screens/Settings.dart';
import 'package:Vista/features/settings/screens/vistaStore/store.dart';
import 'package:Vista/features/settings/screens/vistaStore/pricing_page.dart';
import 'package:Vista/features/posts/screens/ExploreFeedScreen.dart';
import 'package:Vista/features/nearby/screens/nearby_screen.dart';
import 'package:Vista/features/posts/screens/PostDetailPage.dart';
import 'package:Vista/features/posts/screens/appeal_screen.dart';
import 'package:Vista/features/posts/screens/profileScreen.dart';
import 'package:Vista/features/emoji/domain/modern_emoji_lookup.dart';

// Stories Module
import 'package:Vista/features/stories/stories.dart';
import 'package:Vista/features/share/share_target_screen.dart';

import 'package:Vista/screens/maintenance_screen.dart';
import 'package:Vista/widgets/invalid_route_screen.dart';
import 'package:Vista/screens/banned_screen.dart';
import 'package:Vista/core/theme/app_theme.dart';

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
    PushNotificationService.wireSessionHooks();
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
    await _precacheCriticalAssets();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _precacheCriticalAssets() async {
    if (!mounted) return;
    final criticalAssets = <String>[
      'assets/images/modern_bg.jpg',
      'assets/images/vista_custom_bg.png',
      'assets/images/vista_custom_bg_dark.png',
    ];

    for (final asset in criticalAssets) {
      try {
        await precacheImage(AssetImage(asset), context);
      } catch (e) {
        debugPrint('Asset precache skipped for $asset: $e');
      }
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
  StreamSubscription<SharedContent>? _shareSubscription;
  Timer? _sessionCheckTimer;
  Timer? _systemStatusTimer;
  bool _pushServiceInitialized = false;

  final Size viewPort = const Size(428, 926);

  @override
  void dispose() {
    _sessionCheckTimer?.cancel();
    _systemStatusTimer?.cancel();
    _linkSubscription?.cancel();
    _shareSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    try {
      SessionManagerServiceV2().onSessionTerminated = null;
    } catch (_) {}
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _wireFcmSyncHooks();
    unawaited(ModernEmojiLookup.instance.load());
    WidgetsBinding.instance.addObserver(this);
    _appLinks = AppLinks();
    _setupDeepLinkHandling();
    _setupShareIntentHandling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapAppServices());
    });

    _startSessionMonitoring();
    _startSystemStatusMonitoring();
    _setupNetworkStateListener();
    _setupSessionTerminationHandler();
  }

  void _wireFcmSyncHooks() {
    PushNotificationService.wireSessionHooks();
  }

  Future<void> _bootstrapAppServices() async {
    await _bootstrapAuthenticatedUser();
    await _initializePushServiceOnce();
    // نمایش dialog مجوز مکان (اگه لازم باشه) — با تاخیر کوتاه تا UI کاملاً آماده باشه
    Future.delayed(const Duration(seconds: 2), () {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        unawaited(
            LocationPermissionPromptService.checkAndPromptIfNeeded(ctx));
      }
    });
  }

  Future<void> _initializePushServiceOnce() async {
    if (!mounted || _pushServiceInitialized) return;
    _pushServiceInitialized = true;
    try {
      await ref.read(pushNotificationServiceProvider).init(context);
    } catch (e) {
      debugPrint('Push notification init failed: $e');
    }
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
    try {
      await CacheRepository().wipeAllData();
      ref.invalidate(optimizedConversationsProvider);
    } catch (e) {
      debugPrint('Error wiping data on sign out: $e');
    }

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
      await sessionManager.verifyCurrentSession(forceServer: false);
    } catch (_) {}
  }

  Future<void> _setupFCMTokenForUser() async {
    try {
      if (Firebase.apps.isEmpty) return;
      unawaited(PushNotificationService.syncIfNeeded(afterAuth: true));
    } catch (e) {
      debugPrint('FCM token setup failed: $e');
    }
  }

  void _startSessionMonitoring() {
    _sessionCheckTimer =
        Timer.periodic(const Duration(minutes: 5), (timer) async {
      // اگر آفلاین هستیم، خطای شبکه را به عنوان شکست احراز هویتی حساب نکن
      try {
        final networkService = NetworkStateService();
        final networkState = networkService.currentState;
        if (!networkState.isConnected) {
          debugPrint('🔴 [SessionMonitor] Offline — skipping session check');
          return;
        }
      } catch (_) {}
      await _handlePotentialSessionExpiry();
    });
  }

  void _startSystemStatusMonitoring() {
    unawaited(_refreshSystemStatus(force: true));
    _systemStatusTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _refreshSystemStatus(force: true);
    });
  }

  Future<void> _refreshSystemStatus({bool force = false}) async {
    try {
      final status = await SystemStatusService.instance.fetchStatus(
        force: force,
      );
      if (status != null && status.fcmResyncEpoch > 0) {
        unawaited(
          PushNotificationService.handleSystemResyncEpoch(
              status.fcmResyncEpoch),
        );
      }
      // Don't re-push while the maintenance screen is already showing —
      // it polls on its own and pops itself when maintenance ends.
      if (status?.maintenance == true && !MaintenanceScreen.isActive) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/maintenance', (route) => false);
        }
      }
    } catch (_) {}
  }

  void _setupNetworkStateListener() {
    try {
      final networkService = NetworkStateService();
      // مطمئن شو که سرویس راه‌اندازی شده باشد
      unawaited(Future.microtask(() => networkService.initialize()));
      networkService.stateStream.listen((state) {
        if (state.isConnected) {
          debugPrint(
              '🟢 [Network] Connection restored — triggering session sync');
          Future.delayed(const Duration(seconds: 2), () {
            try {
              SessionManagerServiceV2().onNetworkRestored();
              unawaited(PushNotificationService.syncIfNeeded(afterAuth: true));
              // یک بار هم بررسی نشست بلافاصله انجام شود
              _handlePotentialSessionExpiry();
            } catch (_) {}
          });
        }
      });
    } catch (_) {}
  }

  void _setupSessionTerminationHandler() {
    SessionManagerServiceV2().onSessionTerminated = () async {
      try {
        await CacheRepository().wipeAllData();
        ref.invalidate(optimizedConversationsProvider);
      } catch (e) {
        debugPrint('Error wiping data on session terminated: $e');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted) return;

        // نمایش dialog حرفه‌ای — مشابه تلگرام
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.darkSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Text('🚨 ', style: TextStyle(fontSize: 22)),
                Text(
                  'نشست بسته شد',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Vazirmatn',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              'نشست شما بسته شد و برای ادامه باید دوباره وارد شوید. '
              'اگر این کار توسط شما انجام نشده، می‌تواند نشانه دسترسی غیرمجاز به حساب شما باشد.',
              style: TextStyle(
                color: Color(0xFFAAAAAA),
                fontFamily: 'Vazirmatn',
                fontSize: 14,
                height: 1.6,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthWizardScreen()),
                    (r) => false,
                  );
                },
                child: const Text(
                  'ورود مجدد',
                  style: TextStyle(
                    color: Color(0xFF3478F6),
                    fontFamily: 'Vazirmatn',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      });
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AutoLockService().recordUserActivity();
      AutoLockService().refreshSettings();
      SessionManagerServiceV2().onAppResumed();
      unawaited(_refreshSystemStatus(force: true));
      // بررسی dialog مجوز مکان — اگه ۲۴ ساعت گذشته و کاربر آنلاین شد نشون بده
      Future.delayed(const Duration(seconds: 1), () {
        final ctx = navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          unawaited(
              LocationPermissionPromptService.checkAndPromptIfNeeded(ctx));
        }
      });
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

  // ═══════════════════════════════════════════════════════
  //  Share Intent Handling
  // ═══════════════════════════════════════════════════════

  void _setupShareIntentHandling() {
    final svc = ShareReceiverService.instance;
    svc.initialize();

    // اگر اپ از طریق share باز شده (cold start)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 800));
      final initial = await svc.getInitialShare();
      if (initial != null && mounted) {
        _showShareSheet(initial);
      }
    });

    // وقتی اپ در حال اجراست و share جدید می‌رسد (warm start)
    _shareSubscription = svc.stream.listen((content) {
      if (mounted) _showShareSheet(content);
    });
  }

  void _showShareSheet(SharedContent content) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    showShareTargetSheet(ctx, content);
  }

  Future<void> _processInitialLink() async {
    try {
      final link = await _appLinks.getInitialLink();
      if (link != null) _processDeepLink(link);
    } catch (_) {}
  }

  void _processDeepLink(Uri uri) {
    // handleDeepLink is synchronous-return/fire-and-forget, so the old
    // _isLoading guard + double setState never actually gated anything (it
    // flipped true→false in the same frame). Just dispatch.
    try {
      new_deep_link.DeepLinkService().handleDeepLink(uri, navigatorKey);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dynamicThemeProvider);
    final colorBlindMatrix = ref.watch(colorBlindMatrixProvider);
    final currentLocale = ref.watch(localeProvider);

    return OverlaySupport.global(
      child: MaterialApp(
        navigatorKey: navigatorKey,
            title: 'Vista',
            debugShowCheckedModeBanner: false,
            theme: VistaThemes.lightTheme,
            darkTheme: VistaThemes.darkTheme,
            themeMode: ref.watch(themeModeProvider),
            // گذار نرم light↔dark (به‌جای پرشِ ناگهانی) با توکن motion موجود
            themeAnimationDuration: VistaMotion.durationMedium,
            themeAnimationCurve: VistaMotion.smooth,
            locale: currentLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              PersianMaterialLocalizations.delegate,
              PersianCupertinoLocalizations.delegate,
              ...AppLocalizations.localizationsDelegates,
            ],
            localeResolutionCallback: (deviceLocale, supportedLocales) {
              if (deviceLocale == null) return const Locale('fa', 'IR');
              for (final supported in supportedLocales) {
                if (supported.languageCode == deviceLocale.languageCode) {
                  return supported;
                }
              }
              return const Locale('fa', 'IR');
            },
            builder: (context, child) {
              final theme = Theme.of(context);
              final appBarBg = theme.appBarTheme.backgroundColor ??
                  theme.colorScheme.surface;
              final overlayStyle = (theme.appBarTheme.systemOverlayStyle ??
                      const SystemUiOverlayStyle())
                  .copyWith(
                statusBarColor: appBarBg,
                statusBarIconBrightness: theme.brightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
                statusBarBrightness: theme.brightness == Brightness.light
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarColor: theme.scaffoldBackgroundColor,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness:
                    theme.brightness == Brightness.light
                        ? Brightness.dark
                        : Brightness.light,
                systemStatusBarContrastEnforced: false,
                systemNavigationBarContrastEnforced: false,
              );
              SystemUiBarService.sync(overlayStyle);
              
              final safeChild = child ?? const SizedBox.shrink();
              final content = colorBlindMatrix == null
                  ? safeChild
                  : ColorFiltered(
                      colorFilter: ColorFilter.matrix(colorBlindMatrix),
                      child: safeChild,
                    );
                    
              return ScreenUtilInit(
                designSize: Size(viewPort.width, viewPort.height),
                minTextAdapt: true,
                splitScreenMode: true,
                useInheritedMediaQuery: true,
                builder: (context, _) {
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: overlayStyle,
                    child: content,
                  );
                },
              );
            },
            home: const SessionAuthWrapper(), // Use SessionAuthWrapper
            initialRoute: '/',
            routes: {
              '/home': (context) =>
                  const SessionMiddleware(child: HomeScreen()),
              '/onboarding': (context) => const Onboarding(),
              '/auth': (context) => const AuthWizardScreen(),
              '/maintenance': (context) => const MaintenanceScreen(),
              '/banned': (context) => const BannedScreen(),
              '/profile-setup': (context) =>
                  const SessionMiddleware(child: ProfileSetupWizardScreen()),
              '/reset-password': (context) => const ResetPasswordScreen(),
              '/reset-password-code': (context) =>
                  const PasswordResetCodeScreen(),
              '/reset-password-sms': (context) =>
                  const PasswordResetSmsScreen(),
              '/reset-password-confirm': (context) =>
                  const PasswordRecoveryConfirmScreen(),
              '/reset-password-set': (context) => const PasswordSetScreen(),
              '/mandatory-password': (context) =>
                  const MandatoryPasswordScreen(),
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
              '/nearby': (context) =>
                  const SessionMiddleware(child: NearbyScreen()),
              '/verification-store': (context) => VerificationBadgeStore(),
              '/premium': (context) =>
                  const SessionMiddleware(child: PricingPage()),
              '/post-detail': (context) {
                final args = ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
                final postId = args?['postId'];
                if (postId != null) {
                  return SessionMiddleware(
                      child: PostDetailsPage(postId: postId));
                }
                return const InvalidRouteScreen();
              },
              '/appeal': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                String postId = '';
                String type = 'edit';
                if (args is Map) {
                  postId = (args['postId'] ?? '').toString().trim();
                  type = (args['type'] ?? 'edit').toString().trim();
                }
                if (postId.isNotEmpty) {
                  return SessionMiddleware(
                    child: AppealScreen(postId: postId, type: type),
                  );
                }
                return const InvalidRouteScreen();
              },
              '/profile': (context) {
                final rawArgs = ModalRoute.of(context)?.settings.arguments;
                String userId = '';
                String username = '';
                if (rawArgs is String) {
                  userId = rawArgs.trim();
                } else if (rawArgs is Map<String, dynamic>) {
                  userId = (rawArgs['userId'] ?? '').toString().trim();
                  username = (rawArgs['username'] ?? '').toString().trim();
                } else if (rawArgs is Map) {
                  userId = (rawArgs['userId'] ?? '').toString().trim();
                  username = (rawArgs['username'] ?? '').toString().trim();
                }
                if (userId.isNotEmpty) {
                  return SessionMiddleware(
                    child: ProfileScreen(
                      userId: userId,
                      username: username,
                    ),
                  );
                }
                return const InvalidRouteScreen();
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
                return const InvalidRouteScreen();
              },
            },
      ),
    );
  }
}
