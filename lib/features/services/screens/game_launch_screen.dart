// ignore_for_file: deprecated_member_use
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/core/app_config.dart';
import '../providers/services_hub_provider.dart';
import 'in_app_web_screen.dart';

/// Full-screen animated transition shown while the game SSO ticket is being
/// minted and the webview session is bootstrapped. The user sees a branded
/// loading screen and never encounters a login form.
///
/// On success   → replaces itself with [InAppWebScreen] (fade transition).
/// On failure   → shows a retry-capable error panel with a friendly message.
class GameLaunchScreen extends ConsumerStatefulWidget {
  const GameLaunchScreen({super.key});

  @override
  ConsumerState<GameLaunchScreen> createState() => _GameLaunchScreenState();
}

enum _Phase { loading, error }

class _GameLaunchScreenState extends ConsumerState<GameLaunchScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.loading;
  String? _errorMsg;

  late final AnimationController _pulse;
  late final AnimationController _dots;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);

    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _scaleAnim = Tween<double>(begin: 0.90, end: 1.10).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _dots.dispose();
    super.dispose();
  }

  // ─── SSO Flow ──────────────────────────────────────────────────────────────

  Future<void> _launch() async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.loading;
      _errorMsg = null;
    });

    try {
      final ticket =
          await ref.read(servicesHubRepositoryProvider).createGameSsoTicket();
      if (!mounted) return;

      final host = Uri.parse(webUrl).host;
      final url =
          '$webUrl/game/sso?ticket=${Uri.encodeQueryComponent(ticket)}';

      await Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => InAppWebScreen(
            url: url,
            title: 'ویستا کوییز',
            restrictHost: host,
            allowedPathPrefix: '/game',
            appBarColor: const Color(0xFF0a3d6b),
            appBarForegroundColor: Colors.white,
            useBackButton: true,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMsg = _mapError(e);
      });
    }
  }

  String _mapError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('not logged in') ||
        s.contains('401') ||
        s.contains('unauthorized')) {
      return 'برای ورود به بازی باید در ویستا وارد باشید.';
    }
    if (s.contains('timeout') ||
        s.contains('connection') ||
        s.contains('network') ||
        s.contains('socket') ||
        s.contains('failed host lookup')) {
      return 'اتصال اینترنت را بررسی کنید و دوباره تلاش کنید.';
    }
    if (s.contains('429') || s.contains('rate limit')) {
      return 'درخواست‌های زیادی ارسال شده، چند ثانیه صبر کنید.';
    }
    if (s.contains('503') ||
        s.contains('unavailable') ||
        s.contains('sso_unavailable')) {
      return 'سرویس بازی موقتاً در دسترس نیست.';
    }
    return 'ورود به بازی ممکن نشد. دوباره تلاش کنید.';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0d4f8a),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0a3d6b), Color(0xFF1a6ebd), Color(0xFF1b82c9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Subtle dot grid background
              Positioned.fill(
                child: CustomPaint(painter: _DotGridPainter()),
              ),
              // Close button — always visible
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white54, size: 26),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'بازگشت',
                    ),
                  ),
                ),
              ),
              // Main content
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _phase == _Phase.error
                      ? _ErrorPanel(
                          key: const ValueKey('error'),
                          message: _errorMsg ?? 'خطای ناشناخته‌ای رخ داد.',
                          onRetry: _launch,
                          onBack: () => Navigator.pop(context),
                        )
                      : _LoadingPanel(
                          key: const ValueKey('loading'),
                          scaleAnim: _scaleAnim,
                          dotCtrl: _dots,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Loading panel ─────────────────────────────────────────────────────────────

class _LoadingPanel extends StatelessWidget {
  final Animation<double> scaleAnim;
  final AnimationController dotCtrl;

  const _LoadingPanel({
    super.key,
    required this.scaleAnim,
    required this.dotCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: scaleAnim,
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                colors: [Color(0xFF2596d6), Color(0xFF1262a8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: const Color(0xFF1a6ebd).withValues(alpha: 0.75),
                  blurRadius: 60,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
        ),
        const SizedBox(height: 38),
        const Text(
          'ویستا کوییز',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'در حال ورود به لابی بازی...',
          style: TextStyle(color: Colors.white60, fontSize: 15),
        ),
        const SizedBox(height: 30),
        _BounceDots(controller: dotCtrl),
      ],
    );
  }
}

// ── Error panel ───────────────────────────────────────────────────────────────

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.red.withValues(alpha: 0.14),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            child: const Icon(Icons.sports_esports_rounded,
                color: Colors.redAccent, size: 46),
          ),
          const SizedBox(height: 28),
          const Text(
            'ورود به بازی ممکن نشد',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('بازگشت'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF78c02c),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'تلاش مجدد',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bouncing dots animation ───────────────────────────────────────────────────

class _BounceDots extends StatelessWidget {
  final AnimationController controller;
  const _BounceDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (i) {
            // Stagger phase by 1/3 of the period for each dot.
            final phase = (controller.value + i / 3) % 1.0;
            // sin(x*π) gives a smooth 0→1→0 arc over one period.
            final t = sin(phase * pi).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(0, -t * 10.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white
                        .withValues(alpha: 0.35 + t * 0.65),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Background dot-grid painter ───────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    const step = 52.0;
    const r = 2.5;
    for (var x = step / 2; x < size.width + step; x += step) {
      for (var y = step / 2; y < size.height + step; y += step) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
