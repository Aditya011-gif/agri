import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/b2b_contract_model.dart';
import '../../models/buyer_plant_model.dart';
import '../../providers/app_state.dart';
import '../../services/database_service.dart';
import '../../services/smart_contract_pdf_service.dart';
import '../../theme/app_theme.dart';
import 'b2b_contract_screen.dart';
import 'bulk_buyer_orders_screen.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/optimized_logistics_route_widget.dart';

/// Screen: Enterprise B2B Bulk Buying Payment Screen & Non-Custodial Smart Escrow Lock
/// Supports Corporate RTGS/NEFT Virtual Escrow Accounts, NetBanking/UPI Smart Vaults,
/// Letters of Credit (LC), and automates real Tripartite Contract execution and inventory reservation.
class EscrowCheckoutScreen extends StatefulWidget {
  final String commodity;
  final String? variety;
  final String originCluster;
  final String destinationFactory;
  final double orderedTonnage; // in MT
  final double cropRatePerTonne; // in ₹/MT
  final double? orderedQuantityQtl; // in Qtl
  final double? cropRatePerQtl; // in ₹/Qtl
  final String? fpoId;
  final String? fpoName;
  final String? warehouseId;
  final String? inventoryItemId;
  final bool isMultiFpo;
  final List<Map<String, dynamic>> allocations;

  const EscrowCheckoutScreen({
    super.key,
    this.commodity = 'Basmati Paddy 1121',
    this.variety = 'PB-1121 (Export Grade)',
    this.originCluster = 'Karnal FPO Silo Complex 01 (Haryana)',
    this.destinationFactory = 'AgroFoods Milling Plant, Kundli (Haryana)',
    this.orderedTonnage = 250.0,
    this.cropRatePerTonne = 35200.0,
    this.orderedQuantityQtl,
    this.cropRatePerQtl,
    this.fpoId = 'fpo_karnal_01',
    this.fpoName = 'Karnal Agro Farmers Producer Co.',
    this.warehouseId,
    this.inventoryItemId,
    this.isMultiFpo = false,
    this.allocations = const [],
  });

  @override
  State<EscrowCheckoutScreen> createState() => _EscrowCheckoutScreenState();
}

class _EscrowCheckoutScreenState extends State<EscrowCheckoutScreen> {
  final DatabaseService _dbService = DatabaseService();

  List<BuyerDeliveryPlant> _availablePlants = [];
  BuyerDeliveryPlant? _selectedPlant;

  int _selectedCarrierIndex = 0;
  int _selectedPaymentMethod = 0; // 0: RTGS/NEFT Virtual Account, 1: Smart Vault, 2: Letter of Credit
  int _selectedCorporateBankIndex = 0;

  bool _isLockingEscrow = false;
  bool _agreedToContractTerms = true;

  late final TextEditingController _utrController;
  late final TextEditingController _upiController;
  late final TextEditingController _lcNumberController;
  late final TextEditingController _signatoryController;

  final String _virtualAccountNumber = 'AGRI9908${Random().nextInt(899999) + 100000}';
  final String _virtualIfsc = 'ICIC0000104';

  final List<Map<String, dynamic>> _carriers = [
    {
      'name': 'BlackBuck FTL',
      'tag': 'Recommended FTL',
      'quote': 32400.0,
      'transitHours': '24 Hours',
      'rating': 4.8,
      'verifiedFastag': true,
      'truckType': '32ft Multi-Axle Container (250 Qtl)',
    },
    {
      'name': 'Trukky National Freight',
      'tag': 'Best Value',
      'quote': 31800.0,
      'transitHours': '28 Hours',
      'rating': 4.6,
      'verifiedFastag': true,
      'truckType': '32ft Container',
    },
    {
      'name': 'WheelsEye Logistics',
      'tag': 'GPS Telematics',
      'quote': 33100.0,
      'transitHours': '26 Hours',
      'rating': 4.7,
      'verifiedFastag': true,
      'truckType': 'Heavy FTL Body',
    },
    {
      'name': 'Delhivery B2B Freight',
      'tag': 'Fastest Delivery',
      'quote': 35200.0,
      'transitHours': '20 Hours',
      'rating': 4.9,
      'verifiedFastag': true,
      'truckType': 'Express Container',
    },
    {
      'name': 'FR8 Inter-City Logistics',
      'tag': 'Enterprise Fleet',
      'quote': 34500.0,
      'transitHours': '22 Hours',
      'rating': 4.7,
      'verifiedFastag': true,
      'truckType': '32ft MXL',
    },
    {
      'name': 'LoadShare Networks',
      'tag': 'Standard FTL',
      'quote': 33800.0,
      'transitHours': '24 Hours',
      'rating': 4.5,
      'verifiedFastag': true,
      'truckType': 'Container Truck',
    },
    {
      'name': 'Shiprocket Cargo FTL',
      'tag': 'Multi-Carrier',
      'quote': 32900.0,
      'transitHours': '25 Hours',
      'rating': 4.6,
      'verifiedFastag': true,
      'truckType': 'Standard 250 Qtl',
    },
  ];

