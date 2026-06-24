// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// [LocationPermissionDialog] — پیش از درخواست سیستم، کاربر را متقاعد می‌کند
/// ─────────────────────────────────────────────────────────────────────────────
/// نمایش: `LocationPermissionDialog.showRequest(context)` → `bool` (آیا رضایت داد)
class LocationPermissionDialog {
  LocationPermissionDialog._();

  /// نمایش dialog اقناعی پیش از `requestPermission()`.
  /// برمی‌گرداند: `true` = کاربر موافقت کرد، `false` = رد کرد.
  static Future<bool> showRequest(BuildContext context) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.88, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) => const _LocationRequestSheet(),
    );
    return result ?? false;
  }

  /// نمایش dialog راهنمایی به تنظیمات (وقتی دسترسی `deniedForever` است).
  static Future<void> showSettingsGuide(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0, 0.12), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) => const _LocationSettingsSheet(),
    );
  }
}

// ─── Widget اقناعی ──────────────────────────────────────────────────────────
class _LocationRequestSheet extends StatelessWidget {
  const _LocationRequestSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder.withOpacity(0.5)
                      : Colors.white.withOpacity(0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 40,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header gradient strip ──────────────────────────────────
                  Container(
                    height: 5,
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Icon ──────────────────────────────────────────────
                        _GlowIcon(isDark: isDark),
                        const SizedBox(height: 20),

                        // ── Title ─────────────────────────────────────────────
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.heroGradient.createShader(b),
                          child: Text(
                            'بذار بدونیم کجایی',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Subtitle ──────────────────────────────────────────
                        Text(
                          'برای نشون دادن آدم‌های نزدیکت و سرچ هوشمندتر، '
                          'به موقعیت مکانیت نیاز داریم.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── Feature chips ─────────────────────────────────────
                        _FeatureList(isDark: isDark),
                        const SizedBox(height: 28),

                        // ── CTA ───────────────────────────────────────────────
                        _GradientButton(
                          label: 'باشه، اجازه می‌دم',
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'نه، الان نه',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }
}

// ─── Widget راهنمای تنظیمات ──────────────────────────────────────────────────
class _LocationSettingsSheet extends StatelessWidget {
  const _LocationSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder.withOpacity(0.5)
                      : Colors.white.withOpacity(0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warning.withOpacity(0.15),
                    blurRadius: 40,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header gradient strip ──────────────────────────────────
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.warning, AppColors.accent],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28)),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Icon ──────────────────────────────────────────────
                        _SettingsIcon(isDark: isDark),
                        const SizedBox(height: 20),

                        // ── Title ─────────────────────────────────────────────
                        Text(
                          'دسترسی مکان بسته‌ست',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Explanation ───────────────────────────────────────
                        Text(
                          'قبلاً این دسترسی رو رد کردی و سیستم دیگه اجازه پرسیدن مجدد نمیده. '
                          'برای فعال‌سازی باید از تنظیمات دستگاهت اجازه بدی.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: textSecondary,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Steps ─────────────────────────────────────────────
                        _StepsList(isDark: isDark),
                        const SizedBox(height: 26),

                        // ── CTA ───────────────────────────────────────────────
                        _WarningButton(
                          label: 'رفتن به تنظیمات',
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'بعداً',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _GlowIcon extends StatefulWidget {
  final bool isDark;
  const _GlowIcon({required this.isDark});

  @override
  State<_GlowIcon> createState() => _GlowIconState();
}

class _GlowIconState extends State<_GlowIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.22 * _pulse.value),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Inner circle
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryStart, AppColors.primaryEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.45 * _pulse.value),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final bool isDark;
  const _SettingsIcon({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.warning, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.location_off_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  final bool isDark;
  const _FeatureList({required this.isDark});

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.people_alt_rounded, 'نمایش آدم‌های نزدیکت', AppColors.primary),
      (Icons.search_rounded, 'پیشنهادهای شخصی‌سازی‌شده', AppColors.secondary),
      (Icons.location_city_rounded, 'نمایش شهر در پروفایلت', AppColors.accent),
    ];

    final surface = isDark
        ? AppColors.darkSurfaceVariant.withOpacity(0.6)
        : AppColors.lightSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withOpacity(0.4)
              : AppColors.lightBorder.withOpacity(0.6),
        ),
      ),
      child: Column(
        children: features.indexed.map((entry) {
          final i = entry.$1;
          final (icon, label, color) = entry.$2;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18),
                  ],
                ),
              ),
              if (i < features.length - 1)
                Divider(
                  height: 0,
                  thickness: 0.5,
                  indent: 62,
                  color: isDark
                      ? AppColors.darkBorder.withOpacity(0.4)
                      : AppColors.lightBorder,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _StepsList extends StatelessWidget {
  final bool isDark;
  const _StepsList({required this.isDark});

  @override
  Widget build(BuildContext context) {
    const steps = [
      'تنظیمات دستگاه رو باز کن',
      'برنامه‌ها ← Vista رو پیدا کن',
      'مجوزها ← مکان ← همیشه یا فقط هنگام استفاده',
    ];

    final surface = isDark
        ? AppColors.darkSurfaceVariant.withOpacity(0.6)
        : AppColors.lightSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withOpacity(0.4)
              : AppColors.lightBorder.withOpacity(0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.indexed.map((entry) {
          final i = entry.$1;
          final step = entry.$2;
          return Padding(
            padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 12 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.warning, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryStart, AppColors.primaryEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _WarningButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _WarningButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.warning, AppColors.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.warning.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
