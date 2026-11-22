import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'subscription_model.dart';
import 'payment_log_model.dart';
import '../auth/firestore_sync_service.dart';
import '../../services/notification_service.dart';

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, List<Subscription>>((ref) {
      return SubscriptionNotifier(ref);
    });

// StateProvider to keep track of the currently selected month and year in Dashboard
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// 1. Provider to filter active unpaid items for the selected month & year
final currentMonthSubscriptionsProvider = Provider<List<Subscription>>((ref) {
  final subscriptions = ref.watch(subscriptionProvider);
  final selectedDate = ref.watch(selectedMonthProvider);

  return subscriptions.where((sub) {
    final matchesMonth =
        sub.nextDueDate.year == selectedDate.year &&
        sub.nextDueDate.month == selectedDate.month;
    final isActiveUnpaid = !sub.isPaused && !(sub.isOneTimeBill && sub.isPaid);
    return matchesMonth && isActiveUnpaid;
  }).toList();
});

// 2. Provider to calculate the total amount of pending bills/subscriptions for the selected month
final currentMonthTotalProvider = Provider<double>((ref) {
  final monthSubs = ref.watch(currentMonthSubscriptionsProvider);
  return monthSubs.fold(0.0, (sum, sub) => sum + sub.amount);
});

class SubscriptionNotifier extends StateNotifier<List<Subscription>> {
  final Ref ref;
  final Box<Subscription> _box = Hive.box<Subscription>('subscriptions');
  final FirestoreSyncService _firestoreSync = FirestoreSyncService();
  final NotificationService _notificationService = NotificationService();

