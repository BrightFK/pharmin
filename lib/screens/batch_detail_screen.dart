// lib/screens/batch_detail_screen.dart
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

class BatchDetailScreen extends StatefulWidget {
  final Batch batch;

  const BatchDetailScreen({super.key, required this.batch});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  late final Box<Medicine> _medicineBox;
  late final Box<Supplier> _supplierBox;
  bool _showAnalytics = false;

  @override
  void initState() {
    super.initState();
    _medicineBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    _supplierBox = Hive.box<Supplier>(HiveProvider.suppliersBox);
  }

  Medicine? _getMedicine() {
    return _medicineBox.get(widget.batch.medicineId);
  }

  Supplier? _getSupplier() {
    if (widget.batch.supplierId == null) return null;
    return _supplierBox.get(widget.batch.supplierId);
  }

  String _formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _getStatusText() {
    final now = DateTime.now();
    final expiry = widget.batch.expiryDate;

    if (expiry.isBefore(now)) {
      return 'Expired';
    } else if (expiry.isBefore(now.add(const Duration(days: 30)))) {
      return 'Expiring Soon';
    } else if (widget.batch.quantity <= 0) {
      return 'Out of Stock';
    } else {
      return 'Active';
    }
  }

  Color _getStatusColor() {
    final status = _getStatusText();
    switch (status) {
      case 'Expired':
        return Colors.redAccent;
      case 'Expiring Soon':
        return Colors.orange;
      case 'Out of Stock':
        return Colors.grey;
      case 'Active':
        return Colors.green;
      default:
        return Colors.white;
    }
  }

