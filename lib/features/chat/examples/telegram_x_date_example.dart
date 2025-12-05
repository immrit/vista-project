// lib/features/chat/examples/telegram_x_date_example.dart

import 'package:flutter/material.dart';
import '../../../utils/telegram_x_date_utils.dart';

class TelegramXDateExample extends StatelessWidget {
  const TelegramXDateExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telegram-X Date Format Examples')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('⏰ Message Timestamps', [
            _buildExample(
              'همین الان',
              DateTime.now().toTelegramMessageFormat(),
            ),
            _buildExample(
              '۵ دقیقه پیش',
              DateTime.now()
                  .subtract(const Duration(minutes: 5))
                  .toTelegramMessageFormat(),
            ),
            _buildExample(
              '۲ ساعت پیش',
              DateTime.now()
                  .subtract(const Duration(hours: 2))
                  .toTelegramMessageFormat(),
            ),
            _buildExample(
              'دیروز',
              DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toTelegramMessageFormat(),
            ),
            _buildExample(
              '۳ روز پیش',
              DateTime.now()
                  .subtract(const Duration(days: 3))
                  .toTelegramMessageFormat(),
            ),
            _buildExample(
              'ماه پیش',
              DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toTelegramMessageFormat(),
            ),
            _buildExample(
              'سال پیش',
              DateTime.now()
                  .subtract(const Duration(days: 365))
                  .toTelegramMessageFormat(),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('📌 Floating Date Header', [
            _buildExample(
              'امروز',
              DateTime.now().toFloatingHeaderFormat(),
            ),
            _buildExample(
              'دیروز',
              DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toFloatingHeaderFormat(),
            ),
            _buildExample(
              'این هفته',
              DateTime.now()
                  .subtract(const Duration(days: 3))
                  .toFloatingHeaderFormat(),
            ),
            _buildExample(
              'ماه پیش',
              DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toFloatingHeaderFormat(),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('📅 Date Divider', [
            _buildExample(
              'امروز',
              DateTime.now().toDateDividerFormat(),
            ),
            _buildExample(
              'دیروز',
              DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toDateDividerFormat(),
            ),
            _buildExample(
              'این هفته',
              DateTime.now()
                  .subtract(const Duration(days: 3))
                  .toDateDividerFormat(),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('👤 Last Seen', [
            _buildExample(
              'همین الان',
              DateTime.now().toLastSeenFormat(),
            ),
            _buildExample(
              '۵ دقیقه پیش',
              DateTime.now()
                  .subtract(const Duration(minutes: 5))
                  .toLastSeenFormat(),
            ),
            _buildExample(
              '۲ ساعت پیش',
              DateTime.now()
                  .subtract(const Duration(hours: 2))
                  .toLastSeenFormat(),
            ),
            _buildExample(
              'دیروز',
              DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toLastSeenFormat(),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('📋 Short Relative (Chat List)', [
            _buildExample(
              '۵ دقیقه پیش',
              DateTime.now()
                  .subtract(const Duration(minutes: 5))
                  .toShortRelativeFormat(),
            ),
            _buildExample(
              '۲ ساعت پیش',
              DateTime.now()
                  .subtract(const Duration(hours: 2))
                  .toShortRelativeFormat(),
            ),
            _buildExample(
              'دیروز',
              DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toShortRelativeFormat(),
            ),
            _buildExample(
              'این هفته',
              DateTime.now()
                  .subtract(const Duration(days: 3))
                  .toShortRelativeFormat(),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildExample(String label, String result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              result,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
