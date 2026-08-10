import 'package:hive/hive.dart';

import 'typeid_registry.dart';

part 'transaction_item.g.dart';

@HiveType(typeId: TypeIdRegistry.transactionItem)
class TransactionItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String medicineId;

  @HiveField(2)
  String? batchId; // optional: record which batch was consumed

  @HiveField(3)
  double quantity;

  @HiveField(4)
  double unitPrice;

  @HiveField(5)
  double lineTotal;

  TransactionItem({
    required this.id,
    required this.medicineId,
    this.batchId,
    required this.quantity,
    required this.unitPrice,
  }) : lineTotal = quantity * unitPrice;
}
