import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../subscriptions/subscription_model.dart';
import '../subscriptions/subscription_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Group spending by category
    final Map<String, double> categoryTotals = {};
    double totalSpending = 0;

    for (var sub in subscriptions) {
      if (!sub.isPaused) {
        categoryTotals[sub.category] =
            (categoryTotals[sub.category] ?? 0) + sub.amount;
        totalSpending += sub.amount;
      }
    }

    final categories = categoryTotals.keys.toList();

    return Scaffold(
      body: subscriptions.isEmpty || totalSpending == 0
          ? Center(
              child: Text(
                'No active spending data available.\nAdd subscriptions to view analytics!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey,
                  fontSize: 16,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clean body header
                  Text(
                    'Spending Analytics',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total Active Commitment Card (Dark/Light mode adaptive)
                  Card(
                    color: isDark
                        ? const Color(0xFF2C223B)
                        : Colors.deepPurple.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark
                            ? Colors.deepPurple.shade300.withOpacity(0.3)
                            : Colors.deepPurple.shade100,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Active Commitment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.deepPurple.shade100
                                  : Colors.deepPurple.shade900,
                            ),
                          ),
                          Text(
                            currencyFormat.format(totalSpending),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFFF8A80)
                                  : Colors.deepPurple.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. Donut Chart Section
                  Text(
                    'Category Breakdown (Donut Chart)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: categories.map((category) {
                          final amount = categoryTotals[category]!;
                          final percentage = (amount / totalSpending) * 100;
                          final color = _getCategoryColor(category);

                          return PieChartSectionData(
                            color: color,
                            value: amount,
                            title: '${percentage.toStringAsFixed(0)}%',
                            radius: 45,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Monthly Trend Bar Chart Section
                  Text(
                    'Category Monthly Trend (Bar Chart)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY:
                            (categoryTotals.values.isEmpty
                                ? 1000
                                : categoryTotals.values.reduce(
                                    (a, b) => a > b ? a : b,
                                  )) *
                            1.2,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < categories.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      categories[index].length >= 3
                                          ? categories[index].substring(0, 3)
                                          : categories[index],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: categories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value;
                          final amount = categoryTotals[category]!;

                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: amount,
                                color: _getCategoryColor(category),
                                width: 18,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category Itemized List
                  ...categories.map((category) {
                    final amount = categoryTotals[category]!;
                    final percentage = (amount / totalSpending) * 100;
                    final color = _getCategoryColor(category);

                    return Card(
                      color: theme.cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color,
                          radius: 12,
                        ),
                        title: Text(
                          category,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        subtitle: Text(
                          '${percentage.toStringAsFixed(1)}% of total',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                        trailing: Text(
                          currencyFormat.format(amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Entertainment':
        return Colors.purple;
      case 'Utilities':
        return Colors.orange;
      case 'Software':
        return Colors.blue;
      case 'Gym':
        return Colors.green;
      case 'Insurance':
        return Colors.red;
      case 'Education':
        return Colors.indigo; // <--- Education ke liye color
      default:
        return Colors.teal;
    }
  }
}
