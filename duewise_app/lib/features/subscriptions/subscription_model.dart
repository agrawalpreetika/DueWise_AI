import 'package:hive/hive.dart';

part 'subscription_model.g.dart';

@HiveType(typeId: 0)
class Subscription extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String category; // e.g., "Entertainment", "Utilities", "Software", "Gym"

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final String currency; // "INR", "USD", etc.

  @HiveField(5)
  final String billingCycle; // "MONTHLY", "YEARLY", "CUSTOM"

  @HiveField(6)
  final int? customIntervalDays;

  @HiveField(7)
  final DateTime startDate;

  @HiveField(8)
  DateTime nextDueDate;

  @HiveField(9)
  final bool isFreeTrial;

  @HiveField(10)
  final DateTime? trialEndDate;

  @HiveField(11)
  bool isPaused;

  Subscription({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    this.currency = 'INR',
    required this.billingCycle,
    this.customIntervalDays,
    required this.startDate,
    required this.nextDueDate,
    this.isFreeTrial = false,
    this.trialEndDate,
    this.isPaused = false,
  });

  // Helper static function to auto-calculate next due date cleanly
  static DateTime calculateNextDueDate(
    DateTime start,
    String cycle, {
    int? intervalDays,
  }) {
    final c = cycle.trim().toUpperCase();
    if (c == 'MONTHLY') {
      return DateTime(start.year, start.month + 1, start.day);
    } else if (c == 'YEARLY') {
      return DateTime(start.year + 1, start.month, start.day);
    } else if (c == 'CUSTOM' && intervalDays != null && intervalDays > 0) {
      return start.add(Duration(days: intervalDays));
    }
    return start.add(const Duration(days: 30)); // Fallback
  }
}
