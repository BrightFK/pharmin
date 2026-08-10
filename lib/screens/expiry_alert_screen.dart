// lib/screens/expiry_alert_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/batch.dart';
import '../models/medicine.dart';
import '../providers/hive_provider.dart';
import '../widgets/glass_card.dart';

class ExpiryAlertScreen extends StatefulWidget {
  const ExpiryAlertScreen({super.key});

  @override
  State<ExpiryAlertScreen> createState() => _ExpiryAlertScreenState();
}

class _ExpiryAlertScreenState extends State<ExpiryAlertScreen> {
  int _selectedDays = 30;
  final List<int> _dayOptions = [30, 60, 90];

  List<Map<String, dynamic>> _getExpiringMedicines() {
    final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: _selectedDays));

    final expiring = <Map<String, dynamic>>[];

    for (var batch in batchBox.values) {
      if (batch.expiryDate.isAfter(now) && batch.expiryDate.isBefore(cutoff)) {
        final medicine = medBox.get(batch.medicineId);
        if (medicine != null && batch.quantity > 0) {
          final daysLeft = batch.expiryDate.difference(now).inDays;
          expiring.add({
            'medicine': medicine,
            'batch': batch,
            'daysLeft': daysLeft,
          });
        }
      }
    }

    // Sort by days left (soonest first)
    expiring.sort((a, b) => a['daysLeft'].compareTo(b['daysLeft']));
    return expiring;
  }

  Color _getExpiryColor(int daysLeft) {
    if (daysLeft <= 30) return Colors.redAccent;
    if (daysLeft <= 60) return Colors.orange;
    return Colors.yellow.shade700;
  }

  String _getExpiryStatus(int daysLeft) {
    if (daysLeft <= 30) return '⚠️ CRITICAL';
    if (daysLeft <= 60) return '⚠️ WARNING';
    return '⚠️ NOTICE';
  }

  @override
  Widget build(BuildContext context) {
    final expiring = _getExpiringMedicines();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Expiry Alerts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
              // Filter chips
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: _dayOptions.map((days) {
                    final isSelected = _selectedDays == days;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(
                            '$days Days',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedDays = days);
                          },
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          selectedColor: Colors.orange.withValues(alpha: 0.3),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.orange
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Stats
              if (expiring.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              expiring.length.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Items Expiring',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        Column(
                          children: [
                            Text(
                              '${_selectedDays} Days',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Alert Period',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // List
              Expanded(
                child: expiring.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.green.withValues(alpha: 0.3),
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No medicines expiring in $_selectedDays days',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'All stock is healthy! ✅',
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
                        itemCount: expiring.length,
                        itemBuilder: (context, index) {
                          final data = expiring[index];
                          final medicine = data['medicine'] as Medicine;
                          final batch = data['batch'] as Batch;
                          final daysLeft = data['daysLeft'] as int;
                          final status = _getExpiryStatus(daysLeft);
                          final color = _getExpiryColor(daysLeft);

                          return GlassCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withValues(alpha: 0.2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      daysLeft.toString(),
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        medicine.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Batch: ${batch.batchNumber ?? 'N/A'}',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Expires: ${DateFormat('MMM d, yyyy').format(batch.expiryDate)}',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Qty: ${batch.quantity.toStringAsFixed(2)} ${medicine.unit ?? 'pcs'}',
                                        style: TextStyle(
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: color.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$daysLeft days left',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
}
