// lib/models/batch_history.dart
import 'package:hive/hive.dart';

import 'typeid_registry.dart';

part 'batch_history.g.dart';

@HiveType(typeId: TypeIdRegistry.batchHistory)
class BatchHistory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String batchId;

  @HiveField(2)
  final String medicineId;

  @HiveField(3)
  final String medicineName;

  @HiveField(4)
  final String batchNumber;

  @HiveField(5)
  final String eventType; // 'created', 'edited', 'deleted'

  @HiveField(6)
  final DateTime timestamp;

  @HiveField(7)
  final Map<String, dynamic>? snapshot; // Full batch snapshot at time of event

  @HiveField(8)
  final Map<String, dynamic>? changes; // What changed (for edit events)

  @HiveField(9)
  final String? notes;

  BatchHistory({
    required this.id,
    required this.batchId,
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    required this.eventType,
    required this.timestamp,
    this.snapshot,
    this.changes,
    this.notes,
  });
}
