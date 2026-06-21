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
import 'nearby_matches_screen.dart';

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

  // Swipe state
  Offset _drag = Offset.zero;
  late final AnimationController _fly;
  Animation<Offset>? _flyAnim;
  bool _animatingOut = false;
  String? _pendingAction; // action committed after fly-out
  NearbyCandidate? _lastSwiped; // last committed swipe, for manual rewind
  bool _rewinding = false;

  @override
  void initState() {
    super.initState();
    _fly = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280))
      ..addListener(() {
        if (_flyAnim != null) setState(() => _drag = _flyAnim!.value);
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _animatingOut) {
          _onFlyOutDone();
        }
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
    _fly.dispose();
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

  // ── Swipe mechanics ───────────────────────────────────────────────────────
  Size get _screen => MediaQuery.of(context).size;

  void _onPanUpdate(DragUpdateDetails d) {
    if (_animatingOut) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_animatingOut) return;
    final w = _screen.width;
    final h = _screen.height;
    final dx = _drag.dx;
    final dy = _drag.dy;
    final v = d.velocity.pixelsPerSecond;
    const flingV = 800.0; // px/s threshold for a deliberate fling

    // Position-based commit (card dragged past the threshold).
    final pastRight = dx > w * 0.28;
    final pastLeft = dx < -w * 0.28;
    final pastUp = dy < -h * 0.18 && dx.abs() < w * 0.2;

    // Velocity-based commit — only when the fling direction matches the drag
    // direction, so a card thrown back toward center just snaps back.
    final flingRight = v.dx > flingV && dx > w * 0.04;
    final flingLeft = v.dx < -flingV && dx < -w * 0.04;
    final flingUp = v.dy < -flingV && v.dx.abs() < flingV && dy < -h * 0.04;

    if (pastUp || flingUp) {
      _flyOut('superlike');
    } else if (pastRight || flingRight) {
      _flyOut('like');
    } else if (pastLeft || flingLeft) {
      _flyOut('pass');
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    _flyAnim = Tween<Offset>(begin: _drag, end: Offset.zero)
        .animate(CurvedAnimation(parent: _fly, curve: Curves.easeOutBack));
    _animatingOut = false;
    _fly.forward(from: 0);
  }

  void _flyOut(String action) {
    HapticFeedback.mediumImpact();
    final w = _screen.width;
    final h = _screen.height;
    final Offset end;
    switch (action) {
      case 'like':
        end = Offset(w * 1.5, _drag.dy);
        break;
      case 'pass':
        end = Offset(-w * 1.5, _drag.dy);
        break;
      default: // superlike
        end = Offset(_drag.dx, -h * 1.2);
    }
    _pendingAction = action;
    _animatingOut = true;
    _flyAnim = Tween<Offset>(begin: _drag, end: end)
        .animate(CurvedAnimation(parent: _fly, curve: Curves.easeIn));
    _fly.forward(from: 0);
  }

  Future<void> _onFlyOutDone() async {
    final action = _pendingAction;
    final notifier = ref.read(discoverProvider.notifier);
    final cards = ref.read(discoverProvider).cards;
    _animatingOut = false;
    _pendingAction = null;
    _flyAnim = null;
    setState(() => _drag = Offset.zero);

    if (action == null || cards.isEmpty) return;
    final top = cards.first;
    notifier.popTop();

    final res = await notifier.act(top.userId, action);
    if (!mounted) return;
    if (!res.ok) {
      // Server rejected the swipe — rewind the card and tell the user why.
      notifier.reinsertTop(top);
      _showActError(res.errorCode);
      return;
    }
    // Remember this card so the rewind button can undo it.
    setState(() => _lastSwiped = top);
    final result = res.result;
    if (result != null && result.matched) {
      _showMatchDialog(result, top);
    }
  }

  Future<void> _rewind() async {
    final card = _lastSwiped;
    if (card == null || _rewinding || _animatingOut) return;
    setState(() => _rewinding = true);
    final ok = await ref.read(discoverProvider.notifier).undo(card);
    if (!mounted) return;
    setState(() {
      _rewinding = false;
      if (ok) _lastSwiped = null; // one-level undo
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('بازگرداندن ممکن نشد'),
            behavior: SnackBarBehavior.floating),
      );
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

  void _buttonAction(String action) {
    if (_animatingOut || ref.read(discoverProvider).cards.isEmpty) return;
    _flyOut(action);
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
    final notifier = ref.read(discoverProvider.notifier);
    try {
      await ref.read(nearbyRepositoryProvider).report(card.userId, reason);
      // Server auto-passes the user; drop them locally too.
      final cards = ref.read(discoverProvider).cards;
      if (cards.isNotEmpty && cards.first.userId == card.userId) {
        notifier.popTop();
        _lastSwiped = null; // a reported user can't be rewound
      }
      if (!mounted) return;
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
            tooltip: 'مَچ‌ها',
            icon: const Icon(Icons.favorite_rounded, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NearbyMatchesScreen()),
            ),
          ),
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

  // Star icon with a count badge of people who liked the viewer (F3).
  Widget _likesBadge() {
    final async = ref.watch(nearbyReceivedLikesProvider);
    final count = async.maybeWhen(data: (d) => d.count, orElse: () => 0);
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'لایک‌های دریافتی',
          icon: const Icon(Icons.bolt_rounded, color: Color(0xFF3B82F6)),
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
    // Show up to 3 stacked cards (top + 2 behind).
    final visible = cards.take(3).toList();
    final w = _screen.width;
    final rot = (_drag.dx / w) * 0.18;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = visible.length - 1; i >= 0; i--)
                  if (i == 0)
                    // Top, draggable card
                    Transform.translate(
                      offset: _drag,
                      child: Transform.rotate(
                        angle: rot,
                        child: GestureDetector(
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          onLongPress: () => _showCardMenu(visible[0]),
                          child: _shadowed(NearbyCard(
                            candidate: visible[0],
                            dragX: (_drag.dx / w).clamp(-1, 1).toDouble(),
                            dragY: (_drag.dy / _screen.height)
                                .clamp(-1, 1)
                                .toDouble(),
                          )),
                        ),
                      ),
                    )
                  else
                    // Background cards, slightly scaled down
                    Transform.scale(
                      scale: 1 - i * 0.04,
                      child: Transform.translate(
                        offset: Offset(0, i * 12),
                        child: _shadowed(NearbyCard(candidate: visible[i])),
                      ),
                    ),
              ],
            ),
          ),
        ),
        _actionBar(),
      ],
    );
  }

  Widget _shadowed(Widget child) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _actionBar() {
    final mainDisabled =
        _animatingOut || ref.watch(discoverProvider).cards.isEmpty;
    final canRewind = _lastSwiped != null && !_rewinding && !_animatingOut;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Rewind — enabled independently of the deck state (F1).
          _gatedButton(
            enabled: canRewind,
            child: _actionButton(
              icon: Icons.undo_rounded,
              color: const Color(0xFFF59E0B),
              size: 48,
              onTap: _rewind,
            ),
          ),
          _gatedButton(
            enabled: !mainDisabled,
            child: _actionButton(
              icon: Icons.close_rounded,
              color: AppColors.error,
              size: 60,
              onTap: () => _buttonAction('pass'),
            ),
          ),
          _gatedButton(
            enabled: !mainDisabled,
            child: _actionButton(
              icon: Icons.star_rounded,
              color: const Color(0xFF3B82F6),
              size: 50,
              onTap: () => _buttonAction('superlike'),
            ),
          ),
          _gatedButton(
            enabled: !mainDisabled,
            child: _actionButton(
              icon: Icons.favorite_rounded,
              color: AppColors.success,
              size: 60,
              onTap: () => _buttonAction('like'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gatedButton({required bool enabled, required Widget child}) {
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.4,
        duration: const Duration(milliseconds: 150),
        child: child,
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceVariant
              : Colors.white,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.45),
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
