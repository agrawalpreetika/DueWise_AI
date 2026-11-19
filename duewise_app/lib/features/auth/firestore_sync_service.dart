import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../subscriptions/payment_log_model.dart';
import '../subscriptions/subscription_model.dart';

class FirestoreSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _userSubscriptionsRef {
    if (_userId == null) return null;
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('subscriptions');
  }

  // Upload or update subscription in Firestore
  Future<void> syncSubscription(Subscription subscription) async {
    final ref = _userSubscriptionsRef;
    if (ref == null) return;

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
  }

  // Delete subscription from Firestore
  Future<void> deleteSubscription(String id) async {
    final ref = _userSubscriptionsRef;
    if (ref == null) return;

    await ref.doc(id).delete();
  }

  // Pull subscriptions from Firestore to populate Hive on fresh login
  Future<List<Subscription>> fetchCloudSubscriptions() async {
    final ref = _userSubscriptionsRef;
    if (ref == null) {
      print(
        'DEBUG ERROR: _userSubscriptionsRef is NULL! User is not authenticated properly.',
      );
      return [];
    }

    try {
      print('DEBUG: Fetching subscriptions for User UID: $_userId');
      final snapshot = await ref.get();
      print(
        'DEBUG: Successfully fetched ${snapshot.docs.length} documents from cloud.',
      );

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
      print(
        'CRITICAL FIRESTORE FETCH ERROR: $e',
      ); // Yeh asli error print karega!
      return [];
    }
  }

  // Save Payment Log to Firestore
  // Save Payment Log to Firestore (Guaranteed Collection Creation)
  // Save Payment Log to Firestore (Guaranteed Collection Creation)
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
          }, SetOptions(merge: true));

      print('Payment log successfully saved to cloud!');
    } catch (e) {
      print('Error saving payment log to Firestore: $e');
    }
  }

  // Fetch recent payment logs from Firestore (Last 30 Days)
  // Fetch recent payment logs from Firestore
  Future<List<PaymentLog>> fetchRecentPaymentLogs() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('payment_logs')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();

        // Safe Date Parsing
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
