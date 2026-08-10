// lib/screens/medicine_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/batch.dart';
import '../models/medicine.dart';
import '../models/supplier.dart';
import '../providers/hive_provider.dart';
import '../services/hive_service.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/glass_card.dart';
import 'add_edit_batch_screen.dart';
import 'add_edit_medicine_screen.dart';
import 'batch_detail_screen.dart';
import 'batch_history_screen.dart';

class MedicineDetailScreen extends StatefulWidget {
  final Medicine medicine;
  const MedicineDetailScreen({super.key, required this.medicine});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  bool _showAnalytics = false;
  bool _showHistory = false;
  late final Box<Batch> _batchesBox;
  late final Box<Supplier> _supplierBox;

  @override
  void initState() {
    super.initState();
    _batchesBox = Hive.box<Batch>(HiveProvider.batchesBox);
    _supplierBox = Hive.box<Supplier>(HiveProvider.suppliersBox);
  }

  String _supplierDisplay(String? supplierId) {
    if (supplierId == null || supplierId.isEmpty) return 'Not provided';
    final s = _supplierBox.get(supplierId);
    return s?.name ?? 'Unknown (ID: $supplierId)';
  }

  Widget _detailRow(
    String label,
    String value, {
    Color valueColor = Colors.white70,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Analytics calculations
  Map<String, dynamic> _calculateAnalytics() {
    final batches = _batchesBox.values
        .where((b) => b.medicineId == widget.medicine.id)
        .toList();

    if (batches.isEmpty) {
      return {
        'totalBatches': 0,
        'totalStock': 0.0,
        'totalValue': 0.0,
        'expiredBatches': 0,
        'expiredStock': 0.0,
        'expiringSoon': 0,
        'averageCost': 0.0,
        'averageSell': 0.0,
        'stockTrend': '+0%',
        'trendColor': Colors.white60,
        'avgTurnover': '0 units/month',
      };
    }

    final now = DateTime.now();

    double totalStock = 0;
    double totalValue = 0;
    int expiredBatches = 0;
    double expiredStock = 0;
    int expiringSoonCount = 0;
    double totalCost = 0;
    double totalSell = 0;
    int validBatchCount = 0;

    DateTime? oldestDate;
    DateTime? newestDate;
    double oldestStock = 0;
    double newestStock = 0;

    for (var batch in batches) {
      final isExpired = batch.expiryDate.isBefore(now);
      final isExpiringSoon =
          batch.expiryDate.isBefore(now.add(const Duration(days: 30))) &&
          !isExpired;

      if (isExpired) {
        expiredBatches++;
        expiredStock += batch.quantity;
      } else {
        totalStock += batch.quantity;
        totalValue += batch.quantity * batch.sellingPrice;
        totalCost += batch.costPrice * batch.quantity;
        totalSell += batch.sellingPrice * batch.quantity;
        validBatchCount++;
      }

      if (isExpiringSoon && !isExpired) {
        expiringSoonCount++;
      }

      if (oldestDate == null || batch.expiryDate.isBefore(oldestDate)) {
        oldestDate = batch.expiryDate;
        oldestStock = isExpired ? 0 : batch.quantity;
      }
      if (newestDate == null || batch.expiryDate.isAfter(newestDate)) {
        newestDate = batch.expiryDate;
        newestStock = isExpired ? 0 : batch.quantity;
      }
    }

    String stockTrend;
    Color trendColor;
    double trendPercent = 0;

    if (oldestStock > 0 && newestStock > 0) {
      trendPercent = ((newestStock - oldestStock) / oldestStock) * 100;
    } else if (newestStock > 0) {
      trendPercent = 100;
    } else if (oldestStock > 0) {
      trendPercent = -100;
    }

    if (trendPercent > 10) {
      stockTrend = '+${trendPercent.toStringAsFixed(0)}%';
      trendColor = Colors.greenAccent;
    } else if (trendPercent > 0) {
      stockTrend = '+${trendPercent.toStringAsFixed(0)}%';
      trendColor = Colors.lightGreen;
    } else if (trendPercent < -10) {
      stockTrend = '${trendPercent.toStringAsFixed(0)}%';
      trendColor = Colors.redAccent;
    } else if (trendPercent < 0) {
      stockTrend = '${trendPercent.toStringAsFixed(0)}%';
      trendColor = Colors.orange;
    } else {
      stockTrend = '0%';
      trendColor = Colors.white60;
    }

    final avgTurnover = validBatchCount > 0
        ? '${(totalStock / 6).toStringAsFixed(0)} units/month'
        : '0 units/month';

    return {
      'totalBatches': batches.length,
      'totalStock': totalStock,
      'totalValue': totalValue,
      'expiredBatches': expiredBatches,
      'expiredStock': expiredStock,
      'expiringSoon': expiringSoonCount,
      'averageCost': validBatchCount > 0 ? totalCost / validBatchCount : 0,
      'averageSell': validBatchCount > 0 ? totalSell / validBatchCount : 0,
      'stockTrend': stockTrend,
      'trendColor': trendColor,
      'avgTurnover': avgTurnover,
      'batchCount': validBatchCount,
    };
  }

  // History data
  List<Map<String, dynamic>> _getBatchHistory() {
    final batches =
        _batchesBox.values
            .where((b) => b.medicineId == widget.medicine.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (batches.isEmpty) return [];

    return batches.map((batch) {
      final isExpired = batch.expiryDate.isBefore(DateTime.now());
      final daysToExpiry = batch.expiryDate.difference(DateTime.now()).inDays;

      return {
        'batch': batch,
        'batchNumber': batch.batchNumber ?? 'B-${batch.id.substring(0, 4)}',
        'quantity': batch.quantity,
        'costPrice': batch.costPrice,
        'sellingPrice': batch.sellingPrice,
        'expiryDate': batch.expiryDate,
        'createdAt': batch.createdAt,
        'status': isExpired
            ? 'Expired'
            : daysToExpiry < 30
            ? 'Expiring Soon'
            : 'Active',
        'statusColor': isExpired
            ? Colors.redAccent
            : daysToExpiry < 30
            ? Colors.orange
            : Colors.green,
        'totalValue': batch.quantity * batch.sellingPrice,
        'profitPerUnit': batch.sellingPrice - batch.costPrice,
        'storageLocation': batch.storageLocation,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final availableStock = HiveService.availableStock(widget.medicine.id);
    final analytics = _calculateAnalytics();
    final history = _getBatchHistory();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Medicine details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AddEditMedicineScreen(medicine: widget.medicine),
                ),
              );
              setState(() {});
            },
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info card: name + summary + key details
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
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
                                widget.medicine.name.isNotEmpty
                                    ? widget.medicine.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
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
                                  widget.medicine.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.medicine.category ?? 'Not provided',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${availableStock.toStringAsFixed(2)} ${widget.medicine.unit ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Reorder: ${widget.medicine.defaultReorderLevel}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _detailRow(
                        'Unit',
                        widget.medicine.unit ?? 'Not provided',
                      ),
                      _detailRow(
                        'Prescription required',
                        widget.medicine.prescriptionRequired ? 'Yes' : 'No',
                      ),
                      _detailRow(
                        'Preferred supplier',
                        _supplierDisplay(widget.medicine.preferredSupplierId),
                      ),
                      _detailRow(
                        'Notes',
                        widget.medicine.notes?.isNotEmpty == true
                            ? widget.medicine.notes!
                            : 'Not provided',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Actions row (Add Batch, History, Analytics)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickAction(
                      icon: Icons.add_shopping_cart,
                      label: 'Add Batch',
                      onTap: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddEditBatchScreen(
                              medicineId: widget.medicine.id,
                            ),
                          ),
                        );
                        if (result == true) {
                          setState(() {});
                        }
                      },
                    ),

                    // In medicine_detail_screen.dart, update the history action:
                    _buildQuickAction(
                      icon: Icons.history,
                      label: 'History',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BatchHistoryScreen(
                              medicineId: widget.medicine.id,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildQuickAction(
                      icon: Icons.bar_chart,
                      label: 'Analytics',
                      onTap: () =>
                          setState(() => _showAnalytics = !_showAnalytics),
                    ),
                  ],
                ),

                // History Card
                if (_showHistory)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.history,
                                color: Colors.blueAccent,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '📜 Batch History',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 8),
                          if (history.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                  'No batch history available',
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ),
                            )
                          else
                            ...history.map((entry) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: entry['statusColor'],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              entry['batchNumber'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          DateFormat(
                                            'MMM d, yyyy',
                                          ).format(entry['createdAt']),
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Qty: ${entry['quantity'].toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Cost: \$${entry['costPrice'].toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Sell: \$${entry['sellingPrice'].toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Profit: \$${entry['profitPerUnit'].toStringAsFixed(2)}/unit',
                                            style: TextStyle(
                                              color: entry['profitPerUnit'] > 0
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Status: ${entry['status']}',
                                            style: TextStyle(
                                              color: entry['statusColor'],
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (entry['storageLocation'] != null)
                                      Text(
                                        '📍 ${entry['storageLocation']}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                // Analytics Card - With real data
                if (_showAnalytics)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📊 Analytics',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.trending_up,
                                color: Colors.greenAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Stock Trend: ',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          analytics['stockTrend'],
                                          style: TextStyle(
                                            color: analytics['trendColor'],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Average turnover: ${analytics['avgTurnover']}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildAnalyticsStat(
                                  'Total Stock',
                                  analytics['totalStock'].toStringAsFixed(0),
                                  Icons.inventory,
                                  Colors.blueAccent,
                                ),
                              ),
                              Expanded(
                                child: _buildAnalyticsStat(
                                  'Total Value',
                                  '\$${analytics['totalValue'].toStringAsFixed(2)}',
                                  Icons.attach_money,
                                  Colors.greenAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _buildAnalyticsStat(
                                  'Batches',
                                  analytics['totalBatches'].toString(),
                                  Icons.production_quantity_limits,
                                  Colors.orangeAccent,
                                ),
                              ),
                              Expanded(
                                child: _buildAnalyticsStat(
                                  'Expired',
                                  analytics['expiredBatches'].toString(),
                                  Icons.warning,
                                  Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _buildAnalyticsStat(
                                  'Expiring Soon',
                                  analytics['expiringSoon'].toString(),
                                  Icons.timer,
                                  Colors.orange,
                                ),
                              ),
                              Expanded(
                                child: _buildAnalyticsStat(
                                  'Avg Sell Price',
                                  '\$${analytics['averageSell'].toStringAsFixed(2)}',
                                  Icons.price_change,
                                  Colors.purpleAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Batches header with count and add button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          color: Colors.white60,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Batches',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ValueListenableBuilder(
                            valueListenable: _batchesBox.listenable(),
                            builder: (context, box, _) {
                              final count = box.values
                                  .where(
                                    (b) => b.medicineId == widget.medicine.id,
                                  )
                                  .length;
                              return Text(
                                count.toString(),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.add,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Add Batch',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddEditBatchScreen(
                              medicineId: widget.medicine.id,
                            ),
                          ),
                        );
                        if (result == true) {
                          setState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Batches list
                ValueListenableBuilder(
                  valueListenable: _batchesBox.listenable(),
                  builder: (context, box, _) {
                    final list =
                        box.values
                            .where((b) => b.medicineId == widget.medicine.id)
                            .toList()
                          ..sort(
                            (a, b) => a.expiryDate.compareTo(b.expiryDate),
                          );

                    if (list.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.white.withValues(alpha: 0.2),
                                size: 50,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No batches added yet',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add your first batch to track stock',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: list.map((batch) {
                        final expired = batch.expiryDate.isBefore(
                          DateTime.now(),
                        );
                        final expiringSoon = batch.expiryDate.isBefore(
                          DateTime.now().add(const Duration(days: 30)),
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BatchDetailScreen(batch: batch),
                                ),
                              );
                            },
                            child: GlassCard(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: expired
                                        ? Colors.redAccent.withValues(
                                            alpha: 0.2,
                                          )
                                        : Colors.green.withValues(alpha: 0.2),
                                  ),
                                  child: Icon(
                                    expired
                                        ? Icons.warning
                                        : Icons.check_circle,
                                    color: expired
                                        ? Colors.redAccent
                                        : Colors.green,
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  batch.batchNumber ??
                                      'B-${batch.id.substring(0, 4)}',
                                  style: TextStyle(
                                    color: expired
                                        ? Colors.redAccent
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Expiry: ${DateFormat.yMMMd().format(batch.expiryDate)}',
                                      style: TextStyle(
                                        color: expiringSoon && !expired
                                            ? Colors.orange
                                            : Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Qty: ${batch.quantity.toStringAsFixed(2)} • Cost: ${batch.costPrice.toStringAsFixed(2)} • Sell: ${batch.sellingPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (batch.storageLocation != null)
                                      Text(
                                        'Location: ${batch.storageLocation}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11,
                                        ),
                                      ),
                                    Text(
                                      'Supplier: ${batch.supplierId ?? 'Not provided'}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (expiringSoon && !expired)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          'Expiring',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                      onPressed: () async {
                                        final confirmed =
                                            await DeleteConfirmationDialog.show(
                                              context,
                                              title: 'Delete Batch?',
                                              message:
                                                  'Are you sure you want to delete batch #${batch.batchNumber ?? 'Unknown'}? This action cannot be undone.',
                                              confirmText: 'Delete Batch',
                                            );
                                        if (confirmed == true) {
                                          await HiveService.deleteBatch(
                                            batch.id,
                                          );
                                          setState(() {});
                                          SnackBarUtils.showSuccess(
                                            context,
                                            '🗑️ Batch deleted',
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                // Add bottom padding for scrolling
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsStat(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(label, style: TextStyle(color: Colors.white60, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blueAccent, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
