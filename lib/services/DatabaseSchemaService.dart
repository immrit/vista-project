import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

/// سرویس مدیریت ساختار دیتابیس
class DatabaseSchemaService {
  static const String _activeSessionsTable = 'active_sessions';
  static const String _securityLogsTable = 'security_logs';
  static const String _userSecurityTable = 'user_security';

  /// بررسی و ایجاد جداول مورد نیاز
  static Future<void> initializeDatabase() async {
    try {
      developer.log('🔧 شروع راه‌اندازی دیتابیس...',
          name: 'DatabaseSchemaService');

      await _createActiveSessionsTable();
      await _createSecurityLogsTable();

      developer.log('✅ راه‌اندازی دیتابیس با موفقیت انجام شد',
          name: 'DatabaseSchemaService');
    } catch (e) {
      developer.log('❌ خطا در راه‌اندازی دیتابیس: $e',
          name: 'DatabaseSchemaService');
      rethrow;
    }
  }

  /// ایجاد جدول نشست‌های فعال
  static Future<void> _createActiveSessionsTable() async {
    try {
      developer.log('🔧 بررسی وجود جدول $_activeSessionsTable...',
          name: 'DatabaseSchemaService');

      final supabase = Supabase.instance.client;

      // بررسی وجود جدول
      try {
        await supabase.from(_activeSessionsTable).select('id').limit(1);
        developer.log('✅ جدول $_activeSessionsTable از قبل موجود است',
            name: 'DatabaseSchemaService');
        return;
      } catch (e) {
        developer.log(
            '⚠️ جدول $_activeSessionsTable موجود نیست، در حال ایجاد...',
            name: 'DatabaseSchemaService');
      }

      // ایجاد جدول با استفاده از SQL
      final createTableSQL = '''
        CREATE TABLE IF NOT EXISTS $_activeSessionsTable (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
          user_id UUID NOT NULL,
          session_token TEXT NOT NULL UNIQUE,
          refresh_token_hash TEXT,
          device_type TEXT,
          device_name TEXT,
          os_name TEXT,
          os_version TEXT,
          app_version TEXT,
          ip_address TEXT,
          location JSONB,
          is_current BOOLEAN DEFAULT FALSE,
          is_trusted BOOLEAN DEFAULT FALSE,
          last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          expires_at TIMESTAMP WITH TIME ZONE,
          browser_info TEXT,
          platform TEXT,
          login_method TEXT DEFAULT 'password',
          session_metadata JSONB,
          
          -- ایجاد ایندکس‌های مورد نیاز
          CONSTRAINT fk_user_id FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
          CONSTRAINT unique_current_session_per_user UNIQUE (user_id, is_current) DEFERRABLE INITIALLY DEFERRED
        );
        
        -- ایجاد ایندکس‌ها برای بهبود عملکرد
        CREATE INDEX IF NOT EXISTS idx_active_sessions_user_id ON $_activeSessionsTable(user_id);
        CREATE INDEX IF NOT EXISTS idx_active_sessions_is_current ON $_activeSessionsTable(is_current);
        CREATE INDEX IF NOT EXISTS idx_active_sessions_last_activity ON $_activeSessionsTable(last_activity);
        CREATE INDEX IF NOT EXISTS idx_active_sessions_expires_at ON $_activeSessionsTable(expires_at);
        CREATE INDEX IF NOT EXISTS idx_active_sessions_session_token ON $_activeSessionsTable(session_token);
        
        -- ایجاد RLS (Row Level Security)
        ALTER TABLE $_activeSessionsTable ENABLE ROW LEVEL SECURITY;
        
        -- سیاست‌های امنیتی
        CREATE POLICY "Users can view their own sessions" ON $_activeSessionsTable
          FOR SELECT USING (auth.uid() = user_id);
        
        CREATE POLICY "Users can insert their own sessions" ON $_activeSessionsTable
          FOR INSERT WITH CHECK (auth.uid() = user_id);
        
        CREATE POLICY "Users can update their own sessions" ON $_activeSessionsTable
          FOR UPDATE USING (auth.uid() = user_id);
        
        CREATE POLICY "Users can delete their own sessions" ON $_activeSessionsTable
          FOR DELETE USING (auth.uid() = user_id);
      ''';

      // اجرای SQL
      await supabase.rpc('exec_sql', params: {'sql': createTableSQL});

      developer.log('✅ جدول $_activeSessionsTable با موفقیت ایجاد شد',
          name: 'DatabaseSchemaService');
    } catch (e) {
      developer.log('❌ خطا در ایجاد جدول $_activeSessionsTable: $e',
          name: 'DatabaseSchemaService');

      // تلاش با روش جایگزین - استفاده از Supabase Edge Functions
      await _createTableViaEdgeFunction(_activeSessionsTable);
    }
  }

