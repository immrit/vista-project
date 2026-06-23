// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:Vista/core/theme/app_theme.dart';
import '../models/nearby_models.dart';
import '../providers/nearby_provider.dart';
import '../widgets/nearby_card.dart';
import 'nearby_likes_screen.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen>
    with SingleTickerProviderStateMixin {
  // Location bootstrap
  bool _locating = true;
  String? _locationError; // null = ok
  bool _disabled = false; // user turned discovery off for themselves

  // Browsing state
  int _index = 0;
  bool _liking = false;

  // Swipe drag state
  Offset _dragOffset = Offset.zero;
  bool _isAnimating = false;
  late AnimationController _swipeCtrl;
  late Animation<Offset> _swipeAnim;

  @override
  void initState() {
    super.initState();
    _swipeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _swipeCtrl.addListener(() {
      if (_isAnimating) setState(() => _dragOffset = _swipeAnim.value);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  // Decides the entry state: respect a prior opt-out instead of silently
  // re-enabling discovery on every visit.
  Future<void> _init() async {
    setState(() {
      _locating = true;
      _locationError = null;
      _disabled = false;
    });
    try {
      final prefs = await ref.read(nearbyRepositoryProvider).getPreferences();
      if (prefs.hasLocation && !prefs.isEnabled) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _disabled = true;
        });
        return;
      }
    } catch (_) {
      // Fall through to the location flow; discover will surface real errors.
    }
    await _bootstrap();
  }

  Future<void> _disableMe() async {
    try {
      await ref.read(nearbyRepositoryProvider).disable();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _disabled = true;
      _locating = false;
      _locationError = null;
    });
  }

  @override
  void dispose() {
    _swipeCtrl.dispose();
    super.dispose();
  }

  // ── Location ────────────────────────────────────────────────────────────
  Future<void> _bootstrap() async {
    setState(() {
      _locating = true;
      _locationError = null;
      _disabled = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _locating = false;
          _locationError = 'service_off';
        });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _locating = false;
          _locationError = 'permission';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await ref
          .read(nearbyRepositoryProvider)
          .updateLocation(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _locating = false);
      ref.read(discoverProvider.notifier).load(reset: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError = 'failed';
      });
    }
  }

  // ── Browsing ──────────────────────────────────────────────────────────────
  // forward=true → next card, forward=false → previous card.
  void _advance(bool forward) {
    final count = ref.read(discoverProvider).cards.length;
    if (forward) {
      if (_index < count - 1) {
        setState(() => _index++);
        if (_index >= count - 3) ref.read(discoverProvider.notifier).load();
      }
    } else {
      if (_index > 0) setState(() => _index--);
    }
  }

  // ── Swipe gesture handlers ────────────────────────────────────────────────
  void _onDragStart(DragStartDetails _) {
    _swipeCtrl.stop();
    setState(() { _isAnimating = false; _dragOffset = Offset.zero; });
  }

  void _onDragUpdate(DragUpdateDetails d) =>
      setState(() => _dragOffset += d.delta);

  void _onDragEnd(DragEndDetails d, List<NearbyCandidate> cards) {
    final screenW = MediaQuery.of(context).size.width;
    final vx = d.velocity.pixelsPerSecond.dx;
    final safeIndex = _index.clamp(0, cards.length - 1);

    if (_dragOffset.dx.abs() > screenW * 0.32 || vx.abs() > 650) {
      // Velocity takes priority for direction; fall back to position.
      final goingBack = vx.abs() > 400 ? vx > 0 : _dragOffset.dx > 0;
      
      if (goingBack && safeIndex == 0) {
        _snapBack();
        return;
      }

      final targetX = goingBack ? screenW : -screenW * 1.8;
      _swipeAnim = Tween<Offset>(
        begin: _dragOffset,
        end: Offset(targetX, _dragOffset.dy * 1.5),
      ).animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut));
      _isAnimating = true;
      _swipeCtrl.reset();
      _swipeCtrl.forward().then((_) {
        if (!mounted) return;
        setState(() { _dragOffset = Offset.zero; _isAnimating = false; });
        _advance(!goingBack); // right-swipe → back; left-swipe → forward
      });
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    _swipeAnim = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut));
    _isAnimating = true;
    _swipeCtrl.reset();
    _swipeCtrl.forward().then((_) {
      if (!mounted) return;
      setState(() { _dragOffset = Offset.zero; _isAnimating = false; });
    });
  }

  Future<void> _likeCurrent() async {
    final cards = ref.read(discoverProvider).cards;
    if (_liking || _index < 0 || _index >= cards.length) return;
    final card = cards[_index];
    setState(() => _liking = true);
    HapticFeedback.mediumImpact();
    final res =
        await ref.read(discoverProvider.notifier).act(card.userId, 'like');
    if (!mounted) return;
    setState(() => _liking = false);
    if (!res.ok) {
      _showActError(res.errorCode);
      return;
    }
    final result = res.result;
    if (result != null && result.matched) {
      _showMatchDialog(result, card);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لایک شد 💜'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 900)),
      );
      _advance(true);
    }
  }

  void _showActError(String? code) {
    final msg = switch (code) {
      'daily_like_limit' => 'سقف لایک روزانه‌ات پر شد. فردا دوباره سر بزن!',
      'user_blocked' => 'امکان لایک این کاربر وجود ندارد',
      'banned_from_nearby' => 'دسترسی تو به این بخش محدود شده',
      _ => 'ثبت نشد، دوباره تلاش کن',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ── Profile navigation ────────────────────────────────────────────────────
  void _openProfile(NearbyCandidate card) {
    Navigator.pushNamed(context, '/profile', arguments: {
      'userId': card.userId,
      'username': card.username,
    });
  }

  // ── Report (F5) ─────────────────────────────────────────────────────────
  void _showCardMenu(NearbyCandidate card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: AppColors.error),
              title: const Text('گزارش و رد کردن'),
              subtitle: const Text('این کاربر از کاوش تو حذف می‌شود'),
              onTap: () {
                Navigator.pop(ctx);
                _pickReportReason(card);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('انصراف'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _pickReportReason(NearbyCandidate card) {
    const reasons = [
      'پروفایل جعلی یا فیک',
      'محتوای نامناسب',
      'مزاحمت و توهین',
      'تبلیغات و اسپم',
      'سایر موارد',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('علت گزارش',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final r in reasons)
              ListTile(
                title: Text(r),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportUser(card, r);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _reportUser(NearbyCandidate card, String reason) async {
    try {
      await ref.read(nearbyRepositoryProvider).report(card.userId, reason);
      // Server auto-passes the reported user; move on to the next card.
      if (!mounted) return;
      _advance(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('گزارش ثبت شد. ممنون که گزارش دادی'),
            behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ثبت گزارش ناموفق بود'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ── Match popup ─────────────────────────────────────────────────────────
  void _showMatchDialog(NearbyLikeResult result, NearbyCandidate top) {
    final m = result.match;
    final avatar = m?.avatarUrl ?? top.avatarUrl;
    final name = m?.fullName ?? top.fullName;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
              child: const Text('مَچ شدید! 🎉',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 8),
            Text('تو و $name همدیگه رو پسندیدید',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white24,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? Text(name.isNotEmpty ? name.characters.first : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _openChat(result.matchId, name, avatar, top.userId);
                },
                icon:
                    const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                label: const Text('شروع گفتگو',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ادامه کاوش',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(
      String matchId, String name, String avatar, String userId) async {
    if (matchId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در باز کردن گفتگو')));
      }
      return;
    }
    try {
      final convId = await ref.read(nearbyRepositoryProvider).openChat(matchId);
      if (!mounted || convId.isEmpty) return;
      Navigator.pushNamed(context, '/chat', arguments: {
        'conversationId': convId,
        'otherUserId': userId,
        'username': name,
        'avatarUrl': avatar,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در باز کردن گفتگو')));
      }
    }
  }

  // ── Preferences sheet ─────────────────────────────────────────────────────
  void _openPreferences() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreferencesSheet(
        onSaved: () => ref.read(discoverProvider.notifier).load(reset: true),
        onEnable: _bootstrap,
        onDisable: _disableMe,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
          child: const Text('اطراف من',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
        ),
        actions: [
          IconButton(
            tooltip: 'قاطی پاتی (آنلاین‌های رندوم)',
            icon: Icon(
              Icons.shuffle_rounded,
              color: ref.watch(discoverProvider).isRandomOnline
                  ? AppColors.success
                  : AppColors.lightTextSecondary,
            ),
            onPressed: () {
              final current = ref.read(discoverProvider).isRandomOnline;
              ref
                  .read(discoverProvider.notifier)
                  .load(reset: true, setRandomOnline: !current);
            },
          ),
          _likesBadge(),
          IconButton(
            tooltip: 'تنظیمات',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openPreferences,
          ),
        ],
      ),
      body: SafeArea(child: _content(isDark)),
    );
  }

  // Heart icon with a badge of pending received likes — opens the combined
  // "likes + matches" screen (F3).
  Widget _likesBadge() {
    final async = ref.watch(nearbyReceivedLikesProvider);
    final count = async.maybeWhen(data: (d) => d.count, orElse: () => 0);
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'لایک‌ها و مَچ‌ها',
          icon: const Icon(Icons.favorite_rounded, color: AppColors.primary),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NearbyLikesScreen()),
            );
            if (mounted) {
              ref.invalidate(nearbyReceivedLikesProvider);
              ref.read(discoverProvider.notifier).load(reset: true);
            }
          },
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                count > 99 ? '۹۹+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _content(bool isDark) {
    if (_disabled) {
      return _disabledView(isDark);
    }
    if (_locating) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_locationError != null) {
      return _locationErrorView(isDark);
    }

    final state = ref.watch(discoverProvider);
    if (state.errorCode != null && state.cards.isEmpty) {
      return _discoverErrorView(state.errorCode!, isDark);
    }
    if (state.loading && state.cards.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (state.cards.isEmpty) {
      return _emptyView(isDark);
    }
    return _deck(state.cards, isDark);
  }

  Widget _deck(List<NearbyCandidate> cards, bool isDark) {
    final screenW = MediaQuery.of(context).size.width;
    final safeIndex = _index.clamp(0, cards.length - 1);
    final card = cards[safeIndex];
    final isGoingBack = _dragOffset.dx > 0 && safeIndex > 0;

    return Column(
      children: [
        Expanded(
          child: Padding(
            // Extra bottom padding gives visual room for the backing-card peek.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: GestureDetector(
              onPanStart: _onDragStart,
              onPanUpdate: _onDragUpdate,
              onPanEnd: (d) => _onDragEnd(d, cards),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (isGoingBack) ...[
                    _shadowed(NearbyCard(candidate: card)),
                    _rewindCard(cards[safeIndex - 1], screenW),
                  ] else ...[
                    if (safeIndex + 1 < cards.length)
                      _backingCard(cards[safeIndex + 1]),
                    _topCard(card),
                  ],
                ],
              ),
            ),
          ),
        ),
        _actionBar(cards),
      ],
    );
  }

  // The active (forward) card the user drags. Follows the finger with a slight
  // rotation; flung off-screen to the left to move on to the next profile.
  Widget _topCard(NearbyCandidate card) {
    final angle = (_dragOffset.dx / 380).clamp(-0.35, 0.35);
    return Transform(
      transform: Matrix4.identity()
        ..translate(_dragOffset.dx, _dragOffset.dy)
        ..rotateZ(angle),
      alignment: Alignment.bottomCenter,
      child: _shadowed(NearbyCard(
        candidate: card,
        onTap: () => _openProfile(card),
        onReport: () => _showCardMenu(card),
      )),
    );
  }

  // Next card sits behind the top card: scaled down + shifted down so its
  // bottom edge peeks out. As the top card is dragged away it scales up to
  // full size and rises to center (progress 0 → 1).
  Widget _backingCard(NearbyCandidate card) {
    const peekY = 16.0;
    final progress = (_dragOffset.dx.abs() / 160).clamp(0.0, 1.0);
    final scale = 0.92 + progress * 0.08;
    final ty = peekY * (1.0 - progress);
    return Transform(
      transform: Matrix4.identity()
        ..translate(0.0, ty)
        ..scale(scale),
      alignment: Alignment.center,
      child: _shadowed(NearbyCard(candidate: card)),
    );
  }

  // The previous card sliding back in from the left edge on top of the current
  // one. [progress] 0→1 maps off-screen-left → centered, with a gentle tilt
  // (~6°) that straightens as it lands.
  Widget _rewindCard(NearbyCandidate card, double screenW) {
    final progress = (_dragOffset.dx / screenW).clamp(0.0, 1.0);
    final tx = -screenW * (1 - progress);
    final ty = _dragOffset.dy * 0.35;
    final rot = -0.11 * (1 - progress);
    return Transform(
      transform: Matrix4.identity()
        ..translate(tx, ty)
        ..rotateZ(rot),
      alignment: Alignment.center,
      child: _shadowed(NearbyCard(
        candidate: card,
        onTap: () => _openProfile(card),
        onReport: () => _showCardMenu(card),
      )),
    );
  }

  Widget _shadowed(Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.40)
                : Colors.black.withValues(alpha: 0.10),
            blurRadius: isDark ? 20 : 14,
            offset: Offset(0, isDark ? 8 : 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _actionBar(List<NearbyCandidate> cards) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 6, 28, 18),
      child: Center(
        child: _actionButton(
          icon: Icons.favorite_rounded,
          color: AppColors.primary,
          size: 72,
          filled: true,
          onTap: _liking ? null : _likeCurrent,
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? color
              : (isDark ? AppColors.darkSurfaceVariant : Colors.white),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.4), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: filled ? 0.45 : 0.25),
              blurRadius: filled ? 20 : 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child:
            Icon(icon, color: filled ? Colors.white : color, size: size * 0.45),
      ),
    );
  }

  // ── State views ────────────────────────────────────────────────────────
  Widget _locationErrorView(bool isDark) {
    final (msg, action) = switch (_locationError) {
      'service_off' => ('سرویس موقعیت‌مکانی دستگاه خاموش است', 'فعال‌سازی'),
      'permission' => (
          'برای پیدا کردن آدم‌های نزدیک، به دسترسی موقعیت مکانی نیاز داریم',
          'تلاش مجدد'
        ),
      _ => ('خطا در دریافت موقعیت مکانی', 'تلاش مجدد'),
    };
    return _centeredMessage(
      icon: Icons.location_off_rounded,
      message: msg,
      actionLabel: action,
      onAction: () async {
        if (_locationError == 'permission') {
          await Geolocator.openAppSettings();
        } else if (_locationError == 'service_off') {
          await Geolocator.openLocationSettings();
        }
        _bootstrap();
      },
      isDark: isDark,
    );
  }

  Widget _disabledView(bool isDark) {
    return _centeredMessage(
      icon: Icons.visibility_off_rounded,
      message:
          'نمایش تو در «اطراف من» خاموشه.\nبا روشن کردنش، می‌تونی آدم‌های نزدیک رو ببینی و توسط بقیه هم دیده بشی.',
      actionLabel: 'روشن کردن',
      onAction: _bootstrap,
      isDark: isDark,
    );
  }

  Widget _discoverErrorView(String code, bool isDark) {
    final msg = switch (code) {
      'feature_disabled' => 'این سرویس فعلا در دسترس نیست',
      'location_required' => 'ابتدا موقعیت مکانی خود را به‌اشتراک بگذارید',
      'banned_from_nearby' => 'دسترسی شما به این بخش محدود شده است',
      _ => 'خطا در بارگذاری',
    };
    return _centeredMessage(
      icon: Icons.error_outline_rounded,
      message: msg,
      actionLabel: code == 'banned_from_nearby' ? null : 'تلاش مجدد',
      onAction: () {
        ref.read(discoverProvider.notifier).clearError();
        _bootstrap();
      },
      isDark: isDark,
    );
  }

  Widget _emptyView(bool isDark) {
    return _centeredMessage(
      icon: Icons.radar_rounded,
      message:
          'فعلا کسی این اطراف نیست!\nبعدا دوباره سر بزن یا محدوده رو بیشتر کن',
      actionLabel: 'تنظیم محدوده',
      onAction: _openPreferences,
      isDark: isDark,
      secondaryLabel: 'تلاش مجدد',
      onSecondary: () => ref.read(discoverProvider.notifier).load(reset: true),
    );
  }

  Widget _centeredMessage({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    required bool isDark,
  }) {
    final textColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 64, color: AppColors.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 18),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.5)),
            const SizedBox(height: 22),
            if (actionLabel != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onAction,
                child: Text(actionLabel,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            if (secondaryLabel != null)
              TextButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel,
                    style: const TextStyle(color: AppColors.primary)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Preferences bottom sheet ─────────────────────────────────────────────────
class _PreferencesSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  final Future<void> Function() onEnable;
  final Future<void> Function() onDisable;
  const _PreferencesSheet({
    required this.onSaved,
    required this.onEnable,
    required this.onDisable,
  });

  @override
  ConsumerState<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends ConsumerState<_PreferencesSheet> {
  NearbyPreferences? _prefs;
  bool _saving = false;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() => _loadError = false);
    try {
      final p = await ref.read(nearbyRepositoryProvider).getPreferences();
      if (mounted) setState(() => _prefs = p);
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(nearbyRepositoryProvider).updatePreferences(p);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('خطا در ذخیره تنظیمات')));
    }
  }

  // Enable/disable acts immediately — enabling needs the location/permission
  // flow which lives in the parent screen.
  void _toggleEnabled(bool enabled) {
    Navigator.pop(context);
    if (enabled) {
      widget.onEnable();
    } else {
      widget.onDisable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final p = _prefs;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: p == null
          ? _loadError
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48,
                          color: AppColors.error.withValues(alpha: 0.8)),
                      const SizedBox(height: 12),
                      const Text('خطا در بارگذاری تنظیمات',
                          style: TextStyle(fontSize: 15)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _loadPrefs,
                        child: const Text('تلاش مجدد',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightTextTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('تنظیمات کاوش',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),

                // ── Enable / disable discovery for this user
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('نمایش من در «اطراف من»',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('روشن باشه تا دیده بشی و بقیه رو ببینی',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.lightTextSecondary)),
                          ],
                        ),
                      ),
                      Switch(
                        value: p.isEnabled,
                        activeColor: AppColors.primary,
                        onChanged: _toggleEnabled,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _label('علاقه‌مند به'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _genderChip('all', 'همه', p),
                    const SizedBox(width: 8),
                    _genderChip('female', 'خانم', p),
                    const SizedBox(width: 8),
                    _genderChip('male', 'آقا', p),
                  ],
                ),
                const SizedBox(height: 20),

                _label('وضعیت تأهل'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _maritalChip('all', 'فرقی نداره', p),
                    const SizedBox(width: 8),
                    _maritalChip('single', 'مجرد', p),
                    const SizedBox(width: 8),
                    _maritalChip('married', 'متاهل', p),
                  ],
                ),
                const SizedBox(height: 20),

                _label('بازه سنی: ${p.minAge} تا ${p.maxAge} سال'),
                RangeSlider(
                  values: RangeValues(p.minAge.toDouble(), p.maxAge.toDouble()),
                  min: 18,
                  max: 80,
                  divisions: 62,
                  activeColor: AppColors.primary,
                  labels: RangeLabels('${p.minAge}', '${p.maxAge}'),
                  onChanged: (v) => setState(() => _prefs = p.copyWith(
                      minAge: v.start.round(), maxAge: v.end.round())),
                ),
                const SizedBox(height: 8),

                _label('حداکثر فاصله: ${p.maxDistanceKm} کیلومتر'),
                Slider(
                  value: p.maxDistanceKm.toDouble().clamp(1, 200),
                  min: 1,
                  max: 200,
                  divisions: 199,
                  activeColor: AppColors.primary,
                  label: '${p.maxDistanceKm}',
                  onChanged: (v) => setState(
                      () => _prefs = p.copyWith(maxDistanceKm: v.round())),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text('ذخیره',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerRight,
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _genderChip(String value, String label, NearbyPreferences p) =>
      _choiceChip(
        label: label,
        selected: p.interestedIn == value,
        onTap: () => setState(() => _prefs = p.copyWith(interestedIn: value)),
      );

  Widget _maritalChip(String value, String label, NearbyPreferences p) =>
      _choiceChip(
        label: label,
        selected: p.maritalPref == value,
        onTap: () => setState(() => _prefs = p.copyWith(maritalPref: value)),
      );

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.lightBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
