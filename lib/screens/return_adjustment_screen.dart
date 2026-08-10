// lib/screens/return_adjustment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/audit_log.dart';
import '../models/batch.dart';
import '../models/batch_history.dart';
import '../models/medicine.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../providers/hive_provider.dart';
import '../services/hive_service.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/glass_card.dart';

class ReturnAdjustmentScreen extends ConsumerStatefulWidget {
  final String type; // 'return' or 'adjustment'
  const ReturnAdjustmentScreen({super.key, required this.type});

  @override
  ConsumerState<ReturnAdjustmentScreen> createState() =>
      _ReturnAdjustmentScreenState();
}

class _ReturnAdjustmentScreenState
    extends ConsumerState<ReturnAdjustmentScreen> {
  final _uuid = const Uuid();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Medicine> _allMedicines = [];
  List<Medicine> _filteredMedicines = [];
  Medicine? _selectedMedicine;
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _cartItems = <TransactionItem>[];
  double _totalAmount = 0.0;
  bool _isProcessing = false;
  String _adjustmentReason = 'Damaged'; // Default for adjustments
  String _returnReason = 'Customer Return'; // Default for returns

  final List<String> _adjustmentReasons = [
    'Damaged',
    'Expired',
    'Counting Error',
    'Theft/Loss',
    'Return to Supplier',
    'Sample/Demo',
    'Recall',
    'Other',
  ];

  final List<String> _returnReasons = [
    'Customer Return',
    'Damaged in Transit',
    'Wrong Product Delivered',
    'Expired Before Sale',
    'Supplier Recall',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadMedicines() {
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    setState(() {
      _allMedicines = medBox.values.toList();
      _filteredMedicines = _allMedicines;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredMedicines = _allMedicines;
      } else {
        _filteredMedicines = _allMedicines.where((med) {
          final matchesName = med.name.toLowerCase().contains(query);
          final matchesCategory =
              med.category?.toLowerCase().contains(query) ?? false;
          return matchesName || matchesCategory;
        }).toList();
      }
    });
  }

  void _selectMedicine(Medicine med) {
    setState(() {
      _selectedMedicine = med;
      _searchController.clear();
      _searchQuery = '';
      _quantityController.text = '1';
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedMedicine = null;
      _searchController.clear();
      _searchQuery = '';
      _quantityController.clear();
    });
  }

  void _addItem() {
    if (_selectedMedicine == null) {
      SnackBarUtils.showError(context, 'Please select a medicine');
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      SnackBarUtils.showError(context, 'Please enter a valid quantity');
      return;
    }

    // Get batch to get selling price
    final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
    final batches = batchBox.values
        .where((b) => b.medicineId == _selectedMedicine!.id && b.quantity > 0)
        .toList();

    final price = batches.isNotEmpty ? batches.first.sellingPrice : 0.0;

    final item = TransactionItem(
      id: _uuid.v4(),
      medicineId: _selectedMedicine!.id,
      quantity: quantity,
      unitPrice: price,
    );

    setState(() {
      _cartItems.add(item);
      _totalAmount += price * quantity;
      _selectedMedicine = null;
      _searchController.clear();
      _searchQuery = '';
      _quantityController.clear();
    });

    SnackBarUtils.showSuccess(context, 'Added to ${widget.type} list');
  }

  void _removeItem(int index) {
    setState(() {
      final item = _cartItems[index];
      _totalAmount -= item.lineTotal;
      _cartItems.removeAt(index);
    });
  }

  // Copy to clipboard helper
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    SnackBarUtils.showSuccess(context, '📋 Copied to clipboard!');
  }

  Future<void> _processTransaction() async {
    if (_cartItems.isEmpty) {
      SnackBarUtils.showError(context, 'No items to process');
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      SnackBarUtils.showError(context, 'Please provide a reason');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
      final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
      final transactionBox = Hive.box<Transaction>(
        HiveProvider.transactionsBox,
      );
      final auditBox = Hive.box<AuditLog>(HiveProvider.auditBox);
      final historyBox = Hive.box<BatchHistory>(HiveProvider.batchHistoryBox);

      final processedItems = <TransactionItem>[];
      final transactionId = _uuid.v4();
      final reason = _reasonController.text.trim();

      for (var item in _cartItems) {
        final medicine = medBox.get(item.medicineId);
        if (medicine == null) continue;

        if (widget.type == 'return') {
          // RETURN - Add back to stock (increase inventory)
          final batches =
              batchBox.values
                  .where((b) => b.medicineId == item.medicineId)
                  .toList()
                ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

          if (batches.isNotEmpty) {
            final batch = batches.first;
            batch.quantity += item.quantity;
            await batch.save();

            // Add history
            final history = BatchHistory(
              id: _uuid.v4(),
              batchId: batch.id,
              medicineId: item.medicineId,
              medicineName: medicine.name,
              batchNumber: batch.batchNumber ?? 'B-${batch.id.substring(0, 4)}',
              eventType: 'return',
              timestamp: DateTime.now(),
              snapshot: {
                'quantityReturned': item.quantity,
                'reason': reason,
                'transactionId': transactionId,
              },
              notes:
                  'Return: ${item.quantity.toStringAsFixed(2)} units returned - $reason',
            );
            await historyBox.put(history.id, history);
          }
        } else {
          // ADJUSTMENT - Remove from stock (decrease inventory)
          final batches =
              batchBox.values
                  .where(
                    (b) => b.medicineId == item.medicineId && b.quantity > 0,
                  )
                  .toList()
                ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

          double remaining = item.quantity;
          for (var batch in batches) {
            if (remaining <= 0) break;
            final toRemove = remaining > batch.quantity
                ? batch.quantity
                : remaining;
            batch.quantity -= toRemove;
            remaining -= toRemove;
            await batch.save();

            final history = BatchHistory(
              id: _uuid.v4(),
              batchId: batch.id,
              medicineId: item.medicineId,
              medicineName: medicine.name,
              batchNumber: batch.batchNumber ?? 'B-${batch.id.substring(0, 4)}',
              eventType: 'adjustment',
              timestamp: DateTime.now(),
              snapshot: {
                'quantityAdjusted': toRemove,
                'reason': reason,
                'transactionId': transactionId,
              },
              notes:
                  'Adjustment: ${toRemove.toStringAsFixed(2)} units removed - $reason',
            );
            await historyBox.put(history.id, history);
          }
        }

        // Audit log
        final audit = AuditLog(
          id: _uuid.v4(),
          kind: widget.type,
          medicineId: item.medicineId,
          change: widget.type == 'return' ? item.quantity : -item.quantity,
          note:
              '${widget.type.toUpperCase()}: ${medicine.name} x ${item.quantity.toStringAsFixed(2)} - $reason',
        );
        await auditBox.put(audit.id, audit);

        processedItems.add(item);
      }

      // Create transaction
      final transaction = Transaction(
        id: transactionId,
        type: widget.type,
        totalAmount: _totalAmount,
        items: processedItems,
        notes:
            '$reason${_notesController.text.isNotEmpty ? ' - ${_notesController.text.trim()}' : ''}',
      );
      await transactionBox.put(transaction.id, transaction);

      setState(() {
        _cartItems.clear();
        _totalAmount = 0.0;
        _reasonController.clear();
        _notesController.clear();
      });

      SnackBarUtils.showSuccess(
        context,
        '✅ ${widget.type.toUpperCase()} completed successfully!',
      );

      // Show summary dialog with copyable ID
      _showSummaryDialog(transactionId, reason);
    } catch (e) {
      SnackBarUtils.showError(context, 'Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSummaryDialog(String transactionId, String reason) {
    final typeLabel = widget.type.toUpperCase();
    final isReturn = widget.type == 'return';
    final color = isReturn ? Colors.green : Colors.orange;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A237E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isReturn ? Icons.undo : Icons.tune, color: color),
            const SizedBox(width: 8),
            Text(
              '$typeLabel Complete',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaction Details:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('ID: ', style: TextStyle(color: Colors.white60)),
                Expanded(
                  child: Text(
                    transactionId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy,
                    color: Colors.blueAccent,
                    size: 18,
                  ),
                  onPressed: () => _copyToClipboard(transactionId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Reason: $reason',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 4),
            Text(
              'Items: ${_cartItems.length}',
              style: const TextStyle(color: Colors.white60),
            ),
            if (widget.type == 'adjustment') ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠️ Stock has been permanently reduced.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            ],
            if (widget.type == 'return') ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✅ Stock has been successfully returned.',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReturn = widget.type == 'return';
    final color = isReturn ? Colors.green : Colors.orange;
    final reasonOptions = isReturn ? _returnReasons : _adjustmentReasons;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isReturn ? 'Return Stock' : 'Adjust Stock',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D1B2A),
              const Color(0xFF1B263B),
              const Color(0xFF2C3E50),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search
              Container(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search medicine...',
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              // Selected Medicine
              if (_selectedMedicine != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    isReturn
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    isReturn
                                        ? Colors.green.shade400
                                        : Colors.orange.shade400,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _selectedMedicine!.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedMedicine!.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _selectedMedicine!.category ??
                                        'Uncategorized',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white38,
                              ),
                              onPressed: _cancelSelection,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Quantity',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addItem,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Medicine List
              Expanded(
                child: _filteredMedicines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              color: Colors.white.withValues(alpha: 0.2),
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Search for medicines',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredMedicines.length,
                        itemBuilder: (context, index) {
                          final med = _filteredMedicines[index];
                          final stock = HiveService.availableStock(med.id);

                          return GestureDetector(
                            onTap: () => _selectMedicine(med),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          isReturn
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                          isReturn
                                              ? Colors.green.shade400
                                              : Colors.orange.shade400,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        med.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          med.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Stock: ${stock.toStringAsFixed(2)} ${med.unit ?? 'pcs'}',
                                          style: TextStyle(
                                            color: stock > 0
                                                ? Colors.white60
                                                : Colors.redAccent,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: isReturn
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Section - Cart
              if (_cartItems.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Items summary
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          itemCount: _cartItems.length,
                          itemBuilder: (context, index) {
                            final item = _cartItems[index];
                            final medBox = Hive.box<Medicine>(
                              HiveProvider.medicinesBox,
                            );
                            final med = medBox.get(item.medicineId);
                            return ListTile(
                              dense: true,
                              leading: Text(
                                '${item.quantity.toStringAsFixed(2)}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              title: Text(
                                med?.name ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '\$${item.lineTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    onPressed: () => _removeItem(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      // Reason dropdown
                      DropdownButtonFormField<String>(
                        value: isReturn ? _returnReason : _adjustmentReason,
                        dropdownColor: const Color(0xFF1A237E),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Reason *',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Colors.blueAccent,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: reasonOptions.map((reason) {
                          return DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            if (isReturn) {
                              _returnReason = value ?? 'Customer Return';
                              _reasonController.text = _returnReason;
                            } else {
                              _adjustmentReason = value ?? 'Damaged';
                              _reasonController.text = _adjustmentReason;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      // Additional notes
                      TextField(
                        controller: _notesController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Additional notes (optional)',
                          hintStyle: TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Colors.blueAccent,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '\$${_totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isProcessing
                                  ? null
                                  : _processTransaction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      isReturn
                                          ? 'Complete Return'
                                          : 'Complete Adjustment',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
