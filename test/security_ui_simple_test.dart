import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Vista/model/SecurityModels.dart';

void main() {
  group('Security UI Simple Tests', () {
    group('Session List Item Tests', () {
      testWidgets('should display session information correctly',
          (WidgetTester tester) async {
        final mockSession = ActiveSessionModel(
          id: 'test_session_id',
          userId: 'test_user_id',
          sessionToken: 'test_token',
          deviceType: 'Mobile',
          deviceName: 'iPhone 13',
          osName: 'iOS',
          osVersion: '15.0',
          ipAddress: '192.168.1.100',
          isCurrent: true,
          lastActivity: DateTime.now(),
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          loginMethod: 'password',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _buildSessionListItem(mockSession),
            ),
          ),
        );

        // Verify session information is displayed
        expect(find.text('iPhone 13'), findsOneWidget);
        expect(find.text('iOS 15.0'), findsOneWidget);
        expect(find.text('192.168.1.100'), findsOneWidget);
        expect(find.text('نشست فعلی'), findsOneWidget);
      });

      testWidgets('should display trusted session indicator',
          (WidgetTester tester) async {
        final mockSession = ActiveSessionModel(
          id: 'test_session_id',
          userId: 'test_user_id',
          sessionToken: 'test_token',
          deviceType: 'Mobile',
          deviceName: 'Trusted Device',
          osName: 'Android',
          osVersion: '12.0',
          ipAddress: '192.168.1.101',
          isCurrent: false,
          lastActivity: DateTime.now(),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          loginMethod: 'password',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _buildSessionListItem(mockSession),
            ),
          ),
        );

        // Verify trusted session is displayed
        expect(find.text('Trusted Device'), findsOneWidget);
        expect(find.text('Android 12.0'), findsOneWidget);
        expect(find.text('192.168.1.101'), findsOneWidget);
      });

      testWidgets('should display action buttons', (WidgetTester tester) async {
        final mockSession = ActiveSessionModel(
          id: 'test_session_id',
          userId: 'test_user_id',
          sessionToken: 'test_token',
          deviceType: 'Desktop',
          deviceName: 'Work Computer',
          osName: 'Windows',
          osVersion: '11.0',
          ipAddress: '192.168.1.102',
          isCurrent: false,
          lastActivity: DateTime.now(),
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          loginMethod: '2fa',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _buildSessionListItem(mockSession),
            ),
          ),
        );

        // Verify action buttons are displayed
        expect(find.text('اعتماد'), findsOneWidget);
        expect(find.text('قطع اتصال'), findsOneWidget);
      });
    });

    group('System Metrics Card Tests', () {
      testWidgets('should display metrics correctly',
          (WidgetTester tester) async {
        final mockMetrics = {
          'activeSessions': 3,
          'totalSessions': 5,
          'securityScore': 85,
          'lastActivity': DateTime.now(),
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _buildSystemMetricsCard(mockMetrics),
            ),
          ),
        );

        // Verify metrics are displayed
        expect(find.text('آمار سیستم'), findsOneWidget);
        expect(find.text('3'), findsOneWidget); // activeSessions
        expect(find.text('5'), findsOneWidget); // totalSessions
        expect(find.text('85'), findsOneWidget); // securityScore
      });

      testWidgets('should handle zero values', (WidgetTester tester) async {
        final mockMetrics = {
          'activeSessions': 0,
          'totalSessions': 0,
          'securityScore': 0,
          'lastActivity': DateTime.now(),
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _buildSystemMetricsCard(mockMetrics),
            ),
          ),
        );

        // Verify zero values are displayed
        expect(find.text('0'), findsNWidgets(3));
      });

      testWidgets('should display metric icons', (WidgetTester tester) async {
        final mockMetrics = {
          'activeSessions': 1,
          'totalSessions': 1,
          'securityScore': 1,
          'lastActivity': DateTime.now(),
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _buildSystemMetricsCard(mockMetrics),
            ),
          ),
        );

        // Verify icons are displayed
        expect(find.byIcon(Icons.devices), findsOneWidget);
        expect(find.byIcon(Icons.history), findsOneWidget);
        expect(find.byIcon(Icons.security), findsOneWidget);
      });
    });

    group('Security Log Item Tests', () {
      testWidgets('should display security log information',
          (WidgetTester tester) async {
        final mockLog = SecurityLogModel(
          id: 'test_log_id',
          userId: 'test_user_id',
          eventType: 'login_success',
          description: 'User logged in successfully from new device',
          ipAddress: '192.168.1.100',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _buildSecurityLogItem(mockLog),
            ),
          ),
        );

        // Verify log information is displayed
        expect(find.text('login_success'), findsOneWidget);
        expect(find.text('User logged in successfully from new device'),
            findsOneWidget);
        expect(find.text('192.168.1.100'), findsOneWidget);
      });

      testWidgets('should handle different event types',
          (WidgetTester tester) async {
        final eventTypes = [
          'login_success',
          'login_failed',
          'session_created',
          'session_terminated',
          'two_factor_enabled',
          'two_factor_disabled',
          'password_changed',
          'suspicious_activity',
        ];

        for (final eventType in eventTypes) {
          final mockLog = SecurityLogModel(
            id: 'test_log_id',
            userId: 'test_user_id',
            eventType: eventType,
            description: 'Test event: $eventType',
            ipAddress: '127.0.0.1',
            createdAt: DateTime.now(),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: _buildSecurityLogItem(mockLog),
              ),
            ),
          );

          // Verify event type is displayed
          expect(find.text(eventType), findsOneWidget);
          expect(find.text('Test event: $eventType'), findsOneWidget);
        }
      });
    });

    group('User Security Settings Tests', () {
      testWidgets('should display security settings',
          (WidgetTester tester) async {
        final mockSettings = UserSecurityModel(
          id: 'test_id',
          userId: 'test_user_id',
          twoFactorEnabled: true,
          loginAttempts: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _buildSecuritySettingsCard(mockSettings),
            ),
          ),
        );

        // Verify settings are displayed
        expect(find.text('تنظیمات امنیتی'), findsOneWidget);
        expect(find.text('احراز هویت دو مرحله‌ای'), findsOneWidget);
        expect(find.text('تلاش‌های ورود'), findsOneWidget);
      });

      testWidgets('should display enabled/disabled status',
          (WidgetTester tester) async {
        final mockSettings = UserSecurityModel(
          id: 'test_id',
          userId: 'test_user_id',
          twoFactorEnabled: true,
          loginAttempts: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _buildSecuritySettingsCard(mockSettings),
            ),
          ),
        );

        // Verify status indicators
        expect(find.text('فعال'), findsOneWidget); // 2FA
        expect(find.text('0'), findsOneWidget); // Login attempts
      });
    });
  });
}

