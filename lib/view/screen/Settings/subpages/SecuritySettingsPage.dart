import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../provider/security_provider.dart';
import '../../../../model/SecurityModels.dart';
import '../widgets/SettingsLoadingWidget.dart';

// ویجت خطا که در کد استفاده شده
class SettingsErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const SettingsErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('تلاش مجدد'),
            ),
          ],
        ],
      ),
    );
  }
}

class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityAsync = ref.watch(securityNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('امنیت حساب'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF252525) : Colors.white,
      ),
      body: securityAsync.when(
        loading: () => const Center(
          child: SettingsLoadingWidget(
              message: 'در حال بارگذاری تنظیمات امنیت...'),
        ),
        error: (error, _) => Center(
          child: SettingsErrorWidget(
            message: 'خطا در بارگذاری تنظیمات امنیت',
            onRetry: () => ref.refresh(securityNotifierProvider),
          ),
        ),
        data: (security) => _buildSecurityContent(context, ref, security),
      ),
    );
  }

  Widget _buildSecurityContent(
      BuildContext context, WidgetRef ref, UserSecurityModel? security) {
    if (security == null) {
      return const Center(
        child: SettingsErrorWidget(message: 'اطلاعات امنیتی یافت نشد'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final _ = ref.refresh(securityNotifierProvider);
        final __ = ref.refresh(securityScoreProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // امتیاز امنیت
          _buildSecurityScore(context, ref),

          const SizedBox(height: 20),

          // تایید دو مرحله‌ای
          _buildTwoFactorSection(context, ref, security),

          const SizedBox(height: 20),

          // قفل اپلیکیشن
          _buildAppLockSection(context, ref, security),

          const SizedBox(height: 20),

          // جلسات فعال
          _buildActiveSessionsSection(context, ref),

          const SizedBox(height: 20),

          // تاریخچه امنیت
          _buildSecurityLogsSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildSecurityScore(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(securityScoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Text(
                  'امتیاز امنیت',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            scoreAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('خطا در محاسبه امتیاز'),
              data: (score) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: score / 100,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getScoreColor(score),
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$score%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(score),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getScoreColor(score).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getScoreLabel(score),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getScoreColor(score),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  Widget _buildTwoFactorSection(
      BuildContext context, WidgetRef ref, UserSecurityModel security) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SecuritySwitchTile(
            icon: Icons.verified_user,
            iconColor: Colors.green,
            title: 'تایید دو مرحله‌ای',
            subtitle: security.twoFactorEnabled
                ? 'حساب شما محافظت اضافی دارد'
                : 'افزایش امنیت با کد تایید',
            value: security.twoFactorEnabled,
            onChanged: (value) => _handleTwoFactorToggle(context, ref, value),
          ),
          if (security.twoFactorEnabled) ...[
            const Divider(height: 1, indent: 68),
            SecurityListTile(
              icon: Icons.backup,
              iconColor: Colors.orange,
              title: 'کدهای پشتیبان',
              subtitle: '${security.backupCodes?.length ?? 0} کد موجود',
              onTap: () =>
                  _showBackupCodes(context, security.backupCodes ?? []),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppLockSection(
      BuildContext context, WidgetRef ref, UserSecurityModel security) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SecuritySwitchTile(
            icon: Icons.phone_locked,
            iconColor: Colors.red,
            title: 'قفل اپلیکیشن',
            subtitle: security.appLockEnabled
                ? 'برنامه با ${_getAppLockTypeLabel(security.appLockType)} قفل است'
                : 'قفل کردن برنامه هنگام باز شدن',
            value: security.appLockEnabled,
            onChanged: (value) =>
                _handleAppLockToggle(context, ref, value, security),
          ),
          if (security.appLockEnabled) ...[
            const Divider(height: 1, indent: 68),
            SecurityListTile(
              icon: Icons.edit,
              iconColor: Colors.blue,
              title: 'تغییر PIN',
              subtitle: 'تغییر کد عبور قفل اپلیکیشن',
              onTap: () => _changePIN(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveSessionsSection(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SecurityListTile(
        icon: Icons.devices,
        iconColor: Colors.purple,
        title: 'جلسات فعال',
        subtitle: 'مدیریت دستگاه‌های متصل به حساب',
        onTap: () => _showActiveSessions(context, ref),
      ),
    );
  }

  Widget _buildSecurityLogsSection(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SecurityListTile(
        icon: Icons.history,
        iconColor: Colors.teal,
        title: 'تاریخچه امنیت',
        subtitle: 'مشاهده فعالیت‌های امنیتی اخیر',
        onTap: () => _showSecurityLogs(context, ref),
      ),
    );
  }

  // ======================== HELPER METHODS ========================

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'عالی';
    if (score >= 60) return 'متوسط';
    return 'ضعیف';
  }

  String _getAppLockTypeLabel(String? type) {
    switch (type) {
      case 'pin':
        return 'PIN';
      case 'pattern':
        return 'الگو';
      case 'biometric':
        return 'اثر انگشت';
      default:
        return 'PIN';
    }
  }

  // ======================== EVENT HANDLERS ========================

  Future<void> _handleTwoFactorToggle(
      BuildContext context, WidgetRef ref, bool value) async {
    if (value) {
      final confirmed = await _showTwoFactorSetupDialog(context);
      if (!confirmed) return;
    } else {
      final confirmed = await _showTwoFactorDisableDialog(context);
      if (!confirmed) return;
    }

    try {
      await ref.read(securityNotifierProvider.notifier).toggleTwoFactor(value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'تایید دو مرحله‌ای فعال شد'
              : 'تایید دو مرحله‌ای غیرفعال شد'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleAppLockToggle(BuildContext context, WidgetRef ref,
      bool value, UserSecurityModel security) async {
    if (value) {
      final pin = await _showPINSetupDialog(context);
      if (pin == null) return;

      try {
        await ref.read(securityNotifierProvider.notifier).toggleAppLock(
              enabled: true,
              lockType: 'pin',
              pin: pin,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('قفل اپلیکیشن فعال شد'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      final confirmed = await _showAppLockDisableDialog(context);
      if (!confirmed) return;

      try {
        await ref
            .read(securityNotifierProvider.notifier)
            .toggleAppLock(enabled: false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('قفل اپلیکیشن غیرفعال شد'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ======================== DIALOGS ========================

  Future<bool> _showTwoFactorSetupDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('فعال‌سازی تایید دو مرحله‌ای'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.security, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'با فعال کردن تایید دو مرحله‌ای، امنیت حساب شما به طور قابل توجهی افزایش می‌یابد.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'کدهای پشتیبان برای شما تولید خواهد شد که باید آن‌ها را در جای امنی نگهداری کنید.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('فعال‌سازی'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showTwoFactorDisableDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('غیرفعال‌سازی تایید دو مرحله‌ای'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, size: 64, color: Colors.orange),
                SizedBox(height: 16),
                Text(
                  'آیا مطمئن هستید که می‌خواهید تایید دو مرحله‌ای را غیرفعال کنید؟',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'این عمل امنیت حساب شما را کاهش می‌دهد.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('غیرفعال‌سازی',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _showPINSetupDialog(BuildContext context) async {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنظیم PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN (۴-۶ رقم)',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.length < 4) {
                    return 'PIN باید حداقل ۴ رقم باشد';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'تکرار PIN',
                  counterText: '',
                ),
                validator: (value) {
                  if (value != pinController.text) {
                    return 'PIN ها مطابقت ندارند';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, pinController.text);
              }
            },
            child: const Text('تایید'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showAppLockDisableDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('غیرفعال‌سازی قفل اپلیکیشن'),
            content: const Text(
                'آیا مطمئن هستید که می‌خواهید قفل اپلیکیشن را غیرفعال کنید؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('غیرفعال‌سازی'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showBackupCodes(BuildContext context, List<String> codes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('کدهای پشتیبان'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'این کدها را در جای امنی نگهداری کنید. هر کد فقط یک بار قابل استفاده است.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                child: ListView.builder(
                  itemCount: codes.length,
                  itemBuilder: (context, index) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            codes[index],
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: codes[index]));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('کد کپی شد')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

  void _showActiveSessions(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActiveSessionsScreen(),
      ),
    );
  }

  void _showSecurityLogs(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecurityLogsScreen(),
      ),
    );
  }

  Future<void> _changePIN(BuildContext context, WidgetRef ref) async {
    final newPin = await _showPINSetupDialog(context);
    if (newPin == null) return;

    try {
      await ref.read(securityNotifierProvider.notifier).toggleAppLock(
            enabled: true,
            lockType: 'pin',
            pin: newPin,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN با موفقیت تغییر کرد'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در تغییر PIN: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ======================== WIDGETS ========================

class SecuritySwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const SecuritySwitchTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }
}

class SecurityListTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SecurityListTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================== SEPARATE SCREENS ========================

class ActiveSessionsScreen extends ConsumerWidget {
  const ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(activeSessionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('جلسات فعال'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => _terminateAllSessions(context, ref),
            child: const Text('خاتمه همه'),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('خطا: $error')),
        data: (sessions) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) =>
              _buildSessionCard(context, ref, sessions[index]),
        ),
      ),
    );
  }

  Widget _buildSessionCard(
      BuildContext context, WidgetRef ref, ActiveSessionModel session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(session.deviceIcon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        session.deviceName ?? 'دستگاه ناشناس',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (session.isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'فعلی',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.osName ?? ''} • آخرین فعالیت: ${_formatTime(session.lastActivity)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (!session.isCurrent)
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                onPressed: () => _terminateSession(context, ref, session.id),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
    return '${diff.inDays} روز پیش';
  }

  Future<void> _terminateSession(
      BuildContext context, WidgetRef ref, String sessionId) async {
    try {
      final securityService = ref.read(securityServiceProvider);
      await securityService.terminateSession(sessionId);
      final _ = ref.refresh(activeSessionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جلسه خاتمه یافت')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
    }
  }

  Future<void> _terminateAllSessions(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خاتمه همه جلسات'),
        content:
            const Text('آیا مطمئن هستید؟ همه دستگاه‌های دیگر قطع خواهند شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تایید'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final securityService = ref.read(securityServiceProvider);
        await securityService.terminateAllOtherSessions();
        final _ = ref.refresh(activeSessionsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('همه جلسات خاتمه یافت')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    }
  }
}

class SecurityLogsScreen extends ConsumerWidget {
  const SecurityLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(securityLogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('تاریخچه امنیت'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('خطا: $error')),
        data: (logs) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) => _buildLogCard(context, logs[index]),
        ),
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, SecurityLogModel log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(log.eventIcon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.eventTitle,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (log.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      log.description!,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              _formatLogTime(log.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLogTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) return '${diff.inMinutes}د';
    if (diff.inHours < 24) return '${diff.inHours}س';
    if (diff.inDays < 7) return '${diff.inDays}ر';
    return '${time.day}/${time.month}';
  }
}
