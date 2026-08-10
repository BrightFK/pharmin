// lib/screens/sales_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/audit_log.dart';
import '../models/batch.dart';
import '../models/batch_history.dart';
import '../models/medicine.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../providers/hive_provider.dart';
import '../services/hive_service.dart';
import '../services/pharmacy_service.dart';
import '../utils/pdf_receipt_generator.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/glass_card.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _uuid = const Uuid();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Medicine> _allMedicines = [];
  List<Medicine> _filteredMedicines = [];
  Medicine? _selectedMedicine;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'Cash';
  final List<TransactionItem> _cartItems = [];
  double _totalAmount = 0.0;
  bool _isProcessing = false;
  bool _showCart = false;
  bool _showSelectedMedicine = false;

  final List<String> _paymentMethods = [
    'Cash',
    'Card',
    'Mobile Money',
    'Insurance',
    'Credit',
  ];

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
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
          final hasStock = HiveService.availableStock(med.id) > 0;
          return (matchesName || matchesCategory) && hasStock;
        }).toList();
      }
    });
  }

  void _selectMedicine(Medicine med) {
    setState(() {
      _selectedMedicine = med;
      _showSelectedMedicine = true;
      _searchController.clear();
      _searchQuery = '';

      final batches = Hive.box<Batch>(
        HiveProvider.batchesBox,
      ).values.where((b) => b.medicineId == med.id && b.quantity > 0).toList();

      if (batches.isNotEmpty) {
        final earliestBatch = batches.reduce(
          (a, b) => a.expiryDate.isBefore(b.expiryDate) ? a : b,
        );
        _priceController.text = earliestBatch.sellingPrice.toStringAsFixed(2);
      }

      _quantityController.text = '1';
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedMedicine = null;
      _showSelectedMedicine = false;
      _searchController.clear();
      _searchQuery = '';
      _quantityController.clear();
      _priceController.clear();
    });
  }

  void _addToCart() {
    if (_selectedMedicine == null) {
      SnackBarUtils.showError(context, 'Please select a medicine');
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      SnackBarUtils.showError(context, 'Please enter a valid quantity');
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 0) {
      SnackBarUtils.showError(context, 'Please enter a valid price');
      return;
    }

    final available = HiveService.availableStock(_selectedMedicine!.id);
    if (quantity > available) {
      SnackBarUtils.showError(
        context,
        'Not enough stock. Available: ${available.toStringAsFixed(2)}',
      );
      return;
    }

    final existingIndex = _cartItems.indexWhere(
      (item) =>
          item.medicineId == _selectedMedicine!.id && item.unitPrice == price,
    );

    if (existingIndex != -1) {
      setState(() {
        final existing = _cartItems[existingIndex];
        _totalAmount -= existing.lineTotal;
        existing.quantity += quantity;
        existing.lineTotal = existing.quantity * existing.unitPrice;
        _totalAmount += existing.lineTotal;
      });
    } else {
      final item = TransactionItem(
        id: _uuid.v4(),
        medicineId: _selectedMedicine!.id,
        quantity: quantity,
        unitPrice: price,
      );
      setState(() {
        _cartItems.add(item);
        _totalAmount += price * quantity;
      });
    }

    setState(() {
      _selectedMedicine = null;
      _showSelectedMedicine = false;
      _searchController.clear();
      _searchQuery = '';
      _quantityController.clear();
      _priceController.clear();
      _showCart = true;
    });

    SnackBarUtils.showSuccess(context, 'Added to cart');
  }

  void _removeFromCart(int index) {
    setState(() {
      final item = _cartItems[index];
      _totalAmount -= item.lineTotal;
      _cartItems.removeAt(index);
      if (_cartItems.isEmpty) {
        _showCart = false;
      }
    });
  }

  void _updateCartItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(index);
      return;
    }

    setState(() {
      final item = _cartItems[index];
      _totalAmount -= item.lineTotal;
      item.quantity = newQuantity;
      item.lineTotal = item.quantity * item.unitPrice;
      _totalAmount += item.lineTotal;
    });
  }

  void _clearCart() {
    if (_cartItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A237E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cart?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove all items from the cart.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _cartItems.clear();
                _totalAmount = 0.0;
                _showCart = false;
              });
              Navigator.pop(context);
              SnackBarUtils.showInfo(context, 'Cart cleared');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    SnackBarUtils.showSuccess(context, '📋 Copied to clipboard!');
  }

  Future<void> _processSale() async {
    if (_cartItems.isEmpty) {
      SnackBarUtils.showError(context, 'Cart is empty');
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
      final auditEntries = <AuditLog>[];
      final historyEntries = <BatchHistory>[];
      final transactionId = _uuid.v4();

      for (var cartItem in _cartItems) {
        final medicine = medBox.get(cartItem.medicineId);
        if (medicine == null) continue;

        double remaining = cartItem.quantity;

        final batches =
            batchBox.values
                .where(
                  (b) => b.medicineId == cartItem.medicineId && b.quantity > 0,
                )
                .toList()
              ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

        double consumedTotal = 0;
        String? usedBatchId;
        String? usedBatchNumber;

        for (var batch in batches) {
          if (remaining <= 0) break;

          final available = batch.quantity;
          final toConsume = min(remaining, available);

          batch.quantity -= toConsume;
          await batch.save();

          consumedTotal += toConsume;
          remaining -= toConsume;
          usedBatchId = batch.id;
          usedBatchNumber = batch.batchNumber;

          auditEntries.add(
            AuditLog(
              id: _uuid.v4(),
              kind: 'sale',
              medicineId: cartItem.medicineId,
              batchId: batch.id,
              change: -toConsume,
              note: 'Sale: ${medicine.name} x ${toConsume.toStringAsFixed(2)}',
            ),
          );

          historyEntries.add(
            BatchHistory(
              id: _uuid.v4(),
              batchId: batch.id,
              medicineId: cartItem.medicineId,
              medicineName: medicine.name,
              batchNumber: batch.batchNumber ?? 'B-${batch.id.substring(0, 4)}',
              eventType: 'sale',
              timestamp: DateTime.now(),
              snapshot: {
                'quantitySold': toConsume,
                'pricePerUnit': cartItem.unitPrice,
                'totalAmount': toConsume * cartItem.unitPrice,
                'transactionId': transactionId,
              },
              notes:
                  'Sale: ${toConsume.toStringAsFixed(2)} units sold at \$${cartItem.unitPrice.toStringAsFixed(2)} each',
            ),
          );
        }

        if (remaining > 0) {
          throw Exception('Not enough stock for ${medicine.name}');
        }

        processedItems.add(
          TransactionItem(
            id: _uuid.v4(),
            medicineId: cartItem.medicineId,
            batchId: usedBatchId,
            quantity: cartItem.quantity,
            unitPrice: cartItem.unitPrice,
          ),
        );
      }

      // Create transaction
      final transaction = Transaction(
        id: transactionId,
        type: 'sale',
        totalAmount: _totalAmount,
        paymentMethod: _paymentMethod,
        items: processedItems,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await transactionBox.put(transaction.id, transaction);

      // Save all audit logs
      for (var audit in auditEntries) {
        await auditBox.put(audit.id, audit);
      }

      // Save all batch history entries
      for (var history in historyEntries) {
        await historyBox.put(history.id, history);
      }

      setState(() {
        _cartItems.clear();
        _totalAmount = 0.0;
        _notesController.clear();
        _showCart = false;
      });

      Navigator.pop(context);

      SnackBarUtils.showSuccess(
        context,
        '✅ Sale completed! Total: \$${transaction.totalAmount.toStringAsFixed(2)}',
      );

      // Show receipt
      _showReceipt(transaction);
    } catch (e) {
      SnackBarUtils.showError(
        context,
        'Error processing sale: ${e.toString()}',
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // In sales_screen.dart, update the _showReceipt method's print button:

  Future<void> _showReceipt(Transaction transaction) async {
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final medicines = medBox.values.toList();
    final now = DateTime.now();
    final receiptNumber =
        'RCP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${transaction.id.substring(0, 6).toUpperCase()}';
    final profile = await PharmacyService.getProfile();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 380,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.local_pharmacy,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          profile?.pharmacyName?.toUpperCase() ?? 'PHARM IN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile?.address ?? '123 Health Street, Medical City',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      'Tel: ${profile?.phone ?? '+234 800 1234 567'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                    if (profile?.licenseNumber != null) ...[
                      Text(
                        'Lic: ${profile!.licenseNumber}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 9,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'RECEIPT',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Receipt info with copy
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Receipt #',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                          InkWell(
                            onTap: () => _copyToClipboard(receiptNumber),
                            child: Row(
                              children: [
                                Text(
                                  receiptNumber,
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.copy,
                                  color: Colors.grey[400],
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'MMM d, yyyy h:mm a',
                            ).format(transaction.date),
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transaction ID',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                          InkWell(
                            onTap: () => _copyToClipboard(transaction.id),
                            child: Row(
                              children: [
                                Text(
                                  transaction.id.substring(0, 8).toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.copy,
                                  color: Colors.grey[400],
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cashier',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            'PharmIn System',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.black12),
                      // Items header
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'ITEM',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'QTY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'PRICE',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'TOTAL',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.black12),
                      // Items
                      ...transaction.items.map((item) {
                        final med = medBox.get(item.medicineId);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  med?.name ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  item.quantity.toStringAsFixed(2),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '\$${item.unitPrice.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '\$${item.lineTotal.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(color: Colors.black12),
                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '\$${transaction.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Method',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            transaction.paymentMethod ?? 'Cash',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (transaction.notes != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Notes: ${transaction.notes}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.grey.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Thank you for your purchase!',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                      child: const Text('Close'),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.copy,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () {
                            // Copy receipt details
                            final receiptText =
                                '''
PHARM IN
123 Health Street, Medical City
Tel: +234 800 1234 567
RECEIPT #$receiptNumber
Date: ${DateFormat('MMM d, yyyy h:mm a').format(transaction.date)}
---
${transaction.items.map((item) {
                                  final med = medBox.get(item.medicineId);
                                  return '${med?.name ?? 'Unknown'} x${item.quantity.toStringAsFixed(2)}  \$${item.lineTotal.toStringAsFixed(2)}';
                                }).join('\n')}
---
Total: \$${transaction.totalAmount.toStringAsFixed(2)}
Payment: ${transaction.paymentMethod ?? 'Cash'}
---
Thank you for your purchase!
''';
                            _copyToClipboard(receiptText);
                          },
                          tooltip: 'Copy Receipt',
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Generate and share PDF
                            try {
                              // Close the dialog
                              Navigator.pop(context);

                              // Show loading
                              SnackBarUtils.showInfo(
                                context,
                                '📄 Generating PDF receipt...',
                              );

                              // Get medicines for the receipt
                              final medicines = medBox.values.toList();

                              // Generate and share PDF
                              await PdfReceiptGenerator.generateReceipt(
                                transaction,
                                medicines,
                              );

                              SnackBarUtils.showSuccess(
                                context,
                                '📄 PDF receipt generated and shared!',
                              );
                            } catch (e) {
                              SnackBarUtils.showError(
                                context,
                                '❌ Error generating PDF: ${e.toString()}',
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D1B2A),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: const Text(
                            'PDF',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = _cartItems.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Sales',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_cartItems.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                  onPressed: () {
                    setState(() => _showCart = !_showCart);
                  },
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      cartCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
        ],
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
              // Search Bar
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
                      hintText: 'Search medicine by name or category...',
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white38,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _filteredMedicines = _allMedicines;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),

              // Selected Medicine Card
              if (_showSelectedMedicine && _selectedMedicine != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade700,
                                    Colors.blue.shade400,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _selectedMedicine!.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Stock: ${HiveService.availableStock(_selectedMedicine!.id).toStringAsFixed(2)} ${_selectedMedicine!.unit ?? 'pcs'}',
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
                        const SizedBox(height: 12),
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
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Price',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.attach_money,
                                    color: Colors.white60,
                                    size: 18,
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
                              onPressed: _addToCart,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Add',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
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
                              _searchQuery.isEmpty
                                  ? 'Search for medicines to sell'
                                  : 'No medicines found',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 16,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              const SizedBox(height: 8),
                            if (_searchQuery.isNotEmpty)
                              Text(
                                'Try adjusting your search',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredMedicines.length,
                        itemBuilder: (context, index) {
                          final med = _filteredMedicines[index];
                          final stock = HiveService.availableStock(med.id);
                          final isLowStock = stock <= med.defaultReorderLevel;

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
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade700,
                                          Colors.blue.shade400,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        med.name.isNotEmpty
                                            ? med.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '${med.category ?? 'Uncategorized'}',
                                              style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${stock.toStringAsFixed(2)} ${med.unit ?? 'pcs'}',
                                              style: TextStyle(
                                                color: isLowStock
                                                    ? Colors.orange
                                                    : Colors.white60,
                                                fontSize: 11,
                                                fontWeight: isLowStock
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.blueAccent.withValues(
                                      alpha: 0.7,
                                    ),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      floatingActionButton: _cartItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _toggleCart,
              backgroundColor: Colors.blueAccent,
              icon: Badge(
                label: Text(
                  _cartItems.length.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
                child: const Icon(Icons.shopping_cart, color: Colors.white),
              ),
              label: Text(
                '\$${_totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
  // Replace the bottomSheet with this approach:

  void _toggleCart() {
    if (_showCart) {
      setState(() => _showCart = false);
    } else {
      // Show cart as modal bottom sheet
      setState(() => _showCart = true);
      showModalBottomSheet(
        context: context,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildCartSheet(),
      ).then((_) {
        // When bottom sheet is dismissed
        setState(() => _showCart = false);
      });
    }
  }

  Widget _buildCartSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        color: Colors.blueAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Cart (${_cartItems.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _clearCart,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white60,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _showCart = false);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Cart Items
          Expanded(
            child: _cartItems.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white24,
                          size: 40,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Cart is empty',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      final medBox = Hive.box<Medicine>(
                        HiveProvider.medicinesBox,
                      );
                      final med = medBox.get(item.medicineId);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.06),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade700,
                                    Colors.blue.shade400,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  med?.name[0].toUpperCase() ?? '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    med?.name ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove,
                                          color: Colors.white54,
                                          size: 16,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          _updateCartItemQuantity(
                                            index,
                                            item.quantity - 0.5,
                                          );
                                        },
                                      ),
                                      SizedBox(
                                        width: 30,
                                        child: Text(
                                          item.quantity.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add,
                                          color: Colors.white54,
                                          size: 16,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          _updateCartItemQuantity(
                                            index,
                                            item.quantity + 0.5,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${item.lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _removeFromCart(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Checkout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.03),
                  Colors.white.withValues(alpha: 0.01),
                ],
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Column(
              children: [
                // Payment method and notes row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _paymentMethod,
                          dropdownColor: const Color(0xFF1A237E),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: _paymentMethods.map((method) {
                            return DropdownMenuItem<String>(
                              value: method,
                              child: Text(method),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _paymentMethod = value ?? 'Cash');
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _notesController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Notes',
                          hintStyle: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Colors.blueAccent,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processSale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.black87,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Complete Sale',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
