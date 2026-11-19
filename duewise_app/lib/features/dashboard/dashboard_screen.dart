import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../subscriptions/subscription_model.dart';
import '../subscriptions/subscription_provider.dart';
import '../subscriptions/add_subscription_screen.dart';
import '../subscriptions/edit_subscription_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  final List<String> _categories = [
    'All',
    'Entertainment',
    'Utilities',
    'Software',
    'Gym',
    'Insurance',
    'Education',
    'Other',
  ];

  double _calculateForecast(List<Subscription> subscriptions, int days) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));

    return subscriptions
        .where(
          (sub) =>
              !sub.isPaused &&
              !sub.isFreeTrial &&
              sub.nextDueDate.isAfter(now.subtract(const Duration(days: 1))) &&
              sub.nextDueDate.isBefore(cutoff),
        )
        .fold(0.0, (sum, sub) => sum + sub.amount);
  }

  void _changeMonth(WidgetRef ref, int increment) {
    final current = ref.read(selectedMonthProvider);
    final newDate = DateTime(current.year, current.month + increment, 1);
    ref.read(selectedMonthProvider.notifier).state = newDate;
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = ref.watch(subscriptionProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final selectedMonth = ref.watch(selectedMonthProvider);
    final currentMonthSubs = ref.watch(currentMonthSubscriptionsProvider);
    final currentMonthTotal = ref.watch(currentMonthTotalProvider);
    final currentMonthName = DateFormat('MMMM yyyy').format(selectedMonth);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final total7Days = _calculateForecast(subscriptions, 7);
    final total30Days = _calculateForecast(subscriptions, 30);

    final filteredList = subscriptions.where((sub) {
      final matchesSearch = sub.title.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesCategory =
          _selectedCategoryFilter == 'All' ||
          sub.category == _selectedCategoryFilter;
      return matchesSearch && matchesCategory;
    }).toList()..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          // 1. Interactive Month-Selectable Summary Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF4A148C), const Color(0xFF311B92)]
                    : [Colors.deepPurple.shade700, Colors.deepPurple.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$currentMonthName Expenses',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          // Month Selector Arrows
                          InkWell(
                            onTap: () => _changeMonth(ref, -1),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                              child: Icon(
                                Icons.chevron_left,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _changeMonth(ref, 1),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(currentMonthTotal),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${currentMonthSubs.length} bills pending this month',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Compact Rolling Cash Flow Forecast Cards
          Row(
            children: [
              Expanded(
                child: _buildForecastCard(
                  context,
                  title: 'Due in 7 Days',
                  amount: currencyFormat.format(total7Days),
                  color: isDark
                      ? const Color(0xFF3D2C1E)
                      : Colors.orange.shade100,
                  textColor: isDark
                      ? Colors.orange.shade200
                      : Colors.orange.shade900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildForecastCard(
                  context,
                  title: 'Due in 30 Days',
                  amount: currencyFormat.format(total30Days),
                  color: isDark
                      ? const Color(0xFF35243B)
                      : Colors.purple.shade100,
                  textColor: isDark
                      ? Colors.purple.shade200
                      : Colors.purple.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Search Bar
          TextField(
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Search bills or subscriptions...',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 10),

          // 4. Category Filter Chips
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategoryFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.grey.shade300 : Colors.black87),
                      ),
                    ),
                    selectedColor: Colors.deepPurple,
                    backgroundColor: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategoryFilter = cat;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Commitments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              Text(
                '${filteredList.length} items',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 5. Subscription Feed List
          filteredList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'No matching subscriptions found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final sub = filteredList[index];
                    final targetDate = sub.isFreeTrial
                        ? (sub.trialEndDate ?? sub.nextDueDate)
                        : sub.nextDueDate;
                    final daysLeft = targetDate
                        .difference(DateTime.now())
                        .inDays;

                    return Card(
                      color: theme.cardColor,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: sub.isFreeTrial
                              ? (isDark
                                    ? Colors.amber.shade900.withOpacity(0.5)
                                    : Colors.amber.shade100)
                              : (isDark
                                    ? Colors.deepPurple.shade900.withOpacity(
                                        0.5,
                                      )
                                    : Colors.deepPurple.shade50),
                          child: Icon(
                            sub.isFreeTrial
                                ? Icons.card_giftcard
                                : _getCategoryIcon(sub.category),
                            size: 18,
                            color: sub.isFreeTrial
                                ? (isDark
                                      ? Colors.amber.shade200
                                      : Colors.amber.shade900)
                                : (isDark
                                      ? Colors.deepPurple.shade200
                                      : Colors.deepPurple),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                sub.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: theme.textTheme.bodyLarge?.color,
                                  decoration: sub.isPaused
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (sub.isFreeTrial) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.amber.shade900.withOpacity(0.5)
                                      : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.amber.shade400
                                        : Colors.amber.shade700,
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'TRIAL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          sub.isFreeTrial
                              ? '${sub.category} • Ends: ${DateFormat('MMM dd').format(targetDate)}'
                              : '${sub.category} • ${sub.billingCycle} • Due: ${DateFormat('MMM dd').format(sub.nextDueDate)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                        trailing: SizedBox(
                          width: 130,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                sub.isFreeTrial
                                    ? '₹0 (Then ${currencyFormat.format(sub.amount)})'
                                    : currencyFormat.format(sub.amount),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: sub.isFreeTrial ? 10 : 14,
                                  color: sub.isFreeTrial
                                      ? (isDark
                                            ? Colors.orange.shade300
                                            : Colors.orange.shade800)
                                      : theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: daysLeft <= 3
                                      ? (isDark
                                            ? Colors.red.shade900.withOpacity(
                                                0.6,
                                              )
                                            : Colors.red.shade100)
                                      : (isDark
                                            ? Colors.green.shade900.withOpacity(
                                                0.6,
                                              )
                                            : Colors.green.shade100),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  daysLeft == 0
                                      ? 'Today'
                                      : daysLeft < 0
                                      ? 'Overdue'
                                      : '${daysLeft}d left',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: daysLeft <= 3
                                        ? (isDark
                                              ? Colors.red.shade200
                                              : Colors.red.shade900)
                                        : (isDark
                                              ? Colors.green.shade200
                                              : Colors.green.shade900),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          _showMarkAsPaidDialog(context, ref, sub);
                        },
                        onLongPress: () {
                          _showOptionsDialog(context, ref, sub);
                        },
                      ),
                    );
                  },
                ),
          const SizedBox(height: 70),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddSubscriptionScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Bill', style: TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildForecastCard(
    BuildContext context, {
    required String title,
    required String amount,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Entertainment':
        return Icons.movie;
      case 'Utilities':
        return Icons.lightbulb;
      case 'Software':
        return Icons.code;
      case 'Gym':
        return Icons.fitness_center;
      case 'Insurance':
        return Icons.security;
      case 'Education':
        return Icons.school;
      default:
        return Icons.receipt;
    }
  }

  void _showMarkAsPaidDialog(
    BuildContext context,
    WidgetRef ref,
    Subscription sub,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          sub.isFreeTrial ? 'Convert ${sub.title}?' : 'Pay ${sub.title}?',
        ),
        content: Text(
          sub.isFreeTrial
              ? 'Marking this trial as paid will end the free trial and convert it into an active paid subscription.'
              : 'Marking this bill as paid will automatically recalculate and advance its next due date for the next cycle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(subscriptionProvider.notifier).markAsPaid(sub.id);
              Navigator.of(ctx).pop();
            },
            child: Text(sub.isFreeTrial ? 'Convert & Pay' : 'Mark as Paid'),
          ),
        ],
      ),
    );
  }

  void _showOptionsDialog(
    BuildContext context,
    WidgetRef ref,
    Subscription sub,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sub.title),
        content: const Text('Select an action:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditSubscriptionScreen(subscription: sub),
                ),
              );
            },
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () {
              ref.read(subscriptionProvider.notifier).togglePause(sub.id);
              Navigator.of(ctx).pop();
            },
            child: Text(sub.isPaused ? 'Resume' : 'Pause'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmDelete(context, ref, sub);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Subscription sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${sub.title}?'),
        content: const Text(
          'Are you sure you want to delete this subscription? This action will remove it from both local cache and Cloud Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref
                  .read(subscriptionProvider.notifier)
                  .deleteSubscription(sub.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
