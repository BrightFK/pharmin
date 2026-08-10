// lib/screens/transaction_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/medicine.dart';
import '../models/transaction.dart';
import '../providers/hive_provider.dart';
import '../services/pharmacy_service.dart';
import '../utils/pdf_receipt_generator.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/glass_card.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _searchQuery = '';
  String _filterType = 'All';
  DateTimeRange? _dateRange;
  final List<String> _filterOptions = ['All', 'sale', 'return', 'adjustment'];

  List<Transaction> _getFilteredTransactions() {
    final transactionBox = Hive.box<Transaction>(HiveProvider.transactionsBox);
    var transactions = transactionBox.values.toList();

    if (_filterType != 'All') {
      transactions = transactions.where((t) => t.type == _filterType).toList();
    }

    if (_dateRange != null) {
      transactions = transactions.where((t) {
        return t.date.isAfter(_dateRange!.start) &&
            t.date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);

      transactions = transactions.where((transaction) {
        if (transaction.id.toLowerCase().contains(query)) return true;
        if (DateFormat(
          'MMM d, yyyy',
        ).format(transaction.date).toLowerCase().contains(query))
          return true;
        if (transaction.paymentMethod?.toLowerCase().contains(query) ?? false)
          return true;
        for (var item in transaction.items) {
          final med = medBox.get(item.medicineId);
          if (med?.name.toLowerCase().contains(query) ?? false) return true;
        }
        return false;
      }).toList();
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  void _showReceipt(Transaction transaction) async {
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final medicines = medBox.values.toList();
    final profile = await PharmacyService.getProfile();
    final receiptNumber =
        'RCP-${DateFormat('yyyyMMdd').format(transaction.date)}-${transaction.id.substring(0, 6).toUpperCase()}';

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
              // Header with Profile Data
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
                          Text(
                            receiptNumber,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
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
                          Text(
                            transaction.id.substring(0, 8).toUpperCase(),
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
                            'Payment',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            transaction.paymentMethod ?? 'Cash',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.black12),
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
                                profile?.receiptFooter ??
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
              // Footer with Print Button
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
                            final receiptText =
                                '''
${profile?.pharmacyName ?? 'PHARM IN'}
${profile?.address ?? '123 Health Street, Medical City'}
Tel: ${profile?.phone ?? '+234 800 1234 567'}
${profile?.licenseNumber != null ? 'Lic: ${profile!.licenseNumber}\n' : ''}
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
${profile?.receiptFooter ?? 'Thank you for your purchase!'}
''';
                            Clipboard.setData(ClipboardData(text: receiptText));
                            SnackBarUtils.showSuccess(
                              context,
                              '📋 Receipt copied to clipboard!',
                            );
                          },
                          tooltip: 'Copy Receipt',
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              Navigator.pop(context);
                              SnackBarUtils.showInfo(
                                context,
                                '📄 Generating PDF receipt...',
                              );
                              final medicines = medBox.values.toList();
                              await PdfReceiptGenerator.generateReceipt(
                                transaction,
                                medicines,
                              );
                              SnackBarUtils.showSuccess(
                                context,
                                '📄 PDF receipt generated!',
                              );
                            } catch (e) {
                              SnackBarUtils.showError(
                                context,
                                '❌ Error: ${e.toString()}',
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

  Widget _buildTransactionCard(Transaction transaction) {
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final itemCount = transaction.items.length;
    final typeColor = transaction.type == 'sale'
        ? Colors.green
        : transaction.type == 'return'
        ? Colors.orange
        : Colors.blue;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => _showReceipt(transaction),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: typeColor.withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    transaction.type == 'sale'
                        ? Icons.shopping_cart
                        : transaction.type == 'return'
                        ? Icons.undo
                        : Icons.tune,
                    color: typeColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.type.toUpperCase(),
                        style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${itemCount} item${itemCount > 1 ? 's' : ''} • ${transaction.paymentMethod ?? 'Cash'}',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${transaction.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, yyyy').format(transaction.date),
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: transaction.items.take(3).map((item) {
                final med = medBox.get(item.medicineId);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${med?.name ?? 'Unknown'} x${item.quantity.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 9),
                  ),
                );
              }).toList(),
            ),
            if (transaction.items.length > 3)
              Text(
                '... and ${transaction.items.length - 3} more',
                style: TextStyle(color: Colors.white38, fontSize: 9),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _getFilteredTransactions();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Transaction History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
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
              // Search and Filter
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by medicine, date, ID, payment...',
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
                                  onPressed: () =>
                                      setState(() => _searchQuery = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterOptions.map((type) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                type.toUpperCase(),
                                style: TextStyle(
                                  color: _filterType == type
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              selected: _filterType == type,
                              onSelected: (selected) {
                                setState(
                                  () => _filterType = selected ? type : 'All',
                                );
                              },
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              selectedColor: Colors.blueAccent.withValues(
                                alpha: 0.3,
                              ),
                              checkmarkColor: Colors.white,
                              side: BorderSide(
                                color: _filterType == type
                                    ? Colors.blueAccent
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              // Stats
              if (transactions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildStatCard(
                        'Total Sales',
                        transactions
                            .where((t) => t.type == 'sale')
                            .length
                            .toString(),
                        Icons.shopping_cart,
                        Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Total Amount',
                        '\$${transactions.fold(0.0, (sum, t) => sum + t.totalAmount).toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.blueAccent,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              // Transactions List
              Expanded(
                child: transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              color: Colors.white.withValues(alpha: 0.2),
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching transactions'
                                  : 'No transactions yet',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try adjusting your search'
                                  : 'Sales will appear here',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildTransactionCard(transactions[index]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 12),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white60, fontSize: 8),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
