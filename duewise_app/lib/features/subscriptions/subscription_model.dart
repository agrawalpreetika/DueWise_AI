import 'package:hive/hive.dart';

part 'subscription_model.g.dart';

@HiveType(typeId: 0)
class Subscription extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String category; // e.g., "Entertainment", "Utility", "Software", "Gym"

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final String currency; // "INR", "USD", etc.

  @HiveField(5)
  final String? billingCycle; // "MONTHLY", "YEARLY", "CUSTOM", or null for one-time bills

  @HiveField(6)
  final int? customIntervalDays;

  @HiveField(7)
  final DateTime? startDate; // null for one-time bills

  @HiveField(8)
  DateTime nextDueDate; // For one-time bills, this is the "pay by" due date

  @HiveField(9)
  final bool isFreeTrial;

  @HiveField(10)
  final DateTime? trialEndDate;

  @HiveField(11)
  bool isPaused;

  @HiveField(12)
  final String entryType; // "subscription" or "one_time_bill"

  @HiveField(13)
  bool isPaid; // Mainly used for one-time bills once paid

  Subscription({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    this.currency = 'INR',
    this.billingCycle,
    this.customIntervalDays,
    this.startDate,
    required this.nextDueDate,
    this.isFreeTrial = false,
    this.trialEndDate,
    this.isPaused = false,
    this.entryType = 'subscription',
    this.isPaid = false,
  });

  bool get isOneTimeBill => entryType.trim().toLowerCase() == 'one_time_bill';

  String get effectiveBillingLabel {
    if (isOneTimeBill) return 'ONE_TIME';
    return (billingCycle ?? 'MONTHLY').trim().toUpperCase();
  }

  // Helper static function to auto-calculate next due date cleanly
  static DateTime calculateNextDueDate(
    DateTime anchorDate,
    String? cycle, {
    int? intervalDays,
  }) {
    final c = (cycle ?? 'MONTHLY').trim().toUpperCase();
    if (c == 'MONTHLY') {
      return DateTime(anchorDate.year, anchorDate.month + 1, anchorDate.day);
    } else if (c == 'YEARLY') {
      return DateTime(anchorDate.year + 1, anchorDate.month, anchorDate.day);
    } else if (c == 'CUSTOM' && intervalDays != null && intervalDays > 0) {
      return anchorDate.add(Duration(days: intervalDays));
    }
    return anchorDate.add(const Duration(days: 30)); // Fallback
  }
}
