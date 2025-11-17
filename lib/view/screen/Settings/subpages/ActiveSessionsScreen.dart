import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

import 'package:Vista/model/session_model.dart';
import 'package:Vista/provider/session_provider.dart';
import 'package:Vista/services/session_manager_service.dart';

class ActiveSessionsScreen extends ConsumerStatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  ConsumerState<ActiveSessionsScreen> createState() =>
      _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends ConsumerState<ActiveSessionsScreen> {
  bool _canTerminateAll = false;
  int _remainingDays = 0;
  bool _isLoadingPermission = true;
  Map<String, bool> _canTerminateSession = {};

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fa', timeago.FaMessages());
    _checkTerminatePermission();
  }

  Future<void> _checkTerminatePermission() async {
    setState(() {
      _isLoadingPermission = true;
    });

    final sessionManager = ref.read(sessionManagerProvider);
    final canTerminate = await sessionManager.canTerminateOtherSessions();
    final remainingDays = await sessionManager.getRemainingDaysToTerminate();

    if (mounted) {
      setState(() {
        _canTerminateAll = canTerminate;
        _remainingDays = remainingDays;
        _isLoadingPermission = false;
      });
    }
  }

  Future<void> _loadCanTerminateStatus(List<SessionModel> sessions) async {
    final sessionManager = ref.read(sessionManagerProvider);
    for (final session in sessions) {
      if (session.id != sessionManager.currentSessionId) {
        if (!_canTerminateSession.containsKey(session.id)) {
          final canTerminate =
              await sessionManager.canTerminateSession(session.id);
          if (mounted) {
            setState(() {
              _canTerminateSession[session.id] = canTerminate;
            });
          }
        }
      }
    }
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
        backgroundColor: isDark ? Colors.black : Colors.grey[100],
        appBar: AppBar(
          title: const Text(
            'نشست‌های فعال',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'به‌روزرسانی',
              onPressed: () async {
                ref.invalidate(activeSessionsProvider);
                await _checkTerminatePermission();
              },
            ),
          ],
        ),
        body: sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return _buildEmptyState(isDark);
            }

            // جدا کردن نشست فعلی از بقیه
            final currentSession = sessions.firstWhere(
              (s) => s.id == currentSessionId,
              orElse: () => sessions.first,
            );
            final otherSessions =
                sessions.where((s) => s.id != currentSessionId).toList();

            // بارگذاری وضعیت terminate برای هر نشست
            _loadCanTerminateStatus(sessions);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(activeSessionsProvider);
                await _checkTerminatePermission();
              },
              backgroundColor: Colors.cyan,
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_isLoadingPermission)
                    _buildTerminationStatusCard(isDark),
                  const SizedBox(height: 16),
                  if (currentSessionId != null)
                    _ActiveSessionCard(
                      session: currentSession,
                      isCurrent: true,
                      sessionManager: sessionManager,
                      onTap: () => _showSessionDetailsBottomSheet(
                        context,
                        currentSession,
                        true,
                        sessionManager,
                        isDark,
                      ),
                    ),
                  if (otherSessions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Text(
                        'سایر دستگاه‌ها',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ),
                    ...otherSessions.map((session) => _ActiveSessionCard(
                          session: session,
                          isCurrent: false,
                          sessionManager: sessionManager,
                          onTap: () => _showSessionDetailsBottomSheet(
                            context,
                            session,
                            false,
                            sessionManager,
                            isDark,
                          ),
                        )),
                  ],
                  if (otherSessions.length > 1) ...[
                    const SizedBox(height: 16),
                    _buildTerminateAllButton(sessionManager, isDark),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.cyan),
          ),
          error: (error, stack) => _buildErrorState(error.toString(), isDark),
        ),
      ),
    );
  }

  Widget _buildTerminationStatusCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _canTerminateAll
            ? Colors.green.shade900.withOpacity(0.3)
            : Colors.orange.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              _canTerminateAll ? Colors.green.shade700 : Colors.orange.shade700,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _canTerminateAll ? Icons.check_circle : Icons.schedule,
            color: _canTerminateAll
                ? Colors.green.shade400
                : Colors.orange.shade400,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _canTerminateAll
                      ? 'می‌توانید همه نشست‌ها را حذف کنید'
                      : 'محدودیت امنیتی',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _canTerminateAll
                      ? 'نشست فعلی شما بیش از 10 روز قدمت دارد'
                      : 'شما می‌توانید فقط نشست‌های جدیدتر از خود را حذف کنید. برای حذف نشست‌های قدیمی، باید $_remainingDays روز دیگر صبر کنید.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ نشست فعالی وجود ندارد',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          const Text(
            'خطا در بارگذاری نشست‌ها',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTerminateAllButton(
    SessionManagerService sessionManager,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _canTerminateAll
              ? () => _showTerminateAllDialog(context, sessionManager, isDark)
              : null,
          icon: Icon(_canTerminateAll ? Icons.logout : Icons.schedule),
          label: Text(
            _canTerminateAll
                ? 'خروج از همه دستگاه‌ها'
                : 'فقط نشست‌های جدیدتر قابل حذف هستند',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _canTerminateAll ? Colors.red.shade600 : Colors.grey.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  void _showSessionDetailsBottomSheet(
    BuildContext context,
    SessionModel session,
    bool isCurrent,
    SessionManagerService sessionManager,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SessionDetailsBottomSheet(
        session: session,
        isCurrent: isCurrent,
        sessionManager: sessionManager,
        isDark: isDark,
        canTerminate: _canTerminateSession[session.id] ?? false,
        onTerminate: () async {
          Navigator.pop(context);
          final result = await sessionManager.terminateSession(session.id);
          if (mounted) {
            if (result.success) {
              ref.invalidate(activeSessionsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('نشست با موفقیت خاتمه یافت'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.errorMessage ?? 'خطا در خاتمه نشست'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _showTerminateAllDialog(
    BuildContext context,
    SessionManagerService sessionManager,
    bool isDark,
  ) async {
    if (!_canTerminateAll) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'شما می‌توانید فقط نشست‌های جدیدتر از خود را حذف کنید. برای حذف همه نشست‌ها، باید $_remainingDays روز دیگر صبر کنید.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'تایید خاتمه همه نشست‌ها',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید همه نشست‌های دیگر (به جز نشست فعلی) را خاتمه دهید؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('خاتمه همه'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _showLoadingDialog(context, isDark);

      final result = await sessionManager.terminateOtherSessions();

      if (mounted) {
        Navigator.pop(context); // بستن loading dialog

        if (result.success) {
          ref.invalidate(activeSessionsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خروج از همه دستگاه‌ها با موفقیت انجام شد'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'خطا در خروج از دستگاه‌ها'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _showLoadingDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          color: isDark ? Colors.grey[900] : Colors.white,
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('در حال پردازش...'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  final SessionModel session;
  final bool isCurrent;
  final SessionManagerService sessionManager;
  final VoidCallback onTap;

  const _ActiveSessionCard({
    required this.session,
    required this.isCurrent,
    required this.sessionManager,
    required this.onTap,
  });

  String _formatLastActivity(DateTime dateTime) {
    return timeago.format(dateTime, locale: 'fa', allowFromNow: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isCurrent
        ? Colors.cyan.shade700
        : (isDark ? Colors.grey[900] : Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: isCurrent
                  ? Colors.cyanAccent.withOpacity(0.3)
                  : Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCurrent ? Colors.cyan.shade900 : Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCurrent ? Icons.smartphone : Icons.devices_other,
              color: Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            isCurrent ? 'این دستگاه' : session.deviceInfo.deviceName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.deviceInfo.deviceModel} • ${session.platform ?? 'نامشخص'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatLastActivity(session.lastActivity),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          trailing: isCurrent
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'فعلی',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : const Icon(
                  Icons.chevron_left,
                  color: Colors.white54,
                ),
        ),
      ),
    );
  }
}

class _SessionDetailsBottomSheet extends StatelessWidget {
  final SessionModel session;
  final bool isCurrent;
  final SessionManagerService sessionManager;
  final bool isDark;
  final bool canTerminate;
  final VoidCallback onTerminate;

  const _SessionDetailsBottomSheet({
    required this.session,
    required this.isCurrent,
    required this.sessionManager,
    required this.isDark,
    required this.canTerminate,
    required this.onTerminate,
  });

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('yyyy/MM/dd - HH:mm', 'fa');
    return formatter.format(dateTime);
  }

  String _formatLastActivity(DateTime dateTime) {
    return timeago.format(dateTime, locale: 'fa', allowFromNow: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[950] : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.cyan,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Device name and platform
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            isCurrent ? Colors.cyan.shade700 : Colors.grey[800],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isCurrent ? Icons.smartphone : Icons.devices_other,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCurrent
                                ? 'این دستگاه'
                                : session.deviceInfo.deviceName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${session.deviceInfo.deviceModel} • ${session.platform ?? 'نامشخص'}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'فعلی',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),
                Divider(color: Colors.white.withOpacity(0.1), height: 1),
                const SizedBox(height: 24),

                // Info rows
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'موقعیت:',
                  value: session.location?.displayName ?? 'نامشخص',
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.language,
                  label: 'IP Address:',
                  value: session.ipAddress ?? '-',
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'زمان ورود:',
                  value: _formatDateTime(session.createdAt),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.access_time,
                  label: 'آخرین فعالیت:',
                  value: _formatLastActivity(session.lastActivity),
                ),
                if (session.appVersion != null) ...[
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.info_outline,
                    label: 'نسخه اپ:',
                    value: session.appVersion!,
                  ),
                ],

                const SizedBox(height: 32),

                // Action button
                if (!isCurrent)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: canTerminate ? onTerminate : null,
                      icon: const Icon(Icons.logout, size: 20),
                      label: Text(
                        canTerminate
                            ? 'خاتمه نشست'
                            : 'شما نمی‌توانید این نشست را حذف کنید',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canTerminate
                            ? Colors.red.shade600
                            : Colors.grey.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text(
                        'نشست فعلی',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.cyan),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
