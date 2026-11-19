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

  // 1. Upload or update subscription in Firestore
  Future<void> syncSubscription(Subscription subscription) async {
    final ref = _userSubscriptionsRef;
    if (ref == null) return;

    try {
      await ref.doc(subscription.id).set({
        'id': subscription.id,
        'title': subscription.title,
        'category': subscription.category,
        'amount': subscription.amount,
        'billingCycle': subscription.billingCycle,
        'customIntervalDays': subscription.customIntervalDays,
        'startDate': subscription.startDate.toIso8601String(),
        'nextDueDate': subscription.nextDueDate.toIso8601String(),
        'isPaused': subscription.isPaused,
        'isFreeTrial': subscription.isFreeTrial,
        'trialEndDate': subscription.trialEndDate?.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print(
        'Subscription synced to Firestore successfully: ${subscription.title}',
      );
    } catch (e) {
      print('Error syncing subscription to Firestore: $e');
    }
  }

  // 2. Delete subscription from Firestore
  Future<void> deleteSubscription(String id) async {
    final ref = _userSubscriptionsRef;
    if (ref == null) return;

    try {
      await ref.doc(id).delete();
    } catch (e) {
      print('Error deleting cloud subscription: $e');
    }
  }

  // 3. Pull subscriptions from Firestore to populate Hive on fresh login
  Future<List<Subscription>> fetchCloudSubscriptions() async {
    final ref = _userSubscriptionsRef;
    if (ref == null) return [];

    try {
      final snapshot = await ref.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Subscription(
          id: data['id'] ?? doc.id,
          title: data['title'] ?? '',
          category: data['category'] ?? 'General',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          billingCycle: data['billingCycle'] ?? 'Monthly',
          customIntervalDays: data['customIntervalDays'] as int?,
          startDate: data['startDate'] != null
              ? DateTime.parse(data['startDate'])
              : DateTime.now(),
          nextDueDate: data['nextDueDate'] != null
              ? DateTime.parse(data['nextDueDate'])
              : DateTime.now(),
          isPaused: data['isPaused'] ?? false,
          isFreeTrial: data['isFreeTrial'] ?? false,
          trialEndDate: data['trialEndDate'] != null
              ? DateTime.parse(data['trialEndDate'])
              : null,
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
