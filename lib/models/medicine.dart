import 'package:hive/hive.dart';

import 'typeid_registry.dart';

part 'medicine.g.dart';

@HiveType(typeId: TypeIdRegistry.medicine)
class Medicine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? category;

  @HiveField(3)
  String? unit; // tablet, mL, bottle

  @HiveField(4)
  bool prescriptionRequired;

  @HiveField(5)
  double defaultReorderLevel;

  @HiveField(6)
  String? preferredSupplierId;

  @HiveField(7)
  String? notes;

  Medicine({
    required this.id,
    required this.name,
    this.category,
    this.unit,
    this.prescriptionRequired = false,
    this.defaultReorderLevel = 10.0,
    this.preferredSupplierId,
    this.notes,
  });
}
