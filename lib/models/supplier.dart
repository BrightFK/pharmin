import 'package:hive/hive.dart';

import 'typeid_registry.dart';

part 'supplier.g.dart';

@HiveType(typeId: TypeIdRegistry.supplier)
class Supplier extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? contact;

  @HiveField(3)
  String? phone;

  @HiveField(4)
  String? email;

  Supplier({
    required this.id,
    required this.name,
    this.contact,
    this.phone,
    this.email,
  });
}
