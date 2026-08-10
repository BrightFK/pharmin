// lib/services/hive_service.dart
import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/batch.dart';
import '../models/batch_history.dart';
import '../models/medicine.dart';
import '../models/supplier.dart';
import '../providers/hive_provider.dart';

class HiveService {
  static final Uuid _uuid = const Uuid();
  static final Random _random = Random();
  static late final Box<Medicine> _medBox;
  static late final Box<Batch> _batchBox;
  static late final Box<Supplier> _supplierBox;
  static late final Box<BatchHistory> _historyBox;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (!_isInitialized) {
      _medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
      _batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
      _supplierBox = Hive.box<Supplier>(HiveProvider.suppliersBox);
      _historyBox = Hive.box<BatchHistory>(HiveProvider.batchHistoryBox);
      _isInitialized = true;
    }
  }

  static void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'HiveService not initialized. Call HiveService.init() first.',
      );
    }
  }

  static String? _getMedicineName(String medicineId) {
    final med = _medBox.get(medicineId);
    return med?.name;
  }

  // ============ MEDICINE HISTORY ============

  static Future<void> _addMedicineHistory({
    required String medicineId,
    required String medicineName,
    required String eventType,
    Map<String, dynamic>? snapshot,
    Map<String, dynamic>? changes,
    String? notes,
  }) async {
    _ensureInitialized();

    final history = BatchHistory(
      id: _uuid.v4(),
      batchId: medicineId, // Using medicineId as batchId for medicine history
      medicineId: medicineId,
      medicineName: medicineName,
      batchNumber: medicineName, // Using medicine name as identifier
      eventType:
          'medicine_$eventType', // Prefix to distinguish from batch events
      timestamp: DateTime.now(),
      snapshot: snapshot,
      changes: changes,
      notes: notes,
    );

    await _historyBox.put(history.id, history);
  }

  static Map<String, dynamic> _medicineToMap(Medicine medicine) {
    return {
      'name': medicine.name,
      'category': medicine.category,
      'unit': medicine.unit,
      'defaultReorderLevel': medicine.defaultReorderLevel,
      'prescriptionRequired': medicine.prescriptionRequired,
      'preferredSupplierId': medicine.preferredSupplierId,
      'notes': medicine.notes,
    };
  }

  static Map<String, dynamic> _getMedicineChanges(
    Medicine oldMed,
    Medicine newMed,
  ) {
    final changes = <String, dynamic>{};

    if (oldMed.name != newMed.name) {
      changes['name'] = {'old': oldMed.name, 'new': newMed.name};
    }
    if (oldMed.category != newMed.category) {
      changes['category'] = {'old': oldMed.category, 'new': newMed.category};
    }
    if (oldMed.unit != newMed.unit) {
      changes['unit'] = {'old': oldMed.unit, 'new': newMed.unit};
    }
    if (oldMed.defaultReorderLevel != newMed.defaultReorderLevel) {
      changes['defaultReorderLevel'] = {
        'old': oldMed.defaultReorderLevel,
        'new': newMed.defaultReorderLevel,
      };
    }
    if (oldMed.prescriptionRequired != newMed.prescriptionRequired) {
      changes['prescriptionRequired'] = {
        'old': oldMed.prescriptionRequired,
        'new': newMed.prescriptionRequired,
      };
    }
    if (oldMed.preferredSupplierId != newMed.preferredSupplierId) {
      changes['preferredSupplierId'] = {
        'old': oldMed.preferredSupplierId,
        'new': newMed.preferredSupplierId,
      };
    }
    if (oldMed.notes != newMed.notes) {
      changes['notes'] = {'old': oldMed.notes, 'new': newMed.notes};
    }

    return changes;
  }

  // ============ BATCH HISTORY ============

  static Future<void> _addBatchHistory({
    required String batchId,
    required String medicineId,
    required String batchNumber,
    required String eventType,
    Map<String, dynamic>? snapshot,
    Map<String, dynamic>? changes,
    String? notes,
  }) async {
    _ensureInitialized();
    final medicineName = _getMedicineName(medicineId) ?? 'Unknown Medicine';

    final history = BatchHistory(
      id: _uuid.v4(),
      batchId: batchId,
      medicineId: medicineId,
      medicineName: medicineName,
      batchNumber: batchNumber,
      eventType: eventType,
      timestamp: DateTime.now(),
      snapshot: snapshot,
      changes: changes,
      notes: notes,
    );

    await _historyBox.put(history.id, history);
  }

  static Map<String, dynamic> _batchToMap(Batch batch) {
    return {
      'batchNumber': batch.batchNumber,
      'expiryDate': batch.expiryDate.toIso8601String(),
      'quantity': batch.quantity,
      'costPrice': batch.costPrice,
      'sellingPrice': batch.sellingPrice,
      'supplierId': batch.supplierId,
      'storageLocation': batch.storageLocation,
      'manufacturingDate': batch.manufacturingDate?.toIso8601String(),
      'createdAt': batch.createdAt.toIso8601String(),
    };
  }

  static Map<String, dynamic> _getBatchChanges(Batch oldBatch, Batch newBatch) {
    final changes = <String, dynamic>{};

    if (oldBatch.batchNumber != newBatch.batchNumber) {
      changes['batchNumber'] = {
        'old': oldBatch.batchNumber,
        'new': newBatch.batchNumber,
      };
    }
    if (oldBatch.expiryDate != newBatch.expiryDate) {
      changes['expiryDate'] = {
        'old': oldBatch.expiryDate.toIso8601String(),
        'new': newBatch.expiryDate.toIso8601String(),
      };
    }
    if (oldBatch.quantity != newBatch.quantity) {
      changes['quantity'] = {
        'old': oldBatch.quantity,
        'new': newBatch.quantity,
      };
    }
    if (oldBatch.costPrice != newBatch.costPrice) {
      changes['costPrice'] = {
        'old': oldBatch.costPrice,
        'new': newBatch.costPrice,
      };
    }
    if (oldBatch.sellingPrice != newBatch.sellingPrice) {
      changes['sellingPrice'] = {
        'old': oldBatch.sellingPrice,
        'new': newBatch.sellingPrice,
      };
    }
    if (oldBatch.supplierId != newBatch.supplierId) {
      changes['supplierId'] = {
        'old': oldBatch.supplierId,
        'new': newBatch.supplierId,
      };
    }
    if (oldBatch.storageLocation != newBatch.storageLocation) {
      changes['storageLocation'] = {
        'old': oldBatch.storageLocation,
        'new': newBatch.storageLocation,
      };
    }
    if (oldBatch.manufacturingDate != newBatch.manufacturingDate) {
      changes['manufacturingDate'] = {
        'old': oldBatch.manufacturingDate?.toIso8601String(),
        'new': newBatch.manufacturingDate?.toIso8601String(),
      };
    }

    return changes;
  }

  static String _formatChanges(Map<String, dynamic> changes) {
    final parts = <String>[];
    changes.forEach((key, value) {
      parts.add('$key: ${value['old']} → ${value['new']}');
    });
    return parts.join(', ');
  }

  // ============ MEDICINE CRUD ============

  static Future<void> addMedicine(Medicine medicine) async {
    _ensureInitialized();

    // Check if this is a new medicine or update
    final existing = _medBox.get(medicine.id);
    final isNew = existing == null;

    // Save the medicine
    await _medBox.put(medicine.id, medicine);

    // Create history entry
    if (isNew) {
      await _addMedicineHistory(
        medicineId: medicine.id,
        medicineName: medicine.name,
        eventType: 'created',
        snapshot: _medicineToMap(medicine),
        notes: 'Medicine created: ${medicine.name}',
      );
    } else {
      // Medicine edited - track changes
      final changes = _getMedicineChanges(existing!, medicine);
      if (changes.isNotEmpty) {
        await _addMedicineHistory(
          medicineId: medicine.id,
          medicineName: medicine.name,
          eventType: 'edited',
          snapshot: _medicineToMap(medicine),
          changes: changes,
          notes: 'Medicine updated: ${_formatChanges(changes)}',
        );
      }
    }
  }

  static Future<void> deleteMedicine(String id) async {
    _ensureInitialized();
    final medicine = _medBox.get(id);
    if (medicine != null) {
      // Store history before deleting
      await _addMedicineHistory(
        medicineId: medicine.id,
        medicineName: medicine.name,
        eventType: 'deleted',
        snapshot: _medicineToMap(medicine),
        notes: 'Medicine deleted: ${medicine.name}',
      );

      // Delete all batches for this medicine first
      final batchKeys = _batchBox.keys
          .where((key) => _batchBox.get(key)?.medicineId == id)
          .toList();
      for (var key in batchKeys) {
        final batch = _batchBox.get(key);
        if (batch != null) {
          // Also add batch deletion history
          await _addBatchHistory(
            batchId: batch.id,
            medicineId: batch.medicineId,
            batchNumber: batch.batchNumber ?? 'B-${batch.id.substring(0, 4)}',
            eventType: 'deleted',
            snapshot: _batchToMap(batch),
            notes: 'Batch deleted as part of medicine deletion',
          );
        }
        await _batchBox.delete(key);
      }
      await _medBox.delete(id);
    }
  }

  // ============ BATCH CRUD ============

  static Future<void> addBatch(Batch batch) async {
    _ensureInitialized();

    // Check if this is a new batch or update
    final existing = _batchBox.get(batch.id);
    final isNew = existing == null;

    // Save the batch
    await _batchBox.put(batch.id, batch);

    // Create history entry
    if (isNew) {
      await _addBatchHistory(
        batchId: batch.id,
        medicineId: batch.medicineId,
        batchNumber: batch.batchNumber ?? 'B-${batch.id.substring(0, 4)}',
        eventType: 'created',
        snapshot: _batchToMap(batch),
        notes:
            'Batch created for ${_getMedicineName(batch.medicineId) ?? 'Unknown'}',
      );
    } else {
      // Batch edited - track changes
      final changes = _getBatchChanges(existing!, batch);
      if (changes.isNotEmpty) {
        await _addBatchHistory(
          batchId: batch.id,
          medicineId: batch.medicineId,
          batchNumber: batch.batchNumber ?? 'B-${batch.id.substring(0, 4)}',
          eventType: 'edited',
          snapshot: _batchToMap(batch),
          changes: changes,
          notes: 'Batch updated: ${_formatChanges(changes)}',
        );
      }
    }
  }

  static Future<void> deleteBatch(String id) async {
    _ensureInitialized();
    final batch = _batchBox.get(id);
    if (batch != null) {
      // Store history before deleting
      await _addBatchHistory(
        batchId: batch.id,
        medicineId: batch.medicineId,
        batchNumber: batch.batchNumber ?? 'B-${batch.id.substring(0, 4)}',
        eventType: 'deleted',
        snapshot: _batchToMap(batch),
        notes:
            'Batch deleted from ${_getMedicineName(batch.medicineId) ?? 'Unknown'}',
      );
      await _batchBox.delete(id);
    }
  }

  // ============ QUERY METHODS ============

  static double availableStock(String medicineId) {
    _ensureInitialized();
    double total = 0;
    for (var batch in _batchBox.values) {
      if (batch.medicineId == medicineId &&
          batch.expiryDate.isAfter(DateTime.now())) {
        total += batch.quantity;
      }
    }
    return total;
  }

  static bool medicineNameExists(String name, [String? excludeId]) {
    _ensureInitialized();
    for (var med in _medBox.values) {
      if (med.name.toLowerCase() == name.toLowerCase() && med.id != excludeId) {
        return true;
      }
    }
    return false;
  }

  // ============ HISTORY QUERY METHODS ============

  static List<BatchHistory> getBatchHistory(String medicineId) {
    _ensureInitialized();
    final history =
        _historyBox.values.where((h) => h.medicineId == medicineId).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return history;
  }

  static List<BatchHistory> getAllBatchHistory() {
    _ensureInitialized();
    final history = _historyBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return history;
  }

  static List<BatchHistory> getHistoryByEventType(String eventType) {
    _ensureInitialized();
    final history =
        _historyBox.values.where((h) => h.eventType == eventType).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return history;
  }

  static Future<Batch> addSampleBatchForMedicine(String medicineId) async {
    _ensureInitialized();
    final batch = Batch(
      id: _uuid.v4(),
      medicineId: medicineId,
      batchNumber: 'SAMPLE-${DateTime.now().millisecondsSinceEpoch % 10000}',
      expiryDate: DateTime.now().add(const Duration(days: 365)),
      quantity: 50,
      costPrice: 1.0,
      sellingPrice: 2.0,
      storageLocation: 'Sample Location',
      manufacturingDate: DateTime.now(),
    );
    await addBatch(batch); // This will automatically add history
    return batch;
  }

  static Future<void> clearAll() async {
    _ensureInitialized();
    await _medBox.clear();
    await _batchBox.clear();
    await _historyBox.clear();
  }

  static String _generateRandomSupplierId() {
    final suppliers = ['SUP-001', 'SUP-002', 'SUP-003', 'SUP-004', 'SUP-005'];
    return suppliers[_random.nextInt(suppliers.length)];
  }

  // Add this method to HiveService in hive_service.dart

  static Future<void> recordSaleInBatchHistory({
    required String batchId,
    required String medicineId,
    required String medicineName,
    required String batchNumber,
    required double quantitySold,
    required double pricePerUnit,
    required String transactionId,
  }) async {
    _ensureInitialized();

    final history = BatchHistory(
      id: _uuid.v4(),
      batchId: batchId,
      medicineId: medicineId,
      medicineName: medicineName,
      batchNumber: batchNumber,
      eventType: 'sale', // New event type for sales
      timestamp: DateTime.now(),
      snapshot: {
        'quantitySold': quantitySold,
        'pricePerUnit': pricePerUnit,
        'totalAmount': quantitySold * pricePerUnit,
        'transactionId': transactionId,
      },
      notes:
          'Sale: ${quantitySold.toStringAsFixed(2)} units sold at \$${pricePerUnit.toStringAsFixed(2)} each',
    );

    await _historyBox.put(history.id, history);
  }

  static int min(int a, int b) => a < b ? a : b;

  // ============ DEBUG METHODS ============

  static Future<void> printHistoryStats() async {
    _ensureInitialized();
    final allHistory = _historyBox.values.toList();
    print('📊 Total History Records: ${allHistory.length}');

    final created = allHistory.where((h) => h.eventType == 'created').length;
    final edited = allHistory.where((h) => h.eventType == 'edited').length;
    final deleted = allHistory.where((h) => h.eventType == 'deleted').length;
    final medicineCreated = allHistory
        .where((h) => h.eventType == 'medicine_created')
        .length;
    final medicineEdited = allHistory
        .where((h) => h.eventType == 'medicine_edited')
        .length;
    final medicineDeleted = allHistory
        .where((h) => h.eventType == 'medicine_deleted')
        .length;

    print('📝 Batch Created: $created');
    print('✏️ Batch Edited: $edited');
    print('🗑️ Batch Deleted: $deleted');
    print('💊 Medicine Created: $medicineCreated');
    print('💊 Medicine Edited: $medicineEdited');
    print('💊 Medicine Deleted: $medicineDeleted');

    // Print last 5 events
    print('\n📋 Last 5 events:');
    final sorted = allHistory.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    for (var h in sorted.take(5)) {
      final type = h.eventType.contains('medicine_')
          ? h.eventType.replaceFirst('medicine_', '')
          : h.eventType;
      print(
        '  • ${type.toUpperCase()}: ${h.batchNumber} (${h.medicineName}) - ${DateFormat('MMM d, HH:mm').format(h.timestamp)}',
      );
    }
  }
}

const List<String> batchLetters = ['A', 'B', 'C', 'D', 'E'];