  /// ایجاد جدول لاگ‌های امنیتی
  static Future<void> _createSecurityLogsTable() async {
    try {
      developer.log('🔧 بررسی وجود جدول $_securityLogsTable...',
          name: 'DatabaseSchemaService');

      final supabase = Supabase.instance.client;

      // بررسی وجود جدول
      try {
        await supabase.from(_securityLogsTable).select('id').limit(1);
        developer.log('✅ جدول $_securityLogsTable از قبل موجود است',
            name: 'DatabaseSchemaService');
        return;
      } catch (e) {
        developer.log('⚠️ جدول $_securityLogsTable موجود نیست، در حال ایجاد...',
            name: 'DatabaseSchemaService');
      }

      // ایجاد جدول با استفاده از SQL
      final createTableSQL = '''
        CREATE TABLE IF NOT EXISTS $_securityLogsTable (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
          user_id UUID,
          event_type TEXT NOT NULL,
          description TEXT,
          ip_address TEXT,
          device_info JSONB,
          metadata JSONB,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          
          -- ایجاد ایندکس‌های مورد نیاز
          CONSTRAINT fk_security_logs_user_id FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL
        );
        
        -- ایجاد ایندکس‌ها
        CREATE INDEX IF NOT EXISTS idx_security_logs_user_id ON $_securityLogsTable(user_id);
        CREATE INDEX IF NOT EXISTS idx_security_logs_event_type ON $_securityLogsTable(event_type);
        CREATE INDEX IF NOT EXISTS idx_security_logs_created_at ON $_securityLogsTable(created_at);
        
        -- فعال‌سازی RLS
        ALTER TABLE $_securityLogsTable ENABLE ROW LEVEL SECURITY;
        
        -- سیاست‌های امنیتی
        CREATE POLICY "Users can view their own security logs" ON $_securityLogsTable
          FOR SELECT USING (auth.uid() = user_id OR auth.uid() IS NULL);
        
        CREATE POLICY "Users can insert their own security logs" ON $_securityLogsTable
          FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.uid() IS NULL);
      ''';

      // اجرای SQL
      await supabase.rpc('exec_sql', params: {'sql': createTableSQL});

      developer.log('✅ جدول $_securityLogsTable با موفقیت ایجاد شد',
          name: 'DatabaseSchemaService');
    } catch (e) {
      developer.log('❌ خطا در ایجاد جدول $_securityLogsTable: $e',
          name: 'DatabaseSchemaService');

      // تلاش با روش جایگزین
      await _createTableViaEdgeFunction(_securityLogsTable);
    }
  }

  /// ایجاد جدول از طریق Edge Function (روش جایگزین)
  static Future<void> _createTableViaEdgeFunction(String tableName) async {
    try {
      developer.log(
          '🔄 تلاش برای ایجاد جدول $tableName از طریق Edge Function...',
          name: 'DatabaseSchemaService');

      final supabase = Supabase.instance.client;

      // فراخوانی Edge Function برای ایجاد جدول
      final response = await supabase.functions
          .invoke('create-table', body: {'table_name': tableName});

      if (response.status == 200) {
        developer.log('✅ جدول $tableName از طریق Edge Function ایجاد شد',
            name: 'DatabaseSchemaService');
      } else {
        throw Exception(
            'خطا در ایجاد جدول از طریق Edge Function: ${response.status}');
      }
    } catch (e) {
      developer.log('❌ خطا در ایجاد جدول $tableName از طریق Edge Function: $e',
          name: 'DatabaseSchemaService');
      throw Exception(
          'نمی‌توان جدول $tableName را ایجاد کرد. لطفاً با مدیر سیستم تماس بگیرید.');
    }
  }

