// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'batch_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BatchHistoryAdapter extends TypeAdapter<BatchHistory> {
  @override
  final int typeId = 6;

  @override
  BatchHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BatchHistory(
      id: fields[0] as String,
      batchId: fields[1] as String,
      medicineId: fields[2] as String,
      medicineName: fields[3] as String,
      batchNumber: fields[4] as String,
      eventType: fields[5] as String,
      timestamp: fields[6] as DateTime,
      snapshot: (fields[7] as Map?)?.cast<String, dynamic>(),
      changes: (fields[8] as Map?)?.cast<String, dynamic>(),
      notes: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BatchHistory obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.batchId)
      ..writeByte(2)
      ..write(obj.medicineId)
      ..writeByte(3)
      ..write(obj.medicineName)
      ..writeByte(4)
      ..write(obj.batchNumber)
      ..writeByte(5)
      ..write(obj.eventType)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.snapshot)
      ..writeByte(8)
      ..write(obj.changes)
      ..writeByte(9)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