  final List<Map<String, String>> _corporateBanks = [
    {'name': 'HDFC Bank Corporate', 'code': 'HDFC0000060'},
    {'name': 'State Bank of India (CAG)', 'code': 'SBIN0000691'},
    {'name': 'ICICI Bank e-Escrow', 'code': 'ICIC0000104'},
    {'name': 'Axis Bank Commercial', 'code': 'UTIB0000005'},
  ];

  @override
  void initState() {
    super.initState();
    _utrController = TextEditingController(text: 'UTR2026${Random().nextInt(89999999) + 10000000}');
    _upiController = TextEditingController(text: 'procure@itcagro');
    _lcNumberController = TextEditingController(text: 'LC/2026/ICICI/${Random().nextInt(89999) + 10000}');
    _signatoryController = TextEditingController();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    final plants = await BuyerDeliveryPlant.loadSavedPlants();
    if (mounted) {
      setState(() {
        _availablePlants = plants;
        // Prioritize primary or matching plant
        _selectedPlant = plants.firstWhere(
          (p) => p.isPrimary,
          orElse: () => plants.first,
        );
      });
    }
  }

  void _showPlantSelectorModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Delivery Facility (Profile)',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Verified Plants', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Live navigation route, FASTag toll checkpoints, and contract execution adapt dynamically to the destination.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _availablePlants.length,
                  separatorBuilder: (_, __) => const Divider(height: 10),
                  itemBuilder: (context, idx) {
                    final plant = _availablePlants[idx];
                    final isSelected = _selectedPlant?.id == plant.id;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedPlant = plant);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE8F5E9) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.factory_outlined,
                              color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade600,
                              size: 24,
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
                                          plant.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isSelected ? const Color(0xFF1B5E20) : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(plant.address, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Text(
                                          '${plant.latitude.toStringAsFixed(4)}° N, ${plant.longitude.toStringAsFixed(4)}° E',
                                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        plant.corridorName,
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _utrController.dispose();
    _upiController.dispose();
    _lcNumberController.dispose();
    _signatoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    if (_signatoryController.text.isEmpty) {
      _signatoryController.text = user?.name.isNotEmpty == true ? user!.name : 'Corporate Procurement Officer';
    }

    // Determine quantities in Quintals and MT
    final double totalQtl = widget.orderedQuantityQtl ?? (widget.orderedTonnage * 10.0);
    final double totalMT = totalQtl / 10.0;
    final double ratePerQtl = widget.cropRatePerQtl ?? (widget.cropRatePerTonne > 5000 ? widget.cropRatePerTonne / 10.0 : widget.cropRatePerTonne);

    final double cropCost = totalQtl * ratePerQtl;
    final double freightCost = _carriers[_selectedCarrierIndex]['quote'] as double;
    final double transitInsurance = cropCost * 0.002; // 0.2% Single-Trip Transit Insurance
    final double protocolFee = cropCost * 0.015; // 1.5% AgriChain Escrow Protocol Fee
    final double totalEscrowLock = cropCost + freightCost + transitInsurance + protocolFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF1B5E20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'B2B Wholesale Escrow Checkout',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B5E20),
              ),
            ),
            Text(
              'Polygon PoS L2 • Non-Custodial Multi-Carrier Escrow',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Order Summary Card
          _buildOrderSummaryCard(totalQtl, totalMT, ratePerQtl, cropCost),
          const SizedBox(height: 14),

          // 1.5 Real Delivery Plant Selector from Profile
          _buildDeliveryPlantSelectorCard(),
          const SizedBox(height: 16),

          // 2. 7-Carrier Freight Comparison Engine
          _build7CarrierComparatorSection(),
          const SizedBox(height: 16),

          // 3. Itemized Smart Escrow Breakdown Card
          _buildItemizedEscrowBreakdownCard(totalQtl, cropCost, freightCost, transitInsurance, protocolFee, totalEscrowLock),
          const SizedBox(height: 16),

          // 4. B2B Corporate Payment Rails Section
          _buildB2bPaymentMethodsSection(totalEscrowLock),
          const SizedBox(height: 16),

          // 5. Legal Tripartite Contract Review & E-Sign Card
          _buildContractReviewAndSignSection(totalQtl, ratePerQtl, freightCost),
          const SizedBox(height: 20),

          // 6. Execute Escrow Lock Action Button
          _buildEscrowActionButton(totalEscrowLock, totalQtl, totalMT, ratePerQtl, freightCost, transitInsurance, protocolFee),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildDeliveryPlantSelectorCard() {
    final plant = _selectedPlant;
    final plantName = plant?.name ?? widget.destinationFactory;
    final plantAddress = plant?.address ?? widget.destinationFactory;
    final coords = plant != null
        ? '${plant.latitude.toStringAsFixed(4)}° N, ${plant.longitude.toStringAsFixed(4)}° E'
        : '28.8785° N, 77.1275° E';
    final corridor = plant?.corridorName ?? 'NH-44 North Corridor (Haryana)';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.factory, size: 18, color: Color(0xFF2E7D32)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery Facility (Buyer Profile)',
                    style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
                  ),
                ],
              ),
              InkWell(
                onTap: _showPlantSelectorModal,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_vert, size: 14, color: Color(0xFF1B5E20)),
                      const SizedBox(width: 4),
                      Text(
                        'Change Plant',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plantName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Verified Gate',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  plantAddress,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pin_drop, size: 11, color: Color(0xFF1565C0)),
                          const SizedBox(width: 3),
                          Text(
                            coords,
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Corridor: $corridor',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  Widget _buildOrderSummaryCard(double totalQtl, double totalMT, double ratePerQtl, double cropCost) {
    final destName = _selectedPlant?.name ?? widget.destinationFactory;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.commodity,
                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${totalQtl.toStringAsFixed(0)} Qtl (${totalMT.toStringAsFixed(1)} MT)',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
                ),
              ),
            ],
          ),
          if (widget.variety != null && widget.variety!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Variety: ${widget.variety}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
          ],
          const SizedBox(height: 8),
          Text('📍 Origin: ${widget.originCluster}', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade700)),
          Text('🏭 Destination: $destName', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Commodity Valuation (@ ₹${ratePerQtl.toStringAsFixed(0)}/Qtl):', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600)),
              Text('₹${cropCost.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build7CarrierComparatorSection() {
    final destLat = _selectedPlant?.latitude ?? 28.6139;
    final destLng = _selectedPlant?.longitude ?? 77.2090;

    return OptimizedLogisticsRouteWidget(
      commodity: widget.commodity,
      originCluster: widget.originCluster,
      destination: _selectedPlant?.name ?? widget.destinationFactory,
      originPos: const LatLng(29.8021, 76.9298),
      destinationPos: LatLng(destLat, destLng),
      onCarrierAutoSelected: (carrier) {
        final idx = _carriers.indexWhere((c) => c['name'] == carrier['name']);
        if (idx != -1 && idx != _selectedCarrierIndex) {
          setState(() => _selectedCarrierIndex = idx);
        }
      },
    );
  }

  Widget _buildItemizedEscrowBreakdownCard(
    double totalQtl,
    double cropCost,
    double freightCost,
    double insurance,
    double fee,
    double total,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFF1B5E20), size: 18),
              const SizedBox(width: 8),
              Text(
                'Itemized Escrow Lock Amount',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBillRow('Commodity Base Cost (${totalQtl.toStringAsFixed(0)} Qtl)', '₹${cropCost.toStringAsFixed(0)}'),
          _buildBillRow('Freight Fee (${_carriers[_selectedCarrierIndex]['name']})', '₹${freightCost.toStringAsFixed(0)}'),
          _buildBillRow('Single-Trip Transit Insurance (0.2%)', '₹${insurance.toStringAsFixed(0)}'),
          _buildBillRow('AgriChain Escrow Protocol Fee (1.5%)', '₹${fee.toStringAsFixed(0)}'),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Lock in Smart Escrow:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
              ),
              Text(
                '₹${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
        ],
      ),
    );
  }

  Widget _buildB2bPaymentMethodsSection(double totalEscrowLock) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance, color: Color(0xFF1B5E20), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Corporate B2B Payment Rails',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Non-Custodial Escrow', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Mode Selector Tabs
          Row(
            children: [
              _buildPaymentTab(0, 'RTGS / NEFT', Icons.swap_horiz),
              const SizedBox(width: 8),
              _buildPaymentTab(1, 'Smart Vault', Icons.flash_on),
              const SizedBox(width: 8),
              _buildPaymentTab(2, 'Letter of Credit', Icons.description_outlined),
            ],
          ),
          const SizedBox(height: 16),

          // Mode 0: RTGS / NEFT Virtual Account
          if (_selectedPaymentMethod == 0) _buildRtgsVirtualAccountContent(),

          // Mode 1: Smart Vault NetBanking / UPI
          if (_selectedPaymentMethod == 1) _buildSmartVaultContent(),

          // Mode 2: Letter of Credit (LC)
          if (_selectedPaymentMethod == 2) _buildLetterOfCreditContent(),
        ],
      ),
    );
  }

  Widget _buildPaymentTab(int index, String title, IconData icon) {
    final isSelected = _selectedPaymentMethod == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMethod = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRtgsVirtualAccountContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Dedicated Escrow Virtual Account (VAN):', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.copy, size: 14, color: Color(0xFF1B5E20)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _virtualAccountNumber));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Virtual Account copied!')));
                    },
                  ),
                ],
              ),
              Text(
                _virtualAccountNumber,
                style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('IFSC: $_virtualIfsc (ICICI Corporate Banking)', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF334155))),
                  Text('Beneficiary: AgriChain Escrow Hub', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _utrController,
          decoration: InputDecoration(
            labelText: 'Bank 16-Digit UTR (Transaction Reference) Number',
            labelStyle: const TextStyle(fontSize: 12),
            hintText: 'e.g. UTR202688419201',
            prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSmartVaultContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Corporate NetBanking Gateway:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_corporateBanks.length, (idx) {
            final isSelected = _selectedCorporateBankIndex == idx;
            return ChoiceChip(
              label: Text(_corporateBanks[idx]['name']!),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87),
              selected: isSelected,
              selectedColor: const Color(0xFF1B5E20),
              backgroundColor: const Color(0xFFF1F5F9),
              onSelected: (_) => setState(() => _selectedCorporateBankIndex = idx),
            );
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _upiController,
          decoration: InputDecoration(
            labelText: 'Corporate Escrow UPI VPA Handle',
            labelStyle: const TextStyle(fontSize: 12),
            hintText: 'procure@company',
            prefixIcon: const Icon(Icons.alternate_email, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildLetterOfCreditContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '100% Irrevocable Documentary Letter of Credit payable at sight upon weighbridge reconciliation.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lcNumberController,
          decoration: InputDecoration(
            labelText: 'Letter of Credit (LC) Number',
            labelStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.document_scanner_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildContractReviewAndSignSection(double totalQtl, double ratePerQtl, double freightCost) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.draw, color: Color(0xFF1B5E20), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Tripartite Supply Agreement & E-Sign',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _openContractPreview(totalQtl, ratePerQtl, freightCost),
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: const Text('Read Contract', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF1B5E20)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Color(0xFF15803D), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AgriChain Tripartite Supply Contract',
                        style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      const Text(
                        'Clauses: Certified Weighbridge Slips • 24h Factory Gate NABL Assaying • Non-Custodial Escrow Release.',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signatoryController,
            decoration: InputDecoration(
              labelText: 'Authorized Signatory Name',
              labelStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.badge_outlined, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreedToContractTerms,
                activeColor: const Color(0xFF1B5E20),
                onChanged: (val) => setState(() => _agreedToContractTerms = val ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'I confirm that I am an authorized signatory, agree to the legally binding Tripartite Agreement, computerized weighbridge reconciliation, and non-custodial escrow lock.',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openContractPreview(double totalQtl, double ratePerQtl, double freightCost) {
    final plant = _selectedPlant;
    final destFactory = plant != null ? '${plant.name} (${plant.address})' : widget.destinationFactory;

    final contract = B2bContractModel.generateDefault(
      orderId: 'PREVIEW-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      buyerId: 'buyer_institutional',
      buyerName: _signatoryController.text.isNotEmpty ? _signatoryController.text : 'Institutional Buyer Corp',
      buyerCompany: 'Institutional Agro Foods Corp',
      fpoId: widget.fpoId ?? 'fpo_karnal_01',
      fpoName: widget.fpoName ?? 'Karnal Agro Farmers Producer Co.',
      commodity: widget.commodity,
      variety: widget.variety ?? 'Milling Quality',
      qualityGrade: 'Grade A (NABL Assayed)',
      quantityQtl: totalQtl,
      pricePerQtl: ratePerQtl,
      freightAmount: freightCost,
      carrierName: _carriers[_selectedCarrierIndex]['name'],
      originLocation: widget.originCluster,
      destinationFactory: destFactory,
      isMultiFpo: widget.isMultiFpo,
      coFpos: widget.allocations,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => B2bContractScreen(contract: contract),
      ),
    );
  }

  Widget _buildEscrowActionButton(
    double total,
    double totalQtl,
    double totalMT,
    double ratePerQtl,
    double freightCost,
    double insurance,
    double fee,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (_isLockingEscrow || !_agreedToContractTerms)
            ? null
            : () => _executeB2bOrderAndEscrowLock(total, totalQtl, totalMT, ratePerQtl, freightCost, insurance, fee),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        child: _isLockingEscrow
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Executing Tripartite Contract & Locking Escrow...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Execute Contract & Lock ₹${total.toStringAsFixed(0)} Escrow',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _executeB2bOrderAndEscrowLock(
    double total,
    double totalQtl,
    double totalMT,
    double ratePerQtl,
    double freightCost,
    double insurance,
    double fee,
  ) async {
    setState(() => _isLockingEscrow = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final user = appState.currentUser;
      final buyerId = user?.id.isNotEmpty == true ? user!.id : 'buyer_institutional';
      final buyerName = user?.name.isNotEmpty == true ? user!.name : 'Institutional Buyer Corp';
      final orderId = 'PO-B2B-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      final plant = _selectedPlant;
      final destLocationStr = plant != null ? '${plant.name}, ${plant.address}' : widget.destinationFactory;
      final destLat = plant?.latitude ?? 28.8785;
      final destLng = plant?.longitude ?? 77.1275;

      final carrier = _carriers[_selectedCarrierIndex];
      final carrierName = carrier['name'].toString();
      final transitHours = carrier['transitHours'].toString();

      // 1. Generate real legal B2bContractModel
      final contract = B2bContractModel.generateDefault(
        orderId: orderId,
        buyerId: buyerId,
        buyerName: buyerName,
        buyerCompany: 'Institutional Agro Foods Corp',
        buyerSignatory: _signatoryController.text.trim().isNotEmpty ? _signatoryController.text.trim() : buyerName,
        fpoId: widget.fpoId ?? 'fpo_karnal_01',
        fpoName: widget.fpoName ?? 'Karnal Agro Farmers Producer Co.',
        commodity: widget.commodity,
        variety: widget.variety ?? 'Standard Quality',
        qualityGrade: 'Grade A (NABL Assayed)',
        quantityQtl: totalQtl,
        pricePerQtl: ratePerQtl,
        freightAmount: freightCost,
        carrierName: carrierName,
        originLocation: widget.originCluster,
        destinationFactory: destLocationStr,
        isMultiFpo: widget.isMultiFpo,
        coFpos: widget.allocations,
      );

      // 2. Prepare Order Payload for Firestore
      final paymentMethodStr = _selectedPaymentMethod == 0
          ? 'Corporate RTGS Virtual Account (${_utrController.text.trim()})'
          : (_selectedPaymentMethod == 1
              ? 'Smart Escrow Vault (${_corporateBanks[_selectedCorporateBankIndex]['name']})'
              : 'Letter of Credit (${_lcNumberController.text.trim()})');

      final orderData = <String, dynamic>{
        'id': orderId,
        'orderId': orderId,
        'contractId': contract.id,
        'contractNumber': contract.contractNumber,
        'commodity': widget.commodity,
        'crop': widget.commodity,
        'cropName': widget.commodity,
        'variety': widget.variety ?? 'Grade A',
        'totalQuantityQtl': totalQtl,
        'quantityQtl': totalQtl,
        'totalQuantityMT': totalMT,
        'quantityMT': totalMT,
        'quantity': totalMT * 1000, // in kg
        'pricePerQtl': ratePerQtl,
        'totalPrice': total,
        'totalAmount': total,
        'cropCost': totalQtl * ratePerQtl,
        'freightCost': freightCost,
        'insuranceCost': insurance,
        'protocolFee': fee,
        'carrierName': carrierName,
        'eta': 'Tomorrow, $transitHours',
        'status': 'in_transit',
        'escrowStatus': 'Funded & Protected',
        'paymentMethod': paymentMethodStr,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'buyerCompany': 'Institutional Agro Foods Corp',
        'fpoId': widget.fpoId ?? 'fpo_karnal_01',
        'sellerId': widget.fpoId ?? 'fpo_karnal_01',
        'sellerName': widget.fpoName ?? 'Karnal Agro Farmers Producer Co.',
        'fpoName': widget.fpoName ?? 'Karnal Agro Farmers Producer Co.',
        'silo': widget.originCluster,
        'warehouseName': widget.originCluster,
        'destination': destLocationStr,
        'deliveryLocation': destLocationStr,
        'destinationPlantName': plant?.name ?? 'AgroFoods Milling Terminal',
        'destinationAddress': plant?.address ?? widget.destinationFactory,
        'destinationLat': destLat,
        'destinationLng': destLng,
        'destinationCity': plant?.city ?? 'Sonipat',
        'destinationState': plant?.state ?? 'Haryana',
        'originLocation': widget.originCluster,
        'originLat': 29.6857,
        'originLng': 76.9905,
        'isMultiFpo': widget.isMultiFpo,
        'fpoAllocations': widget.allocations,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // 3. Persist atomically to Firestore & deduct FPO stock
      final success = await _dbService.createB2bOrderAndContract(
        orderData: orderData,
        contract: contract,
        inventoryItemId: widget.inventoryItemId,
        quantityToReserveMT: totalMT,
        isMultiFpo: widget.isMultiFpo,
        allocations: widget.allocations,
      );

      if (!mounted) return;
      setState(() => _isLockingEscrow = false);

      if (success) {
        // Automatically trigger Smart Contract PDF download/preview like retail!
        SmartContractPdfService.autoDownloadOrPreviewB2bContract(
          context: context,
          contract: contract,
          openDirectly: true,
        );
        _showSuccessDialog(orderId, contract, total);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to execute order. Please check network connectivity.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLockingEscrow = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error executing escrow: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(String orderId, B2bContractModel contract, double total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF15803D), size: 28),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escrow Locked & Contract Signed!',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    'Order ID: $orderId',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contract: ${contract.contractNumber}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Polygon PoS: 0x8a92b1...49f0', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text('Hash: ${contract.sha256Hash.substring(0, 24)}...', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '₹${total.toStringAsFixed(0)} is safely locked in the non-custodial Smart Escrow Vault. Warehouse dock staging has been triggered and the transporter has been dispatched.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155), height: 1.4),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              SmartContractPdfService.autoDownloadOrPreviewB2bContract(
                context: context,
                contract: contract,
                openDirectly: true,
              );
            },
            icon: const Icon(Icons.picture_as_pdf, size: 15),
            label: const Text('Download PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1B5E20),
              side: const BorderSide(color: Color(0xFF1B5E20)),
            ),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => B2bContractScreen(contract: contract)),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1B5E20),
              side: const BorderSide(color: Color(0xFF1B5E20)),
            ),
            child: const Text('View Contract'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close checkout screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BulkBuyerOrdersScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            child: const Text('Track Order & Fleet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
