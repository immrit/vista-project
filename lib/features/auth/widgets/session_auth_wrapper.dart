import 'dart:async';

import 'package:Vista/features/auth/screens/auth_wizard_screen.dart';
import 'package:Vista/features/auth/data/auth_repository.dart';
import 'package:Vista/features/auth/screens/mandatory_password_screen.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'package:Vista/features/home/screens/homeScreen.dart';
import 'package:Vista/features/onboarding/screens/Onboarding.dart';
import 'package:Vista/features/profile/screens/profile_setup_wizard_screen.dart';
import 'package:Vista/services/onboarding_service.dart';
import 'package:Vista/middleware/session_middleware.dart';
import 'package:Vista/screens/maintenance_screen.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import 'package:Vista/services/PushNotificationService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:Vista/services/system_status_service.dart';
import 'package:Vista/utils/vista_toast.dart';

class SessionAuthWrapper extends ConsumerStatefulWidget {
  const SessionAuthWrapper({super.key});

  @override
  ConsumerState<SessionAuthWrapper> createState() => _SessionAuthWrapperState();
}

class _SessionAuthWrapperState extends ConsumerState<SessionAuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _requiresProfileSetup = false;
  bool _requiresPasswordSetup = false;
  bool _isMaintenance = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _resolveAuthState();
  }

  Future<void> _resolveAuthState() async {
    // ─── Step 0: بررسی وضعیت سیستم (نگهداری و مسدودی) ────────────
    final status = await SystemStatusService.instance.fetchStatus();
    if (status != null && status.maintenance) {
      if (mounted) {
        // The MaintenanceScreen below carries the full message and polls
        // itself out, so this toast is just a brief heads-up. A 1-day toast
        // used to linger on screen after maintenance ended.
        VistaToast.show(
          context: context,
          message: 'سیستم در حال بروزرسانی و تعمیر است...',
          icon: Icons.build_circle_outlined,
          backgroundColor: Colors.amber.shade700,
          textColor: Colors.white,
          duration: const Duration(seconds: 4),
        );
        setState(() {
          _isMaintenance = true;
          _isLoading = false;
        });
      }
      return;
    }

    // ─── Step 1: بررسی توکن محلی ───────────────────────────────
    // اگر توکن معتبر محلی وجود داشته باشد، کاربر را وارد می‌کنیم.
    // این مانع logout ناخواسته در صورت مشکل شبکه یا session validation می‌شود.
    final hasTokenSession = await TokenStorage.hasValidSession();
    bool tokenIsFresh = hasTokenSession;
    if (!hasTokenSession) {
      // توکن منقضی شده — سعی می‌کنیم با refresh token تجدید کنیم
      final hasRefresh = await TokenStorage.hasRefreshToken();
      if (hasRefresh) {
        final refreshed = await SessionManagerServiceV2.instance
            .performSessionRefreshPublic();
        if (refreshed == RefreshResult.authError) {
          _setNotAuthenticated();
          return;
        }
        if (refreshed == RefreshResult.success) {
          tokenIsFresh = true;
        }
        // If refreshed == RefreshResult.networkError, we STILL allow entry (offline mode)
      } else {
        _setNotAuthenticated();
        return;
      }
    }

    // ─── Step 2: دریافت اطلاعات کاربر از بک‌اند ────────────────
    // این مرحله اختیاری است — اگر شکست بخورد، کاربر همچنان لاگین در نظر گرفته می‌شود
    bool requiresProfileSetup = false;
    bool requiresPasswordSetup = false;
    
    if (tokenIsFresh) {
      try {
        final accessToken = await TokenStorage.getAccessToken();
        if (accessToken != null && accessToken.isNotEmpty) {
          final user = await AuthRepository().me(accessToken).timeout(
                const Duration(seconds: 8),
                onTimeout: () => throw Exception('timeout'),
              );
          if (!mounted) return;
          await TokenStorage.saveUserAuthState(user);
          ref.read(authControllerProvider.notifier).acceptAuthenticatedUser(user);
          requiresProfileSetup = !user.profileCompleted;
          requiresPasswordSetup = user.passwordRequired;
        }
      } catch (e) {
        debugPrint('⚠️ /me failed (non-fatal): $e — treating token as valid');
        final err = e.toString();
        if (err.contains('401') || err.contains('unauthorized')) {
          // Token expired exactly now (clock skew). Try refresh!
          final refreshed = await SessionManagerServiceV2.instance.performSessionRefreshPublic();
          if (refreshed == RefreshResult.authError) {
            _setNotAuthenticated();
            return;
          }
          if (refreshed == RefreshResult.success) {
            // Retry /me ONCE with the fresh token, so profile-setup /
            // password-setup gating isn't skipped by the offline fallback
            // (which assumes profileCompleted: true).
            try {
              final freshToken = await TokenStorage.getAccessToken();
              if (freshToken != null && freshToken.isNotEmpty) {
                final user = await AuthRepository().me(freshToken).timeout(
                      const Duration(seconds: 8),
                      onTimeout: () => throw Exception('timeout'),
                    );
                if (!mounted) return;
                await TokenStorage.saveUserAuthState(user);
                ref
                    .read(authControllerProvider.notifier)
                    .acceptAuthenticatedUser(user);
                requiresProfileSetup = !user.profileCompleted;
                requiresPasswordSetup = user.passwordRequired;
                tokenIsFresh = true;
              }
            } catch (_) {
              tokenIsFresh = false;
            }
          } else {
            tokenIsFresh = false;
          }
        } else {
          tokenIsFresh = false; // Fall back to offline flow since /me failed
        }
      }
    }

    if (!tokenIsFresh) {
      // در غیر این صورت (یا عدم اینترنت): ادامه با توکن محلی
      final userId = await TokenStorage.getUserId();
      final passwordRequired = await TokenStorage.getPasswordRequired();
      if (userId != null && userId.isNotEmpty) {
        requiresPasswordSetup = passwordRequired ?? false;
        if (!mounted) return;
        ref.read(authControllerProvider.notifier).acceptAuthenticatedUser(
              AuthUserResponse(
                id: userId,
                fullName: '',
                accountStatus: 'active',
                profileCompleted: true, // فرض: تکمیل است تا loop بی‌نهایت نشود
                hasPassword: passwordRequired == false,
                passwordRequired: passwordRequired ?? false,
                createdAt: DateTime.now(),
              ),
            );
      }
    }

    // ─── Step 3: راه‌اندازی Session Manager در پس‌زمینه ─────────
    // این مرحله در پس‌زمینه انجام می‌شود و کاربر را منتظر نمی‌گذارد
    SessionManagerServiceV2.instance.initInBackground();
    unawaited(PushNotificationService.syncIfNeeded(afterAuth: true));

    if (!mounted) return;
    setState(() {
      _isAuthenticated = true;
      _requiresProfileSetup = requiresProfileSetup;
      _requiresPasswordSetup = requiresPasswordSetup;
      _isLoading = false;
    });
  }

  void _setNotAuthenticated() async {
    // First launch (or onboarding version bump): show the intro slides once
    // before the auth wizard. Previously the onboarding screen existed but
    // nothing ever routed to it.
    final onboardingDone = await OnboardingService.isOnboardingCompleted();
    if (!mounted) return;
    setState(() {
      _isAuthenticated = false;
      _showOnboarding = !onboardingDone;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
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
      );
    }

    if (_isMaintenance) {
      return const MaintenanceScreen();
    }

    if (_isAuthenticated) {
      if (_requiresPasswordSetup) {
        return const SessionMiddleware(child: MandatoryPasswordScreen());
      }
      if (_requiresProfileSetup) {
        return const SessionMiddleware(child: ProfileSetupWizardScreen());
      }
      return const SessionMiddleware(child: HomeScreen());
    }

    if (_showOnboarding) {
      // Onboarding marks itself completed and pushes '/auth' when finished.
      return const Onboarding();
    }
    return const AuthWizardScreen();
  }
}
