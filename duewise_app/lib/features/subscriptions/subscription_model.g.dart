// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubscriptionAdapter extends TypeAdapter<Subscription> {
  @override
  final int typeId = 0;

  @override
  Subscription read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subscription(
      id: fields[0] as String,
      title: fields[1] as String,
      category: fields[2] as String,
      amount: fields[3] as double,
      currency: fields[4] as String,
      billingCycle: fields[5] as String,
      customIntervalDays: fields[6] as int?,
      startDate: fields[7] as DateTime,
      nextDueDate: fields[8] as DateTime,
      isFreeTrial: fields[9] as bool,
      trialEndDate: fields[10] as DateTime?,
      isPaused: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Subscription obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(5)
      ..write(obj.billingCycle)
      ..writeByte(6)
      ..write(obj.customIntervalDays)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.nextDueDate)
      ..writeByte(9)
      ..write(obj.isFreeTrial)
      ..writeByte(10)
      ..write(obj.trialEndDate)
      ..writeByte(11)
      ..write(obj.isPaused);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
