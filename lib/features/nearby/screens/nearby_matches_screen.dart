// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:Vista/core/theme/app_theme.dart';
import '../models/nearby_models.dart';
import '../providers/nearby_provider.dart';

class NearbyMatchesScreen extends ConsumerWidget {
  const NearbyMatchesScreen({super.key});

  Future<void> _openChat(
      BuildContext context, WidgetRef ref, NearbyMatch m) async {
    try {
      final convId = await ref.read(nearbyRepositoryProvider).openChat(m.matchId);
      if (!context.mounted || convId.isEmpty) return;
      Navigator.pushNamed(context, '/chat', arguments: {
        'conversationId': convId,
        'otherUserId': m.userId,
        'username': m.fullName,
        'avatarUrl': m.avatarUrl,
      });
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در باز کردن گفتگو')));
      }
    }
  }

  Future<void> _unmatch(
      BuildContext context, WidgetRef ref, NearbyMatch m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف مَچ'),
        content: Text('مطمئنی می‌خوای مَچ با ${m.fullName} رو حذف کنی؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(nearbyRepositoryProvider).unmatch(m.matchId);
    ref.invalidate(nearbyMatchesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final matches = ref.watch(nearbyMatchesProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('مَچ‌های من',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.refresh(nearbyMatchesProvider.future),
        child: matches.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, __) => _message(isDark, 'خطا در بارگذاری مَچ‌ها'),
          data: (list) => list.isEmpty
              ? _message(isDark, 'هنوز مَچی نداری!\nبا کاوش در «اطراف من» شروع کن')
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _tile(context, ref, list[i], isDark),
                ),
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext context, WidgetRef ref, NearbyMatch m, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage:
                m.avatarUrl.isNotEmpty ? NetworkImage(m.avatarUrl) : null,
            child: m.avatarUrl.isEmpty
                ? Text(m.fullName.isNotEmpty ? m.fullName.characters.first : '?',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(m.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    if (m.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          color: Color(0xFF3B82F6), size: 16),
                    ],
                  ],
                ),
                if (m.username.isNotEmpty)
                  Text('@${m.username}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary),
            onPressed: () => _openChat(context, ref, m),
          ),
          IconButton(
            icon: Icon(Icons.heart_broken_rounded,
                color: AppColors.error.withValues(alpha: 0.8)),
            onPressed: () => _unmatch(context, ref, m),
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
