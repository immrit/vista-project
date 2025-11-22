import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

import 'package:Vista/model/session_model.dart';
import 'package:Vista/provider/session_provider.dart';
import 'package:Vista/services/session_manager_service.dart';
import 'package:Vista/DB/unified_message_cache_service.dart';
import 'package:Vista/DB/unified_conversation_cache_service.dart';
import 'package:Vista/view/screen/auth/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveSessionsScreen extends ConsumerStatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  ConsumerState<ActiveSessionsScreen> createState() =>
      _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends ConsumerState<ActiveSessionsScreen> {
  final Map<String, bool> _canTerminateSession = {};
  String? _resolvedCurrentSessionId;
  bool _isResolvingSession = false;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fa', timeago.FaMessages());
  }

  /// ✅ پیدا کردن نشست فعلی از session token یا device ID
  Future<void> _resolveCurrentSession(
    List<SessionModel> sessions,
    SessionManagerService sessionManager,
    String? currentSessionId,
  ) async {
    if (_isResolvingSession) return;
    
    // اگر currentSessionId معتبر است و در لیست sessions وجود دارد
    if (currentSessionId != null && 
        sessions.any((s) => s.id == currentSessionId)) {
      _resolvedCurrentSessionId = currentSessionId;
      return;
    }

    _isResolvingSession = true;

    try {
      // تلاش برای پیدا کردن نشست فعلی از session token
      final foundSessionId = await sessionManager.findCurrentSessionId();
      if (foundSessionId != null && 
          sessions.any((s) => s.id == foundSessionId)) {
        _resolvedCurrentSessionId = foundSessionId;
        if (mounted) {
          setState(() {});
        }
      } else {
        // اگر پیدا نشد، از اولین نشست استفاده کن
        _resolvedCurrentSessionId = sessions.isNotEmpty ? sessions.first.id : null;
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('⚠️ Error finding current session: $e');
      // در صورت خطا، از اولین نشست استفاده کن
      _resolvedCurrentSessionId = sessions.isNotEmpty ? sessions.first.id : null;
      if (mounted) {
        setState(() {});
      }
    } finally {
      _isResolvingSession = false;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            'نشست‌های فعال',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'به‌روزرسانی',
              onPressed: () {
                ref.invalidate(activeSessionsProvider);
              },
            ),
          ],
        ),
        body: sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return _buildEmptyState(isDark);
            }

            // ✅ پیدا کردن نشست فعلی (یک بار در background)
            final actualCurrentSessionId = _resolvedCurrentSessionId ?? currentSessionId;
            
            // اگر هنوز resolve نشده، در background resolve کن
            if (_resolvedCurrentSessionId == null || 
                !sessions.any((s) => s.id == _resolvedCurrentSessionId)) {
              _resolveCurrentSession(sessions, sessionManager, currentSessionId);
            }

            // جدا کردن نشست فعلی از بقیه
            SessionModel? currentSession;
            if (actualCurrentSessionId != null) {
              try {
                currentSession = sessions.firstWhere(
                  (s) => s.id == actualCurrentSessionId,
                );
              } catch (e) {
                // اگر پیدا نشد، از اولین نشست استفاده کن
                currentSession = sessions.isNotEmpty ? sessions.first : null;
              }
            } else {
              // اگر نشست فعلی پیدا نشد، از اولین نشست استفاده کن
              currentSession = sessions.isNotEmpty ? sessions.first : null;
            }

            final otherSessions = currentSession != null
                ? sessions.where((s) => s.id != currentSession!.id).toList()
                : sessions;

            // بارگذاری وضعیت terminate برای هر نشست
            _loadCanTerminateStatus(sessions);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(activeSessionsProvider);
              },
              backgroundColor: colorScheme.primary,
              color: colorScheme.onPrimary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (currentSession != null) ...[
                    _ActiveSessionCard(
                      session: currentSession!,
                      isCurrent: true,
                      sessionManager: sessionManager,
                      onTap: () => _showSessionDetailsBottomSheet(
                        context,
                        currentSession!,
                        true,
                        sessionManager,
                        isDark,
                      ),
                    ),
                  ],
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
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
                ],
              ),
            );
          },
          loading: () => Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          ),
          error: (error, stack) => _buildErrorState(error.toString(), isDark),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ نشست فعالی وجود ندارد',
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // آیکون خطا با Background زیبا
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 72,
                color: colorScheme.error.withOpacity(0.8),
              ),
            ),

            const SizedBox(height: 32),

            // عنوان خطا
            Text(
              'خطا در بارگذاری نشست‌ها',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 12),

            // توضیح ساده و کاربرپسند
            Text(
              'متأسفانه نتوانستیم نشست‌های فعال شما را بارگذاری کنیم.\nلطفاً اتصال اینترنت خود را بررسی کنید.',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontSize: 15,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // دکمه تلاش مجدد
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(activeSessionsProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('تلاش مجدد'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
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
      builder: (sheetContext) => _SessionDetailsBottomSheet(
        session: session,
        isCurrent: isCurrent,
        sessionManager: sessionManager,
        isDark: isDark,
        canTerminate: _canTerminateSession[session.id] ?? false,
        onTerminate: () async {
          final navigator = Navigator.of(sheetContext);
          final messenger = ScaffoldMessenger.of(sheetContext);

          navigator.pop();
          final result = await sessionManager.terminateSession(session.id);
          if (mounted) {
            if (result.success) {
              ref.invalidate(activeSessionsProvider);
              messenger.showSnackBar(
                SnackBar(
                  content: const Text('نشست با موفقیت خاتمه یافت'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(result.errorMessage ?? 'خطا در خاتمه نشست'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isCurrent
        ? (isDark
            ? colorScheme.primary.withOpacity(0.2)
            : colorScheme.primaryContainer)
        : colorScheme.surface;

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
                  ? colorScheme.primary.withOpacity(0.2)
                  : Colors.black.withOpacity(isDark ? 0.3 : 0.1),
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
              color: isCurrent
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCurrent ? Icons.smartphone : Icons.devices_other,
              color: isCurrent ? colorScheme.onPrimary : colorScheme.onSurface,
              size: 24,
            ),
          ),
          title: Text(
            isCurrent ? 'این دستگاه' : session.deviceInfo.deviceName,
            style: TextStyle(
              color: isCurrent
                  ? (isDark
                      ? colorScheme.onSurface
                      : colorScheme.onPrimaryContainer)
                  : colorScheme.onSurface,
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
                  style: TextStyle(
                    color: isCurrent
                        ? (isDark
                            ? colorScheme.onSurface.withOpacity(0.7)
                            : colorScheme.onPrimaryContainer.withOpacity(0.7))
                        : colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isCurrent
                          ? (isDark
                              ? colorScheme.onSurface.withOpacity(0.6)
                              : colorScheme.onPrimaryContainer.withOpacity(0.6))
                          : colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatLastActivity(session.lastActivity),
                      style: TextStyle(
                        color: isCurrent
                            ? (isDark
                                ? colorScheme.onSurface.withOpacity(0.6)
                                : colorScheme.onPrimaryContainer
                                    .withOpacity(0.6))
                            : colorScheme.onSurface.withOpacity(0.6),
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
                    color: Colors.green.shade600,
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
              : Icon(
                  Icons.chevron_left,
                  color: colorScheme.onSurface.withOpacity(0.5),
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

  Future<void> _handleLogout(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // نمایش دیالوگ تایید
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'تایید خروج',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Text(
          'آیا مطمئن هستید که می‌خواهید از حساب کاربری خود خارج شوید؟',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // نمایش loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'در حال خروج...',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // پاک کردن کش پیام‌ها و مکالمات
      try {
        await UnifiedMessageCacheService().clearAllCache();
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await UnifiedConversationCacheService().clearCache(userId);
        }
      } catch (e) {
        // خطا را نادیده می‌گیریم
      }

      // خروج از حساب با استفاده از SessionManager
      await sessionManager.userLogout();

      if (context.mounted) {
        navigator.pop(); // بستن loading dialog
        navigator.pop(); // بستن bottom sheet

        // هدایت به صفحه لاگین
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );

        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('با موفقیت خارج شدید'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        navigator.pop(); // بستن loading dialog
        messenger.showSnackBar(
          SnackBar(
            content: Text('خطا در خروج: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
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
                      color: colorScheme.onSurface.withOpacity(0.3),
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
                        color: isCurrent
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isCurrent ? Icons.smartphone : Icons.devices_other,
                        color: isCurrent
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
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
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${session.deviceInfo.deviceModel} • ${session.platform ?? 'نامشخص'}',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.7),
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
                          color: Colors.green.shade600,
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
                Divider(
                  color: colorScheme.onSurface.withOpacity(0.1),
                  height: 1,
                ),
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
                            ? colorScheme.error
                            : colorScheme.surfaceContainerHighest,
                        foregroundColor: canTerminate
                            ? colorScheme.onError
                            : colorScheme.onSurface.withOpacity(0.6),
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
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text(
                        'خروج از حساب کاربری',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: colorScheme.onSurface,
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
