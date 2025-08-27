import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
                  child: Text('Test Table'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _testInsertSession,
                  child: Text('Test Insert'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _testRLSPolicies,
                  child: Text('Test RLS'),
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
        final result = await supabase.rpc('check_rls_status',
            params: {'p_table_name': 'active_sessions'});
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
        if (e.toString().contains('RLS')) {
          _addResult('🔒 Row Level Security policy violation');
        }
        if (e.toString().contains('permission')) {
          _addResult('🚫 Permission denied');
        }
      }
    } catch (e) {
      _addResult('❌ Error in insertion test: $e');
    }
  }
}