// Helper method to build session list item widget
Widget _buildSessionListItem(ActiveSessionModel session) {
  return Card(
    margin: const EdgeInsets.all(8.0),
    child: ListTile(
      title: Text(session.deviceName ?? 'Unknown Device'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${session.osName} ${session.osVersion}'),
          Text(session.ipAddress ?? 'Unknown IP'),
          if (session.isCurrent)
            const Text('نشست فعلی', style: TextStyle(color: Colors.green)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!session.isCurrent) ...[
            ElevatedButton(
              onPressed: () {},
              child: const Text('اعتماد'),
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('قطع اتصال'),
          ),
        ],
      ),
    ),
  );
}

// Helper method to build system metrics card widget
Widget _buildSystemMetricsCard(Map<String, dynamic> metrics) {
  return Card(
    margin: const EdgeInsets.all(16.0),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'آمار سیستم',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'نشست‌های فعال',
                  '${metrics['activeSessions']}',
                  Icons.devices,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'کل نشست‌ها',
                  '${metrics['totalSessions']}',
                  Icons.history,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'امتیاز امنیتی',
                  '${metrics['securityScore']}',
                  Icons.security,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// Helper method to build metric item widget
Widget _buildMetricItem(String label, String value, IconData icon) {
  return Column(
    children: [
      Icon(icon, size: 32, color: Colors.blue),
      const SizedBox(height: 8),
      Text(
        value,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

// Helper method to build security log item widget
Widget _buildSecurityLogItem(SecurityLogModel log) {
  return Card(
    margin: const EdgeInsets.all(8.0),
    child: ListTile(
      title: Text(log.eventType),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(log.description ?? ''),
          Text(log.ipAddress ?? 'Unknown IP'),
          Text(log.createdAt.toString()),
        ],
      ),
      leading: Icon(
        _getEventIcon(log.eventType),
        color: _getEventColor(log.eventType),
      ),
    ),
  );
}

// Helper method to build security settings card widget
Widget _buildSecuritySettingsCard(UserSecurityModel settings) {
  return Card(
    margin: const EdgeInsets.all(16.0),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تنظیمات امنیتی',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingItem(
            'احراز هویت دو مرحله‌ای',
            settings.twoFactorEnabled ? 'فعال' : 'غیرفعال',
            Icons.security,
            settings.twoFactorEnabled ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 8),
          _buildSettingItem(
            'تلاش‌های ورود',
            '${settings.loginAttempts ?? 0}',
            Icons.warning,
            (settings.loginAttempts ?? 0) > 0 ? Colors.orange : Colors.green,
          ),
        ],
      ),
    ),
  );
}

// Helper method to build setting item widget
Widget _buildSettingItem(
    String label, String value, IconData icon, Color color) {
  return Row(
    children: [
      Icon(icon, color: color),
      const SizedBox(width: 16),
      Expanded(child: Text(label)),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

// Helper method to get event icon
IconData _getEventIcon(String eventType) {
  switch (eventType) {
    case 'login_success':
      return Icons.check_circle;
    case 'login_failed':
      return Icons.error;
    case 'session_created':
      return Icons.add_circle;
    case 'session_terminated':
      return Icons.remove_circle;
    case 'two_factor_enabled':
      return Icons.security;
    case 'two_factor_disabled':
      return Icons.security;
    case 'password_changed':
      return Icons.lock;
    case 'suspicious_activity':
      return Icons.warning;
    default:
      return Icons.info;
  }
}

// Helper method to get event color
Color _getEventColor(String eventType) {
  switch (eventType) {
    case 'login_success':
    case 'session_created':
    case 'two_factor_enabled':
    case 'password_changed':
      return Colors.green;
    case 'login_failed':
    case 'session_terminated':
    case 'two_factor_disabled':
      return Colors.red;
    case 'suspicious_activity':
      return Colors.orange;
    default:
      return Colors.blue;
  }
}
