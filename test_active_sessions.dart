import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // راه‌اندازی Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Active Sessions Test',
      home: ActiveSessionsTestPage(),
    );
  }
}

class ActiveSessionsTestPage extends StatefulWidget {
  @override
  _ActiveSessionsTestPageState createState() => _ActiveSessionsTestPageState();
}

class _ActiveSessionsTestPageState extends State<ActiveSessionsTestPage> {
  final _results = <String>[];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Active Sessions Test'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _runAllTests,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _testTableExists,
                  child: Text('Test Table Exists'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _testInsertSession,
                  child: Text('Test Insert Session'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _testRLSPolicies,
                  child: Text('Test RLS Policies'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                final isError =
                    result.contains('❌') || result.contains('Error');
                return ListTile(
                  title: Text(
                    result,
                    style: TextStyle(
                      color: isError ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addResult(String result) {
    setState(() {
      _results.insert(
          0, '${DateTime.now().toString().substring(11, 19)}: $result');
    });
    print(result);
  }

  Future<void> _runAllTests() async {
    setState(() {
      _results.clear();
      _isLoading = true;
    });

    try {
      await _testTableExists();
      await Future.delayed(Duration(seconds: 1));

      await _testRLSPolicies();
      await Future.delayed(Duration(seconds: 1));

      await _testInsertSession();
      await Future.delayed(Duration(seconds: 1));

      await _testForeignKeys();
      await Future.delayed(Duration(seconds: 1));

      await _testSessionCreation();
    } catch (e) {
      _addResult('❌ Error running tests: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testTableExists() async {
    try {
      _addResult('🔍 Testing table existence...');

      final supabase = Supabase.instance.client;

      // تست 1: بررسی وجود جدول
      try {
        final result =
            await supabase.from('active_sessions').select('id').limit(1);

        _addResult('✅ Table exists and accessible');
        _addResult('📊 Table has ${result.length} rows');
      } catch (e) {
        _addResult('❌ Table access error: $e');
        return;
      }

      // تست 2: بررسی ساختار جدول
      try {
        final result =
            await supabase.from('active_sessions').select('*').limit(1);

        if (result.isNotEmpty) {
          final columns = result.first.keys.toList();
          _addResult('📋 Table columns: ${columns.join(', ')}');
        }
      } catch (e) {
        _addResult('❌ Error reading table structure: $e');
      }
    } catch (e) {
      _addResult('❌ Error in table existence test: $e');
    }
  }

  Future<void> _testRLSPolicies() async {
    try {
      _addResult('🔒 Testing RLS policies...');

      final supabase = Supabase.instance.client;

      // تست 1: بررسی RLS فعال بودن
      try {
        final result = await supabase
            .rpc('check_rls_status', params: {'table_name': 'active_sessions'});
        _addResult('✅ RLS status: $result');
      } catch (e) {
        _addResult('⚠️ Could not check RLS status: $e');
      }

      // تست 2: بررسی سیاست‌های موجود
      try {
        final policies = await supabase
            .from('pg_policies')
            .select('*')
            .eq('tablename', 'active_sessions');

        _addResult('📋 Found ${policies.length} RLS policies');

        for (final policy in policies) {
          _addResult('   - ${policy['policyname']}: ${policy['cmd']}');
        }
      } catch (e) {
        _addResult('⚠️ Could not check policies: $e');
      }
    } catch (e) {
      _addResult('❌ Error in RLS test: $e');
    }
  }

  Future<void> _testInsertSession() async {
    try {
      _addResult('📝 Testing session insertion...');

      final supabase = Supabase.instance.client;

      // تست 1: درج نشست ساده
      try {
        final testSession = {
          'user_id': '00000000-0000-0000-0000-000000000000', // UUID تست
          'session_token': 'test_${DateTime.now().millisecondsSinceEpoch}',
          'device_type': 'test',
          'is_current': false,
        };

        final result =
            await supabase.from('active_sessions').insert(testSession).select();

        _addResult('✅ Test session inserted successfully');
        _addResult('📊 Inserted session ID: ${result.first['id']}');

        // حذف نشست تست
        await supabase
            .from('active_sessions')
            .delete()
            .eq('id', result.first['id']);

        _addResult('🗑️ Test session cleaned up');
      } catch (e) {
        _addResult('❌ Error inserting test session: $e');

        // بررسی جزئیات خطا
        if (e.toString().contains('foreign key')) {
          _addResult('🔗 Foreign key constraint error detected');
        }
        if (e.toString().contains('not null')) {
          _addResult('📝 Not null constraint error detected');
        }
        if (e.toString().contains('unique')) {
          _addResult('🔑 Unique constraint error detected');
        }
      }
    } catch (e) {
      _addResult('❌ Error in insertion test: $e');
    }
  }

  Future<void> _testForeignKeys() async {
    try {
      _addResult('🔗 Testing foreign key constraints...');

      final supabase = Supabase.instance.client;

      // تست 1: بررسی constraint های foreign key
      try {
        final constraints = await supabase
            .from('information_schema.table_constraints')
            .select('*')
            .eq('table_name', 'active_sessions')
            .eq('constraint_type', 'FOREIGN KEY');

        _addResult('📋 Found ${constraints.length} foreign key constraints');

        for (final constraint in constraints) {
          _addResult('   - ${constraint['constraint_name']}');
        }
      } catch (e) {
        _addResult('⚠️ Could not check foreign key constraints: $e');
      }

      // تست 2: بررسی جدول auth.users
      try {
        final usersCheck =
            await supabase.from('auth.users').select('id').limit(1);

        _addResult('✅ Auth users table accessible');
      } catch (e) {
        _addResult('❌ Auth users table not accessible: $e');
      }
    } catch (e) {
      _addResult('❌ Error in foreign key test: $e');
    }
  }

  Future<void> _testSessionCreation() async {
    try {
      _addResult('🚀 Testing full session creation...');

      final supabase = Supabase.instance.client;

      // دریافت اطلاعات دستگاه
      final deviceInfo = await _getDeviceInfo();
      final packageInfo = await PackageInfo.fromPlatform();
      final locationInfo = await _getLocationInfo();

      _addResult('📱 Device info collected: ${deviceInfo['platform']}');

      // ایجاد نشست کامل
      try {
        final sessionData = {
          'user_id': '00000000-0000-0000-0000-000000000000',
          'session_token': 'full_test_${DateTime.now().millisecondsSinceEpoch}',
          'device_type': deviceInfo['device_type'],
          'device_name': deviceInfo['device_name'],
          'os_name': deviceInfo['os_name'],
          'os_version': deviceInfo['os_version'],
          'app_version': '${packageInfo.version}+${packageInfo.buildNumber}',
          'platform': deviceInfo['platform'],
          'login_method': 'test',
          'is_current': false,
          'is_trusted': false,
          'last_activity': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'expires_at':
              DateTime.now().add(Duration(days: 30)).toIso8601String(),
          'ip_address': locationInfo['ip_address'],
          'location': locationInfo['location'],
          'session_metadata': {
            'created_via': 'test_app',
            'device_id': deviceInfo['device_id'],
            'test_mode': true,
          },
        };

        final result =
            await supabase.from('active_sessions').insert(sessionData).select();

        _addResult('✅ Full session created successfully');
        _addResult('📊 Session ID: ${result.first['id']}');
        _addResult('🔑 Session Token: ${result.first['session_token']}');

        // حذف نشست تست
        await supabase
            .from('active_sessions')
            .delete()
            .eq('id', result.first['id']);

        _addResult('🗑️ Test session cleaned up');
      } catch (e) {
        _addResult('❌ Error creating full session: $e');

        // تحلیل خطا
        _analyzeError(e.toString());
      }
    } catch (e) {
      _addResult('❌ Error in session creation test: $e');
    }
  }

  void _analyzeError(String error) {
    if (error.contains('foreign key')) {
      _addResult('🔗 Foreign key constraint issue');
    }
    if (error.contains('not null')) {
      _addResult('📝 Missing required field');
    }
    if (error.contains('unique')) {
      _addResult('🔑 Duplicate value constraint');
    }
    if (error.contains('check')) {
      _addResult('✅ Check constraint violation');
    }
    if (error.contains('RLS')) {
      _addResult('🔒 Row Level Security policy violation');
    }
    if (error.contains('permission')) {
      _addResult('🚫 Permission denied');
    }
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final Map<String, String> info = {};

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info['platform'] = 'android';
        info['device_type'] = 'mobile';
        info['device_name'] = androidInfo.model;
        info['os_name'] = 'Android';
        info['os_version'] = androidInfo.version.release;
        info['device_id'] = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info['platform'] = 'ios';
        info['device_type'] = 'mobile';
        info['device_name'] = iosInfo.model;
        info['os_name'] = 'iOS';
        info['os_version'] = iosInfo.systemVersion;
        info['device_id'] = iosInfo.identifierForVendor ?? 'unknown';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        info['platform'] = 'windows';
        info['device_type'] = 'desktop';
        info['device_name'] = windowsInfo.computerName;
        info['os_name'] = 'Windows';
        info['os_version'] = windowsInfo.buildNumber.toString();
        info['device_id'] = windowsInfo.deviceId;
      } else {
        info['platform'] = 'unknown';
        info['device_type'] = 'unknown';
        info['device_name'] = 'Unknown Device';
        info['os_name'] = 'Unknown OS';
        info['os_version'] = 'Unknown Version';
        info['device_id'] = 'unknown';
      }

      return info;
    } catch (e) {
      return {
        'platform': 'unknown',
        'device_type': 'unknown',
        'device_name': 'Unknown Device',
        'os_name': 'Unknown OS',
        'os_version': 'Unknown Version',
        'device_id': 'unknown',
      };
    }
  }

  Future<Map<String, dynamic>> _getLocationInfo() async {
    try {
      final response = await http.get(Uri.parse('http://ip-api.com/json/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'ip_address': data['query'] ?? 'unknown',
          'location': {
            'city': data['city'] ?? '',
            'region': data['regionName'] ?? '',
            'country': data['country'] ?? '',
            'timezone': data['timezone'] ?? '',
            'isp': data['isp'] ?? '',
          },
        };
      }
    } catch (e) {
      // ignore
    }

    return {
      'ip_address': 'unknown',
      'location': {
        'city': '',
        'region': '',
        'country': '',
        'timezone': '',
        'isp': '',
      },
    };
  }
}