  IconData _getStatusIcon() {
    final status = _getStatusText();
    switch (status) {
      case 'Expired':
        return Icons.cancel;
      case 'Expiring Soon':
        return Icons.warning;
      case 'Out of Stock':
        return Icons.inventory_2;
      case 'Active':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white60, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medicine = _getMedicine();
    final supplier = _getSupplier();
    final status = _getStatusText();
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    final daysToExpiry = widget.batch.expiryDate
        .difference(DateTime.now())
        .inDays;
    final profitMargin = widget.batch.sellingPrice - widget.batch.costPrice;
    final marginPercentage = widget.batch.costPrice > 0
        ? (profitMargin / widget.batch.costPrice) * 100
        : 0;
    final totalValue = widget.batch.quantity * widget.batch.sellingPrice;
    final totalCost = widget.batch.quantity * widget.batch.costPrice;
    final estimatedProfit = totalValue - totalCost;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Batch #${widget.batch.batchNumber ?? 'Unknown'}',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddEditBatchScreen(
                    medicineId: widget.batch.medicineId,
                    batch: widget.batch,
                  ),
                ),
              );
              if (result == true) {
                setState(() {}); // Refresh if changes were made
              }
            },
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withValues(alpha: 0.2),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Batch #${widget.batch.batchNumber ?? 'Unknown'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Medicine: ${medicine?.name ?? 'Unknown'}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${widget.batch.quantity.toStringAsFixed(2)} units',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            daysToExpiry > 0
                                ? '$daysToExpiry days left'
                                : 'Expired ${daysToExpiry.abs()} days ago',
                            style: TextStyle(color: statusColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsStat(
                        'Total Value',
                        _formatCurrency(totalValue),
                        Icons.attach_money,
                        Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAnalyticsStat(
                        'Est. Profit',
                        _formatCurrency(estimatedProfit),
                        Icons.trending_up,
                        Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAnalyticsStat(
                        'Margin',
                        '${marginPercentage.toStringAsFixed(1)}%',
                        Icons.percent,
                        Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Batch Details Card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Batch Information',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        'Batch Number',
                        widget.batch.batchNumber ?? 'Not provided',
                        icon: Icons.numbers,
                      ),
                      _buildInfoRow(
                        'Expiry Date',
                        DateFormat(
                          'EEEE, MMMM d, yyyy',
                        ).format(widget.batch.expiryDate),
                        icon: Icons.calendar_today,
                      ),
                      _buildInfoRow(
                        'Quantity',
                        '${widget.batch.quantity.toStringAsFixed(2)} units',
                        icon: Icons.production_quantity_limits,
                      ),
                      _buildInfoRow(
                        'Cost Price',
                        _formatCurrency(widget.batch.costPrice),
                        icon: Icons.shopping_cart,
                      ),
                      _buildInfoRow(
                        'Selling Price',
                        _formatCurrency(widget.batch.sellingPrice),
                        icon: Icons.currency_exchange,
                      ),
                      _buildInfoRow(
                        'Profit per Unit',
                        _formatCurrency(profitMargin),
                        icon: Icons.trending_up,
                      ),
                      _buildInfoRow(
                        'Supplier',
                        supplier?.name ?? 'Not provided',
                        icon: Icons.business,
                      ),
                      if (widget.batch.supplierId != null)
                        _buildInfoRow(
                          'Supplier ID',
                          widget.batch.supplierId!,
                          icon: Icons.badge,
                        ),

                      _buildInfoRow(
                        'Storage Location',
                        widget.batch.storageLocation ?? 'Not specified',
                        icon: Icons.location_on,
                      ),
                      _buildInfoRow(
                        'Manufacturing Date',
                        widget.batch.manufacturingDate != null
                            ? DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(widget.batch.manufacturingDate!)
                            : 'Not provided',
                        icon: Icons.build,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          'Edit Batch',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddEditBatchScreen(
                                medicineId: widget.batch.medicineId,
                                batch: widget.batch,
                              ),
                            ),
                          );
                          if (result == true) {
                            setState(() {}); // Refresh if changes were made
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // lib/screens/batch_detail_screen.dart - Updated delete dialog
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: () async {
                          final confirmed = await DeleteConfirmationDialog.show(
                            context,
                            title: 'Delete Batch?',
                            message:
                                'Are you sure you want to delete batch #${widget.batch.batchNumber ?? 'Unknown'}? This action cannot be undone.',
                            confirmText: 'Delete Batch',
                          );
                          if (confirmed == true) {
                            await HiveService.deleteBatch(widget.batch.id);
                            if (!mounted) return;
                            Navigator.pop(context);
                            SnackBarUtils.showSuccess(
                              context,
                              '🗑️ Batch deleted',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Toggle Analytics
                GestureDetector(
                  onTap: () => setState(() => _showAnalytics = !_showAnalytics),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.bar_chart,
                              color: Colors.blueAccent,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Show Analytics',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          _showAnalytics
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white60,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showAnalytics) ...[
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📊 Batch Analytics',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Days in Inventory',
                          '${DateTime.now().difference(widget.batch.expiryDate).inDays.abs()} days',
                          icon: Icons.timer,
                        ),
                        _buildInfoRow(
                          'Stock Turnover Rate',
                          '${(widget.batch.quantity / 30).toStringAsFixed(1)} units/day',
                          icon: Icons.speed,
                        ),
                        _buildInfoRow(
                          'Total Cost',
                          _formatCurrency(totalCost),
                          icon: Icons.money_off,
                        ),
                        _buildInfoRow(
                          'Total Revenue Potential',
                          _formatCurrency(totalValue),
                          icon: Icons.money,
                        ),
                        _buildInfoRow(
                          'Net Profit Potential',
                          _formatCurrency(estimatedProfit),
                          icon: Icons.trending_up,
                        ),
                        _buildInfoRow(
                          'Profit Margin',
                          '${marginPercentage.toStringAsFixed(1)}%',
                          icon: Icons.percent,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blue.shade400.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lightbulb,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  estimatedProfit > 0
                                      ? '💡 This batch has a healthy profit margin of ${marginPercentage.toStringAsFixed(1)}%'
                                      : '⚠️ This batch has a negative profit margin. Consider adjusting pricing.',
                                  style: TextStyle(
                                    color: estimatedProfit > 0
                                        ? Colors.greenAccent
                                        : Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
