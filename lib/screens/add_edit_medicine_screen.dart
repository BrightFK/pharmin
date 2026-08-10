// lib/screens/add_edit_medicine_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/medicine.dart';
import '../services/hive_service.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/delete_confirmation_dialog.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final Medicine? medicine;
  const AddEditMedicineScreen({super.key, this.medicine});

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _categoryCtl = TextEditingController();
  final _unitCtl = TextEditingController();
  final _reorderCtl = TextEditingController();
  final _preferredSupplierCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  bool _prescriptionRequired = false;
  bool _isActive = true;

  // Preset lists
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
  final List<String> _presetUnits = [
    'tablet',
    'capsule',
    'syrup',
    'ml',
    'bottle',
    'pcs',
  ];

  String? _selectedCategory;
  String? _selectedUnit;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    if (widget.medicine != null) {
      _nameCtl.text = widget.medicine!.name;
      _selectedCategory = widget.medicine!.category;
      _selectedUnit = widget.medicine!.unit;
      _reorderCtl.text = widget.medicine!.defaultReorderLevel.toString();
      _preferredSupplierCtl.text = widget.medicine!.preferredSupplierId ?? '';
      _notesCtl.text = widget.medicine!.notes ?? '';
      _prescriptionRequired = widget.medicine!.prescriptionRequired;
      _isActive = true;
    } else {
      // No defaults — require user to choose every field
      _selectedCategory = null;
      _selectedUnit = null;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _categoryCtl.dispose();
    _unitCtl.dispose();
    _reorderCtl.dispose();
    _preferredSupplierCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  List<String?> _buildCategoryOptions() {
    final opts = <String?>[null] + _presetCategories;
    if (_selectedCategory != null &&
        !_presetCategories.contains(_selectedCategory)) {
      opts.insert(1, _selectedCategory);
    }
    return opts;
  }

  List<String> _buildUnitOptions() {
    final opts = List<String>.from(_presetUnits);
    if (_selectedUnit != null && !opts.contains(_selectedUnit)) {
      opts.insert(0, _selectedUnit!);
    }
    return opts;
  }

  Future<void> _save() async {
    setState(() => _nameError = null);

    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtl.text.trim();
    final category = _selectedCategory;
    final unit = _selectedUnit;
    final reorderText = _reorderCtl.text.trim();
    final supplier = _preferredSupplierCtl.text.trim();
    final notes = _notesCtl.text.trim();

    // All required - defensive
    if (name.isEmpty ||
        category == null ||
        unit == null ||
        reorderText.isEmpty ||
        supplier.isEmpty ||
        notes.isEmpty) {
      // Should not reach here because validators block, but guard anyway
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Color(0xFF1A237E),
        ),
      );
      return;
    }

    final reorderVal = double.tryParse(reorderText);
    if (reorderVal == null || reorderVal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid reorder level'),
          backgroundColor: Color(0xFF1A237E),
        ),
      );
      return;
    }

    // Duplicate name check (case-insensitive). If another record exists, block.
    final exists = HiveService.medicineNameExists(name, widget.medicine?.id);
    if (exists) {
      setState(() => _nameError = 'A medicine with this name already exists');
      return;
    }

    final id = widget.medicine?.id ?? const Uuid().v4();
    final med = Medicine(
      id: id,
      name: name,
      category: category,
      unit: unit,
      prescriptionRequired: _prescriptionRequired,
      defaultReorderLevel: reorderVal,
      preferredSupplierId: supplier,
      notes: notes,
    );

    await HiveService.addMedicine(med);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.medicine == null ? 'Medicine created' : 'Medicine updated',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A237E),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _confirmAndDelete() async {
    if (widget.medicine == null) return;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A237E),
        title: const Text(
          'Delete Medicine?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This action cannot be undone. This will also delete all batches for this medicine.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (res == true) {
      await HiveService.deleteMedicine(widget.medicine!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Medicine deleted'),
          backgroundColor: Color(0xFF1A237E),
        ),
      );
    }
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required String label,
    required IconData icon,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      dropdownColor: const Color(0xFF1B263B),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        hintStyle: TextStyle(color: Colors.white38),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medicine != null;
    final categoryOptions = _buildCategoryOptions();
    final unitOptions = _buildUnitOptions();

    final categoryItems = categoryOptions
        .map<DropdownMenuItem<String?>>(
          (c) => DropdownMenuItem<String?>(
            value: c,
            child: Text(
              c == null ? 'Select Category' : c,
              style: TextStyle(
                color: c == null ? Colors.white60 : Colors.white,
              ),
            ),
          ),
        )
        .toList();

    final unitItems = unitOptions
        .map<DropdownMenuItem<String>>(
          (u) => DropdownMenuItem<String>(
            value: u,
            child: Text(u, style: const TextStyle(color: Colors.white)),
          ),
        )
        .toList();

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
          isEdit ? 'Edit Medicine' : 'New Medicine',
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
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () async {
                final confirmed = await DeleteConfirmationDialog.show(
                  context,
                  title: 'Delete Medicine?',
                  message:
                      'Are you sure you want to delete "${widget.medicine!.name}"? This will also delete all associated batches. This action cannot be undone.',
                  confirmText: 'Delete Medicine',
                );
                if (confirmed == true) {
                  await HiveService.deleteMedicine(widget.medicine!.id);
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pop(context);
                  SnackBarUtils.showSuccess(context, '🗑️ Medicine deleted');
                }
              },
            ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0xFF0D1B2A),
              Color(0xFF1B263B),
              Color(0xFF2C3E50),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade700, Colors.blue.shade400],
                        ),
                      ),
                      child: const Icon(
                        Icons.medication,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  _buildTextField(
                    controller: _nameCtl,
                    label: 'Medicine Name *',
                    icon: Icons.medication,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter a name';
                      if (_nameError != null) return _nameError;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Category dropdown (required)
                  _buildDropdownField<String?>(
                    value: _selectedCategory,
                    items: categoryItems,
                    label: 'Category *',
                    icon: Icons.category,
                    onChanged: (v) => setState(() {
                      _selectedCategory = v;
                      _categoryCtl.text = v ?? '';
                    }),
                    validator: (v) => (v == null || (v is String && v.isEmpty))
                        ? 'Select a category'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Unit dropdown (required)
                  _buildDropdownField<String>(
                    value: _selectedUnit,
                    items: unitItems,
                    label: 'Unit *',
                    icon: Icons.square_foot,
                    onChanged: (v) => setState(() {
                      _selectedUnit = v;
                      _unitCtl.text = v ?? '';
                    }),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Select a unit' : null,
                  ),
                  const SizedBox(height: 16),

                  // Reorder level (required, numeric >= 0)
                  _buildTextField(
                    controller: _reorderCtl,
                    label: 'Default Reorder Level *',
                    icon: Icons.trending_up,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter reorder level';
                      final n = double.tryParse(v);
                      if (n == null) return 'Enter a valid number';
                      if (n < 0) return 'Cannot be negative';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Preferred supplier (required)
                  _buildTextField(
                    controller: _preferredSupplierCtl,
                    label: 'Preferred Supplier ID *',
                    icon: Icons.people,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter supplier ID'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Notes (required)
                  TextFormField(
                    controller: _notesCtl,
                    decoration: InputDecoration(
                      labelText: 'Notes *',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.note, color: Colors.blueAccent),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(
                          color: Colors.blueAccent,
                          width: 2,
                        ),
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
                    maxLines: 3,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter notes' : null,
                  ),
                  const SizedBox(height: 16),

                  // Prescription switch (user must choose — but it's boolean so always has value)
                  SwitchListTile(
                    value: _prescriptionRequired,
                    onChanged: (v) => setState(() => _prescriptionRequired = v),
                    title: const Text(
                      'Prescription required?',
                      style: TextStyle(color: Colors.white),
                    ),
                    activeColor: Colors.blueAccent,
                    tileColor: Colors.transparent,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 24),

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
                        isEdit ? 'Update Medicine' : 'Create Medicine',
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
}
