// lib/screens/inventory_list_screen.dart - Fixed overflow issue

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pharmin/screens/pharmacy_profile_screen.dart';
import 'package:pharmin/screens/return_adjustment_screen.dart';
import 'package:pharmin/screens/sales_screen.dart' hide ReturnAdjustmentScreen;
import 'package:pharmin/screens/transaction_history_screen.dart';
import 'package:uuid/uuid.dart';

import '../models/batch.dart';
import '../models/medicine.dart';
import '../models/supplier.dart';
import '../providers/hive_provider.dart';
import '../services/hive_service.dart';
import '../widgets/glass_card.dart';
import 'add_edit_medicine_screen.dart';
import 'batch_history_screen.dart';
import 'expiry_alert_screen.dart';
import 'export_reports_screen.dart';
import 'medicine_detail_screen.dart';
import 'notification_settings_screen.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final _uuid = const Uuid();
  String _searchQuery = '';
  String _filterCategory = 'All';
  String _sortOption = 'Name A→Z';

  final List<String> _sortOptions = [
    'Name A→Z',
    'Name Z→A',
    'Qty ↑',
    'Qty ↓',
    'Reorder ↑',
    'Reorder ↓',
    'Expiry Soonest',
    'Expiry Latest',
  ];

  // Preset categories from the add/edit screen
  final List<String> _presetCategories = [
    'Analgesic',
    'Antibiotic',
    'Antiseptic',
    'Cough & Cold',
    'Vitamin & Supplement',
    'Antihistamine',
    'Gastrointestinal',
    'Respiratory',
    'Antidiabetic',
    'Cardiovascular',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
  }

  bool _matchesSearch({
    required Medicine med,
    required String q,
    required Box<Batch> batchBox,
    required Box<Supplier> supplierBox,
  }) {
    if (q.isEmpty) return true;
    final low = q.toLowerCase();
    // medicine fields
    if (med.name.toLowerCase().contains(low)) return true;
    if ((med.category ?? '').toLowerCase().contains(low)) return true;
    if ((med.unit ?? '').toLowerCase().contains(low)) return true;
    if ((med.notes ?? '').toLowerCase().contains(low)) return true;
    // preferred supplier name (if present)
    if (med.preferredSupplierId != null) {
      final s = supplierBox.get(med.preferredSupplierId);
      if (s != null && s.name.toLowerCase().contains(low)) return true;
    }
    // any batch numbers
    final batches = batchBox.values.where((b) => b.medicineId == med.id);
    for (var b in batches) {
      if ((b.batchNumber ?? '').toLowerCase().contains(low)) return true;
    }
    return false;
  }

  // Return the earliest expiry date for given medicine, or null if none
  DateTime? _earliestExpiryForMedicine(String medicineId, Box<Batch> batchBox) {
    final batches = batchBox.values.where(
      (b) => b.medicineId == medicineId && b.quantity > 0,
    );
    if (batches.isEmpty) return null;
    DateTime earliest = batches.first.expiryDate;
    for (var b in batches) {
      if (b.expiryDate.isBefore(earliest)) earliest = b.expiryDate;
    }
    return earliest;
  }

  List<String> _computeCategories(Box<Medicine> medBox) {
    final cats = <String>{};
    // Add all preset categories first
    cats.addAll(_presetCategories);
    // Then add any categories from the database
    for (var m in medBox.values) {
      if (m.category != null && m.category!.trim().isNotEmpty) {
        cats.add(m.category!.trim());
      }
    }
    final list = <String>['All'];
    final sorted = cats.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    list.addAll(sorted);
    return list;
  }

  List<Medicine> _applyFilterSort({
    required Iterable<Medicine> meds,
    required Box<Batch> batchBox,
    required Box<Supplier> supplierBox,
    required String search,
    required String filterCategory,
    required String sortOption,
  }) {
    final q = search.trim().toLowerCase();

    // Filter by search and category
    var filtered = meds.where((med) {
      final matchesCategory =
          filterCategory == 'All' || (med.category ?? '') == filterCategory;
      if (!matchesCategory) return false;
      return _matchesSearch(
        med: med,
        q: q,
        batchBox: batchBox,
        supplierBox: supplierBox,
      );
    }).toList();

    // Sorting
    if (sortOption == 'Name A→Z') {
      filtered.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else if (sortOption == 'Name Z→A') {
      filtered.sort(
        (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      );
    } else if (sortOption == 'Qty ↑') {
      filtered.sort(
        (a, b) => HiveService.availableStock(
          a.id,
        ).compareTo(HiveService.availableStock(b.id)),
      );
    } else if (sortOption == 'Qty ↓') {
      filtered.sort(
        (a, b) => HiveService.availableStock(
          b.id,
        ).compareTo(HiveService.availableStock(a.id)),
      );
    } else if (sortOption == 'Reorder ↑') {
      filtered.sort(
        (a, b) => a.defaultReorderLevel.compareTo(b.defaultReorderLevel),
      );
    } else if (sortOption == 'Reorder ↓') {
      filtered.sort(
        (a, b) => b.defaultReorderLevel.compareTo(a.defaultReorderLevel),
      );
    } else if (sortOption == 'Expiry Soonest') {
      filtered.sort((a, b) {
        final ea = _earliestExpiryForMedicine(a.id, batchBox);
        final eb = _earliestExpiryForMedicine(b.id, batchBox);
        if (ea == null && eb == null) return 0;
        if (ea == null) return 1;
        if (eb == null) return -1;
        return ea.compareTo(eb);
      });
    } else if (sortOption == 'Expiry Latest') {
      filtered.sort((a, b) {
        final ea = _earliestExpiryForMedicine(a.id, batchBox);
        final eb = _earliestExpiryForMedicine(b.id, batchBox);
        if (ea == null && eb == null) return 0;
        if (ea == null) return 1;
        if (eb == null) return -1;
        return eb.compareTo(ea);
      });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
    final supplierBox = Hive.box<Supplier>(HiveProvider.suppliersBox);

    final categories = _computeCategories(medBox);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PharmIn',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Add medicine',
            icon: const Icon(Icons.add_box, color: Colors.white),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddEditMedicineScreen(),
                ),
              );
              setState(() {});
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(
              0xFF1B263B,
            ), // Dark blue matching your app background
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            onSelected: (v) async {
              if (v == 'history') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BatchHistoryScreen()),
                );
              } else if (v == 'transactions') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TransactionHistoryScreen(),
                  ),
                );
              } else if (v == 'return') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ReturnAdjustmentScreen(type: 'return'),
                  ),
                );
              } else if (v == 'adjustment') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ReturnAdjustmentScreen(type: 'adjustment'),
                  ),
                );
              } else if (v == 'expiry') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpiryAlertScreen()),
                );
              } else if (v == 'export') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExportReportsScreen(),
                  ),
                );
              } else if (v == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PharmacyProfileScreen(),
                  ),
                );
              } else if (v == 'notifications') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Pharmacy Profile',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Notifications',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'expiry',
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Expiry Alerts',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Batch History',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'transactions',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Transaction History',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Export Reports',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'return',
                child: Row(
                  children: [
                    Icon(Icons.undo, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('Return Stock', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'adjustment',
                child: Row(
                  children: [
                    Icon(Icons.tune, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Text('Adjust Stock', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
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
          ),
          SafeArea(
            child: Column(
              children: [
                // Search + filter + sort row - Made more compact
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Search box
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 42, // Fixed height
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              hintStyle: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 18,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Category filter
                      Flexible(
                        flex: 1,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filterCategory,
                              dropdownColor: const Color(0xFF1A237E),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              icon: Icon(
                                Icons.filter_list,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 18,
                              ),
                              isExpanded: true,
                              items: categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(
                                  () => _filterCategory = value ?? 'All',
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Sort dropdown
                      Flexible(
                        flex: 1,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortOption,
                              dropdownColor: const Color(0xFF1A237E),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                              icon: Icon(
                                Icons.sort,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 18,
                              ),
                              isExpanded: true,
                              items: _sortOptions
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        s,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(
                                () => _sortOption = v ?? _sortOption,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Stat cards row - Made more compact
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.inventory,
                        label: 'Total',
                        value: medBox.values.length.toString(),
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        icon: Icons.warning_amber,
                        label: 'Low Stock',
                        value: _getLowStockCount(
                          medBox.values.cast(),
                        ).toString(),
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        icon: Icons.attach_money,
                        label: 'Value',
                        value:
                            '\$${_getTotalValue(medBox.values.cast()).toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Medicine list - Takes remaining space
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ValueListenableBuilder<Box<Medicine>>(
                      valueListenable: medBox.listenable(),
                      builder: (context, box, _) {
                        final meds = _applyFilterSort(
                          meds: box.values.cast<Medicine>(),
                          batchBox: batchBox,
                          supplierBox: supplierBox,
                          search: _searchQuery,
                          filterCategory: _filterCategory,
                          sortOption: _sortOption,
                        );

                        if (meds.isEmpty) {
                          return Center(
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                vertical: 30,
                                horizontal: 20,
                              ),
                              overlayColor: Colors.white.withValues(
                                alpha: 0.06,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.white.withValues(alpha: 0.3),
                                    size: 50,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No medicines found',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Try adjusting your search'
                                        : 'Add your first medicine',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Add Medicine',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AddEditMedicineScreen(),
                                        ),
                                      );
                                      setState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: meds.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final med = meds[index];
                            final available = HiveService.availableStock(
                              med.id,
                            );
                            final isLowStock =
                                available <= med.defaultReorderLevel;

                            return GestureDetector(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MedicineDetailScreen(medicine: med),
                                  ),
                                );
                                setState(() {});
                              },
                              child: GlassCard(
                                overlayColor: Colors.white.withValues(
                                  alpha: 0.06,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    // Medicine initial circle - smaller
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: isLowStock
                                              ? [
                                                  Colors.orange.shade700,
                                                  Colors.red.shade400,
                                                ]
                                              : [
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

                                    // Medicine info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
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
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.category,
                                                color: Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                                size: 10,
                                              ),
                                              const SizedBox(width: 2),
                                              Flexible(
                                                child: Text(
                                                  med.category ??
                                                      'Uncategorized',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.7),
                                                    fontSize: 10,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isLowStock) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.redAccent
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'LOW',
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontSize: 7,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Stock info
                                    SizedBox(
                                      width: 55,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${available.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${med.unit ?? ''}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.4,
                                              ),
                                              fontSize: 8,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SalesScreen()),
          );
        },
        backgroundColor: Colors.blueAccent, // Changed from greenAccent
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.blueAccent, size: 12),
                const SizedBox(width: 3),
                Text(
                  value,
                  style: const TextStyle(
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

  int _getLowStockCount(Iterable<Medicine> medicines) {
    int count = 0;
    for (var med in medicines) {
      if (HiveService.availableStock(med.id) <= med.defaultReorderLevel)
        count++;
    }
    return count;
  }

  double _getTotalValue(Iterable<Medicine> medicines) {
    double total = 0;
    for (var med in medicines) {
      final available = HiveService.availableStock(med.id);
      total += available * 10.0;
    }
    return total;
  }
}
