import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../services/database_service.dart';
import '../../services/smart_contract_service.dart';
import '../../services/smart_contract_pdf_service.dart';
import '../../utils/crop_image_helper.dart';

class RetailCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> crop;
  final void Function(int tabIndex)? onNavigateTab;

  const RetailCheckoutScreen({
    super.key,
    required this.crop,
    this.onNavigateTab,
  });

  @override
  State<RetailCheckoutScreen> createState() => _RetailCheckoutScreenState();
}

class _RetailCheckoutScreenState extends State<RetailCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _pincodeController;
  late TextEditingController _notesController;

  double _selectedQty = 5.0;
  double _pricePerKg = 0.0;
  double _maxQty = 100.0;
  String _cropName = 'Fresh Harvest';
  String _variety = 'Certified Pure';
  String _grade = 'Grade A';
  String _farmerName = 'Local Farmer';
  String _location = 'Farm Cluster';
  String _distance = 'Nearby';
  String _imageUrl = '';
  bool _isNFT = false;

  String _paymentMethod = 'UPI'; // 'UPI', 'NetBanking', 'COD'
  String _selectedUpiApp = 'Google Pay';
  bool _isProcessing = false;
  String _processingStep = '';

  @override
  void initState() {
    super.initState();
    final crop = widget.crop;
    _cropName = crop['name'] ?? crop['cropName'] ?? 'Fresh Farm Produce';
    _variety = crop['variety'] ?? 'Premium Hybrid';
    _grade = crop['qualityGrade']?.toString() ?? crop['grade']?.toString() ?? 'Grade A';
    _farmerName = crop['farmerName'] ?? 'Rajesh Verma (Verified Kisaan)';
    _location = crop['location'] ?? 'Karnal Agri-Cluster, Haryana';
    _distance = crop['distance'] ?? '8.4 km';
    _imageUrl = crop['imageUrl']?.toString() ?? crop['image']?.toString() ?? '';
    _isNFT = crop['isNFT'] as bool? ?? true;

    _pricePerKg = _toDouble(crop['price']);
    if (_pricePerKg <= 0) _pricePerKg = 45.0;

    _maxQty = _toDouble(crop['quantity']);
    if (_maxQty <= 0) _maxQty = 150.0;

    final initialQty = _toDouble(crop['selectedQuantity'] ?? crop['orderQuantity']);
    if (initialQty > 0) {
      if (initialQty > _maxQty) _maxQty = initialQty * 1.5;
      _selectedQty = initialQty;
    } else {
      _selectedQty = (_maxQty >= 5.0) ? 5.0 : 1.0;
    }

    _nameController = TextEditingController(text: 'Aditya Sharma');
    _phoneController = TextEditingController(text: '9876543210');
    _addressController = TextEditingController(text: 'House No. 42, Model Town, Urban Estate');
    _cityController = TextEditingController(text: 'Karnal, Haryana');
    _pincodeController = TextEditingController(text: '132001');
    _notesController = TextEditingController(text: 'Please call before arrival. Deliver at doorstep.');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.userName != 'Guest' && _nameController.text == 'Aditya Sharma') {
      _nameController.text = appState.userName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }

  double get _subtotal => _selectedQty * _pricePerKg;
  double get _deliveryFee => _subtotal >= 1000 ? 0.0 : 49.0;
  double get _totalPayable => _subtotal + _deliveryFee;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Secure Checkout',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 11, color: Color(0xFF1B5E20)),
                const SizedBox(width: 4),
                Text(
                  'Web2.5 Smart Escrow • 100% INR Settlement',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Crop Summary Card
                  _buildCropSummaryCard(),
                  const SizedBox(height: 16),

                  // 2. Quantity Selector Card
                  _buildQuantitySelectorCard(),
                  const SizedBox(height: 16),

                  // 3. Web2.5 Blockchain & Smart Escrow Assurance Card
                  _buildSmartEscrowExplanationCard(),
                  const SizedBox(height: 16),

                  // 4. Delivery Address & Recipient Details Card
                  _buildDeliveryDetailsCard(),
                  const SizedBox(height: 16),

                  // 5. Payment Method Selector (100% INR Fiat)
                  _buildPaymentMethodCard(),
                  const SizedBox(height: 16),

                  // 6. Detailed Price Breakdown
                  _buildPriceBreakdownCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Fixed Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActionBar(),
          ),

          // Processing Overlay Modal
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  // 1. Crop Summary Card
  Widget _buildCropSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crop Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                CropImageHelper.buildCropImage(
                  _imageUrl,
                  _cropName,
                  height: 90,
                  width: 90,
                  fit: BoxFit.cover,
                ),
                if (_isNFT)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.verified, color: Color(0xFF69F0AE), size: 10),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Crop Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _cropName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _grade,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _variety,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$_farmerName • $_location',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${_pricePerKg.toStringAsFixed(0)} / kg',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    Text(
                      '${_maxQty.toStringAsFixed(0)} kg available',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Quantity Selector Card
  Widget _buildQuantitySelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Quantity (in kg)',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
              ),
              Text(
                '₹${_pricePerKg.toStringAsFixed(0)} per kg',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stepper Row
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _selectedQty > 1.0
                    ? () {
                        setState(() {
                          if (_selectedQty >= 5.0) {
                            _selectedQty -= 5.0;
                            if (_selectedQty < 1.0) _selectedQty = 1.0;
                          } else {
                            _selectedQty -= 1.0;
                          }
                        });
                      }
                    : null,
                icon: const Icon(Icons.remove, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(
                      '${_selectedQty.toStringAsFixed(0)} kg',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(
                onPressed: _selectedQty < _maxQty
                    ? () {
                        setState(() {
                          _selectedQty = (_selectedQty + 5.0 <= _maxQty) ? _selectedQty + 5.0 : _maxQty;
                        });
                      }
                    : null,
                icon: const Icon(Icons.add, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick Select Chips
          Wrap(
            spacing: 8,
            children: [5.0, 10.0, 25.0, 50.0, _maxQty].map((qty) {
              if (qty > _maxQty && qty != _maxQty) return const SizedBox.shrink();
              final isMax = qty == _maxQty;
              final isSelected = _selectedQty == qty;
              final label = isMax ? 'Max (${qty.toInt()} kg)' : '${qty.toInt()} kg';

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: AppTheme.primaryGreen,
                backgroundColor: Colors.grey.shade100,
                labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.darkGreen,
                ),
                side: BorderSide(color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedQty = qty);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 3. Web2.5 Blockchain & Smart Escrow Explanation Card
  Widget _buildSmartEscrowExplanationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3D1F), Color(0xFF1E5E2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F3D1F).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFF69F0AE), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Escrow Protection Guarantee',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Web2.5 Fiat-to-Smart Contract Architecture',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFFB9F6CA),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF69F0AE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Zero Crypto Needed',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F3D1F),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: Colors.white24),

          _buildEscrowBullet(
            icon: Icons.currency_rupee,
            title: '100% Indian Rupee (₹) Settlement',
            desc: 'You pay in regular INR via UPI or NetBanking. No crypto wallets, no seed phrases, and no coin volatility.',
          ),
          const SizedBox(height: 10),
          _buildEscrowBullet(
            icon: Icons.lock_clock_outlined,
            title: 'Automated Escrow Lock (AgriTradeEscrow.sol)',
            desc: 'Your payment is cryptographically locked on Polygon PoS. Money is never paid to the farmer upfront.',
          ),
          const SizedBox(height: 10),
          _buildEscrowBullet(
            icon: Icons.pin_outlined,
            title: '6-Digit Delivery Handshake OTP',
            desc: 'Payment releases to the farmer ONLY when you physically inspect the crop and share your 6-digit OTP.',
          ),
          const SizedBox(height: 10),
          _buildEscrowBullet(
            icon: Icons.bolt_outlined,
            title: 'Gasless Meta-Transactions (EIP-2771)',
            desc: 'AgriChain relayer sponsors 100% of blockchain gas fees. You pay ₹0 blockchain charges.',
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowBullet({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF69F0AE), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 4. Delivery Address & Recipient Details Card
  Widget _buildDeliveryDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delivery & Contact Details',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Full Name & Phone
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Recipient Name',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter recipient name' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile (For Delivery OTP)',
                    prefixIcon: const Icon(Icons.phone_android, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Enter valid 10-digit mobile' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Street Address
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'House / Flat No., Society, Landmark',
              prefixIcon: const Icon(Icons.home_outlined, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter delivery address' : null,
          ),
          const SizedBox(height: 12),

          // City & Pincode
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City / District, State',
                    prefixIcon: const Icon(Icons.location_city, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter city' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Pincode',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().length != 6) ? '6 digits' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Delivery Speed Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: AppTheme.primaryGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direct Farm Logistics: Dispatch within 24 hours. Directly weighed at farm gate.',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.darkGreen, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. Payment Method Selector (100% INR Fiat)
  Widget _buildPaymentMethodCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Mode (100% INR Fiat)',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Instant UPI / Bank',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Options
          _buildPaymentOption(
            value: 'UPI',
            title: 'UPI Instant Payment (Zero Surcharge)',
            subtitle: 'Google Pay, PhonePe, Paytm, BHIM UPI',
            icon: Icons.account_balance_wallet_outlined,
          ),
          if (_paymentMethod == 'UPI') ...[
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 10),
              child: Row(
                children: ['Google Pay', 'PhonePe', 'Paytm', 'BHIM'].map((app) {
                  final isSelected = _selectedUpiApp == app;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(app),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppTheme.darkGreen : Colors.grey.shade700,
                      ),
                      side: BorderSide(color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300),
                      onSelected: (_) => setState(() => _selectedUpiApp = app),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          _buildPaymentOption(
            value: 'NetBanking',
            title: 'NetBanking & RuPay / Visa Cards',
            subtitle: 'SBI, HDFC, ICICI, PNB, and all Indian banks',
            icon: Icons.credit_card_outlined,
          ),
          _buildPaymentOption(
            value: 'COD',
            title: 'Pay on Doorstep Delivery',
            subtitle: 'UPI/Cash payment collected upon inspection at delivery',
            icon: Icons.handshake_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.primaryGreen : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Icon(icon, color: AppTheme.darkGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Detailed Price Breakdown
  Widget _buildPriceBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Breakdown',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
          ),
          const SizedBox(height: 12),

          _buildPriceRow(
            label: '${_selectedQty.toStringAsFixed(0)} kg × ₹${_pricePerKg.toStringAsFixed(0)}',
            value: '₹${_subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),

          _buildPriceRow(
            label: 'Farm-to-Door Logistics',
            value: _deliveryFee == 0 ? 'FREE' : '₹${_deliveryFee.toStringAsFixed(2)}',
            isGreen: _deliveryFee == 0,
          ),
          const SizedBox(height: 8),

          _buildPriceRow(
            label: 'Smart Contract Escrow Guarantee',
            value: 'FREE',
            subtext: '(₹25 Waived by AgriChain)',
            isGreen: true,
          ),
          const SizedBox(height: 8),

          _buildPriceRow(
            label: 'Blockchain Gas Relayer Fee',
            value: 'FREE (Sponsored)',
            isGreen: true,
          ),
          const Divider(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable (INR ₹)',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
              ),
              Text(
                '₹${_totalPayable.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow({
    required String label,
    required String value,
    String? subtext,
    bool isGreen = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
            ),
            if (subtext != null) ...[
              const SizedBox(width: 4),
              Text(
                subtext,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isGreen ? const Color(0xFF15803D) : AppTheme.darkGreen,
          ),
        ),
      ],
    );
  }

  // Bottom Action Bar
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Payable',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  '₹${_totalPayable.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _handlePlaceOrderAndLockEscrow,
                  icon: const Icon(Icons.lock, size: 18),
                  label: Text(
                    'Lock in Smart Escrow',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Processing Overlay Modal
  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Executing Smart Contract',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
            ),
            const SizedBox(height: 8),
            Text(
              _processingStep,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: AppTheme.primaryGreen, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Relayed on Polygon (Gasless)',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Main Action: Trigger Smart Contract + Create Order
  Future<void> _handlePlaceOrderAndLockEscrow() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final buyerSignatureUrl = Provider.of<AppState>(context, listen: false).currentUser?.signatureUrl;

    setState(() {
      _isProcessing = true;
      _processingStep = 'Connecting to Polygon RPC node & preparing smart contract terms...';
    });

    try {
      // Step 1: Deploy / Create Purchase Contract
      await Future.delayed(const Duration(milliseconds: 900));
      setState(() {
        _processingStep = 'Anchoring Indian Contract Act & IT Act 2000 legal terms in AgriTradeEscrow.sol...';
      });

      final contractRes = await SmartContractService.createPurchaseContract(
        buyerAddress: '0xBuyer_${_phoneController.text.trim()}',
        sellerAddress: '0xFarmer_${_farmerName.replaceAll(' ', '_')}',
        cropId: widget.crop['id']?.toString() ?? 'CROP_${DateTime.now().millisecondsSinceEpoch}',
        nftTokenId: widget.crop['nftTokenId']?.toString() ?? 'NFT_7719',
        amount: _totalPayable,
        quantity: '${_selectedQty.toStringAsFixed(0)} kg',
        expectedDelivery: DateTime.now().add(const Duration(days: 2)),
      );

      // Step 2: Lock Escrow in Polygon Smart Contract
      setState(() {
        _processingStep = 'Locking ₹${_totalPayable.toStringAsFixed(0)} in Digital Escrow (Gasless Meta-Transaction)...';
      });

      final escrowRes = await SmartContractService.lockEscrow(
        contractId: contractRes['contractId'] as String,
        buyerAddress: '0xBuyer_${_phoneController.text.trim()}',
        amount: _totalPayable,
      );

      // Step 3: Generate 6-digit Delivery Handshake OTP
      final deliveryOtp = (Random().nextInt(900000) + 100000).toString();
      final orderId = 'RET-${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';

      // Step 4: Write order to Firestore Database
      setState(() {
        _processingStep = 'Registering order and delivery tracking in AgriChain decentralized database...';
      });

      final fullDeliveryAddress = '${_addressController.text.trim()}, ${_cityController.text.trim()} - ${_pincodeController.text.trim()}';

      final currentBuyer = Provider.of<AppState>(context, listen: false).currentUser;
      final buyerId = currentBuyer?.id.isNotEmpty == true ? currentBuyer!.id : 'demo_retailBuyer_001';
      final buyerEmail = currentBuyer?.email.isNotEmpty == true ? currentBuyer!.email : 'retail@agrichain.com';
      final farmerId = widget.crop['farmerId'] ?? widget.crop['sellerId'] ?? widget.crop['userId'] ?? 'demo_farmer_001';

      final orderData = {
        'orderId': orderId,
        'cropName': _cropName,
        'cropId': widget.crop['id']?.toString() ?? '',
        'variety': _variety,
        'grade': _grade,
        'imageUrl': _imageUrl,
        'quantity': _selectedQty,
        'unit': 'kg',
        'pricePerUnit': _pricePerKg,
        'price': _pricePerKg,
        'subtotal': _subtotal,
        'deliveryFee': _deliveryFee,
        'totalAmount': _totalPayable,
        'totalPrice': _totalPayable,
        'farmerName': _farmerName,
        'farmerId': farmerId,
        'sellerId': farmerId,
        'orderType': 'retail_order',
        'farmerDistance': _distance,
        'farmerLocation': _location,
        'farmerSignatureUrl': widget.crop['farmerSignatureUrl'] ?? widget.crop['signatureUrl'],
        'isFarmerDigiLockerVerified': widget.crop['isFarmerDigiLockerVerified'] ?? true,
        'digiLockerCertId': widget.crop['digiLockerCertId'] ?? 'DL-ESIGN-8921-HRY',
        'buyerSignatureUrl': buyerSignatureUrl,
        'isBuyerDigiLockerVerified': true,
        'buyerId': buyerId,
        'userId': buyerId,
        'buyerEmail': buyerEmail,
        'buyerName': _nameController.text.trim(),
        'buyerPhone': _phoneController.text.trim(),
        'deliveryAddress': fullDeliveryAddress,
        'deliveryNotes': _notesController.text.trim(),
        'paymentMethod': _paymentMethod == 'UPI' ? 'UPI ($_selectedUpiApp)' : _paymentMethod,
        'status': 'active', // active, in_transit, delivered
        'escrowStatus': 'LOCKED',
        'deliveryOtp': deliveryOtp,
        'contractId': contractRes['contractId'],
        'contractAddress': contractRes['contractAddress'],
        'txHash': escrowRes['transactionHash'] ?? contractRes['transactionHash'],
        'blockNumber': escrowRes['blockNumber'] ?? contractRes['blockNumber'],
        'gasUsed': escrowRes['gasUsed'] ?? '0.0035 MATIC (Sponsored)',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final created = await _dbService.createRetailOrder(orderData);

      if (created && mounted) {
        try {
          final appState = Provider.of<AppState>(context, listen: false);
          appState.deductCropQuantity(
            widget.crop['id']?.toString() ?? '',
            _cropName,
            _selectedQty,
          );
        } catch (_) {}
      }

      setState(() {
        _isProcessing = false;
      });

      if (!mounted) return;

      if (created) {
        _showOrderSuccessDialog(orderData);
        // Automatically open the signed smart contract PDF for view/download
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            SmartContractPdfService.autoDownloadOrPreviewContract(
              context: context,
              order: orderData,
              openDirectly: true,
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Order created locally, database sync pending.')),
        );
        _showOrderSuccessDialog(orderData);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order processing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Success Dialog with Delivery OTP & Blockchain Details
  void _showOrderSuccessDialog(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Green Success Circle
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                    ),
                    child: const Icon(Icons.check, color: Color(0xFF15803D), size: 36),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Order Placed & Escrow Locked!',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order ${order['orderId']} • ₹${(order['totalAmount'] as num).toStringAsFixed(0)} locked in Smart Escrow',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 18),

                  // Delivery OTP Box (Prominent)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F3D1F), Color(0xFF1E5E2E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F3D1F).withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.key, color: Color(0xFF69F0AE), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'YOUR DELIVERY VERIFICATION OTP',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF69F0AE),
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: order['deliveryOtp'] as String));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📋 Delivery OTP copied to clipboard!')),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                order['deliveryOtp'] as String,
                                style: GoogleFonts.spaceMono(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy, color: Colors.white70, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '⚠️ IMPORTANT: Share this OTP with the delivery agent ONLY after you inspect and accept the crop. Once shared, funds are released to the farmer.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Blockchain On-Chain Receipt Accordion
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAF7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hub_outlined, color: AppTheme.primaryGreen, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Decentralized Blockchain Proof (Polygon)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                            ),
                          ],
                        ),
                        const Divider(height: 14),
                        _buildReceiptRow('Contract ID', order['contractId'] as String),
                        _buildReceiptRow('Tx Hash', order['txHash'] as String, isHash: true),
                        _buildReceiptRow('Block Number', '#${order['blockNumber']}'),
                        _buildReceiptRow('Gas Sponsored', '0.0035 MATIC (Buyer Paid ₹0)', isGreen: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Download Signed Smart Contract Button
                  Container(
                    width: double.infinity,
                    height: 48,
                    margin: const EdgeInsets.only(bottom: 14),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SmartContractPdfService.autoDownloadOrPreviewContract(
                          context: context,
                          order: order,
                          openDirectly: false,
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: Text(
                        'Download Signed Smart Contract (PDF)',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3D1F),
                        foregroundColor: const Color(0xFF69F0AE),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.darkGreen,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(
                            'Continue Shopping',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            if (widget.onNavigateTab != null) {
                              widget.onNavigateTab!(2); // Navigate to Tab 2: Orders Tab
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(
                            'Track in Orders',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isHash = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: isHash
                  ? GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)
                  : GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isGreen ? const Color(0xFF15803D) : AppTheme.darkGreen,
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
