// lib/screens/pharmacy_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/pharmacy_profile.dart';
import '../providers/hive_provider.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/glass_card.dart';

class PharmacyProfileScreen extends StatefulWidget {
  const PharmacyProfileScreen({super.key});

  @override
  State<PharmacyProfileScreen> createState() => _PharmacyProfileScreenState();
}

class _PharmacyProfileScreenState extends State<PharmacyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _licenseController = TextEditingController();
  final _footerController = TextEditingController();

  late Box<PharmacyProfile> _profileBox;
  PharmacyProfile? _profile;
  bool _isLoading = true;

  // Real-time preview values
  String _previewName = '';
  String _previewAddress = '';
  String _previewPhone = '';
  String _previewLicense = '';
  String _previewFooter = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();

    // Add listeners for real-time preview updates
    _nameController.addListener(_updatePreview);
    _addressController.addListener(_updatePreview);
    _phoneController.addListener(_updatePreview);
    _licenseController.addListener(_updatePreview);
    _footerController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _nameController.removeListener(_updatePreview);
    _addressController.removeListener(_updatePreview);
    _phoneController.removeListener(_updatePreview);
    _licenseController.removeListener(_updatePreview);
    _footerController.removeListener(_updatePreview);

    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _licenseController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    setState(() {
      _previewName = _nameController.text;
      _previewAddress = _addressController.text;
      _previewPhone = _phoneController.text;
      _previewLicense = _licenseController.text;
      _previewFooter = _footerController.text;
    });
  }

  void _loadProfile() {
    _profileBox = Hive.box<PharmacyProfile>(HiveProvider.pharmacyProfileBox);
    final profiles = _profileBox.values.toList();
    if (profiles.isNotEmpty) {
      _profile = profiles.first;
      _nameController.text = _profile!.pharmacyName;
      _addressController.text = _profile!.address ?? '';
      _phoneController.text = _profile!.phone ?? '';
      _emailController.text = _profile!.email ?? '';
      _websiteController.text = _profile!.website ?? '';
      _taxIdController.text = _profile!.taxId ?? '';
      _licenseController.text = _profile!.licenseNumber ?? '';
      _footerController.text = _profile!.receiptFooter ?? '';

      // Update preview with initial values
      _updatePreview();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final id = _profile?.id ?? const Uuid().v4();
    final profile = PharmacyProfile(
      id: id,
      pharmacyName: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      taxId: _taxIdController.text.trim().isEmpty
          ? null
          : _taxIdController.text.trim(),
      licenseNumber: _licenseController.text.trim().isEmpty
          ? null
          : _licenseController.text.trim(),
      receiptFooter: _footerController.text.trim().isEmpty
          ? null
          : _footerController.text.trim(),
    );

    await _profileBox.put(profile.id, profile);
    setState(() => _profile = profile);

    SnackBarUtils.showSuccess(context, '✅ Pharmacy profile saved!');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Pharmacy Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_profile != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1A237E),
                    title: const Text(
                      'Delete Profile?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'This will remove your pharmacy profile. Receipts will use default values.',
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
                        onPressed: () async {
                          await _profileBox.delete(_profile!.id);
                          setState(() => _profile = null);
                          _nameController.clear();
                          _addressController.clear();
                          _phoneController.clear();
                          _emailController.clear();
                          _websiteController.clear();
                          _taxIdController.clear();
                          _licenseController.clear();
                          _footerController.clear();
                          _updatePreview();
                          Navigator.pop(context);
                          SnackBarUtils.showSuccess(
                            context,
                            '🗑️ Profile deleted',
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade700,
                                      Colors.blue.shade400,
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.local_pharmacy,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _profile != null
                                          ? _profile!.pharmacyName
                                          : 'Set up your pharmacy',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _profile != null
                                          ? 'Profile is configured'
                                          : 'Add your pharmacy details',
                                      style: TextStyle(
                                        color: _profile != null
                                            ? Colors.greenAccent
                                            : Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_profile != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Form Fields
                        const Text(
                          'PHARMACY INFORMATION',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildTextField(
                          controller: _nameController,
                          label: 'Pharmacy Name *',
                          icon: Icons.local_pharmacy,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter pharmacy name'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _addressController,
                          label: 'Address',
                          icon: Icons.location_on,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _websiteController,
                          label: 'Website',
                          icon: Icons.language,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _taxIdController,
                          label: 'Tax ID / Business Reg.',
                          icon: Icons.business_center,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _licenseController,
                          label: 'Pharmacy License Number',
                          icon: Icons.verified,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _footerController,
                          label: 'Receipt Footer Message',
                          icon: Icons.message,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),

                        // Real-time Preview Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade900.withValues(alpha: 0.2),
                                Colors.blue.shade700.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade400.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.preview,
                                    color: Colors.blueAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'LIVE RECEIPT PREVIEW',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'REAL-TIME',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Pharmacy Name
                                    Text(
                                      _previewName.isNotEmpty
                                          ? _previewName.toUpperCase()
                                          : 'PHARMACY NAME',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),

                                    // Address
                                    if (_previewAddress.isNotEmpty)
                                      Text(
                                        _previewAddress,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),

                                    // Phone
                                    if (_previewPhone.isNotEmpty)
                                      Text(
                                        'Tel: $_previewPhone',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),

                                    // License
                                    if (_previewLicense.isNotEmpty)
                                      Text(
                                        'Lic: $_previewLicense',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),

                                    const SizedBox(height: 8),
                                    Container(
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 8),

                                    // Receipt header
                                    const Text(
                                      'RECEIPT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Sample items (showing preview layout)
                                    _buildSampleReceiptItems(),

                                    const SizedBox(height: 8),
                                    Container(
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 8),

                                    // Footer
                                    Text(
                                      _previewFooter.isNotEmpty
                                          ? _previewFooter
                                          : 'Thank you for your purchase!',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),

                                    // Real-time indicator
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '● LIVE PREVIEW',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 7,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              _profile != null
                                  ? 'Update Profile'
                                  : 'Save Profile',
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

  Widget _buildSampleReceiptItems() {
    return Column(
      children: [
        _buildSampleItem('Paracetamol', '2', '2.50', '5.00'),
        const SizedBox(height: 2),
        _buildSampleItem('Amoxicillin', '1', '15.00', '15.00'),
        const SizedBox(height: 2),
        _buildSampleItem('Cetirizine', '3', '1.20', '3.60'),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
              Text(
                '\$23.60',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSampleItem(String name, String qty, String price, String total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: const TextStyle(fontSize: 9, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              qty,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '\$$price',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 9, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '\$$total',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
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
      validator: validator,
    );
  }
}
