import 'package:hive/hive.dart';

import 'typeid_registry.dart';

part 'settings.g.dart';

@HiveType(typeId: TypeIdRegistry.settings)
class Settings extends HiveObject {
  @HiveField(0)
  List<int> expiryWindows; // e.g., [30, 60, 90]

  @HiveField(1)
  String defaultCurrency;

  @HiveField(2)
  bool allowFractionalQuantity;

  Settings({
    this.expiryWindows = const [30, 60, 90],
    this.defaultCurrency = 'USD',
    this.allowFractionalQuantity = true,
  });
}
