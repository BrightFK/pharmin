// lib/screens/export_reports_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/batch.dart';
import '../models/medicine.dart';
import '../models/transaction.dart';
import '../providers/hive_provider.dart';
import '../services/hive_service.dart';
import '../services/pharmacy_service.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/glass_card.dart';

class ExportReportsScreen extends StatefulWidget {
  const ExportReportsScreen({super.key});

  @override
  State<ExportReportsScreen> createState() => _ExportReportsScreenState();
}

class _ExportReportsScreenState extends State<ExportReportsScreen> {
  bool _isExporting = false;

  String _csvClean(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(2);
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2);
  }

  String _generateStockReportCSV() {
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
    final now = DateTime.now();
    final profile = PharmacyService.getProfileSync();

    final buffer = StringBuffer();

    buffer.writeln(
      '${profile?.pharmacyName?.toUpperCase() ?? 'PHARM IN'} - COMPLETE STOCK REPORT',
    );
    if (profile?.address != null) buffer.writeln(profile!.address);
    if (profile?.phone != null) buffer.writeln('Tel: ${profile!.phone}');
    if (profile?.email != null) buffer.writeln('Email: ${profile!.email}');
    if (profile?.licenseNumber != null) {
      buffer.writeln('License: ${profile!.licenseNumber}');
    }
    buffer.writeln(
      'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}',
    );
    buffer.writeln('=' * 80);
    buffer.writeln('');

    buffer.writeln(
      'Name,Category,Unit,Total Stock,Reorder Level,Status,Stock Value,Avg Cost,Avg Sell,Profit Margin,Total Batches,Expiry Alerts',
    );

    for (var medicine in medBox.values) {
      final stock = HiveService.availableStock(medicine.id);
      final isLowStock = stock <= medicine.defaultReorderLevel;
      final status = isLowStock ? 'LOW STOCK' : 'OK';

      final batches = batchBox.values
          .where((b) => b.medicineId == medicine.id && b.quantity > 0)
          .toList();

      double totalValue = 0.0;
      double totalCost = 0.0;
      double totalSell = 0.0;
      double totalQty = 0.0;

      for (var batch in batches) {
        totalValue += batch.quantity * batch.sellingPrice;
        totalCost += batch.quantity * batch.costPrice;
        totalSell += batch.quantity * batch.sellingPrice;
        totalQty += batch.quantity;
      }

      final avgCost = totalQty > 0 ? totalCost / totalQty : 0.0;
      final avgSell = totalQty > 0 ? totalSell / totalQty : 0.0;
      final profitMargin = avgCost > 0
          ? ((avgSell - avgCost) / avgCost) * 100
          : 0.0;

      List<String> alertList = [];
      for (var batch in batches) {
        final daysLeft = batch.expiryDate.difference(now).inDays;
        if (daysLeft <= 90 && daysLeft >= 0) {
          alertList.add('${batch.batchNumber}: expires in $daysLeft days');
        } else if (daysLeft < 0) {
          alertList.add('${batch.batchNumber}: EXPIRED');
        }
      }

      final expiryAlerts = alertList.isEmpty
          ? 'No alerts'
          : alertList.join('; ');

      final cleanName = _csvClean(medicine.name);
      final cleanCategory = _csvClean(medicine.category);
      final cleanUnit = _csvClean(medicine.unit);
      final cleanAlerts = _csvClean(expiryAlerts);

      final row =
          '$cleanName,$cleanCategory,$cleanUnit,'
          '${_formatNumber(stock)},${_formatNumber(medicine.defaultReorderLevel)},$status,'
          '${_formatCurrency(totalValue)},${_formatCurrency(avgCost)},${_formatCurrency(avgSell)},'
          '${_formatNumber(profitMargin)}%,${batches.length},$cleanAlerts';
      buffer.writeln(row);
    }

    buffer.writeln('');
    buffer.writeln('=' * 80);
    buffer.writeln('SUMMARY STATISTICS');
    buffer.writeln('=' * 80);

    int totalMedicines = medBox.values.length;
    int lowStockCount = 0;
    int expiringCount = 0;
    double grandTotalValue = 0.0;

    for (var medicine in medBox.values) {
      final stock = HiveService.availableStock(medicine.id);
      if (stock <= medicine.defaultReorderLevel) {
        lowStockCount++;
      }

      final batches = batchBox.values
          .where((b) => b.medicineId == medicine.id && b.quantity > 0)
          .toList();
      for (var batch in batches) {
        grandTotalValue += batch.quantity * batch.sellingPrice;
        final daysLeft = batch.expiryDate.difference(now).inDays;
        if (daysLeft <= 90 && daysLeft >= 0) {
          expiringCount++;
        }
      }
    }

    buffer.writeln('Total Medicines,$totalMedicines');
    buffer.writeln('Low Stock Items,$lowStockCount');
    buffer.writeln('Items Expiring Soon (90 days or less),$expiringCount');
    buffer.writeln(
      'Grand Total Stock Value,${_formatCurrency(grandTotalValue)}',
    );

    return buffer.toString();
  }

  String _generateTransactionReportCSV() {
    final transactionBox = Hive.box<Transaction>(HiveProvider.transactionsBox);
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final now = DateTime.now();
    final profile = PharmacyService.getProfileSync();

    final buffer = StringBuffer();

    buffer.writeln(
      '${profile?.pharmacyName?.toUpperCase() ?? 'PHARM IN'} - TRANSACTION REPORT',
    );
    if (profile?.address != null) buffer.writeln(profile!.address);
    if (profile?.phone != null) buffer.writeln('Tel: ${profile!.phone}');
    if (profile?.email != null) buffer.writeln('Email: ${profile!.email}');
    if (profile?.licenseNumber != null) {
      buffer.writeln('License: ${profile!.licenseNumber}');
    }
    buffer.writeln(
      'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}',
    );
    buffer.writeln('=' * 80);
    buffer.writeln('');

    buffer.writeln(
      'Date,Time,Transaction ID,Type,Medicine,Quantity,Unit Price,Total,Payment Method,Profit,Notes',
    );

    for (var transaction in transactionBox.values) {
      for (var item in transaction.items) {
        final medicine = medBox.get(item.medicineId);

        double profit = 0.0;
        final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
        final batches = batchBox.values
            .where((b) => b.medicineId == item.medicineId && b.quantity > 0)
            .toList();
        if (batches.isNotEmpty) {
          final totalCost = batches.fold<double>(
            0.0,
            (sum, b) => sum + b.costPrice,
          );
          final avgCost = totalCost / batches.length;
          profit = (item.unitPrice - avgCost) * item.quantity;
        }

        final cleanMedName = _csvClean(medicine?.name);
        final cleanNotes = _csvClean(transaction.notes);

        final row =
            '${DateFormat('yyyy-MM-dd').format(transaction.date)},'
            '${DateFormat('HH:mm:ss').format(transaction.date)},'
            '${transaction.id.substring(0, 8)},'
            '${transaction.type},'
            '$cleanMedName,'
            '${_formatNumber(item.quantity)},'
            '${_formatCurrency(item.unitPrice)},'
            '${_formatCurrency(item.lineTotal)},'
            '${transaction.paymentMethod ?? 'Cash'},'
            '${_formatCurrency(profit)},'
            '"$cleanNotes"';
        buffer.writeln(row);
      }
    }

    buffer.writeln('');
    buffer.writeln('=' * 80);
    buffer.writeln('SUMMARY');
    buffer.writeln('=' * 80);

    final totalSales = transactionBox.values
        .where((t) => t.type == 'sale')
        .fold<double>(0.0, (sum, t) => sum + t.totalAmount);
    final totalReturns = transactionBox.values
        .where((t) => t.type == 'return')
        .fold<double>(0.0, (sum, t) => sum + t.totalAmount);
    final totalAdjustments = transactionBox.values
        .where((t) => t.type == 'adjustment')
        .fold<double>(0.0, (sum, t) => sum + t.totalAmount);

    buffer.writeln('Total Sales,${_formatCurrency(totalSales)}');
    buffer.writeln('Total Returns,${_formatCurrency(totalReturns)}');
    buffer.writeln('Total Adjustments,${_formatCurrency(totalAdjustments)}');
    buffer.writeln('Net Revenue,${_formatCurrency(totalSales - totalReturns)}');

    return buffer.toString();
  }

  String _generateExpiryReportCSV() {
    final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final now = DateTime.now();
    final profile = PharmacyService.getProfileSync();

    final buffer = StringBuffer();

    buffer.writeln(
      '${profile?.pharmacyName?.toUpperCase() ?? 'PHARM IN'} - EXPIRY ALERT REPORT',
    );
    if (profile?.address != null) buffer.writeln(profile!.address);
    if (profile?.phone != null) buffer.writeln('Tel: ${profile!.phone}');
    if (profile?.email != null) buffer.writeln('Email: ${profile!.email}');
    if (profile?.licenseNumber != null) {
      buffer.writeln('License: ${profile!.licenseNumber}');
    }
    buffer.writeln(
      'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}',
    );
    buffer.writeln('=' * 80);
    buffer.writeln('');

    buffer.writeln(
      'Medicine,Batch Number,Expiry Date,Days Left,Status,Quantity,Cost Price,Selling Price,Total Value,Location',
    );

    final sortedBatches = batchBox.values.toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    for (var batch in sortedBatches) {
      if (batch.quantity > 0) {
        final medicine = medBox.get(batch.medicineId);
        final daysLeft = batch.expiryDate.difference(now).inDays;

        String status;
        if (daysLeft < 0) {
          status = 'EXPIRED';
        } else if (daysLeft <= 30) {
          status = 'CRITICAL (expires in 30 days or less)';
        } else if (daysLeft <= 60) {
          status = 'WARNING (expires in 60 days or less)';
        } else if (daysLeft <= 90) {
          status = 'NOTICE (expires in 90 days or less)';
        } else {
          status = 'OK';
        }

        final totalValue = batch.quantity * batch.sellingPrice;
        final cleanMedName = _csvClean(medicine?.name);
        final cleanBatch = _csvClean(batch.batchNumber);
        final cleanLocation = _csvClean(batch.storageLocation);

        final row =
            '$cleanMedName,'
            '$cleanBatch,'
            '${DateFormat('yyyy-MM-dd').format(batch.expiryDate)},'
            '$daysLeft,'
            '$status,'
            '${_formatNumber(batch.quantity)},'
            '${_formatCurrency(batch.costPrice)},'
            '${_formatCurrency(batch.sellingPrice)},'
            '${_formatCurrency(totalValue)},'
            '"$cleanLocation"';
        buffer.writeln(row);
      }
    }

    buffer.writeln('');
    buffer.writeln('=' * 80);
    buffer.writeln('EXPIRY SUMMARY');
    buffer.writeln('=' * 80);

    int critical = 0, warning = 0, notice = 0, expired = 0;
    for (var batch in batchBox.values) {
      if (batch.quantity > 0) {
        final daysLeft = batch.expiryDate.difference(now).inDays;
        if (daysLeft < 0) {
          expired++;
        } else if (daysLeft <= 30) {
          critical++;
        } else if (daysLeft <= 60) {
          warning++;
        } else if (daysLeft <= 90) {
          notice++;
        }
      }
    }

    buffer.writeln('Expired Items,$expired');
    buffer.writeln('Critical (expires in 30 days or less),$critical');
    buffer.writeln('Warning (expires in 60 days or less),$warning');
    buffer.writeln('Notice (expires in 90 days or less),$notice');

    return buffer.toString();
  }

  String _generateLowStockReportCSV() {
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
    final now = DateTime.now();
    final profile = PharmacyService.getProfileSync();

    final buffer = StringBuffer();

    buffer.writeln(
      '${profile?.pharmacyName?.toUpperCase() ?? 'PHARM IN'} - LOW STOCK ALERT REPORT',
    );
    if (profile?.address != null) buffer.writeln(profile!.address);
    if (profile?.phone != null) buffer.writeln('Tel: ${profile!.phone}');
    if (profile?.email != null) buffer.writeln('Email: ${profile!.email}');
    if (profile?.licenseNumber != null) {
      buffer.writeln('License: ${profile!.licenseNumber}');
    }
    buffer.writeln(
      'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}',
    );
    buffer.writeln('=' * 80);
    buffer.writeln('');

    buffer.writeln(
      'Name,Category,Current Stock,Reorder Level,Shortage,Unit,Avg Cost,Avg Sell,Est. Reorder Cost,Est. Reorder Value,Priority',
    );

    List<Map<String, dynamic>> lowStockItems = [];

    for (var medicine in medBox.values) {
      final stock = HiveService.availableStock(medicine.id);
      if (stock <= medicine.defaultReorderLevel) {
        final shortage = medicine.defaultReorderLevel - stock;

        final batches = batchBox.values
            .where((b) => b.medicineId == medicine.id && b.quantity > 0)
            .toList();
        double avgCost = 0.0;
        double avgSell = 0.0;
        if (batches.isNotEmpty) {
          double totalCost = 0.0;
          double totalSell = 0.0;
          double totalQty = 0.0;
          for (var batch in batches) {
            totalCost += batch.costPrice * batch.quantity;
            totalSell += batch.sellingPrice * batch.quantity;
            totalQty += batch.quantity;
          }
          avgCost = totalCost / totalQty;
          avgSell = totalSell / totalQty;
        }

        String priority;
        if (stock == 0) {
          priority = 'OUT OF STOCK - URGENT';
        } else if (shortage > medicine.defaultReorderLevel * 0.5) {
          priority = 'HIGH';
        } else if (shortage > medicine.defaultReorderLevel * 0.25) {
          priority = 'MEDIUM';
        } else {
          priority = 'LOW';
        }

        lowStockItems.add({
          'medicine': medicine,
          'stock': stock,
          'shortage': shortage,
          'avgCost': avgCost,
          'avgSell': avgSell,
          'priority': priority,
        });
      }
    }

    lowStockItems.sort((a, b) => b['shortage'].compareTo(a['shortage']));

    for (var item in lowStockItems) {
      final med = item['medicine'] as Medicine;
      final shortage = item['shortage'] as double;
      final avgCost = item['avgCost'] as double;
      final avgSell = item['avgSell'] as double;
      final priority = item['priority'] as String;

      final cleanName = _csvClean(med.name);
      final cleanCategory = _csvClean(med.category);
      final cleanUnit = _csvClean(med.unit);

      final reorderCost = shortage * avgCost;
      final reorderValue = shortage * avgSell;

      final row =
          '$cleanName,'
          '$cleanCategory,'
          '${_formatNumber(item['stock'] as double)},'
          '${_formatNumber(med.defaultReorderLevel)},'
          '${_formatNumber(shortage)},'
          '$cleanUnit,'
          '${_formatCurrency(avgCost)},'
          '${_formatCurrency(avgSell)},'
          '${_formatCurrency(reorderCost)},'
          '${_formatCurrency(reorderValue)},'
          '$priority';
      buffer.writeln(row);
    }

    buffer.writeln('');
    buffer.writeln('=' * 80);
    buffer.writeln('LOW STOCK SUMMARY');
    buffer.writeln('=' * 80);
    buffer.writeln('Total Low Stock Items,${lowStockItems.length}');

    int outOfStock = 0;
    int highPriority = 0;
    for (var item in lowStockItems) {
      if (item['stock'] == 0) {
        outOfStock++;
      }
      if (item['priority'] == 'HIGH') {
        highPriority++;
      }
    }

    buffer.writeln('Out of Stock Items,$outOfStock');
    buffer.writeln('High Priority Items,$highPriority');

    return buffer.toString();
  }

  String _generateSummaryReportCSV() {
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
    final transactionBox = Hive.box<Transaction>(HiveProvider.transactionsBox);
    final now = DateTime.now();
    final profile = PharmacyService.getProfileSync();

    final buffer = StringBuffer();

    buffer.writeln(
      '${profile?.pharmacyName?.toUpperCase() ?? 'PHARM IN'} - BUSINESS SUMMARY REPORT',
    );
    if (profile?.address != null) buffer.writeln(profile!.address);
    if (profile?.phone != null) buffer.writeln('Tel: ${profile!.phone}');
    if (profile?.email != null) buffer.writeln('Email: ${profile!.email}');
    if (profile?.licenseNumber != null) {
      buffer.writeln('License: ${profile!.licenseNumber}');
    }
    buffer.writeln(
      'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}',
    );
    buffer.writeln('=' * 80);
    buffer.writeln('');

    buffer.writeln('INVENTORY OVERVIEW');
    buffer.writeln('-' * 40);

    int totalMedicines = medBox.values.length;
    int totalBatches = 0;
    int lowStockCount = 0;
    double totalStockValue = 0.0;
    double totalCostValue = 0.0;

    for (var medicine in medBox.values) {
      final stock = HiveService.availableStock(medicine.id);
      if (stock <= medicine.defaultReorderLevel) {
        lowStockCount++;
      }

      final batches = batchBox.values
          .where((b) => b.medicineId == medicine.id && b.quantity > 0)
          .toList();
      totalBatches += batches.length;

      for (var batch in batches) {
        totalStockValue += batch.quantity * batch.sellingPrice;
        totalCostValue += batch.quantity * batch.costPrice;
      }
    }

    buffer.writeln('Total Medicines,$totalMedicines');
    buffer.writeln('Total Batches,$totalBatches');
    buffer.writeln(
      'Total Stock Value (Sell Price),${_formatCurrency(totalStockValue)}',
    );
    buffer.writeln(
      'Total Stock Value (Cost Price),${_formatCurrency(totalCostValue)}',
    );
    buffer.writeln(
      'Potential Profit,${_formatCurrency(totalStockValue - totalCostValue)}',
    );
    buffer.writeln('Low Stock Items,$lowStockCount');
    final profitMarginPercent = totalCostValue > 0
        ? ((totalStockValue - totalCostValue) / totalCostValue * 100)
        : 0.0;
    buffer.writeln(
      'Profit Margin (Avg),${_formatNumber(profitMarginPercent)}%',
    );

    buffer.writeln('');

    buffer.writeln('SALES OVERVIEW');
    buffer.writeln('-' * 40);

    final sales = transactionBox.values.where((t) => t.type == 'sale').toList();
    final returns = transactionBox.values
        .where((t) => t.type == 'return')
        .toList();
    final adjustments = transactionBox.values
        .where((t) => t.type == 'adjustment')
        .toList();

    final totalSales = sales.fold<double>(0.0, (sum, t) => sum + t.totalAmount);
    final totalReturns = returns.fold<double>(
      0.0,
      (sum, t) => sum + t.totalAmount,
    );

    buffer.writeln('Total Sales,${sales.length}');
    buffer.writeln('Total Returns,${returns.length}');
    buffer.writeln('Total Adjustments,${adjustments.length}');
    buffer.writeln(
      'Revenue (Sales - Returns),${_formatCurrency(totalSales - totalReturns)}',
    );

    buffer.writeln('');
    buffer.writeln('TRANSACTION TIMELINE (Last 7 Days)');
    buffer.writeln('-' * 40);
    buffer.writeln('Date,Sales Count,Sales Amount');

    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: i)));
    for (var date in last7Days) {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final daySales = transactionBox.values
          .where(
            (t) =>
                t.type == 'sale' &&
                t.date.isAfter(dayStart) &&
                t.date.isBefore(dayEnd),
          )
          .toList();

      final count = daySales.length;
      final amount = daySales.fold<double>(
        0.0,
        (sum, t) => sum + t.totalAmount,
      );

      buffer.writeln(
        '${DateFormat('yyyy-MM-dd').format(date)},$count,${_formatCurrency(amount)}',
      );
    }

    return buffer.toString();
  }

  // ============ PREVIEW DATA GENERATORS ============

  List<Map<String, dynamic>> _getStockPreviewData() {
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
    final now = DateTime.now();
    final data = <Map<String, dynamic>>[];

    for (var medicine in medBox.values) {
      final stock = HiveService.availableStock(medicine.id);
      final isLowStock = stock <= medicine.defaultReorderLevel;

      final batches = batchBox.values
          .where((b) => b.medicineId == medicine.id && b.quantity > 0)
          .toList();

      double totalValue = 0.0;
      double totalCost = 0.0;
      double totalSell = 0.0;
      double totalQty = 0.0;

      for (var batch in batches) {
        totalValue += batch.quantity * batch.sellingPrice;
        totalCost += batch.quantity * batch.costPrice;
        totalSell += batch.quantity * batch.sellingPrice;
        totalQty += batch.quantity;
      }

      final avgCost = totalQty > 0 ? totalCost / totalQty : 0.0;
      final avgSell = totalQty > 0 ? totalSell / totalQty : 0.0;
      final profitMargin = avgCost > 0
          ? ((avgSell - avgCost) / avgCost) * 100
          : 0.0;

      List<String> alertList = [];
      for (var batch in batches) {
        final daysLeft = batch.expiryDate.difference(now).inDays;
        if (daysLeft <= 90 && daysLeft >= 0) {
          alertList.add('${batch.batchNumber}: expires in $daysLeft days');
        } else if (daysLeft < 0) {
          alertList.add('${batch.batchNumber}: EXPIRED');
        }
      }

      data.add({
        'Name': medicine.name,
        'Category': medicine.category ?? 'Uncategorized',
        'Unit': medicine.unit ?? 'pcs',
        'Total Stock': stock,
        'Reorder Level': medicine.defaultReorderLevel,
        'Status': isLowStock ? 'LOW STOCK' : 'OK',
        'Stock Value': totalValue,
        'Avg Cost': avgCost,
        'Avg Sell': avgSell,
        'Profit Margin': profitMargin,
        'Total Batches': batches.length,
        'Expiry Alerts': alertList.isEmpty ? 'No alerts' : alertList.join('; '),
      });
    }

    return data;
  }

  List<Map<String, dynamic>> _getTransactionPreviewData() {
    final transactionBox = Hive.box<Transaction>(HiveProvider.transactionsBox);
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final data = <Map<String, dynamic>>[];

    for (var transaction in transactionBox.values) {
      for (var item in transaction.items) {
        final medicine = medBox.get(item.medicineId);
        data.add({
          'Date': DateFormat('yyyy-MM-dd').format(transaction.date),
          'Time': DateFormat('HH:mm:ss').format(transaction.date),
          'Transaction ID': transaction.id.substring(0, 8),
          'Type': transaction.type,
          'Medicine': medicine?.name ?? 'Unknown',
          'Quantity': item.quantity,
          'Unit Price': item.unitPrice,
          'Total': item.lineTotal,
          'Payment Method': transaction.paymentMethod ?? 'Cash',
          'Notes': transaction.notes ?? '',
        });
      }
    }

    return data;
  }

  List<Map<String, dynamic>> _getExpiryPreviewData() {
    final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final now = DateTime.now();
    final data = <Map<String, dynamic>>[];

    final sortedBatches = batchBox.values.toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    for (var batch in sortedBatches) {
      if (batch.quantity > 0) {
        final medicine = medBox.get(batch.medicineId);
        final daysLeft = batch.expiryDate.difference(now).inDays;

        String status;
        if (daysLeft < 0) {
          status = 'EXPIRED';
        } else if (daysLeft <= 30) {
          status = 'CRITICAL (expires in 30 days or less)';
        } else if (daysLeft <= 60) {
          status = 'WARNING (expires in 60 days or less)';
        } else if (daysLeft <= 90) {
          status = 'NOTICE (expires in 90 days or less)';
        } else {
          status = 'OK';
        }

        data.add({
          'Medicine': medicine?.name ?? 'Unknown',
          'Batch Number': batch.batchNumber ?? 'N/A',
          'Expiry Date': batch.expiryDate,
          'Days Left': daysLeft,
          'Status': status,
          'Quantity': batch.quantity,
          'Cost Price': batch.costPrice,
          'Selling Price': batch.sellingPrice,
          'Total Value': batch.quantity * batch.sellingPrice,
          'Location': batch.storageLocation ?? 'Not specified',
        });
      }
    }

    return data;
  }

  // ============ PREVIEW DIALOG ============

  void _showReportPreview(
    String title,
    String content,
    List<Map<String, dynamic>> data,
    List<String> headers,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B263B),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.preview,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${data.length} rows • ${headers.length} columns',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Table
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: _buildPreviewTable(headers, data),
                    ),
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B263B),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white60,
                      ),
                      child: const Text('Close'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showExportOptions(title, content);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('Export & Share'),
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

  Widget _buildPreviewTable(
    List<String> headers,
    List<Map<String, dynamic>> data,
  ) {
    final displayData = data.length > 20 ? data.sublist(0, 20) : data;

    return Theme(
      data: Theme.of(context).copyWith(
        cardTheme: CardThemeData(color: Colors.transparent, elevation: 0),
      ),
      child: Card(
        color: Colors.transparent,
        elevation: 0,
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 0.5,
            ),
            verticalInside: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          columnWidths: {
            for (int i = 0; i < headers.length; i++)
              i: const IntrinsicColumnWidth(),
          },
          children: [
            // Header row
            TableRow(
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withValues(alpha: 0.2),
              ),
              children: headers.map((header) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Text(
                    header,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.left,
                  ),
                );
              }).toList(),
            ),
            // Data rows
            ...displayData.map((row) {
              return TableRow(
                children: headers.map((header) {
                  var value = row[header] ?? '';

                  if (value is double) {
                    if (header.contains('Price') ||
                        header.contains('Cost') ||
                        header.contains('Value') ||
                        header.contains('Total') ||
                        header.contains('Revenue') ||
                        header.contains('Amount') ||
                        header.contains('Sell') ||
                        header.contains('Profit')) {
                      value = '\$${value.toStringAsFixed(2)}';
                    } else {
                      value = value.toStringAsFixed(2);
                    }
                  }

                  if (value is DateTime) {
                    value = DateFormat('MMM d, yyyy').format(value);
                  }

                  Color textColor = Colors.white70;
                  final valueStr = value.toString();
                  if (header == 'Status' || header.contains('Status')) {
                    if (valueStr.contains('LOW') ||
                        valueStr.contains('CRITICAL') ||
                        valueStr.contains('EXPIRED')) {
                      textColor = Colors.redAccent;
                    } else if (valueStr.contains('WARNING')) {
                      textColor = Colors.orange;
                    } else if (valueStr.contains('NOTICE')) {
                      textColor = Colors.yellow.shade700;
                    } else if (valueStr.contains('OK')) {
                      textColor = Colors.greenAccent;
                    }
                  } else if (header == 'Priority') {
                    if (valueStr.contains('URGENT') ||
                        valueStr.contains('HIGH')) {
                      textColor = Colors.redAccent;
                    } else if (valueStr.contains('MEDIUM')) {
                      textColor = Colors.orange;
                    } else if (valueStr.contains('LOW')) {
                      textColor = Colors.greenAccent;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      valueStr,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showExportOptions(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.ios_share,
                color: Colors.blueAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Export Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(color: Colors.white12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.file_download,
                  color: Colors.blueAccent,
                  size: 20,
                ),
              ),
              title: const Text(
                'Export as CSV',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Share as CSV file',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                Navigator.pop(context);
                final filename =
                    '${title.replaceAll(' ', '_').toLowerCase()}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
                _shareCSV(content, filename);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.copy,
                  color: Colors.greenAccent,
                  size: 20,
                ),
              ),
              title: const Text(
                'Copy to Clipboard',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Copy content as text',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: content));
                SnackBarUtils.showSuccess(
                  context,
                  '📋 Report copied to clipboard!',
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white60),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareCSV(String content, String filename) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$filename';

      final file = File(path);
      await file.writeAsString(content, encoding: utf8);

      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv', name: filename)],
        text:
            '📊 Pharmacy Inventory Report\n\nPlease find attached the CSV report.\nGenerated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
      );

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          '✅ Report exported successfully!\nFile: $filename',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '❌ Error exporting report: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Export Reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
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
                const Text(
                  'Preview and share detailed reports of your inventory',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 24),

                _buildExportCard(
                  icon: Icons.inventory_2,
                  title: 'Stock Report',
                  subtitle:
                      'Full inventory with values, profit margins, and expiry alerts',
                  color: Colors.blue,
                  onTap: () {
                    final headers = [
                      'Name',
                      'Category',
                      'Unit',
                      'Total Stock',
                      'Reorder Level',
                      'Status',
                      'Stock Value',
                      'Avg Cost',
                      'Avg Sell',
                      'Profit Margin',
                      'Total Batches',
                      'Expiry Alerts',
                    ];
                    final data = _getStockPreviewData();
                    final csv = _generateStockReportCSV();
                    _showReportPreview('Stock Report', csv, data, headers);
                  },
                  isLoading: _isExporting,
                ),

                const SizedBox(height: 12),

                _buildExportCard(
                  icon: Icons.receipt_long,
                  title: 'Transaction Report',
                  subtitle:
                      'All sales, returns, adjustments with profit calculations',
                  color: Colors.green,
                  onTap: () {
                    final headers = [
                      'Date',
                      'Time',
                      'Transaction ID',
                      'Type',
                      'Medicine',
                      'Quantity',
                      'Unit Price',
                      'Total',
                      'Payment Method',
                      'Notes',
                    ];
                    final data = _getTransactionPreviewData();
                    final csv = _generateTransactionReportCSV();
                    _showReportPreview(
                      'Transaction Report',
                      csv,
                      data,
                      headers,
                    );
                  },
                  isLoading: _isExporting,
                ),

                const SizedBox(height: 12),

                _buildExportCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Expiry Report',
                  subtitle:
                      'All batches with expiry status and priority alerts',
                  color: Colors.orange,
                  onTap: () {
                    final headers = [
                      'Medicine',
                      'Batch Number',
                      'Expiry Date',
                      'Days Left',
                      'Status',
                      'Quantity',
                      'Cost Price',
                      'Selling Price',
                      'Total Value',
                      'Location',
                    ];
                    final data = _getExpiryPreviewData();
                    final csv = _generateExpiryReportCSV();
                    _showReportPreview('Expiry Report', csv, data, headers);
                  },
                  isLoading: _isExporting,
                ),

                const SizedBox(height: 12),

                _buildExportCard(
                  icon: Icons.error,
                  title: 'Low Stock Report',
                  subtitle:
                      'Items below reorder level with estimated reorder costs',
                  color: Colors.red,
                  onTap: () {
                    final allData = _getStockPreviewData();
                    final data = allData
                        .where((item) => item['Status'] == 'LOW STOCK')
                        .toList();
                    if (data.isEmpty) {
                      SnackBarUtils.showInfo(
                        context,
                        'No low stock items found!',
                      );
                      return;
                    }
                    final headers = [
                      'Name',
                      'Category',
                      'Current Stock',
                      'Reorder Level',
                      'Shortage',
                      'Unit',
                      'Avg Cost',
                      'Avg Sell',
                      'Est. Reorder Cost',
                      'Est. Reorder Value',
                      'Priority',
                    ];
                    final csv = _generateLowStockReportCSV();
                    _showReportPreview('Low Stock Report', csv, data, headers);
                  },
                  isLoading: _isExporting,
                ),

                const SizedBox(height: 12),

                _buildExportCard(
                  icon: Icons.summarize,
                  title: 'Summary Report',
                  subtitle:
                      'Complete business overview with key metrics and trends',
                  color: Colors.purple,
                  onTap: () {
                    final data = _getStockPreviewData();
                    final csv = _generateSummaryReportCSV();
                    _showReportPreview('Summary Report', csv, data, [
                      'Name',
                      'Category',
                      'Total Stock',
                      'Stock Value',
                      'Status',
                    ]);
                  },
                  isLoading: _isExporting,
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: Colors.amber.shade300,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '📋 Preview & Export',
                            style: TextStyle(
                              color: Colors.amber.shade200,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Tap any report card to preview the data in a table\n'
                        '• Export as CSV file or copy to clipboard\n'
                        '• Open CSV files in Excel, Google Sheets, or any spreadsheet app',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      children: [
                        Icon(Icons.preview, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Preview',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
