import 'package:hive/hive.dart';

part 'payment_log_model.g.dart';

@HiveType(typeId: 1)
class PaymentLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String subscriptionId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final double amountPaid;

  @HiveField(4)
  final DateTime paidAt;

  @HiveField(5)
  final String billingPeriod;

  PaymentLog({
    required this.id,
    required this.subscriptionId,
    required this.title,
    required this.amountPaid,
    required this.paidAt,
    required this.billingPeriod,
  });
}
