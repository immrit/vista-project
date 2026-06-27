import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:dio/dio.dart';
import 'package:Vista/model/session_model.dart';
import 'package:Vista/provider/session_provider.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import 'package:Vista/services/sensitive_action_guard.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// صفحه نشست‌های فعال - طراحی مدرن Security Hub
class ActiveSessionsScreen extends ConsumerStatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  ConsumerState<ActiveSessionsScreen> createState() =>
      _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends ConsumerState<ActiveSessionsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fa', timeago.FaMessages());
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(activeSessionsProvider);
    final sessionManager = ref.watch(sessionManagerProvider);
    final currentSessionId = sessionManager.currentSessionId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : AppColors.lightSurfaceVariant,
        appBar: AppBar(
          title: const Text(
            'امنیت و نشست‌ها',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          elevation: 0,
          centerTitle: true,
          backgroundColor: isDark ? Colors.black : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'به‌روزرسانی',
              onPressed: () => ref.invalidate(activeSessionsProvider),
            ),
          ],
        ),
        body: sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) return _buildEmptyState(isDark);

            SessionModel? currentSession;
            try {
              currentSession = sessions.firstWhere((s) => s.isCurrentSession);
            } catch (_) {
              // Fallback to local session ID if backend flag is missing
              if (currentSessionId != null) {
                try {
                  currentSession = sessions.firstWhere((s) => s.id == currentSessionId);
                } catch (_) {}
              }
              currentSession ??= sessions.isNotEmpty ? sessions.first : null;
            }

            final otherSessions = currentSession != null
                ? sessions.where((s) => s.id != currentSession!.id).toList()
                : sessions;

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(activeSessionsProvider),
              color: isDark ? Colors.white : Colors.black,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Section - Current Device
                  if (currentSession != null)
                    _buildCurrentDeviceHero(currentSession, isDark),

                  // Other Sessions
                  if (otherSessions.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader('سایر دستگاه‌ها', isDark),
                    const SizedBox(height: 12),
                    _buildOtherSessionsList(
                        otherSessions, sessionManager, isDark),
                  ],

                  // Terminate All Button
                  if (otherSessions.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildTerminateAllButton(sessionManager),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
          loading: () => Center(
            child: CircularProgressIndicator(
              color: isDark ? Colors.white : Colors.black,
              strokeWidth: 2,
            ),
          ),
          error: (error, _) => _buildErrorState(isDark),
        ),
      ),
    );
  }

  Widget _buildCurrentDeviceHero(SessionModel session, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pulsing Icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green
                      .withValues(alpha: 0.1 + (_pulseController.value * 0.1)),
                  border: Border.all(
                    color: Colors.green
                        .withValues(alpha: 0.3 + (_pulseController.value * 0.2)),
                    width: 3,
                  ),
                ),
                child: Icon(
                  _getDeviceIcon(session.platform),
                  size: 48,
                  color: Colors.green,
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // This Device Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'این دستگاه • آنلاین',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Device Info
          Text(
            session.deviceName ?? session.deviceInfo.deviceName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${session.deviceInfo.deviceModel} • ${session.platform ?? 'نامشخص'}',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          if (_sessionLocationText(session) != null)
            Text(
              _sessionLocationText(session)!,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildOtherSessionsList(
    List<SessionModel> sessions,
    SessionManagerServiceV2 sessionManager,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(sessions.length, (index) {
          final session = sessions[index];
          return Column(
            children: [
              _buildSessionTile(session, sessionManager, isDark),
              if (index < sessions.length - 1)
                Divider(
                  height: 1,
                  indent: 72,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSessionTile(
    SessionModel session,
    SessionManagerServiceV2 sessionManager,
    bool isDark,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _getDeviceIcon(session.platform),
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          size: 24,
        ),
      ),
      title: Text(
        session.deviceName ?? session.deviceInfo.deviceName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${session.deviceInfo.deviceModel} • ${session.platform ?? 'نامشخص'}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 12,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(width: 4),
              Text(
                timeago.format(session.lastActivity, locale: 'fa'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
              if (_sessionLocationText(session) != null) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.location_on_outlined,
                  size: 12,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  _sessionLocationText(session)!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.close,
          color: Colors.red[400],
          size: 20,
        ),
        onPressed: () => _terminateSession(session, sessionManager),
      ),
      onTap: () => _showSessionDetails(session, sessionManager, isDark),
    );
  }

  Widget _buildTerminateAllButton(
    SessionManagerServiceV2 sessionManager,
  ) {
    return OutlinedButton.icon(
      onPressed: () => _terminateAllSessions(sessionManager),
      icon: const Icon(Icons.logout, size: 20),
      label: const Text('خاتمه تمام نشست‌های دیگر'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 80,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            'فقط این دستگاه فعال است',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'هیچ نشست دیگری وجود ندارد',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'خطا در بارگذاری نشست‌ها',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لطفاً اتصال اینترنت را بررسی کنید',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => ref.invalidate(activeSessionsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String? platform) {
    if (platform == null) return Icons.devices_other;
    final p = platform.toLowerCase();
    if (p.contains('android')) return Icons.phone_android;
    if (p.contains('ios') || p.contains('iphone')) return Icons.phone_iphone;
    if (p.contains('mac') || p.contains('darwin')) return Icons.laptop_mac;
    if (p.contains('windows')) return Icons.laptop_windows;
    if (p.contains('linux')) return Icons.computer;
    if (p.contains('web')) return Icons.language;
    return Icons.devices_other;
  }

  String? _sessionLocationText(SessionModel session) {
    final location = session.location;
    if (location == null) return null;
    final text = location.displayName.trim();
    if (text.isEmpty || text == 'نامشخص') return null;
    return text;
  }

  Future<void> _terminateSession(
    SessionModel session,
    SessionManagerServiceV2 sessionManager,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmDialog(
        title: 'خاتمه نشست',
        message: 'آیا از خاتمه این نشست مطمئن هستید؟',
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await sessionManager.terminateSession(session.id);
      if (mounted) {
        if (result) {
          ref.invalidate(activeSessionsProvider);
          _showSuccessSnackBar('نشست با موفقیت خاتمه یافت');
        } else {
          _showErrorSnackBar('خطا در خاتمه نشست');
        }
      }
    } catch (e) {
      if (mounted) {
        if (e is DioException &&
            e.response?.data != null &&
            e.response!.data is Map) {
          final data = e.response!.data as Map;
          if (data['message'] != null) {
            _showErrorSnackBar(data['message'].toString());
            return;
          }
        }
        _showErrorSnackBar('خطا در خاتمه نشست');
      }
    }
  }

  Future<void> _terminateAllSessions(
    SessionManagerServiceV2 sessionManager,
  ) async {
    final allowed = await SensitiveActionGuard.verify(
      context,
      action: SensitiveAction.terminateAllOtherSessions,
    );
    if (!allowed) return;

    try {
      final successCount = await sessionManager.terminateAllOtherSessions();
      if (mounted) {
        ref.invalidate(activeSessionsProvider);
        _showSuccessSnackBar('$successCount نشست دیگر با موفقیت خاتمه یافت');
      }
    } catch (e) {
      if (mounted) {
        if (e is DioException &&
            e.response?.data != null &&
            e.response!.data is Map) {
          final data = e.response!.data as Map;
          if (data['message'] != null) {
            _showErrorSnackBar(data['message'].toString());
            return;
          }
        }
        _showErrorSnackBar('خطا در خاتمه نشست‌ها');
      }
    }
  }

  void _showSessionDetails(
    SessionModel session,
    SessionManagerServiceV2 sessionManager,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SessionDetailsSheet(
        session: session,
        isDark: isDark,
        onTerminate: () {
          Navigator.pop(context);
          _terminateSession(session, sessionManager);
        },
      ),
    );
  }

  Widget _buildConfirmDialog({
    required String title,
    required String message,
    required bool isDark,
  }) {
    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
      content: Text(
        message,
        style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'انصراف',
            style:
                TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'تایید',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Bottom Sheet برای جزئیات نشست
class _SessionDetailsSheet extends StatelessWidget {
  final SessionModel session;
  final bool isDark;
  final VoidCallback onTerminate;

  const _SessionDetailsSheet({
    required this.session,
    required this.isDark,
    required this.onTerminate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Device Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getDeviceIcon(session.platform),
                size: 32,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Device Name
            Text(
              session.deviceName ?? session.deviceInfo.deviceName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${session.deviceInfo.deviceModel} • ${session.platform ?? 'نامشخص'}',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Info Items
            _buildInfoItem('آخرین فعالیت',
                timeago.format(session.lastActivity, locale: 'fa'), isDark),
            if (session.ipAddress != null && session.ipAddress!.isNotEmpty)
              _buildInfoItem('آدرس IP', session.ipAddress!, isDark),
            if (_sessionLocationText(session) != null)
              _buildInfoItem('مکان نشست', _sessionLocationText(session)!, isDark),
            _buildInfoItem('سیستم‌عامل', session.platform ?? 'نامشخص', isDark),
            if (session.appVersion != null && session.appVersion!.isNotEmpty)
              _buildInfoItem('نسخه اپ', session.appVersion!, isDark),

            const SizedBox(height: 24),

            // Terminate Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTerminate,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('خاتمه این نشست'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String? platform) {
    if (platform == null) return Icons.devices_other;
    final p = platform.toLowerCase();
    if (p.contains('android')) return Icons.phone_android;
    if (p.contains('ios') || p.contains('iphone')) return Icons.phone_iphone;
    if (p.contains('mac') || p.contains('darwin')) return Icons.laptop_mac;
    if (p.contains('windows')) return Icons.laptop_windows;
    if (p.contains('linux')) return Icons.computer;
    if (p.contains('web')) return Icons.language;
    return Icons.devices_other;
  }

  String? _sessionLocationText(SessionModel session) {
    final location = session.location;
    if (location == null) return null;
    final text = location.displayName.trim();
    if (text.isEmpty || text == 'نامشخص') return null;
    return text;
  }
}
