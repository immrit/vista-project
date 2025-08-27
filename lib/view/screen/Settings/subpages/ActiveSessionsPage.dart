import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../../../provider/security_provider.dart';
import '../../../../model/SecurityModels.dart';
import '../../../../services/ActiveSessionsService.dart';

/// صفحه مدیریت نشست‌های فعال - بهبود یافته
class ActiveSessionsPage extends ConsumerStatefulWidget {
  const ActiveSessionsPage({super.key});

  @override
  ConsumerState<ActiveSessionsPage> createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends ConsumerState<ActiveSessionsPage> {
  Timer? _autoRefreshTimer;
  bool _showAllSessions = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🔐 ActiveSessionsPage initState شروع شد');
    _initializeCurrentSession();
    _startAutoRefreshTimer();
  }

  @override
  void dispose() {
    _stopAutoRefreshTimer();
    super.dispose();
  }

  Future<void> _initializeCurrentSession() async {
    try {
      debugPrint('🔐 شروع ایجاد نشست فعلی...');
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        // بررسی وجود نشست فعلی
        final session = await ref.read(currentActiveSessionProvider.future);
        if (session != null) {
          debugPrint('✅ نشست فعلی موجود است: ${session.id}');
        } else {
          debugPrint('⚠️ نشست فعلی موجود نیست، ایجاد نشست جدید...');
          // ایجاد نشست جدید
          try {
            await ActiveSessionsService.createLoginSession(currentUser.id);
            debugPrint('✅ نشست جدید ایجاد شد');
          } catch (e) {
            debugPrint('❌ خطا در ایجاد نشست جدید: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ خطا در ایجاد نشست فعلی: $e');
    }
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        _refreshSessionsSilently();
      }
    });
  }

  void _stopAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
  }

  void _refreshSessionsSilently() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      ref.invalidate(userActiveSessionsProvider(currentUser.id));
      ref.invalidate(currentActiveSessionProvider);
      ref.invalidate(sessionStatsProvider(currentUser.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userId = currentUser?.id ?? '';

    if (userId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('کاربر وارد نشده است'),
        ),
      );
    }

    final sessionsAsync = ref.watch(userActiveSessionsProvider(userId));
    final sessionsState = ref.watch(activeSessionsStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('نشست‌های فعال'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final currentUser = Supabase.instance.client.auth.currentUser;
              if (currentUser != null) {
                // پاک کردن کش و بارگذاری مجدد
                ref.invalidate(userActiveSessionsProvider(currentUser.id));
                ref.invalidate(currentActiveSessionProvider);
                ref.invalidate(sessionStatsProvider(currentUser.id));

                // بارگذاری مجدد از state provider
                ref
                    .read(activeSessionsStateProvider.notifier)
                    .loadUserSessions(currentUser.id);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final currentUser = Supabase.instance.client.auth.currentUser;
          if (currentUser != null) {
            // پاک کردن کش و بارگذاری مجدد
            ref.invalidate(userActiveSessionsProvider(currentUser.id));
            ref.invalidate(currentActiveSessionProvider);
            ref.invalidate(sessionStatsProvider(currentUser.id));

            // بارگذاری مجدد از state provider
            ref
                .read(activeSessionsStateProvider.notifier)
                .loadUserSessions(currentUser.id);
          }
        },
        child: sessionsAsync.when(
          data: (sessions) => _buildSessionsList(sessions, sessionsState),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('خطا در بارگذاری نشست‌ها: $error');
            return _buildErrorWidget(error.toString());
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSessionActions(context, userId),
        icon: const Icon(Icons.security),
        label: const Text('عملیات امنیتی'),
      ),
    );
  }

  Widget _buildSessionsList(
      List<ActiveSessionModel> sessions, ActiveSessionsState state) {
    if (sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('هیچ نشست فعالی یافت نشد'),
            Text('شما فقط از این دستگاه وارد شده‌اید',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // آمار کلی
        if (state.stats != null && state.stats!.isNotEmpty)
          _buildSessionStats(state.stats!)
        else
          _buildSimpleSessionStats(sessions.length),

        // لیست نشست‌ها
        Expanded(
          child: ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _buildSessionCard(session, state);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleSessionStats(int totalSessions) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'آمار نشست‌ها',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'کل نشست‌ها',
                    '$totalSessions',
                    Icons.devices,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'نشست‌های فعال',
                    '$totalSessions',
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'نشست فعلی',
                    '1',
                    Icons.radio_button_checked,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStats(Map<String, dynamic> stats) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'آمار نشست‌ها',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'کل نشست‌ها',
                    '${stats['total_sessions'] ?? 0}',
                    Icons.devices,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'نشست‌های فعال',
                    '${stats['active_sessions'] ?? 0}',
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'نشست فعلی',
                    '${stats['current_session'] ?? 0}',
                    Icons.radio_button_checked,
                  ),
                ),
              ],
            ),
            if (stats['device_types'] != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'نشست‌ها بر اساس نوع دستگاه:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: (stats['device_types'] as Map<String, dynamic>)
                    .entries
                    .map((entry) => Chip(
                          label: Text('${entry.key}: ${entry.value}'),
                          backgroundColor: Colors.blue.shade100,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSessionCard(
      ActiveSessionModel session, ActiveSessionsState state) {
    final isCurrentSession = session.isCurrent;
    final isExpired = session.isExpired;
    final isRecentlyActive = session.isRecentlyActive;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCurrentSession ? Colors.green : Colors.blue,
          child: Text(
            session.deviceIcon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                session.deviceName ?? 'دستگاه ناشناس',
                style: TextStyle(
                  fontWeight:
                      isCurrentSession ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isCurrentSession)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'فعلی',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${session.osName} ${session.osVersion ?? ''}'),
            Text('آخرین فعالیت: ${_formatTimeAgo(session.lastActivity)}'),
            if (session.location != null)
              Text('موقعیت: ${_formatLocation(session.location!)}'),
            if (session.browserInfo != null)
              Text('مرورگر: ${session.browserInfo}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleSessionAction(value, session, state),
          itemBuilder: (context) => [
            if (!isCurrentSession)
              const PopupMenuItem(
                value: 'terminate',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('ترمینیت نشست'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info),
                  SizedBox(width: 8),
                  Text('جزئیات'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('خطا در بارگذاری نشست‌ها'),
          Text(error, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final currentUser = Supabase.instance.client.auth.currentUser;
              if (currentUser != null) {
                // پاک کردن کش و بارگذاری مجدد
                ref.invalidate(userActiveSessionsProvider(currentUser.id));
                ref.invalidate(currentActiveSessionProvider);
                ref.invalidate(sessionStatsProvider(currentUser.id));

                // بارگذاری مجدد از state provider
                ref
                    .read(activeSessionsStateProvider.notifier)
                    .loadUserSessions(currentUser.id);
              }
            },
            child: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }

  void _showSessionActions(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('ترمینیت تمام نشست‌های غیر فعلی'),
              subtitle:
                  const Text('شما از تمام دستگاه‌های دیگر خارج خواهید شد'),
              onTap: () {
                Navigator.pop(context);
                _terminateAllOtherSessions(userId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('تمدید نشست فعلی'),
              subtitle: const Text('نشست فعلی شما تمدید خواهد شد'),
              onTap: () {
                Navigator.pop(context);
                _refreshCurrentSession(userId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('تغییر رمز عبور'),
              subtitle:
                  const Text('تغییر رمز عبور تمام نشست‌ها را باطل می‌کند'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/update-password');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleSessionAction(
      String action, ActiveSessionModel session, ActiveSessionsState state) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    switch (action) {
      case 'terminate':
        _terminateSession(session.id, currentUser.id);
        break;
      case 'details':
        _showSessionDetails(session);
        break;
    }
  }

  Future<void> _terminateSession(String sessionId, String userId) async {
    try {
      final success = await ref
          .read(activeSessionsStateProvider.notifier)
          .terminateSession(sessionId, userId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نشست با موفقیت ترمینیت شد')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در ترمینیت نشست')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
    }
  }

  Future<void> _terminateAllOtherSessions(String userId) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تایید عملیات'),
          content: const Text(
              'آیا مطمئن هستید که می‌خواهید تمام نشست‌های غیر فعلی را ترمینیت کنید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('تایید'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final success = await ref
            .read(activeSessionsStateProvider.notifier)
            .terminateAllOtherSessions(userId);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تمام نشست‌های غیر فعلی ترمینیت شدند')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در ترمینیت نشست‌ها')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
    }
  }

  Future<void> _refreshCurrentSession(String userId) async {
    try {
      await ref
          .read(activeSessionsStateProvider.notifier)
          .refreshCurrentSession(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نشست فعلی تمدید شد')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در تمدید نشست: $e')),
      );
    }
  }

  void _showSessionDetails(ActiveSessionModel session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('جزئیات نشست ${session.deviceName ?? 'ناشناس'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('شناسه نشست', session.id),
              _buildDetailRow('نوع دستگاه', session.deviceType ?? 'نامشخص'),
              _buildDetailRow('نام دستگاه', session.deviceName ?? 'نامشخص'),
              _buildDetailRow(
                  'سیستم عامل', '${session.osName} ${session.osVersion ?? ''}'),
              _buildDetailRow('نسخه اپ', session.appVersion ?? 'نامشخص'),
              _buildDetailRow('آدرس IP', session.ipAddress ?? 'نامشخص'),
              _buildDetailRow('مرورگر', session.browserInfo ?? 'نامشخص'),
              _buildDetailRow('روش ورود', session.loginMethod),
              _buildDetailRow(
                  'آخرین فعالیت', _formatDateTime(session.lastActivity)),
              _buildDetailRow(
                  'تاریخ ایجاد', _formatDateTime(session.createdAt)),
              if (session.expiresAt != null)
                _buildDetailRow(
                    'تاریخ انقضا', _formatDateTime(session.expiresAt!)),
              if (session.location != null)
                _buildDetailRow('موقعیت', _formatLocation(session.location!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'همین الان';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ساعت پیش';
    } else {
      return '${difference.inDays} روز پیش';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatLocation(Map<String, dynamic> location) {
    final city = location['city'] ?? '';
    final country = location['country'] ?? '';
    final region = location['region'] ?? '';

    if (city.isNotEmpty && country.isNotEmpty) {
      return '$city, $country';
    } else if (region.isNotEmpty && country.isNotEmpty) {
      return '$region, $country';
    } else if (country.isNotEmpty) {
      return country;
    } else {
      return 'نامشخص';
    }
  }
}
