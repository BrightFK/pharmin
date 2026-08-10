import 'package:hive/hive.dart';

import 'transaction_item.dart';
import 'typeid_registry.dart';

part 'transaction.g.dart';

@HiveType(typeId: TypeIdRegistry.transaction)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String type; // 'sale' | 'return' | 'adjustment'

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  double totalAmount;

  @HiveField(4)
  String? paymentMethod;

  @HiveField(5)
  List<TransactionItem> items;

  @HiveField(6)
  String? notes;

  Transaction({
    required this.id,
    required this.type,
    DateTime? date,
    this.totalAmount = 0.0,
    this.paymentMethod,
    this.items = const [],
    this.notes,
  }) : date = date ?? DateTime.now();
}
