import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/demand_matching_models.dart';
import '../../services/database_service.dart';
import '../../services/intelligent_matching_engine.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/optimized_logistics_route_widget.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';

class DynamicDemandMatcherScreen extends StatefulWidget {
  final String? initialCommodity;
  final double? initialQuantityKg;
  final double? initialBudgetPerKg;

  const DynamicDemandMatcherScreen({
    super.key,
    this.initialCommodity,
    this.initialQuantityKg,
    this.initialBudgetPerKg,
  });

  @override
  State<DynamicDemandMatcherScreen> createState() => _DynamicDemandMatcherScreenState();
}

class _DynamicDemandMatcherScreenState extends State<DynamicDemandMatcherScreen> {
  final IntelligentMatchingEngine _engine = IntelligentMatchingEngine();
  final DatabaseService _dbService = DatabaseService();

  late String _selectedCommodity;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  String _selectedGrade = 'Grade A';
  String _deliveryLocation = 'Karnal Central Agro Hub';
  String _selectedPackaging = 'Jute Bags 50kg';

  DemandMatchPlan? _matchPlan;
  bool _isMatching = false;
  bool _isContractLocked = false;

  final List<String> _commodities = [
    'Wheat',
    'Rice / Paddy',
    'Mustard / Oilseeds',
    'Potato',
    'Tomato',
    'Maize / Corn',
    'Kinnow / Orange',
    'Guava',
    'Mango',
    'Papaya',
    'Apple',
    'Cauliflower',
    'Green Peas',
    'Green Chilli',
    'Onion',
    'Garlic',
    'Okra / Bhindi',
    'Carrot',
  ];

