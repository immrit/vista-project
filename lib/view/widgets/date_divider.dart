import 'package:flutter/material.dart';

class DateDivider extends StatelessWidget {
  final DateTime date;
  const DateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: FloatingDateChip(date: date),
    );
  }
}

class FloatingDateChip extends StatelessWidget {
  final DateTime date;

  const FloatingDateChip({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        _formatDate(date),
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.year == date.year && now.month == date.month && now.day == date.day) {
      return "Today";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == date.year && yesterday.month == date.month && yesterday.day == date.day) {
      return "Yesterday";
    }
    const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${date.day} ${monthNames[date.month]} ${date.year}";
  }
}