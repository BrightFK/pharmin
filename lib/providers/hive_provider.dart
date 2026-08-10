// lib/providers/hive_provider.dart
import 'package:hive_flutter/hive_flutter.dart';

import '../models/audit_log.dart';
import '../models/batch.dart';
import '../models/batch_history.dart';
import '../models/medicine.dart';
import '../models/pharmacy_profile.dart';
import '../models/supplier.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';

class HiveProvider {
  static const String medicinesBox = 'medicinesBox';
  static const String batchesBox = 'batchesBox';
  static const String suppliersBox = 'suppliersBox';
  static const String batchHistoryBox = 'batchHistoryBox';
  static const String transactionsBox = 'transactionsBox';
  static const String auditBox = 'auditBox';
  static const String pharmacyProfileBox = 'pharmacyProfileBox';

  static Future<void> init() async {
    // Register adapters
    Hive.registerAdapter(MedicineAdapter());
    Hive.registerAdapter(BatchAdapter());
    Hive.registerAdapter(SupplierAdapter());
    Hive.registerAdapter(BatchHistoryAdapter());
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(TransactionItemAdapter());
    Hive.registerAdapter(AuditLogAdapter());
    Hive.registerAdapter(PharmacyProfileAdapter());

    // Open boxes
    await Hive.openBox<Medicine>(medicinesBox);
    await Hive.openBox<Batch>(batchesBox);
    await Hive.openBox<Supplier>(suppliersBox);
    await Hive.openBox<BatchHistory>(batchHistoryBox);
    await Hive.openBox<Transaction>(transactionsBox);
    await Hive.openBox<AuditLog>(auditBox);
    await Hive.openBox<PharmacyProfile>(pharmacyProfileBox);
  }
}
