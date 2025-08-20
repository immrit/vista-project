import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../security/totp_service.dart';

class TwoFactorTestScreen extends ConsumerStatefulWidget {
  const TwoFactorTestScreen({super.key});

  @override
  ConsumerState<TwoFactorTestScreen> createState() =>
      _TwoFactorTestScreenState();
}

class _TwoFactorTestScreenState extends ConsumerState<TwoFactorTestScreen> {
  String? _testSecret;
  String? _currentCode;
  String? _testResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    try {
      // تست 1: تولید سکرت
      debugPrint('🧪 شروع تست TOTP...');
      final secret = TOTPService.generateSecret();
      debugPrint('🧪 سکرت تولید شد: $secret');

      // تست 2: تولید کد
      final code = TOTPService.generateCode(secret);
      debugPrint('🧪 کد تولید شد: $code');

      // تست 3: تایید کد
      final isValid = TOTPService.verifyCode(secret, code);
      debugPrint('🧪 تایید کد: $isValid');

      // تست 4: تست کامل TOTP
      final testResult = TOTPService.testTOTP(secret);
      debugPrint('🧪 نتیجه تست: $testResult');

      // تست 5: تولید QR Data
      final qrData = TOTPService.generateQRCodeData(
        secret: secret,
        accountName: 'test@vista.app',
        issuer: 'Vista',
      );
      debugPrint('🧪 QR Data: $qrData');

      setState(() {
        _testSecret = secret;
        _currentCode = code;
        _testResult = '''
🧪 تست TOTP کامل شد!

📋 سکرت: $secret
🔐 کد فعلی: $code
✅ تایید کد: $isValid
🔍 طول سکرت: ${secret.length}
🌐 Base32 معتبر: ${TOTPService.isValidSecret(secret)}
⏰ زمان باقی‌مانده: ${TOTPService.getTimeRemaining()}s

📱 QR Data:
$qrData

📊 جزئیات تست:
${testResult.entries.map((e) => '${e.key}: ${e.value}').join('\n')}
''';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ خطا در تست: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تست تایید دو مرحله‌ای'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runTest,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // کارت اطلاعات
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'اطلاعات تست',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_testSecret != null) ...[
                      _buildInfoRow('سکرت', _testSecret!),
                      _buildInfoRow('طول سکرت', '${_testSecret!.length}'),
                      _buildInfoRow('Base32 معتبر',
                          '${TOTPService.isValidSecret(_testSecret!)}'),
                    ],
                    if (_currentCode != null) ...[
                      _buildInfoRow('کد فعلی', _currentCode!),
                      _buildInfoRow('زمان باقی‌مانده',
                          '${TOTPService.getTimeRemaining()}s'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // دکمه تست
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _runTest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('در حال تست...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow),
                          SizedBox(width: 8),
                          Text('اجرای تست'),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // نتیجه تست
            if (_testResult != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assessment,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'نتیجه تست',
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          _testResult!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // راهنمای عیب‌یابی
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'راهنمای عیب‌یابی',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTroubleshootingItem(
                      'کد تولید نمی‌شود',
                      'بررسی کنید که سکرت Base32 معتبر باشد',
                    ),
                    _buildTroubleshootingItem(
                      'QR Code اسکن نمی‌شود',
                      'بررسی کنید که QR Data مطابق استاندارد باشد',
                    ),
                    _buildTroubleshootingItem(
                      'تایید کد ناموفق',
                      'بررسی کنید که زمان دستگاه درست باشد',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingItem(String problem, String solution) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '❌ $problem',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '💡 $solution',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
