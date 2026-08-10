// lib/screens/add_edit_batch_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/batch.dart';
import '../services/hive_service.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/delete_confirmation_dialog.dart';

class AddEditBatchScreen extends StatefulWidget {
  final String medicineId;
  final Batch? batch;
  const AddEditBatchScreen({super.key, required this.medicineId, this.batch});

  @override
  State<AddEditBatchScreen> createState() => _AddEditBatchScreenState();
}

class _AddEditBatchScreenState extends State<AddEditBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batchNoCtl = TextEditingController();
  final _qtyCtl = TextEditingController();
  final _costCtl = TextEditingController();
  final _sellCtl = TextEditingController();
  final _locationCtl = TextEditingController();
  final _supplierIdCtl = TextEditingController();
  DateTime? _expiry;
  DateTime? _manufacturingDate;

  @override
  void initState() {
    super.initState();
    if (widget.batch != null) {
      // Edit mode - populate with existing data
      _batchNoCtl.text = widget.batch!.batchNumber ?? '';
      _qtyCtl.text = widget.batch!.quantity.toString();
      _costCtl.text = widget.batch!.costPrice.toString();
      _sellCtl.text = widget.batch!.sellingPrice.toString();
      _expiry = widget.batch!.expiryDate;
      _locationCtl.text = widget.batch!.storageLocation ?? '';
      _manufacturingDate = widget.batch!.manufacturingDate;
      _supplierIdCtl.text = widget.batch!.supplierId ?? '';
    }
  }

  @override
  void dispose() {
    _batchNoCtl.dispose();
    _qtyCtl.dispose();
    _costCtl.dispose();
    _sellCtl.dispose();
    _locationCtl.dispose();
    _supplierIdCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(String field) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: field == 'expiry'
          ? (_expiry ?? now.add(const Duration(days: 30)))
          : (_manufacturingDate ?? now),
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        if (field == 'expiry') {
          _expiry = picked;
        } else {
          _manufacturingDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_expiry == null) {
      SnackBarUtils.showError(context, 'Please select expiry date');
      return;
    }

    if (_manufacturingDate == null) {
      SnackBarUtils.showError(context, 'Please select manufacturing date');
      return;
    }

    if (_manufacturingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select manufacturing date')),
      );
      return;
    }

    final id = widget.batch?.id ?? const Uuid().v4();
    final batch = Batch(
      id: id,
      medicineId: widget.medicineId,
      batchNumber: _batchNoCtl.text.trim().isEmpty
          ? 'B-${id.substring(0, 4)}'
          : _batchNoCtl.text.trim(),
      expiryDate: _expiry!,
      quantity: double.tryParse(_qtyCtl.text.trim()) ?? 0.0,
      costPrice: double.tryParse(_costCtl.text.trim()) ?? 0.0,
      sellingPrice: double.tryParse(_sellCtl.text.trim()) ?? 0.0,
      storageLocation: _locationCtl.text.trim().isEmpty
          ? null
          : _locationCtl.text.trim(),
      manufacturingDate: _manufacturingDate,
      supplierId: _supplierIdCtl.text.trim().isEmpty
          ? null
          : _supplierIdCtl.text.trim(),
    );

    await HiveService.addBatch(batch);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.batch != null;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        title: Text(
          isEdit ? 'Edit Batch' : 'Add New Batch',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () async {
                final confirmed = await DeleteConfirmationDialog.show(
                  context,
                  title: 'Delete Batch?',
                  message:
                      'Are you sure you want to delete batch #${widget.batch!.batchNumber ?? 'Unknown'}? This action cannot be undone.',
                  confirmText: 'Delete Batch',
                );
                if (confirmed == true) {
                  await HiveService.deleteBatch(widget.batch!.id);
                  if (!mounted) return;
                  Navigator.pop(context, true);
                  Navigator.pop(context, true);
                  SnackBarUtils.showSuccess(context, '🗑️ Batch deleted');
                }
              },
            ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D1B2A),
              const Color(0xFF1B263B),
              const Color(0xFF2C3E50),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade900.withValues(alpha: 0.3),
                          Colors.blue.shade900.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.blue.shade400.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          color: Colors.blueAccent,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit ? 'Update Batch' : 'New Batch Entry',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isEdit
                                    ? 'Modify existing batch details'
                                    : 'Add stock to inventory',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isEdit)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.blueAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'ID: ${widget.batch!.id.substring(0, 8)}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Batch Number - Required
                  _buildTextField(
                    controller: _batchNoCtl,
                    label: 'Batch Number *',
                    icon: Icons.numbers,
                    hint: 'Enter batch number',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter batch number'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Quantity - Required
                  _buildTextField(
                    controller: _qtyCtl,
                    label: 'Quantity *',
                    icon: Icons.production_quantity_limits,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter quantity';
                      }
                      final qty = double.tryParse(v.trim());
                      if (qty == null || qty <= 0) {
                        return 'Quantity must be greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Cost Price - Required
                  _buildTextField(
                    controller: _costCtl,
                    label: 'Cost Price *',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter cost price';
                      }
                      final price = double.tryParse(v.trim());
                      if (price == null || price < 0) {
                        return 'Invalid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Selling Price - Required
                  _buildTextField(
                    controller: _sellCtl,
                    label: 'Selling Price *',
                    icon: Icons.currency_exchange,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter selling price';
                      }
                      final price = double.tryParse(v.trim());
                      if (price == null || price < 0) {
                        return 'Invalid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Storage Location - Required
                  _buildTextField(
                    controller: _locationCtl,
                    label: 'Storage Location *',
                    icon: Icons.location_on,
                    hint: 'e.g., Aisle 3, Shelf B',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter storage location'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Supplier ID - Optional (can be required or not)
                  _buildTextField(
                    controller: _supplierIdCtl,
                    label: 'Supplier ID (Optional)',
                    icon: Icons.business,
                    hint: 'Enter supplier ID (leave empty if none)',
                  ),
                  const SizedBox(height: 16),

                  // Expiry Date - Required
                  _buildDatePicker(
                    label: 'Expiry Date *',
                    date: _expiry,
                    icon: Icons.calendar_today,
                    onTap: () => _pickDate('expiry'),
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),

                  // Manufacturing Date - Required
                  _buildDatePicker(
                    label: 'Manufacturing Date *',
                    date: _manufacturingDate,
                    icon: Icons.build,
                    onTap: () => _pickDate('manufacturing'),
                    isRequired: true,
                  ),
                  const SizedBox(height: 30),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        isEdit ? 'Update Batch' : 'Add Batch',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
    bool isRequired = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: date != null
                ? Colors.blue.shade400.withValues(alpha: 0.3)
                : Colors.red.shade400.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  Text(
                    date == null
                        ? 'Select date'
                        : '${date.toLocal().toIso8601String().split("T").first}',
                    style: TextStyle(
                      color: date == null ? Colors.white38 : Colors.white,
                      fontWeight: date == null
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (isRequired && date == null)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(color: Colors.redAccent, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