  final List<String> _deliveryLocations = [
    'Karnal Central Agro Hub',
    'Panipat Food Processing Silo',
    'Kurukshetra Mandi Logistics Park',
    'Sonipat Industrial Cluster',
    'Ambala Grain Warehouse',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCommodity = widget.initialCommodity ?? 'Wheat';
    if (!_commodities.contains(_selectedCommodity)) {
      _selectedCommodity = _commodities.firstWhere(
        (c) => c.toLowerCase().contains(_selectedCommodity.toLowerCase()),
        orElse: () => 'Wheat',
      );
    }
    _qtyController = TextEditingController(
      text: (widget.initialQuantityKg ?? 500.0).toStringAsFixed(0),
    );
    _priceController = TextEditingController(
      text: (widget.initialBudgetPerKg ?? 35.0).toStringAsFixed(2),
    );

    // Automatically compute initial match on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runMatchingAlgorithm();
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _runMatchingAlgorithm() {
    setState(() {
      _isMatching = true;
      _isContractLocked = false;
    });

    final targetQty = double.tryParse(_qtyController.text) ?? 500.0;
    final maxPrice = double.tryParse(_priceController.text) ?? 35.0;

    final appState = Provider.of<AppState>(context, listen: false);
    final user = appState.currentUser;

    final requirement = BuyerDemandRequirement(
      id: 'REQ-${DateTime.now().millisecondsSinceEpoch}',
      buyerId: user?.id ?? 'DEMO-BUYER-01',
      buyerName: user?.name.isNotEmpty == true ? user!.name : 'AgroFoods Ltd',
      companyName: user?.name.isNotEmpty == true ? user!.name : 'AgroFoods Milling India',
      commodity: _selectedCommodity,
      targetQuantityKg: targetQty,
      maxBudgetPricePerKg: maxPrice,
      requiredGrade: _selectedGrade,
      deliveryLocation: _deliveryLocation,
      deliveryLat: 29.6857,
      deliveryLng: 76.9905,
      earliestDeliveryDate: DateTime.now(),
      latestDeliveryDate: DateTime.now().add(const Duration(days: 4)),
      requiredPackaging: _selectedPackaging,
    );

    final plan = _engine.findOptimalMatch(requirement: requirement);

    setState(() {
      _matchPlan = plan;
      _isMatching = false;
    });
  }

  Future<void> _lockEscrowAndGenerateContract() async {
    if (_matchPlan == null) return;

    setState(() {
      _isMatching = true;
    });

    // Also persist this RFQ/Demand so FPOs and Farmers see it on their screens
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final user = appState.currentUser;

      await _dbService.createBulkRfq({
        'buyerId': user?.id ?? 'DEMO-BUYER',
        'buyerName': user?.name.isNotEmpty == true ? user!.name : 'AgroFoods Milling India',
        'companyName': user?.name.isNotEmpty == true ? user!.name : 'AgroFoods Milling India',
        'commodity': _selectedCommodity,
        'quantityQtl': (_matchPlan!.totalFulfilledQuantityKg / 100.0),
        'targetPricePerQtl': (_matchPlan!.weightedAvgPricePerKg * 100.0),
        'qualityGrade': _selectedGrade,
        'deliveryLocation': _deliveryLocation,
        'status': 'MATCHED_ESCROW_LOCKED',
        'matchedFarmersCount': _matchPlan!.totalFarmerParticipants,
        'matchedPlanId': _matchPlan!.planId,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() {
      _isMatching = false;
      _isContractLocked = true;
    });

    _showContractSuccessModal();
  }

  void _showContractSuccessModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified, color: AppTheme.primaryGreen, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Consolidated Escrow Locked! 🤝',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ऑर्डर और एस्क्रो फंड सफलतापूर्वक सुरक्षित कर दिए गए हैं।',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Total Fulfilled Payload', '${_matchPlan?.totalFulfilledQuantityKg.toStringAsFixed(0)} kg'),
                    const Divider(height: 16),
                    _buildModalRow('Participating Farmers', '${_matchPlan?.totalFarmerParticipants} Smallholders Combined'),
                    const Divider(height: 16),
                    _buildModalRow('Weighted Avg Price', '₹${_matchPlan?.weightedAvgPricePerKg.toStringAsFixed(2)} / kg'),
                    const Divider(height: 16),
                    _buildModalRow('Total Escrow Deposited', '₹${_matchPlan?.totalCost.toStringAsFixed(2)}', isBold: true),
                    const Divider(height: 16),
                    _buildModalRow('Dispatch Vehicle', _matchPlan?.recommendedVehicle ?? 'Tata Ace'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'View Live Tracking & Route (ट्रैकिंग देखें)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppTheme.darkGreen : Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Smart Crop Lot Matcher', 'स्मार्ट किसान लॉट मिलाप'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            Text(
              context.tr('Smallholder Aggregation & Multi-FPO Pool', 'किसान लॉट समूहन व एफपीओ पूल'),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Center(child: LanguageSwitcherPill(isDark: false)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Explanatory Banner
            _buildExplanationBanner(),
            const SizedBox(height: 16),

            // Buyer Procurement Input Card
            _buildProcurementInputCard(),
            const SizedBox(height: 20),

            // Matching Results View
            if (_isMatching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.primaryGreen),
                      SizedBox(height: 14),
                      Text(
                        'Running 10-Factor Optimization Engine...',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else if (_matchPlan != null) ...[
              _buildPlanOverviewCard(_matchPlan!),
              const SizedBox(height: 16),
              _buildFarmerLotBreakdown(_matchPlan!),
              const SizedBox(height: 16),
              _buildLogisticsAndRouteCard(_matchPlan!),
              const SizedBox(height: 24),
              _buildLockEscrowButton(),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B5E20),
            const Color(0xFF2E7D32),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hub, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-Farmer Lot Aggregator 🌾',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'यदि आपको 500 kg चाहिए, तो सिस्टम स्वचालित रूप से किसान A (150kg) + किसान B (220kg) + किसान C (130kg) के लॉट्स को मिलाकर पूरा ऑर्डर तैयार करता है।',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcurementInputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Buyer Demand Parameters (मांग का विवरण)',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Commodity Dropdown
          Text('Commodity / फसल', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCommodity,
                isExpanded: true,
                items: _commodities.map((crop) {
                  return DropdownMenuItem(value: crop, child: Text(crop, style: GoogleFonts.inter(fontSize: 13)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCommodity = val;
                      if (val.contains('Wheat')) _priceController.text = '35.00';
                      if (val.contains('Rice')) _priceController.text = '44.00';
                      if (val.contains('Mustard')) _priceController.text = '62.00';
                      if (val.contains('Potato')) _priceController.text = '19.00';
                      if (val.contains('Tomato')) _priceController.text = '28.00';
                      if (val.contains('Maize')) _priceController.text = '24.00';
                      if (val.contains('Kinnow') || val.contains('Orange')) _priceController.text = '28.00';
                      if (val.contains('Guava')) _priceController.text = '32.00';
                      if (val.contains('Mango')) _priceController.text = '62.00';
                      if (val.contains('Papaya')) _priceController.text = '25.00';
                      if (val.contains('Apple')) _priceController.text = '96.00';
                      if (val.contains('Cauliflower')) _priceController.text = '18.00';
                      if (val.contains('Green Peas') || val.contains('Peas')) _priceController.text = '36.00';
                      if (val.contains('Green Chilli') || val.contains('Chilli')) _priceController.text = '42.00';
                      if (val.contains('Onion')) _priceController.text = '26.00';
                      if (val.contains('Garlic')) _priceController.text = '115.00';
                      if (val.contains('Okra') || val.contains('Bhindi')) _priceController.text = '29.00';
                      if (val.contains('Carrot')) _priceController.text = '19.00';
                    });
                    _runMatchingAlgorithm();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Quantity & Max Price row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Target Qty (कुल मात्रा kg)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        suffixText: 'kg',
                        suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (_) => _runMatchingAlgorithm(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Max Price (अधिकतम दर ₹/kg)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (_) => _runMatchingAlgorithm(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Grade & Delivery Location
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quality Grade', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGrade,
                          isExpanded: true,
                          items: ['Grade A', 'Grade B'].map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.inter(fontSize: 12)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedGrade = val);
                              _runMatchingAlgorithm();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Packaging Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPackaging,
                          isExpanded: true,
                          items: ['Jute Bags 50kg', 'HDPE Sacks 50kg', 'Crates'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: GoogleFonts.inter(fontSize: 12)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedPackaging = val);
                              _runMatchingAlgorithm();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Delivery Location
          Text('Delivery Hub / गंतव्य स्थान', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _deliveryLocation,
                isExpanded: true,
                items: _deliveryLocations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _deliveryLocation = val);
                    _runMatchingAlgorithm();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _runMatchingAlgorithm,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Re-calculate Multi-Lot Match (पुनः मैच करें)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOverviewCard(DemandMatchPlan plan) {
    final savingsPerKg = plan.buyerRequirement.maxBudgetPricePerKg - plan.weightedAvgPricePerKg;
    final totalSavings = savingsPerKg * plan.totalFulfilledQuantityKg;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${plan.fulfillmentPercentage.toStringAsFixed(0)}% ORDER FULFILLED',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Match Score: ${plan.compositeScore.toStringAsFixed(0)}/100',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Fulfilled
          Text(
            '${plan.totalFulfilledQuantityKg.toStringAsFixed(0)} kg ${plan.buyerRequirement.commodity}',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGreen,
            ),
          ),
          Text(
            'Combined across ${plan.totalFarmerParticipants} smallholder lots to meet your exact requirement.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // 3-Pill metrics row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Avg Sourcing Price', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Text('₹${plan.weightedAvgPricePerKg.toStringAsFixed(2)} / kg', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.shade300),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Order Value', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text('₹${plan.totalCost.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.shade300),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Budget Savings', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(
                          savingsPerKg > 0 ? '+₹${totalSavings.toStringAsFixed(0)}' : 'At Budget',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: savingsPerKg > 0 ? const Color(0xFF2E7D32) : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerLotBreakdown(DemandMatchPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Matched Farmer Lots (आवंटित किसान लॉट्स)',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${plan.matchedLots.length} Farmers',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...plan.matchedLots.map((contribution) {
          final lot = contribution.lot;
          final isFractional = contribution.allocatedQuantityKg < lot.quantityKg;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      child: const Icon(Icons.person, color: AppTheme.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lot.farmerName,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Score: ${lot.reliabilityScore.toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '📍 ${lot.village}, ${lot.district} • ${contribution.distanceKm} km away',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          if (lot.fpoAffiliation != null)
                            Text(
                              'Coop: ${lot.fpoAffiliation}',
                              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),

                // Allocation info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Allocated Contribution', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${contribution.allocatedQuantityKg.toStringAsFixed(0)} kg',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                            ),
                            if (isFractional) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Text(
                                  'Marginal Split (from ${lot.quantityKg.toStringAsFixed(0)}kg)',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Price & Farmer Payout', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${contribution.agreedPricePerKg.toStringAsFixed(2)}/kg = ₹${contribution.farmerGrossEarnings.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLogisticsAndRouteCard(DemandMatchPlan plan) {
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
              const Icon(Icons.local_shipping, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Logistics & Fleet Assignment (वाहन चयन)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assigned Vehicle Class', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Text(plan.recommendedVehicle, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${plan.vehicleCapacityUtilizationPct.toStringAsFixed(1)}% Capacity',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.eco, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'CO2 Saved: ${plan.co2SavedKg.toStringAsFixed(1)} kg',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                  ),
                ],
              ),
              Text(
                'Est. Logistics: ₹${plan.estimatedLogisticsCost.toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Automated Logistics & 3-Route Map Optimization
          OptimizedLogisticsRouteWidget(
            commodity: plan.buyerRequirement.commodity,
            originCluster: 'Aggregated Farmer Cluster (${plan.totalFarmerParticipants} Farms, GT Road)',
            destination: plan.buyerRequirement.deliveryLocation,
            originPos: LatLng(
              plan.matchedLots.isNotEmpty ? plan.matchedLots.first.lot.latitude : 29.8021,
              plan.matchedLots.isNotEmpty ? plan.matchedLots.first.lot.longitude : 76.9298,
            ),
            destinationPos: LatLng(plan.buyerRequirement.deliveryLat, plan.buyerRequirement.deliveryLng),
          ),
        ],
      ),
    );
  }

  Widget _buildLockEscrowButton() {
    if (_isContractLocked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Column(
          children: [
            const Icon(Icons.lock, color: AppTheme.primaryGreen, size: 28),
            const SizedBox(height: 6),
            Text(
              'Escrow Locked & Smart Contract Ratified! 🔒',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.darkGreen, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              'Participating farmers have received instant allocation notifications.',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _lockEscrowAndGenerateContract,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, size: 20),
            const SizedBox(width: 10),
            Text(
              'Lock Consolidated Escrow & Order (₹${_matchPlan?.totalCost.toStringAsFixed(0)})',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
