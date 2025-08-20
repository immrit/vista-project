import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../provider/security_provider.dart';
import '../../../../model/SecurityModels.dart';

/// صفحه مدیریت نشست‌های فعال
class ActiveSessionsPage extends ConsumerStatefulWidget {
  const ActiveSessionsPage({super.key});

  @override
  ConsumerState<ActiveSessionsPage> createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends ConsumerState<ActiveSessionsPage> {
  Map<String, dynamic>? _systemMetrics;

  @override
  void initState() {
    super.initState();
    debugPrint('🔐 ActiveSessionsPage initState شروع شد');
    _loadSystemMetrics();
    _initializeCurrentSession();
  }

  Future<void> _initializeCurrentSession() async {
    try {
      debugPrint('🔐 شروع ایجاد نشست فعلی...');
      // اطمینان از ایجاد نشست فعلی
      final session = await ref.read(currentSessionProvider.future);
      if (session != null) {
        debugPrint('✅ نشست فعلی ایجاد شد: ${session.id}');
      } else {
        debugPrint('⚠️ نشست فعلی ایجاد نشد');
      }
    } catch (e) {
      debugPrint('❌ خطا در ایجاد نشست فعلی: $e');
    }
  }

  Future<void> _loadSystemMetrics() async {
    try {
      final testingService = ref.read(securityTestingServiceProvider);
      final metrics = await testingService.getSystemMetrics();
      setState(() {
        _systemMetrics = metrics;
      });
    } catch (e) {
      debugPrint('خطا در بارگذاری آمار سیستم: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // دریافت userId فعلی
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userId = currentUser?.id ?? '';

    if (userId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('کاربر وارد نشده است'),
        ),
      );
    }

    final sessionsAsync = ref.watch(activeSessionsProvider(userId));

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
                // پاک کردن کش نشست‌ها
                SecurityCache.remove('sessions_${currentUser.id}');

                // به‌روزرسانی نشست فعلی
                ref.invalidate(currentSessionProvider);
                ref.invalidate(activeSessionsProvider(currentUser.id));

                // بارگذاری مجدد نشست فعلی
                await _initializeCurrentSession();
              }
              _loadSystemMetrics();
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'test',
                child: Row(
                  children: [
                    Icon(Icons.science),
                    SizedBox(width: 8),
                    Text('تست سیستم'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'optimize',
                child: Row(
                  children: [
                    Icon(Icons.tune),
                    SizedBox(width: 8),
                    Text('بهینه‌سازی'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'diagnostic',
                child: Row(
                  children: [
                    Icon(Icons.analytics),
                    SizedBox(width: 8),
                    Text('تشخیص کامل'),
                  ],
                ),
              ),
            ],
            child: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          // نمایش آمار سیستم
          if (_systemMetrics != null) _buildSystemMetricsCard(),

          // لیست نشست‌ها
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _buildErrorWidget(error),
              data: (sessions) => _buildSessionsList(sessions),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMetricsCard() {
    if (_systemMetrics == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'آمار سیستم',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'نشست‌های فعال',
                    '${_systemMetrics!['total_sessions'] ?? 0}',
                    Icons.devices,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'نشست فعلی',
                    '${_systemMetrics!['current_sessions'] ?? 0}',
                    Icons.phone_android,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'امتیاز امنیت',
                    '${_systemMetrics!['security_score'] ?? 0}',
                    Icons.security,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'خطا در بارگذاری نشست‌ها',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(activeSessionsProvider);
              _loadSystemMetrics();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(List<ActiveSessionModel> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'هیچ نشست فعالی یافت نشد',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'شما در حال حاضر در هیچ دستگاهی وارد نشده‌اید',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // گروه‌بندی نشست‌ها
    final currentSessions = sessions.where((s) => s.isCurrent).toList();
    final otherSessions = sessions.where((s) => !s.isCurrent).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (currentSessions.isNotEmpty) ...[
          _buildSectionHeader('نشست فعلی', Icons.phone_android, Colors.green),
          const SizedBox(height: 8),
          ...currentSessions.map((session) => _buildSessionCard(session, true)),
          const SizedBox(height: 24),
        ],
        if (otherSessions.isNotEmpty) ...[
          _buildSectionHeader(
              'سایر نشست‌ها', Icons.devices_other, Colors.orange),
          const SizedBox(height: 8),
          ...otherSessions.map((session) => _buildSessionCard(session, false)),
        ],
        const SizedBox(height: 24),
        _buildGlobalSessionActions(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(ActiveSessionModel session, bool isCurrent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: _buildDeviceIcon(session.deviceType, isCurrent),
        title: Row(
          children: [
            Expanded(
              child: Text(
                session.deviceName ?? 'دستگاه ناشناس',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'فعلی',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (session.isTrusted)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session.osName ?? 'OS نامشخص'} ${session.osVersion ?? ''}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'IP: ${session.ipAddress ?? 'نامشخص'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            Text(
              'آخرین فعالیت: ${_formatDateTime(session.lastActivity)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSessionDetail(
                    'نوع دستگاه', _getDeviceTypeText(session.deviceType)),
                _buildSessionDetail(
                    'نام دستگاه', session.deviceName ?? 'نامشخص'),
                _buildSessionDetail('سیستم عامل',
                    '${session.osName ?? 'نامشخص'} ${session.osVersion ?? ''}'),
                _buildSessionDetail('نسخه اپ', session.appVersion ?? 'نامشخص'),
                _buildSessionDetail(
                    'روش ورود', _getLoginMethodText(session.loginMethod)),
                _buildSessionDetail('آدرس IP', session.ipAddress ?? 'نامشخص'),
                _buildSessionDetail(
                    'تاریخ ایجاد', _formatDateTime(session.createdAt)),
                _buildSessionDetail(
                    'تاریخ انقضا',
                    session.expiresAt != null
                        ? _formatDateTime(session.expiresAt!)
                        : 'نامحدود'),
                if (session.location != null) ...[
                  _buildSessionDetail(
                      'موقعیت', _formatLocation(session.location!)),
                ],
                if (session.browserInfo != null) ...[
                  _buildSessionDetail('مرورگر', session.browserInfo!),
                ],
                if (session.platform != null) ...[
                  _buildSessionDetail('پلتفرم', session.platform!),
                ],
                const SizedBox(height: 16),
                _buildSessionActions(session, isCurrent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceIcon(String? deviceType, bool isCurrent) {
    IconData iconData;
    Color color;

    switch (deviceType?.toLowerCase()) {
      case 'mobile':
        iconData = Icons.phone_android;
        break;
      case 'web':
        iconData = Icons.computer;
        break;
      case 'desktop':
        iconData = Icons.laptop;
        break;
      case 'tablet':
        iconData = Icons.tablet_android;
        break;
      default:
        iconData = Icons.devices;
    }

    color = isCurrent ? Colors.green : Colors.grey;
    return Icon(iconData, color: color, size: 32);
  }

  Widget _buildSessionDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionActions(ActiveSessionModel session, bool isCurrent) {
    return Row(
      children: [
        if (!isCurrent) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _terminateSession(session.id),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('خاتمه نشست'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (!session.isTrusted) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _markSessionAsTrusted(session.id),
              icon: const Icon(Icons.verified, size: 18),
              label: const Text('علامت‌گذاری قابل اعتماد'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGlobalSessionActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _terminateAllOtherSessions,
          icon: const Icon(Icons.logout),
          label: const Text('خاتمه تمام نشست‌های دیگر'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _refreshSessions,
          icon: const Icon(Icons.refresh),
          label: const Text('به‌روزرسانی نشست‌ها'),
        ),
      ],
    );
  }

  // ======================== HELPER METHODS ========================

  String _getDeviceTypeText(String? deviceType) {
    switch (deviceType?.toLowerCase()) {
      case 'mobile':
        return 'موبایل';
      case 'web':
        return 'وب';
      case 'desktop':
        return 'دسکتاپ';
      case 'tablet':
        return 'تبلت';
      default:
        return 'نامشخص';
    }
  }

  String _getLoginMethodText(String loginMethod) {
    switch (loginMethod) {
      case 'password':
        return 'رمز عبور';
      case '2fa':
        return 'تایید دو مرحله‌ای';
      case 'biometric':
        return 'احراز هویت بیومتریک';
      case 'social':
        return 'شبکه اجتماعی';
      default:
        return loginMethod;
    }
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }

  // ======================== ACTION METHODS ========================

  Future<void> _terminateSession(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تایید'),
        content:
            const Text('آیا مطمئن هستید که می‌خواهید این نشست را خاتمه دهید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تایید'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // استفاده از SessionManagementService
        final sessionService = ref.read(sessionManagementServiceProvider);
        await sessionService.terminateSession(sessionId);

        // پاک کردن کش و بارگذاری مجدد
        _invalidateSessionsProvider();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('نشست با موفقیت خاتمه یافت'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در خاتمه نشست: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markSessionAsTrusted(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تایید'),
        content: const Text(
            'آیا مطمئن هستید که می‌خواهید این نشست را به عنوان قابل اعتماد علامت‌گذاری کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تایید'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // استفاده از SessionManagementService
        final sessionService = ref.read(sessionManagementServiceProvider);
        await sessionService.markSessionAsTrusted(sessionId);

        // پاک کردن کش و بارگذاری مجدد
        _invalidateSessionsProvider();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('نشست به عنوان قابل اعتماد علامت‌گذاری شد'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در علامت‌گذاری نشست: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _terminateAllOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تایید'),
        content: const Text(
            'آیا مطمئن هستید که می‌خواهید تمام نشست‌های دیگر را خاتمه دهید؟\n\nاین کار شما را از سایر دستگاه‌ها خارج خواهد کرد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تایید'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // دریافت کاربر فعلی
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          throw Exception('کاربر وارد نشده است');
        }

        // دریافت نشست فعلی
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser == null) {
          throw Exception('کاربر وارد نشده است');
        }

        final sessionService = ref.read(sessionManagementServiceProvider);
        final sessions = await sessionService.getActiveSessions(currentUser.id);

        if (sessions.isEmpty) {
          throw Exception('هیچ نشست فعالی یافت نشد');
        }

        final currentSession = sessions.firstWhere((s) => s.isCurrent);
        await sessionService.terminateAllOtherSessions(
            user.id, currentSession.sessionToken);

        // پاک کردن کش و بارگذاری مجدد
        _invalidateSessionsProvider();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تمام نشست‌های دیگر خاتمه یافتند'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در خاتمه نشست‌ها: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _refreshSessions() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      ref.invalidate(activeSessionsProvider(currentUser.id));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('نشست‌ها به‌روزرسانی شدند'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _invalidateSessionsProvider() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      ref.invalidate(activeSessionsProvider(currentUser.id));
    }
  }

  void _handleMenuAction(String action) {
    if (action == 'test') {
      _runSecurityTest();
    } else if (action == 'optimize') {
      _optimizeSystem();
    } else if (action == 'diagnostic') {
      _runDiagnostic();
    }
  }

  Future<void> _runSecurityTest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تست امنیت'),
        content: const Text(
            'آیا مطمئن هستید که می‌خواهید امنیت سیستم را تست کنید؟ این کار ممکن است باعث تغییرات در عملکرد سیستم شود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تایید'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final testingService = ref.read(securityTestingServiceProvider);
        await testingService.runSecurityValidationTest();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تست امنیت با موفقیت انجام شد.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSystemMetrics(); // Refresh metrics after test
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در انجام تست امنیت: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _optimizeSystem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بهینه‌سازی سیستم'),
        content: const Text(
            'آیا مطمئن هستید که می‌خواهید سیستم را بهینه کنید؟ این کار ممکن است باعث تغییرات در عملکرد سیستم شود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تایید'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final testingService = ref.read(securityTestingServiceProvider);
        await testingService.optimizeSystem();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('سیستم با موفقیت بهینه شد.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSystemMetrics(); // Refresh metrics after optimization
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در بهینه‌سازی سیستم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _runDiagnostic() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تشخیص کامل سیستم'),
        content: const Text(
            'آیا مطمئن هستید که می‌خواهید تمام آمار و سیستم‌های جانبی را تشخیص دهید؟ این کار ممکن است باعث تغییرات در عملکرد سیستم شود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تایید'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final testingService = ref.read(securityTestingServiceProvider);
        await testingService.runFullDiagnostic();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تشخیص کامل سیستم با موفقیت انجام شد.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSystemMetrics(); // Refresh metrics after diagnostic
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در انجام تشخیص کامل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