  /// ایجاد جدول تنظیمات امنیتی کاربر
  static Future<void> _createUserSecurityTable() async {
    try {
      developer.log('🔧 بررسی وجود جدول $_userSecurityTable...',
          name: 'DatabaseSchemaService');

      final supabase = Supabase.instance.client;

      // بررسی وجود جدول
      try {
        await supabase.from(_userSecurityTable).select('id').limit(1);
        developer.log('✅ جدول $_userSecurityTable از قبل موجود است',
            name: 'DatabaseSchemaService');
        return;
      } catch (e) {
        developer.log('⚠️ جدول $_userSecurityTable موجود نیست، در حال ایجاد...',
            name: 'DatabaseSchemaService');
      }

      // ایجاد جدول با استفاده از SQL
      final createTableSQL = '''
        CREATE TABLE IF NOT EXISTS $_userSecurityTable (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
          user_id UUID NOT NULL UNIQUE,
          two_factor_enabled BOOLEAN DEFAULT FALSE,
          two_factor_secret TEXT,
          backup_codes TEXT[],
          two_factor_setup_at TIMESTAMP WITH TIME ZONE,
          app_lock_enabled BOOLEAN DEFAULT FALSE,
          app_lock_type TEXT CHECK (app_lock_type IN ('pin', 'pattern', 'biometric')),
          app_lock_hash TEXT,
          last_login_at TIMESTAMP WITH TIME ZONE,
          login_ip_address TEXT,
          device_info JSONB,
          failed_login_attempts INTEGER DEFAULT 0,
          locked_until TIMESTAMP WITH TIME ZONE,
          security_score INTEGER DEFAULT 0,
          last_security_check TIMESTAMP WITH TIME ZONE,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          
          CONSTRAINT fk_user_security_user_id FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
        );
        
        -- ایجاد ایندکس‌ها
        CREATE INDEX IF NOT EXISTS idx_user_security_user_id ON $_userSecurityTable(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_security_two_factor_enabled ON $_userSecurityTable(two_factor_enabled);
        CREATE INDEX IF NOT EXISTS idx_user_security_app_lock_enabled ON $_userSecurityTable(app_lock_enabled);
        
        -- فعال‌سازی RLS
        ALTER TABLE $_userSecurityTable ENABLE ROW LEVEL SECURITY;
        
        -- سیاست‌های امنیتی
        CREATE POLICY "Users can view their own security settings" ON $_userSecurityTable
          FOR SELECT USING (auth.uid() = user_id);
        
        CREATE POLICY "Users can insert their own security settings" ON $_userSecurityTable
          FOR INSERT WITH CHECK (auth.uid() = user_id);
        
        CREATE POLICY "Users can update their own security settings" ON $_userSecurityTable
          FOR UPDATE USING (auth.uid() = user_id);
        
        CREATE POLICY "Users can delete their own security settings" ON $_userSecurityTable
          FOR DELETE USING (auth.uid() = user_id);
      ''';

      // اجرای SQL
      await supabase.rpc('exec_sql', params: {'sql': createTableSQL});

      developer.log('✅ جدول $_userSecurityTable با موفقیت ایجاد شد',
          name: 'DatabaseSchemaService');
    } catch (e) {
      developer.log('❌ خطا در ایجاد جدول $_userSecurityTable: $e',
          name: 'DatabaseSchemaService');

      // تلاش با روش جایگزین
      await _createTableViaEdgeFunction(_userSecurityTable);
    }
  }

  /// بررسی وضعیت دیتابیس
  static Future<Map<String, dynamic>> checkDatabaseStatus() async {
    try {
      developer.log('🔍 بررسی وضعیت دیتابیس...', name: 'DatabaseSchemaService');

      final supabase = Supabase.instance.client;
      final status = <String, dynamic>{};

      // بررسی جدول نشست‌های فعال
      try {
        await supabase.from(_activeSessionsTable).select('id').limit(1);
        status['active_sessions_table'] = 'exists';
      } catch (e) {
        status['active_sessions_table'] = 'missing';
        status['active_sessions_error'] = e.toString();
      }

      // بررسی جدول لاگ‌های امنیتی
      try {
        await supabase.from(_securityLogsTable).select('id').limit(1);
        status['security_logs_table'] = 'exists';
      } catch (e) {
        status['security_logs_table'] = 'missing';
        status['security_logs_error'] = e.toString();
      }

      // بررسی اتصال کلی
      try {
        await supabase.from('profiles').select('id').limit(1);
        status['connection'] = 'ok';
      } catch (e) {
        status['connection'] = 'error';
        status['connection_error'] = e.toString();
      }

      // بررسی جدول تنظیمات امنیتی کاربر
      try {
        await supabase.from(_userSecurityTable).select('id').limit(1);
        status['user_security_table'] = 'exists';
      } catch (e) {
        status['user_security_table'] = 'missing';
        status['user_security_error'] = e.toString();
      }

      status['timestamp'] = DateTime.now().toIso8601String();

      developer.log('✅ بررسی وضعیت دیتابیس تکمیل شد',
          name: 'DatabaseSchemaService');
      return status;
    } catch (e) {
      developer.log('❌ خطا در بررسی وضعیت دیتابیس: $e',
          name: 'DatabaseSchemaService');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// پاک کردن و بازسازی جداول (فقط برای توسعه)
  static Future<void> resetDatabase() async {
    try {
      developer.log('🔄 شروع بازسازی دیتابیس...',
          name: 'DatabaseSchemaService');

      final supabase = Supabase.instance.client;

      // حذف جداول موجود
      try {
        await supabase.rpc('exec_sql', params: {
          'sql': 'DROP TABLE IF EXISTS $_activeSessionsTable CASCADE;'
        });
        await supabase.rpc('exec_sql', params: {
          'sql': 'DROP TABLE IF EXISTS $_securityLogsTable CASCADE;'
        });
        await supabase.rpc('exec_sql', params: {
          'sql': 'DROP TABLE IF EXISTS $_userSecurityTable CASCADE;'
        });
        developer.log('✅ جداول قدیمی حذف شدند', name: 'DatabaseSchemaService');
      } catch (e) {
        developer.log('⚠️ خطا در حذف جداول قدیمی: $e',
            name: 'DatabaseSchemaService');
      }

      // ایجاد مجدد جداول
      await _createActiveSessionsTable();
      await _createSecurityLogsTable();
      await _createUserSecurityTable();

      developer.log('✅ دیتابیس با موفقیت بازسازی شد',
          name: 'DatabaseSchemaService');
    } catch (e) {
      developer.log('❌ خطا در بازسازی دیتابیس: $e',
          name: 'DatabaseSchemaService');
      rethrow;
    }
  }
}
