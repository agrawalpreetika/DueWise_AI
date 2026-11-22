import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'subscription_model.dart';
import 'payment_log_model.dart';
import 'firestore_sync_service.dart'; // Import Sync Service

class SubscriptionRepository {
  final Box<Subscription> _box = Hive.box<Subscription>('subscriptions');
  final Box<PaymentLog> _logBox = Hive.box<PaymentLog>('payment_logs');
  final FirestoreSyncService _syncService = FirestoreSyncService();

  List<Subscription> getAllSubscriptions() {
    return _box.values.toList();
  }

  List<PaymentLog> getAllPaymentLogs() {
    return _logBox.values.toList()
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
  }

  // Sync from Cloud to local Hive on User Sign-In
  Future<void> syncWithCloud() async {
    try {
      final cloudData = await _syncService.fetchCloudSubscriptions();
      for (var sub in cloudData) {
        await _box.put(sub.id, sub);
      }
    } catch (e) {
      // Quietly fall back to Hive if offline
    }
  }

  Future<void> addSubscription(Subscription subscription) async {
    await _box.put(subscription.id, subscription);
    await _syncService.syncSubscription(subscription);
  }

  Future<void> updateSubscription(Subscription subscription) async {
    await _box.put(subscription.id, subscription);
    await _syncService.syncSubscription(subscription);
  }

  Future<void> deleteSubscription(String id) async {
    await _box.delete(id);
    await _syncService.deleteSubscription(id);
  }

  Future<void> togglePauseStatus(String id) async {
    final subscription = _box.get(id);
    if (subscription != null) {
      subscription.isPaused = !subscription.isPaused;
      await subscription.save();
      await _syncService.syncSubscription(subscription);
    }
  }

  DateTime calculateNextDueDate(
    DateTime currentDueDate,
    String? billingCycle,
    int? customDays,
  ) {
    final cycle = (billingCycle ?? 'MONTHLY').trim().toUpperCase();
    if (cycle == 'MONTHLY') {
      return DateTime(
        currentDueDate.year,
        currentDueDate.month + 1,
        currentDueDate.day,
      );
    } else if (cycle == 'YEARLY') {
      return DateTime(
        currentDueDate.year + 1,
        currentDueDate.month,
        currentDueDate.day,
      );
    } else if (cycle == 'CUSTOM' && customDays != null && customDays > 0) {
      return currentDueDate.add(Duration(days: customDays));
    }
    return currentDueDate.add(const Duration(days: 30));
  }

  Future<void> markAsPaid(String id) async {
    final subscription = _box.get(id);
    if (subscription != null) {
      final billingLabel = subscription.isOneTimeBill
          ? 'ONE_TIME'
          : (subscription.billingCycle ?? 'MONTHLY').toUpperCase();

      // 1. Record Audit Log in payment_logs
      final log = PaymentLog(
        id: const Uuid().v4(),
        subscriptionId: subscription.id,
        title: subscription.title,
        amountPaid: subscription.amount,
        paidAt: DateTime.now(),
        billingPeriod:
            '${DateFormat('MMMM_yyyy').format(DateTime.now()).toUpperCase()}_$billingLabel',
      );
      await _logBox.put(log.id, log);

      // 2. For one-time bills, mark paid without advancing due date;
      //    for recurring subscriptions, advance nextDueDate to next cycle.
      if (subscription.isOneTimeBill) {
        subscription.isPaid = true;
      } else {
        subscription.nextDueDate = calculateNextDueDate(
          subscription.nextDueDate,
          subscription.billingCycle,
          subscription.customIntervalDays,
        );
        subscription.isPaid = false;
      }
      await subscription.save();

      // 3. Sync Updated Record to Cloud
      await _syncService.syncSubscription(subscription);
    }
  }
}
