import 'package:flutter/material.dart';

import 'package:Vista/core/theme/app_theme.dart';
import '../models/nearby_models.dart';

/// A single Tinder-style profile card: full-bleed avatar, gradient scrim,
/// name/age, verified badge, distance, bio and the info chips the user chose
/// to display. [dragX] in [-1,1] drives the LIKE / NOPE / SUPER stamps.
class NearbyCard extends StatelessWidget {
  final NearbyCandidate candidate;
  final double dragX;
  final double dragY;

  const NearbyCard({
    super.key,
    required this.candidate,
    this.dragX = 0,
    this.dragY = 0,
  });

  String _genderLabel(String g) {
    switch (g.toLowerCase()) {
      case 'male':
      case 'مرد':
        return 'آقا';
      case 'female':
      case 'زن':
        return 'خانم';
      default:
        return g;
    }
  }

  String _maritalLabel(String m) {
    switch (m.toLowerCase()) {
      case 'single':
        return 'مجرد';
      case 'married':
        return 'متاهل';
      default:
        return m;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final title = c.age > 0 ? '${c.fullName}، ${c.age}' : c.fullName;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Avatar / fallback
          if (c.avatarUrl.isNotEmpty)
            Image.network(
              c.avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(c),
              loadingBuilder: (ctx, child, progress) =>
                  progress == null ? child : _fallback(c),
            )
          else
            _fallback(c),

          // ── Bottom scrim
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54, Colors.black87],
                stops: [0.45, 0.78, 1.0],
              ),
            ),
          ),

          // ── Distance chip (top-left)
          Positioned(
            top: 16,
            left: 16,
            child: _chip(
              icon: Icons.location_on_rounded,
              label: c.distanceLabel,
              bg: Colors.black.withValues(alpha: 0.45),
              fg: Colors.white,
            ),
          ),

          // ── Info (bottom)
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                        ),
                      ),
                    ),
                    if (c.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded,
                          color: Color(0xFF3B82F6), size: 22),
                    ],
                  ],
                ),
                if (c.username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${c.username}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (c.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    c.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (c.gender.isNotEmpty)
                      _chip(
                        icon: Icons.person_rounded,
                        label: _genderLabel(c.gender),
                        bg: Colors.white.withValues(alpha: 0.18),
                        fg: Colors.white,
                      ),
                    if (c.maritalStatus.isNotEmpty)
                      _chip(
                        icon: Icons.favorite_border_rounded,
                        label: _maritalLabel(c.maritalStatus),
                        bg: Colors.white.withValues(alpha: 0.18),
                        fg: Colors.white,
                      ),
                    if (c.locationText.isNotEmpty)
                      _chip(
                        icon: Icons.place_outlined,
                        label: c.locationText,
                        bg: Colors.white.withValues(alpha: 0.18),
                        fg: Colors.white,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Swipe stamps
          _stamp(
            visible: dragX > 0.12,
            opacity: (dragX * 2).clamp(0, 1).toDouble(),
            label: 'لایک',
            color: AppColors.success,
            alignment: Alignment.topLeft,
            angle: -0.35,
          ),
          _stamp(
            visible: dragX < -0.12,
            opacity: (-dragX * 2).clamp(0, 1).toDouble(),
            label: 'رد',
            color: AppColors.error,
            alignment: Alignment.topRight,
            angle: 0.35,
          ),
          _stamp(
            visible: dragY < -0.18 && dragX.abs() < 0.18,
            opacity: (-dragY * 2).clamp(0, 1).toDouble(),
            label: 'سوپرلایک',
            color: const Color(0xFF3B82F6),
            alignment: Alignment.bottomCenter,
            angle: 0,
          ),
        ],
      ),
    );
  }

  Widget _fallback(NearbyCandidate c) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      alignment: Alignment.center,
      child: Text(
        c.fullName.isNotEmpty ? c.fullName.characters.first : '?',
        style: const TextStyle(
            color: Colors.white, fontSize: 96, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _stamp({
    required bool visible,
    required double opacity,
    required String label,
    required Color color,
    required Alignment alignment,
    required double angle,
  }) {
    if (!visible) return const SizedBox.shrink();
    return Positioned.fill(
      child: Align(
        alignment: alignment == Alignment.bottomCenter
            ? Alignment.bottomCenter
            : alignment,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: angle,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
