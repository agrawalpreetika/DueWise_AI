// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentLogAdapter extends TypeAdapter<PaymentLog> {
  @override
  final int typeId = 1;

  @override
  PaymentLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentLog(
      id: fields[0] as String,
      subscriptionId: fields[1] as String,
      title: fields[2] as String,
      amountPaid: fields[3] as double,
      paidAt: fields[4] as DateTime,
      billingPeriod: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.subscriptionId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.amountPaid)
      ..writeByte(4)
      ..write(obj.paidAt)
      ..writeByte(5)
      ..write(obj.billingPeriod);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
