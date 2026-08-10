// lib/services/pharmacy_service.dart
import 'package:hive_flutter/hive_flutter.dart';

import '../models/pharmacy_profile.dart';
import '../providers/hive_provider.dart';

class PharmacyService {
  static PharmacyProfile? _profile;
  static bool _isLoaded = false;

  static Future<PharmacyProfile?> getProfile() async {
    if (_isLoaded && _profile != null) return _profile;

    final box = Hive.box<PharmacyProfile>(HiveProvider.pharmacyProfileBox);
    final profiles = box.values.toList();
    if (profiles.isNotEmpty) {
      _profile = profiles.first;
      _isLoaded = true;
      return _profile;
    }
    return null;
  }

  // Sync version for CSV generation (since it's synchronous)
  static PharmacyProfile? getProfileSync() {
    if (_isLoaded && _profile != null) return _profile;

    final box = Hive.box<PharmacyProfile>(HiveProvider.pharmacyProfileBox);
    final profiles = box.values.toList();
    if (profiles.isNotEmpty) {
      _profile = profiles.first;
      _isLoaded = true;
      return _profile;
    }
    return null;
  }

  static String getPharmacyName() {
    final profile = getProfileSync();
    return profile?.pharmacyName ?? 'PHARM IN';
  }

  static String getAddress() {
    final profile = getProfileSync();
    return profile?.address ?? '123 Health Street, Medical City';
  }

  static String getPhone() {
    final profile = getProfileSync();
    return profile?.phone ?? '+234 800 1234 567';
  }

  static String getEmail() {
    final profile = getProfileSync();
    return profile?.email ?? 'info@pharmin.com';
  }

  static String getLicenseNumber() {
    final profile = getProfileSync();
    return profile?.licenseNumber ?? '';
  }

  static String getTaxId() {
    final profile = getProfileSync();
    return profile?.taxId ?? '';
  }

  static String getReceiptFooter() {
    final profile = getProfileSync();
    return profile?.receiptFooter ?? 'Thank you for your purchase!';
  }

  static Future<void> refresh() async {
    _profile = null;
    _isLoaded = false;
    await getProfile();
  }
}