  SubscriptionNotifier(this.ref) : super([]) {
    state = _box.values.toList();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _fetchAndSyncFromCloud(user.uid);
      }
    });
  }

  Future<void> _fetchAndSyncFromCloud(String userId) async {
    try {
      // 1. Fetch Subscriptions / Bills from Cloud
      final cloudSubs = await _firestoreSync.fetchCloudSubscriptions();
      if (cloudSubs.isNotEmpty) {
        await _box.clear();
        for (var sub in cloudSubs) {
          await _box.put(sub.id, sub);
          if (!sub.isPaused && !(sub.isOneTimeBill && sub.isPaid)) {
            await _notificationService.scheduleSubscriptionReminders(sub);
          }
        }
        state = _box.values.toList();
      }

      // 2. Fetch Payment Logs (History) from Cloud with safe Box handling
      final cloudLogs = await _firestoreSync.fetchRecentPaymentLogs();
      if (cloudLogs.isNotEmpty) {
        try {
          var logBox = Hive.isBoxOpen('payment_logs')
              ? Hive.box<PaymentLog>('payment_logs')
              : await Hive.openBox<PaymentLog>('payment_logs');

          await logBox.clear();
          for (var log in cloudLogs) {
            await logBox.put(log.id, log);
          }
          print(
            'Successfully synced ${cloudLogs.length} payment logs to local Hive box.',
          );
        } catch (hiveError) {
          print('Hive payment_logs box error: $hiveError');
        }
      }
    } catch (e) {
      print('Cloud Sync Error on Auth State Change: $e');
    }
  }

  Future<void> refreshFromCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _fetchAndSyncFromCloud(user.uid);
    }
  }

  Future<void> updateSubscription(Subscription updatedSub) async {
    await _box.put(updatedSub.id, updatedSub);

    await _notificationService.cancelSubscriptionReminders(updatedSub.id);
    if (!updatedSub.isPaused &&
        !(updatedSub.isOneTimeBill && updatedSub.isPaid)) {
      await _notificationService.scheduleSubscriptionReminders(updatedSub);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestoreSync.syncSubscription(updatedSub);
    }

    state = _box.values.toList();
  }

  Future<void> addSubscription(Subscription subscription) async {
    await _box.put(subscription.id, subscription);
    if (!subscription.isPaused &&
        !(subscription.isOneTimeBill && subscription.isPaid)) {
      await _notificationService.scheduleSubscriptionReminders(subscription);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestoreSync.syncSubscription(subscription);
    }
    state = _box.values.toList();
  }

  Future<void> markAsPaid(String id) async {
    final sub = _box.get(id);
    if (sub != null) {
      final now = DateTime.now();

      final paymentLog = PaymentLog(
        id: now.millisecondsSinceEpoch.toString(),
        subscriptionId: sub.id,
        title: sub.title,
        amountPaid: sub.amount,
        paidAt: now,
        billingPeriod: sub.effectiveBillingLabel,
      );

      try {
        final logBox = Hive.isBoxOpen('payment_logs')
            ? Hive.box<PaymentLog>('payment_logs')
            : await Hive.openBox<PaymentLog>('payment_logs');
        await logBox.put(paymentLog.id, paymentLog);
      } catch (e) {
        print('Hive log write error: $e');
      }

      if (sub.isOneTimeBill) {
        // One-time bill: mark paid, keep dueDate unchanged, cancel pending reminders
        final paidBill = Subscription(
          id: sub.id,
          title: sub.title,
          amount: sub.amount,
          currency: sub.currency,
          category: sub.category,
          billingCycle: null,
          customIntervalDays: null,
          startDate: null,
          nextDueDate: sub.nextDueDate,
          isFreeTrial: false,
          trialEndDate: null,
          isPaused: sub.isPaused,
          entryType: 'one_time_bill',
          isPaid: true,
        );

        await _box.put(sub.id, paidBill);
        await _notificationService.cancelSubscriptionReminders(paidBill.id);

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _firestoreSync.syncSubscription(paidBill);
          await _firestoreSync.savePaymentLog(user.uid, paymentLog);
        }
      } else {
        // Recurring subscription: advance nextDueDate to next cycle
        final DateTime nextDate = Subscription.calculateNextDueDate(
          sub.nextDueDate,
          sub.billingCycle,
          intervalDays: sub.customIntervalDays,
        );

        final updatedSub = Subscription(
          id: sub.id,
          title: sub.title,
          amount: sub.amount,
          currency: sub.currency,
          category: sub.category,
          billingCycle: sub.billingCycle ?? 'MONTHLY',
          startDate: sub.startDate,
          nextDueDate: nextDate,
          customIntervalDays: sub.customIntervalDays,
          isFreeTrial: false,
          trialEndDate: sub.trialEndDate,
          isPaused: sub.isPaused,
          entryType: sub.entryType,
          isPaid: false,
        );

        await _box.put(sub.id, updatedSub);

        await _notificationService.cancelSubscriptionReminders(updatedSub.id);
        await _notificationService.scheduleSubscriptionReminders(updatedSub);

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _firestoreSync.syncSubscription(updatedSub);
          await _firestoreSync.savePaymentLog(user.uid, paymentLog);
        }
      }

      state = _box.values.toList();
    }
  }

  Future<void> togglePause(String id) async {
    final sub = _box.get(id);
    if (sub != null) {
      final updatedSub = Subscription(
        id: sub.id,
        title: sub.title,
        amount: sub.amount,
        currency: sub.currency,
        category: sub.category,
        billingCycle: sub.billingCycle,
        startDate: sub.startDate,
        nextDueDate: sub.nextDueDate,
        customIntervalDays: sub.customIntervalDays,
        isFreeTrial: sub.isFreeTrial,
        trialEndDate: sub.trialEndDate,
        isPaused: !sub.isPaused,
        entryType: sub.entryType,
        isPaid: sub.isPaid,
      );

      await _box.put(id, updatedSub);

      if (updatedSub.isPaused ||
          (updatedSub.isOneTimeBill && updatedSub.isPaid)) {
        await _notificationService.cancelSubscriptionReminders(id);
      } else {
        await _notificationService.scheduleSubscriptionReminders(updatedSub);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestoreSync.syncSubscription(updatedSub);
      }
      state = _box.values.toList();
    }
  }

  Future<void> deleteSubscription(String id) async {
    await _box.delete(id);
    await _notificationService.cancelSubscriptionReminders(id);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestoreSync.deleteSubscription(id);
    }
    state = _box.values.toList();
  }
}
