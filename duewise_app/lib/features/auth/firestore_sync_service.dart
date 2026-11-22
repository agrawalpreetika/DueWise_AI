import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../subscriptions/payment_log_model.dart';
import '../subscriptions/subscription_model.dart';

class FirestoreSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Corrected type definition
  CollectionReference<Map<String, dynamic>>? get _userSubscriptionsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('subscriptions');
  }

  // 1. Upload or update subscription / one-time bill in Firestore
  Future<void> syncSubscription(Subscription subscription) async {
    final ref = _userSubscriptionsRef;
    if (ref == null) return;

    try {
      await ref.doc(subscription.id).set({
        'id': subscription.id,
        'title': subscription.title,
        'category': subscription.category,
        'amount': subscription.amount,
        'currency': subscription.currency,
        'entryType': subscription.entryType,
        'billingCycle': subscription.billingCycle,
        'customIntervalDays': subscription.customIntervalDays,
        'startDate': subscription.startDate?.toIso8601String(),
        'nextDueDate': subscription.nextDueDate.toIso8601String(),
        'isPaused': subscription.isPaused,
        'isPaid': subscription.isPaid,
        'isFreeTrial': subscription.isFreeTrial,
        'trialEndDate': subscription.trialEndDate?.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print(
        'Subscription/bill synced to Firestore successfully: ${subscription.title}',
      );
    } catch (e) {
      print('Error syncing subscription/bill to Firestore: $e');
    }
  }

  // 2. Delete subscription / one-time bill from Firestore
  Future<void> deleteSubscription(String id) async {
    final ref = _userSubscriptionsRef;
    if (ref == null) return;

    try {
      await ref.doc(id).delete();
    } catch (e) {
      print('Error deleting cloud subscription/bill: $e');
    }
  }

  // 3. Pull subscriptions / one-time bills from Firestore to populate Hive on fresh login
  Future<List<Subscription>> fetchCloudSubscriptions() async {
    final ref = _userSubscriptionsRef;
    if (ref == null) return [];

    try {
      final snapshot = await ref.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final entryType =
            (data['entryType'] as String?)?.trim().toLowerCase() ??
            'subscription';
        final isOneTime = entryType == 'one_time_bill';

        final rawStartDate = data['startDate'];
        DateTime? parsedStartDate;
        if (!isOneTime && rawStartDate != null) {
          if (rawStartDate is Timestamp) {
            parsedStartDate = rawStartDate.toDate();
          } else if (rawStartDate is String) {
            parsedStartDate = DateTime.tryParse(rawStartDate);
          }
        }

        final rawNextDueDate = data['nextDueDate'];
        DateTime parsedNextDueDate = DateTime.now();
        if (rawNextDueDate is Timestamp) {
          parsedNextDueDate = rawNextDueDate.toDate();
        } else if (rawNextDueDate is String) {
          parsedNextDueDate =
              DateTime.tryParse(rawNextDueDate) ?? DateTime.now();
        }

        final rawTrialEndDate = data['trialEndDate'];
        DateTime? parsedTrialEndDate;
        if (rawTrialEndDate is Timestamp) {
          parsedTrialEndDate = rawTrialEndDate.toDate();
        } else if (rawTrialEndDate is String) {
          parsedTrialEndDate = DateTime.tryParse(rawTrialEndDate);
        }

        return Subscription(
          id: data['id'] ?? doc.id,
          title: data['title'] ?? '',
          category: data['category'] ?? 'Utilities',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          currency: (data['currency'] as String?) ?? 'INR',
          entryType: isOneTime ? 'one_time_bill' : 'subscription',
          billingCycle: isOneTime
              ? null
              : ((data['billingCycle'] as String?) ?? 'MONTHLY'),
          customIntervalDays: isOneTime
              ? null
              : (data['customIntervalDays'] as int?),
          startDate: parsedStartDate,
          nextDueDate: parsedNextDueDate,
          isPaused: data['isPaused'] ?? false,
          isPaid: data['isPaid'] ?? false,
          isFreeTrial: isOneTime ? false : (data['isFreeTrial'] ?? false),
          trialEndDate: isOneTime ? null : parsedTrialEndDate,
        );
      }).toList();
    } catch (e) {
      print('Firestore subscription parsing error: $e');
      return [];
    }
  }

  // 4. Save Payment Log to Firestore
  Future<void> savePaymentLog(String userId, PaymentLog log) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('payment_logs')
          .doc(log.id)
          .set({
            'id': log.id,
            'subscriptionId': log.subscriptionId,
            'title': log.title,
            'amountPaid': log.amountPaid,
            'paidAt': Timestamp.fromDate(log.paidAt),
            'billingPeriod': log.billingPeriod,
          });
      print('Payment log saved to cloud successfully.');
    } catch (e) {
      print('Error saving payment log to Firestore: $e');
    }
  }

  // 5. FETCH RECENT PAYMENT LOGS FROM CLOUD
  Future<List<PaymentLog>> fetchRecentPaymentLogs() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('payment_logs')
          .orderBy('paidAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();

        DateTime parseDate(dynamic dateVal) {
          if (dateVal is Timestamp) {
            return dateVal.toDate();
          } else if (dateVal is String) {
            return DateTime.tryParse(dateVal) ?? DateTime.now();
          }
          return DateTime.now();
        }

        return PaymentLog(
          id: data['id'] ?? doc.id,
          subscriptionId: data['subscriptionId'] ?? '',
          title: data['title'] ?? '',
          amountPaid: (data['amountPaid'] as num?)?.toDouble() ?? 0.0,
          paidAt: parseDate(data['paidAt']),
          billingPeriod: data['billingPeriod'] ?? 'Monthly',
        );
      }).toList();
    } catch (e) {
      print('Error fetching cloud payment logs: $e');
      return [];
    }
  }
}
