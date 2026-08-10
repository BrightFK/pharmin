// lib/screens/batch_history_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/batch_history.dart';
import '../providers/hive_provider.dart';
import '../widgets/glass_card.dart';

class BatchHistoryScreen extends StatefulWidget {
  final String? medicineId;

  const BatchHistoryScreen({super.key, this.medicineId});

  @override
  State<BatchHistoryScreen> createState() => _BatchHistoryScreenState();
}

class _BatchHistoryScreenState extends State<BatchHistoryScreen> {
  late final Box<BatchHistory> _historyBox;
  String _filterType = 'All';
  String _searchQuery = '';

  // Define filter options with their display names
  final Map<String, String> _filterOptions = {
    'All': 'All Events',
    'created': 'Batch Created',
    'edited': 'Batch Edited',
    'deleted': 'Batch Deleted',
    'sale': 'Sales',
    'medicine_created': 'Medicine Created',
    'medicine_edited': 'Medicine Edited',
    'medicine_deleted': 'Medicine Deleted',
  };

  @override
  void initState() {
    super.initState();
    _historyBox = Hive.box<BatchHistory>(HiveProvider.batchHistoryBox);
  }

  List<BatchHistory> _getFilteredHistory() {
    var history = _historyBox.values.toList();

    if (widget.medicineId != null) {
      history = history
          .where((h) => h.medicineId == widget.medicineId)
          .toList();
    }

    if (_filterType != 'All') {
      history = history.where((h) => h.eventType == _filterType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      history = history.where((h) {
        return h.batchNumber.toLowerCase().contains(query) ||
            h.medicineName.toLowerCase().contains(query) ||
            h.eventType.toLowerCase().contains(query) ||
            (h.notes?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return history;
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'created':
      case 'medicine_created':
        return Icons.add_circle;
      case 'edited':
      case 'medicine_edited':
        return Icons.edit;
      case 'deleted':
      case 'medicine_deleted':
        return Icons.delete;
      case 'sale':
        return Icons.shopping_cart;
      default:
        return Icons.info;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'created':
      case 'medicine_created':
        return Colors.green;
      case 'edited':
      case 'medicine_edited':
        return Colors.blue;
      case 'deleted':
      case 'medicine_deleted':
        return Colors.red;
      case 'sale':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getDisplayEventType(String eventType) {
    switch (eventType) {
      case 'created':
        return 'Batch Created';
      case 'edited':
        return 'Batch Edited';
      case 'deleted':
        return 'Batch Deleted';
      case 'sale':
        return 'Sale';
      case 'medicine_created':
        return 'Medicine Created';
      case 'medicine_edited':
        return 'Medicine Edited';
      case 'medicine_deleted':
        return 'Medicine Deleted';
      default:
        return eventType;
    }
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: _filterType == value ? Colors.white : Colors.white70,
          fontSize: 11,
        ),
      ),
      selected: _filterType == value,
      onSelected: (selected) {
        setState(() {
          _filterType = selected ? value : 'All';
        });
      },
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: _filterType == value
            ? Colors.blueAccent
            : Colors.white.withValues(alpha: 0.1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildHistoryCard(BatchHistory history) {
    final eventIcon = _getEventIcon(history.eventType);
    final eventColor = _getEventColor(history.eventType);
    final displayType = _getDisplayEventType(history.eventType);
    final formattedDate = DateFormat(
      'MMM d, yyyy - h:mm a',
    ).format(history.timestamp);

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: eventColor.withValues(alpha: 0.2),
                ),
                child: Icon(eventIcon, color: eventColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history.batchNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      history.medicineName,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: eventColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: eventColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  displayType.toUpperCase(),
                  style: TextStyle(
                    color: eventColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white38, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (history.notes != null) ...[
            const SizedBox(height: 4),
            Text(
              history.notes!,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Show sale details if it's a sale event
          if (history.eventType == 'sale' && history.snapshot != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade900.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.shade700.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'Qty',
                        style: TextStyle(color: Colors.white54, fontSize: 9),
                      ),
                      Text(
                        '${history.snapshot!['quantitySold']?.toStringAsFixed(2) ?? '0'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
                        'Unit Price',
                        style: TextStyle(color: Colors.white54, fontSize: 9),
                      ),
                      Text(
                        '\$${history.snapshot!['pricePerUnit']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
                        'Total',
                        style: TextStyle(color: Colors.white54, fontSize: 9),
                      ),
                      Text(
                        '\$${history.snapshot!['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (history.changes != null && history.changes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Changes:',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...history.changes!.entries.map((entry) {
                    final key = entry.key;
                    final value = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$key: ',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${value['old'] ?? 'null'} → ${value['new'] ?? 'null'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          if (history.snapshot != null && history.eventType != 'sale') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.shade400.withValues(alpha: 0.1),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (history.snapshot!['quantity'] != null)
                    _buildSnapshotChip(
                      'Qty',
                      history.snapshot!['quantity'].toString(),
                    ),
                  if (history.snapshot!['costPrice'] != null)
                    _buildSnapshotChip(
                      'Cost',
                      '\$${history.snapshot!['costPrice']}',
                    ),
                  if (history.snapshot!['sellingPrice'] != null)
                    _buildSnapshotChip(
                      'Sell',
                      '\$${history.snapshot!['sellingPrice']}',
                    ),
                  if (history.snapshot!['storageLocation'] != null)
                    _buildSnapshotChip(
                      'Location',
                      history.snapshot!['storageLocation'],
                    ),
                  if (history.snapshot!['name'] != null)
                    _buildSnapshotChip('Name', history.snapshot!['name']),
                  if (history.snapshot!['category'] != null)
                    _buildSnapshotChip(
                      'Category',
                      history.snapshot!['category'],
                    ),
                  if (history.snapshot!['unit'] != null)
                    _buildSnapshotChip('Unit', history.snapshot!['unit']),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSnapshotChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70, fontSize: 10),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = _getFilteredHistory();
    final stats = _calculateStats(history);

    if (_historyBox.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.medicineId != null ? 'Batch History' : 'All History',
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
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, color: Colors.white38, size: 80),
                SizedBox(height: 16),
                Text(
                  'No history records yet',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'History will appear when you add, edit, delete, or sell items',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.medicineId != null ? 'Batch History' : 'All History',
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
              // Stats bar
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      'Total',
                      stats['total'].toString(),
                      Icons.history,
                    ),
                    _buildStatItem(
                      'Created',
                      stats['created'].toString(),
                      Icons.add_circle,
                      Colors.green,
                    ),
                    _buildStatItem(
                      'Edited',
                      stats['edited'].toString(),
                      Icons.edit,
                      Colors.blue,
                    ),
                    _buildStatItem(
                      'Deleted',
                      stats['deleted'].toString(),
                      Icons.delete,
                      Colors.red,
                    ),
                    _buildStatItem(
                      'Sales',
                      stats['sale'].toString(),
                      Icons.shopping_cart,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
              // Search and filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search history...',
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
                    const SizedBox(height: 8),
                    // Filter chips - Horizontal scrollable
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterOptions.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildFilterChip(entry.value, entry.key),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // History list
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              color: Colors.white.withValues(alpha: 0.2),
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matching history records',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try adjusting your search or filters'
                                  : 'No history found',
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
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildHistoryCard(history[index]),
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

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, [
    Color color = Colors.white60,
  ]) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Text(label, style: TextStyle(color: Colors.white60, fontSize: 9)),
      ],
    );
  }

  Map<String, int> _calculateStats(List<BatchHistory> history) {
    final stats = {
      'total': history.length,
      'created': 0,
      'edited': 0,
      'deleted': 0,
      'sale': 0,
    };

    for (var h in history) {
      final eventType = h.eventType;
      if (eventType == 'created' || eventType == 'medicine_created') {
        stats['created'] = (stats['created'] ?? 0) + 1;
      } else if (eventType == 'edited' || eventType == 'medicine_edited') {
        stats['edited'] = (stats['edited'] ?? 0) + 1;
      } else if (eventType == 'deleted' || eventType == 'medicine_deleted') {
        stats['deleted'] = (stats['deleted'] ?? 0) + 1;
      } else if (eventType == 'sale') {
        stats['sale'] = (stats['sale'] ?? 0) + 1;
      }
    }

    return stats;
  }
}
