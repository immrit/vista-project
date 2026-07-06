// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:Vista/core/theme/app_theme.dart';
import '../models/nearby_models.dart';
import '../providers/nearby_provider.dart';
import '../services/geocoder_service.dart';
import '../widgets/nearby_card.dart';
import '../widgets/location_permission_dialog.dart';
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
  String? _currentZone; // tracks zone of current card for transition detection
  String? _zoneTransition; // non-null = show zone-change banner

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
        if (!mounted) return;
        setState(() {
          _locating = false;
          _locationError = 'service_off';
        });
        return;
      }

      var perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.denied) {
        // درخواست مستقیم از سیستم — dialog اقناعی قبلاً (global) نمایش داده شده
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _locationError = 'permission_forever';
        });
        await LocationPermissionDialog.showSettingsGuide(context);
        return;
      }

      if (perm == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _locationError = 'permission';
        });
        return;
      }

      // Indoors/weak GPS a high-accuracy fix can hang for minutes — cap the
      // wait and fall back to the last known position. City-level matching
      // doesn't need "high" accuracy anyway.
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } on TimeoutException {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _locationError = 'failed';
        });
        return;
      }

      // Send coordinates right away so the deck can load; enrich with the
      // city/province name in the background once (if) Nominatim answers —
      // the public geocoder is rate-limited and must not block bootstrap.
      await ref.read(nearbyRepositoryProvider).updateLocation(
            pos.latitude,
            pos.longitude,
          );
      if (!mounted) return;
      setState(() => _locating = false);
      ref.read(discoverProvider.notifier).load(reset: true);

      final lat = pos.latitude;
      final lng = pos.longitude;
      // Capture the repo now — reading ref inside the closure after this
      // screen is disposed would throw.
      final repo = ref.read(nearbyRepositoryProvider);
      unawaited(() async {
        try {
          final geo = await GeocoderService.lookup(lat, lng);
          if (geo == null) return;
          await repo.updateLocation(
            lat,
            lng,
            cityName: geo.cityName,
            provinceName: geo.provinceName,
          );
        } catch (_) {
          // best-effort enrichment only
        }
      }());
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
    final cards = ref.read(discoverProvider).cards;
    if (forward) {
      if (_index < cards.length - 1) {
        final newIndex = _index + 1;
        final transition = _detectZoneChange(cards[newIndex]);
        setState(() {
          _index = newIndex;
          if (transition != null) _zoneTransition = transition;
        });
        if (transition != null) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _zoneTransition = null);
          });
        }
        if (_index >= cards.length - 5) {
          ref.read(discoverProvider.notifier).load();
        }
      }
    } else {
      if (_index > 0) {
        final newIndex = _index - 1;
        final transition = _detectZoneChange(cards[newIndex]);
        setState(() {
          _index = newIndex;
          if (transition != null) _zoneTransition = transition;
        });
        if (transition != null) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _zoneTransition = null);
          });
        }
      }
    }
  }

  /// Returns a banner message when the card's city differs from the last one,
  /// so the user sees the layered city-by-city progression. Tracks the city
  /// name (finer than zone) and updates [_currentZone] in place. Null = no
  /// transition.
  String? _detectZoneChange(NearbyCandidate card) {
    // Key on the real place name when known, else on the coarse zone bucket.
    final key = card.cityLabel.isNotEmpty ? card.cityLabel : card.zoneType;
    if (_currentZone == null) {
      _currentZone = key;
      return null;
    }
    if (_currentZone == key) return null;
    _currentZone = key;

    if (card.cityLabel.isNotEmpty) {
      return 'افراد ${card.cityLabel}';
    }
    // No place name resolved — fall back to a generic, non-vague hint.
    return 'افراد دورتر';
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
            Image.asset('assets/images/match_icon.png', width: 90, height: 90),
            const SizedBox(height: 12),
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

    // Initialize zone tracking on first card shown (no banner on first card).
    _currentZone ??= card.cityLabel.isNotEmpty ? card.cityLabel : card.zoneType;

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
                  // Zone transition banner — floats above cards
                  if (_zoneTransition != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _zoneBanner(_zoneTransition!),
                    ),
                ],
              ),
            ),
          ),
        ),
        _actionBar(cards),
      ],
    );
  }

  Widget _zoneBanner(String message) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.layers_rounded, color: Colors.white70, size: 15),
            const SizedBox(width: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
    final (msg, action, icon) = switch (_locationError) {
      'service_off' => (
          'سرویس موقعیت‌مکانی دستگاه خاموش است.\nبرای استفاده از «اطراف من» باید GPS فعال باشه.',
          'فعال‌سازی',
          Icons.gps_off_rounded,
        ),
      'permission_forever' => (
          'دسترسی مکان مسدود شده.\nبرای فعال‌سازی باید از تنظیمات دستگاه اجازه بدی.',
          'راهنمای تنظیمات',
          Icons.lock_outline_rounded,
        ),
      'permission' => (
          'برای پیدا کردن آدم‌های نزدیک، به دسترسی موقعیت مکانی نیاز داریم.',
          'فعال‌سازی',
          Icons.location_off_rounded,
        ),
      _ => (
          'خطا در دریافت موقعیت مکانی',
          'تلاش مجدد',
          Icons.error_outline_rounded,
        ),
    };
    return _centeredMessage(
      icon: icon,
      message: msg,
      actionLabel: action,
      onAction: () async {
        if (_locationError == 'permission_forever') {
          await LocationPermissionDialog.showSettingsGuide(context);
          await Geolocator.openAppSettings();
        } else if (_locationError == 'service_off') {
          await Geolocator.openLocationSettings();
          _bootstrap();
        } else {
          _bootstrap();
        }
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
          'فعلا کسی آنلاین نیست!\nهمه آنلاین‌های نزدیک رو دیدی. بعداً دوباره سر بزن.',
      actionLabel: 'تلاش مجدد',
      onAction: () => ref.read(discoverProvider.notifier).load(reset: true),
      isDark: isDark,
    );
  }

  Widget _centeredMessage({
    IconData? icon,
    Widget? customIcon,
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
            if (customIcon != null) customIcon
            else if (icon != null) Icon(icon,
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
