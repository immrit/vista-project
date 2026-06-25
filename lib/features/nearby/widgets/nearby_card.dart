import 'package:flutter/material.dart';

import 'package:Vista/core/theme/app_theme.dart';
import '../models/nearby_models.dart';

/// A single Tinder-style profile card: full-bleed avatar, gradient scrim,
/// name/age, verified badge, distance, bio and info chips. [onTap] opens the
/// profile; [onReport] surfaces the report action.
class NearbyCard extends StatelessWidget {
  final NearbyCandidate candidate;
  final VoidCallback? onReport;
  final VoidCallback? onTap;

  const NearbyCard({
    super.key,
    required this.candidate,
    this.onReport,
    this.onTap,
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

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
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

          // ── City + distance chip (top-left). Always shows the real city name.
          if (c.locationLine.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              child: _chip(
                icon: Icons.location_on_rounded,
                label: c.locationLine,
                bg: Colors.black.withValues(alpha: 0.6),
                fg: Colors.white,
              ),
            ),

          // ── Report button (top-right)
          if (onReport != null)
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.4),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onReport,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.report_gmailerrorred_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
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
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8)
                          ],
                        ),
                      ),
                    ),
                    if (c.gender.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _genderBadge(c.gender),
                    ],
                    if (c.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          color: Color(0xFF3B82F6), size: 20),
                    ],
                  ],
                ),
                if (c.presenceLabel.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.isOnlineNow
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF94A3B8),
                          boxShadow: c.isOnlineNow
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E)
                                        .withValues(alpha: 0.6),
                                    blurRadius: 4,
                                  )
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        c.presenceLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _genderBadge(String gender) {
    final isMale = gender.toLowerCase() == 'male' || gender == 'مرد';
    final color = isMale ? const Color(0xFF3B9AE1) : const Color(0xFFE13B82);
    // Unicode symbols: same font metrics → identical visual size.
    final glyph = isMale ? '♂' : '♀';
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        glyph,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
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
}
