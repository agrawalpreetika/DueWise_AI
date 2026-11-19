import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../subscriptions/subscription_model.dart';
import '../subscriptions/subscription_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final subscriptions = ref.watch(subscriptionProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter subscriptions due on the selected date
    final dueOnSelectedDate = subscriptions.where((sub) {
      return sub.nextDueDate.year == _selectedDate.year &&
          sub.nextDueDate.month == _selectedDate.month &&
          sub.nextDueDate.day == _selectedDate.day;
    }).toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Payment Calendar Title Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              'Payment Calendar',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
          ),

          // Date Picker Calendar Header Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              onDateChanged: (newDate) {
                setState(() {
                  _selectedDate = newDate;
                });
              },
            ),
          ),

          // Selected Date Header & Dues Chip
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bills Due on ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                Chip(
                  label: Text(
                    '${dueOnSelectedDate.length} Due',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: dueOnSelectedDate.isEmpty
                          ? (isDark ? Colors.grey.shade300 : Colors.black87)
                          : (isDark
                                ? Colors.purple.shade100
                                : Colors.deepPurple.shade900),
                    ),
                  ),
                  backgroundColor: dueOnSelectedDate.isEmpty
                      ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                      : (isDark
                            ? Colors.deepPurple.shade800
                            : Colors.deepPurple.shade100),
                ),
              ],
            ),
          ),

          // Subscriptions List for Picked Date
          dueOnSelectedDate.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'No payments due on this date.',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: dueOnSelectedDate.length,
                  itemBuilder: (context, index) {
                    final sub = dueOnSelectedDate[index];

                    return Card(
                      color: theme.cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: sub.isFreeTrial
                              ? (isDark
                                    ? Colors.orange.shade900.withOpacity(0.5)
                                    : Colors.orange.shade100)
                              : (isDark
                                    ? Colors.deepPurple.shade900.withOpacity(
                                        0.5,
                                      )
                                    : Colors.deepPurple.shade50),
                          child: Icon(
                            sub.isFreeTrial
                                ? Icons.warning_amber_rounded
                                : Icons.payment,
                            color: sub.isFreeTrial
                                ? (isDark
                                      ? Colors.orange.shade200
                                      : Colors.orange.shade900)
                                : (isDark
                                      ? Colors.deepPurple.shade200
                                      : Colors.deepPurple),
                          ),
                        ),
                        title: Text(
                          sub.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        subtitle: Text(
                          sub.isFreeTrial
                              ? '⚠️ Free Trial Converting Today!'
                              : '${sub.category} • ${sub.billingCycle}',
                          style: TextStyle(
                            color: sub.isFreeTrial
                                ? (isDark
                                      ? Colors.orange.shade300
                                      : Colors.orange.shade900)
                                : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700),
                            fontWeight: sub.isFreeTrial
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          currencyFormat.format(sub.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
