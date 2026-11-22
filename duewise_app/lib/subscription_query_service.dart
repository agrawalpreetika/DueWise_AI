import 'package:intl/intl.dart';

import 'features/subscriptions/subscription_model.dart';

class SubscriptionQueryService {
  static String _cycleDisplayLabel(Subscription s) {
    if (s.isOneTimeBill) return 'One-Time Bill';
    final cycle = (s.billingCycle ?? 'MONTHLY').toUpperCase();
    if (cycle == 'CUSTOM' && (s.customIntervalDays ?? 0) > 0) {
      return 'CUSTOM (${s.customIntervalDays} days)';
    }
    return cycle;
  }

  static String executeQuery({
    required List<Subscription> subscriptions,
    required Map<String, dynamic> queryData,
  }) {
    final queryType = queryData['query_type'] as String? ?? 'all_active';
    final activeSubs = subscriptions
        .where((s) => !s.isPaused && !(s.isOneTimeBill && s.isPaid))
        .toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateFormatter = DateFormat('MMM dd, yyyy');

    switch (queryType) {
      case 'due_today':
        final dueToday = activeSubs.where((s) {
          final due = DateTime(
            s.nextDueDate.year,
            s.nextDueDate.month,
            s.nextDueDate.day,
          );
          return due.isAtSameMomentAs(today);
        }).toList();

        if (dueToday.isEmpty) {
          return "You have no subscriptions or bills due today.";
        }
        final total = dueToday.fold<double>(0, (sum, s) => sum + s.amount);
        final list = dueToday
            .map(
              (s) =>
                  "• ${s.title}${s.isOneTimeBill ? ' (One-Time)' : ''} — ₹${s.amount.toStringAsFixed(0)}",
            )
            .join("\n");
        return "Subscriptions & bills due today (Total: ₹${total.toStringAsFixed(0)}):\n$list";

      case 'due_on_date':
        final targetStr = queryData['target_date'] as String?;
        if (targetStr == null || targetStr.isEmpty) {
          return "Please provide a valid date (e.g., 25 Nov).";
        }
        final target = DateTime.tryParse(targetStr);
        if (target == null) {
          return "Did not understand date: $targetStr";
        }
        final targetDay = DateTime(target.year, target.month, target.day);

        final matching = activeSubs.where((s) {
          final due = DateTime(
            s.nextDueDate.year,
            s.nextDueDate.month,
            s.nextDueDate.day,
          );
          return due.isAtSameMomentAs(targetDay);
        }).toList();

        final formattedDate = dateFormatter.format(targetDay);
        if (matching.isEmpty) {
          return "No subscriptions or bills are due on $formattedDate.";
        }
        final total = matching.fold<double>(0, (sum, s) => sum + s.amount);
        final list = matching
            .map(
              (s) =>
                  "• ${s.title}${s.isOneTimeBill ? ' (One-Time)' : ''} — ₹${s.amount.toStringAsFixed(0)}",
            )
            .join("\n");
        return "Due on $formattedDate (Total: ₹${total.toStringAsFixed(0)}):\n$list";

      case 'upcoming_days':
        final days = (queryData['days_ahead'] as num?)?.toInt() ?? 7;
        final endLimit = today.add(Duration(days: days));

        final upcoming = activeSubs.where((s) {
          final due = DateTime(
            s.nextDueDate.year,
            s.nextDueDate.month,
            s.nextDueDate.day,
          );
          return !due.isBefore(today) && !due.isAfter(endLimit);
        }).toList()..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

        if (upcoming.isEmpty) {
          return "No subscriptions or bills due in the next $days days.";
        }
        final total = upcoming.fold<double>(0, (sum, s) => sum + s.amount);
        final list = upcoming
            .map(
              (s) =>
                  "• ${s.title}${s.isOneTimeBill ? ' (One-Time)' : ''} — ₹${s.amount.toStringAsFixed(0)} (${dateFormatter.format(s.nextDueDate)})",
            )
            .join("\n");
        return "Upcoming in $days days (Total: ₹${total.toStringAsFixed(0)}):\n$list";

      case 'this_month_expenses':
        final thisMonthSubs = activeSubs.where((s) {
          return s.nextDueDate.year == now.year &&
              s.nextDueDate.month == now.month;
        }).toList()..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

        final monthLabel = DateFormat('MMMM yyyy').format(now);
        if (thisMonthSubs.isEmpty) {
          return "No active subscriptions or bills are due in $monthLabel.";
        }
        final total = thisMonthSubs.fold<double>(0, (sum, s) => sum + s.amount);
        final list = thisMonthSubs
            .map(
              (s) =>
                  "• ${s.title}${s.isOneTimeBill ? ' (One-Time)' : ''} — ₹${s.amount.toStringAsFixed(0)} (${dateFormatter.format(s.nextDueDate)})",
            )
            .join("\n");
        return "Expenses due in $monthLabel (Total: ₹${total.toStringAsFixed(0)}):\n$list";

      case 'next_month_expenses':
        final nextMonthDate = DateTime(now.year, now.month + 1, 1);
        final nextMonthSubs = activeSubs.where((s) {
          return s.nextDueDate.year == nextMonthDate.year &&
              s.nextDueDate.month == nextMonthDate.month;
        }).toList()..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

        final nextMonthLabel = DateFormat('MMMM yyyy').format(nextMonthDate);
        if (nextMonthSubs.isEmpty) {
          return "No active subscriptions or bills are due in $nextMonthLabel.";
        }
        final total = nextMonthSubs.fold<double>(0, (sum, s) => sum + s.amount);
        final list = nextMonthSubs
            .map(
              (s) =>
                  "• ${s.title}${s.isOneTimeBill ? ' (One-Time)' : ''} — ₹${s.amount.toStringAsFixed(0)} (${dateFormatter.format(s.nextDueDate)})",
            )
            .join("\n");
        return "Expenses due in $nextMonthLabel (Total: ₹${total.toStringAsFixed(0)}):\n$list";

      case 'monthly_expenses':
        double monthlyTotal = 0;
        int countedSubs = 0;

        for (final s in activeSubs) {
          if (s.isFreeTrial || s.isOneTimeBill) continue;
          countedSubs++;
          final cycle = (s.billingCycle ?? 'MONTHLY').toUpperCase();
          if (cycle == 'MONTHLY') {
            monthlyTotal += s.amount;
          } else if (cycle == 'YEARLY') {
            monthlyTotal += (s.amount / 12);
          } else if (cycle == 'CUSTOM' && (s.customIntervalDays ?? 0) > 0) {
            monthlyTotal += (s.amount * 30) / s.customIntervalDays!;
          }
        }
        return "Your estimated recurring monthly expense is ₹${monthlyTotal.toStringAsFixed(2)} ($countedSubs active recurring subscriptions).";

      case 'by_category':
        final rawCat = (queryData['category'] as String? ?? '').toLowerCase();
        final filtered = activeSubs.where((s) {
          final subCat = s.category.toLowerCase();
          if (rawCat.startsWith('utilit') && subCat.startsWith('utilit')) {
            return true;
          }
          return subCat == rawCat;
        }).toList();

        final displayCat = queryData['category'] ?? 'Selected';
        if (filtered.isEmpty) {
          return "No active subscriptions or bills in the $displayCat category.";
        }
        final total = filtered.fold<double>(0, (sum, s) => sum + s.amount);
        final list = filtered
            .map(
              (s) =>
                  "• ${s.title} — ₹${s.amount.toStringAsFixed(0)} (${_cycleDisplayLabel(s)})",
            )
            .join("\n");
        return "$displayCat items (Total: ₹${total.toStringAsFixed(0)}):\n$list";

      case 'by_name':
        final rawName = (queryData['subscription_name'] as String? ?? '')
            .trim();
        if (rawName.isEmpty) {
          return "Please specify which subscription or bill you are asking about.";
        }
        final needle = rawName.toLowerCase();

        final matches = activeSubs
            .where((s) => s.title.toLowerCase().contains(needle))
            .toList();

        if (matches.isEmpty) {
          final pausedMatch = subscriptions.any(
            (s) => s.isPaused && s.title.toLowerCase().contains(needle),
          );
          if (pausedMatch) {
            return "You don't have an active item matching \"$rawName\" (a matching paused item exists).";
          }
          return "You don't have an active subscription or unpaid bill matching \"$rawName\".";
        }

        if (matches.length == 1) {
          final s = matches.first;
          final trialTag = (!s.isOneTimeBill && s.isFreeTrial)
              ? " • Free Trial"
              : "";
          final duePrefix = s.isOneTimeBill ? "Pay by" : "Next due";
          return "${s.title} — ₹${s.amount.toStringAsFixed(0)} (${_cycleDisplayLabel(s)}$trialTag, $duePrefix: ${dateFormatter.format(s.nextDueDate)})";
        }

        final total = matches.fold<double>(0, (sum, s) => sum + s.amount);
        final list = matches
            .map(
              (s) =>
                  "• ${s.title} — ₹${s.amount.toStringAsFixed(0)} (${_cycleDisplayLabel(s)}, Due: ${dateFormatter.format(s.nextDueDate)})",
            )
            .join("\n");
        return "Items matching \"$rawName\" (Total: ₹${total.toStringAsFixed(0)}):\n$list";

      case 'all_active':
      default:
        if (activeSubs.isEmpty) {
          return "You have no active subscriptions or unpaid bills.";
        }
        final list = activeSubs
            .map(
              (s) =>
                  "• ${s.title}${s.isOneTimeBill ? ' (One-Time)' : ''} — ₹${s.amount.toStringAsFixed(0)} (Due: ${dateFormatter.format(s.nextDueDate)})",
            )
            .join("\n");
        return "Your active subscriptions & bills (${activeSubs.length}):\n$list";
    }
  }
}
