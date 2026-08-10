import 'package:hive/hive.dart';

import 'typeid_registry.dart';

part 'audit_log.g.dart';

@HiveType(typeId: TypeIdRegistry.auditLog)
class AuditLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String kind; // 'sale', 'adjustment', 'expiry_auto', etc.

  @HiveField(2)
  String? medicineId;

  @HiveField(3)
  String? batchId;

  @HiveField(4)
  double change;

  @HiveField(5)
  String? note;

  @HiveField(6)
  DateTime date;

  AuditLog({
    required this.id,
    required this.kind,
    this.medicineId,
    this.batchId,
    required this.change,
    this.note,
    DateTime? date,
  }) : date = date ?? DateTime.now();
}
