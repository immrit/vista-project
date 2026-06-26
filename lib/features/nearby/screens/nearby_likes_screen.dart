// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:Vista/core/theme/app_theme.dart';
import '../data/nearby_repository.dart';
import '../models/nearby_models.dart';
import '../providers/nearby_provider.dart';
import 'nearby_matches_screen.dart';

/// Combined "likes + matches" screen (F3): tab 0 = people who liked you, tab 1 =
/// your matches. [initialTab] lets a deep link open straight to either tab.
class NearbyLikesScreen extends StatelessWidget {
  final int initialTab;
  const NearbyLikesScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text('لایک‌ها و مَچ‌ها',
              style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            tabs: [
              Tab(text: 'لایک‌های دریافتی'),
              Tab(text: 'مَچ‌ها'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReceivedLikesTab(),
            NearbyMatchesBody(),
          ],
        ),
      ),
    );
  }
}

/// People who liked the viewer. Tapping "like back" creates an instant match.
class _ReceivedLikesTab extends ConsumerWidget {
  const _ReceivedLikesTab();

  Future<void> _act(BuildContext context, WidgetRef ref, NearbyReceivedLike u,
      String action) async {
    try {
      final res =
          await ref.read(nearbyRepositoryProvider).like(u.userId, action);
      ref.invalidate(nearbyReceivedLikesProvider);
      if (!context.mounted) return;
      if (action == 'pass') return;
      if (res.matched) {
        _showMatch(context, ref, u, res);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('لایک شد ✓'), behavior: SnackBarBehavior.floating),
        );
      }
    } on NearbyException catch (e) {
      if (!context.mounted) return;
      final msg = switch (e.code) {
        'daily_like_limit' => 'سقف لایک روزانه‌ات پر شد',
        'user_blocked' => 'امکان لایک این کاربر نیست',
        _ => 'خطا، دوباره تلاش کن',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('خطا، دوباره تلاش کن'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showMatch(BuildContext context, WidgetRef ref, NearbyReceivedLike u,
      NearbyLikeResult res) {
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
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white24,
              backgroundImage:
                  u.avatarUrl.isNotEmpty ? NetworkImage(u.avatarUrl) : null,
              child: u.avatarUrl.isEmpty
                  ? Text(
                      u.fullName.isNotEmpty ? u.fullName.characters.first : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(height: 24),
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
                  await _openChat(context, ref, res.matchId, u);
                },
                icon:
                    const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                label: const Text('شروع گفتگو',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('بعداً', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref, String matchId,
      NearbyReceivedLike u) async {
    if (matchId.isEmpty) return;
    try {
      final convId = await ref.read(nearbyRepositoryProvider).openChat(matchId);
      if (!context.mounted || convId.isEmpty) return;
      Navigator.pushNamed(context, '/chat', arguments: {
        'conversationId': convId,
        'otherUserId': u.userId,
        'username': u.fullName,
        'avatarUrl': u.avatarUrl,
      });
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در باز کردن گفتگو')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(nearbyReceivedLikesProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.refresh(nearbyReceivedLikesProvider.future),
      child: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => _message(isDark, 'خطا در بارگذاری'),
        data: (data) => data.likes.isEmpty
            ? _message(
                isDark, 'هنوز کسی لایکت نکرده!\nبا کاوش بیشتر، دیده می‌شی')
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: data.likes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) =>
                    _tile(context, ref, data.likes[i], isDark),
              ),
      ),
    );
  }

  Widget _tile(
      BuildContext context, WidgetRef ref, NearbyReceivedLike u, bool isDark) {
    final isSuper = u.action == 'superlike';
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isSuper
                ? AppColors.info.withValues(alpha: 0.5)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage:
                    u.avatarUrl.isNotEmpty ? NetworkImage(u.avatarUrl) : null,
                child: u.avatarUrl.isEmpty
                    ? Text(
                        u.fullName.isNotEmpty
                            ? u.fullName.characters.first
                            : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20))
                    : null,
              ),
              if (isSuper)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(Icons.star_rounded,
                      color: AppColors.info, size: 18),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(u.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    if (u.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          color: AppColors.info, size: 16),
                    ],
                  ],
                ),
                Text(isSuper ? 'سوپرلایکت کرده ⭐' : 'لایکت کرده',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'رد',
            icon: Icon(Icons.close_rounded,
                color: AppColors.error.withValues(alpha: 0.8)),
            onPressed: () => _act(context, ref, u, 'pass'),
          ),
          IconButton(
            tooltip: 'لایک متقابل',
            icon: const Icon(Icons.favorite_rounded, color: AppColors.success),
            onPressed: () => _act(context, ref, u, 'like'),
          ),
        ],
      ),
    );
  }

  Widget _message(bool isDark, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded,
                size: 60, color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary)),
          ],
        ),
      ),
    );
  }
}
