import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../subscriptions/payment_log_model.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Payment Audit History',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Box<PaymentLog>>(
              valueListenable: Hive.box<PaymentLog>('payment_logs')
                  .listenable(),
              builder: (context, box, _) {
                final now = DateTime.now();
                final thirtyDaysAgo = now.subtract(const Duration(days: 30));

                final recentLogs =
                    box.values
                        .where((log) => log.paidAt.isAfter(thirtyDaysAgo))
                        .toList()
                      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));

                if (recentLogs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No payment history found in the last 30 days.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: recentLogs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = recentLogs[index];
                    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a')
                        .format(log.paidAt);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                      title: Text(
                        log.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$formattedDate\n${log.billingPeriod}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Text(
                        '₹${log.amountPaid.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
