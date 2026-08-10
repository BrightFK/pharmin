// lib/models/pharmacy_profile.dart
import 'package:hive/hive.dart';

import 'typeid_registry.dart';

part 'pharmacy_profile.g.dart';

@HiveType(typeId: TypeIdRegistry.pharmacyProfile)
class PharmacyProfile extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pharmacyName;

  @HiveField(2)
  String? address;

  @HiveField(3)
  String? phone;

  @HiveField(4)
  String? email;

  @HiveField(5)
  String? website;

  @HiveField(6)
  String? logoPath; // For future logo support

  @HiveField(7)
  String? taxId; // Business registration number

  @HiveField(8)
  String? licenseNumber; // Pharmacy license number

  @HiveField(9)
  String? receiptFooter; // Custom footer message

  PharmacyProfile({
    required this.id,
    required this.pharmacyName,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.logoPath,
    this.taxId,
    this.licenseNumber,
    this.receiptFooter,
  });
}
