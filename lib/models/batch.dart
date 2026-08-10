// lib/models/batch.dart
import 'package:hive/hive.dart';

import 'typeid_registry.dart';

part 'batch.g.dart';

@HiveType(typeId: TypeIdRegistry.batch)
class Batch extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String medicineId;

  @HiveField(2)
  String? batchNumber;

  @HiveField(3)
  DateTime expiryDate;

  @HiveField(4)
  double quantity;

  @HiveField(5)
  double costPrice;

  @HiveField(6)
  double sellingPrice;

  @HiveField(7)
  String? supplierId;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime? manufacturingDate; // Added

  @HiveField(10)
  String? storageLocation; // Added

  Batch({
    required this.id,
    required this.medicineId,
    required this.expiryDate,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
    this.batchNumber,
    this.supplierId,
    this.manufacturingDate,
    this.storageLocation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
