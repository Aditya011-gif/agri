import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/fpo_inventory_model.dart';
import '../../models/crop_benchmark_model.dart';
import '../../services/fpo_inventory_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

/// Screen: Publish Commercial Bulk Crop Listing
/// Tailored specifically for FPO B2B wholesale warehouse inventory with
/// mandatory NABL / AGMARK quality certification and verified member sourcing manifest.
class FpoAddCropScreen extends StatefulWidget {
  const FpoAddCropScreen({super.key});

  @override
  State<FpoAddCropScreen> createState() => _FpoAddCropScreenState();
}

class _FpoAddCropScreenState extends State<FpoAddCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final FpoInventoryService _inventoryService = FpoInventoryService();

  // Form Controllers
  final _commodityController = TextEditingController(text: 'Sharbati Wheat');
  final _varietyController = TextEditingController(text: 'Sharbati 306 (Milling Grade)');
  final _quantityController = TextEditingController(text: '1200'); // 1,200 Qtl
  final _moqController = TextEditingController(text: '250'); // 250 Qtl (1 FTL standard)
  final _pricePerQtlController = TextEditingController(text: '3560'); // ₹3,560 / Qtl
  final _moistureController = TextEditingController(text: '11.2');
  final _storageLocationController = TextEditingController(text: 'Silo Bay 04 (Aerated)');

  // Selected crop preset for quick fill
  String _selectedPreset = 'Sharbati Wheat';

  // Sample photo state
  XFile? _imageFile;

  // Mandatory Quality Certification state (Replacing AI camera assay)
  XFile? _qualityCertificateFile;
  Uint8List? _qualityCertificateBytes;
  String _certificateType = 'NABL Lab Analysis Report';
  final List<String> _certificateTypes = [
    'NABL Lab Analysis Report',
    'AGMARK Grade Certificate',
    'Mandi Weighbridge & Assay Slip',
    'FSSAI Compliance Certificate',
  ];

  String _selectedGrade = 'Grade A (Milling Grade)';
  String _selectedWarehouse = 'Central Silo Depot 01, Karnal Hub';
  int _dispatchLeadTimeDays = 2;
  bool _isMultiFpoEligible = true;
  bool _isSubmitting = false;

  // Mandatory Inward Manifest: Verified Constituent Farmers
  final List<FarmerInwardConsignment> _farmerContributions = [];

  @override
  void initState() {
    super.initState();
    _populateDefaultFarmerContributions();
  }

  void _populateDefaultFarmerContributions([double? targetTotalQtl]) {
    final now = DateTime.now();
    final total = targetTotalQtl ?? (double.tryParse(_quantityController.text.trim()) ?? 1200.0);
    final crop = _commodityController.text.trim();
    final variety = _varietyController.text.trim();
    final price = double.tryParse(_pricePerQtlController.text.trim()) ?? 3560.0;
    final moisture = double.tryParse(_moistureController.text.trim()) ?? 11.2;

    _farmerContributions.clear();
    final share1 = (total * 0.375).roundToDouble(); // 450 Qtl
    final share2 = (total * 0.333).roundToDouble(); // 400 Qtl
    final share3 = (total - share1 - share2).clamp(0.0, total); // 350 Qtl

    _farmerContributions.addAll([
      FarmerInwardConsignment(
        farmerId: 'farmer_sukhwinder_02',
        farmerName: 'Sukhwinder Sandhu',
        farmerPhone: '+91 98451 22310',
        village: 'Nilokheri, Karnal',
        commodity: crop,
        variety: variety,
        quantityQtl: share1,
        procurementPricePerQtl: price,
        depositDate: now.subtract(const Duration(days: 3)),
        moisturePct: moisture,
        qualityGrade: _selectedGrade,
        receiptNumber: 'INW-${now.year}-0412',
        status: 'pooled_in_listing',
      ),
      FarmerInwardConsignment(
        farmerId: 'farmer_ramesh_01',
        farmerName: 'Rameshwar Singh',
        farmerPhone: '+91 98123 45678',
        village: 'Taraori, Karnal',
        commodity: crop,
        variety: variety,
        quantityQtl: share2,
        procurementPricePerQtl: price,
        depositDate: now.subtract(const Duration(days: 2)),
        moisturePct: moisture,
        qualityGrade: _selectedGrade,
        receiptNumber: 'INW-${now.year}-0418',
        status: 'pooled_in_listing',
      ),
      FarmerInwardConsignment(
        farmerId: 'farmer_baldev_03',
        farmerName: 'Baldev Raj Chaudhary',
        farmerPhone: '+91 94160 88291',
        village: 'Gharaunda, Karnal',
        commodity: crop,
        variety: variety,
        quantityQtl: share3,
        procurementPricePerQtl: price,
        depositDate: now.subtract(const Duration(days: 1)),
        moisturePct: moisture,
        qualityGrade: _selectedGrade,
        receiptNumber: 'INW-${now.year}-0425',
        status: 'pooled_in_listing',
      ),
    ]);
  }

  final List<String> _gradeOptions = [
    'Grade A (Milling Grade)',
    'Super Fine Export Grade',
    'Industrial Grade 1',
    'FAQ Standard Grade',
  ];

  final List<String> _warehouseOptions = [
    'Central Silo Depot 01, Karnal Hub',
    'Grain Warehouse Unit 02, Panipat',
    'Cold Storage Facility Bay A, Sonipat',
    'Depot Silo Complex, Kurukshetra',
  ];

  // Crop presets with typical MSP, market rate, and variety
  final Map<String, Map<String, dynamic>> _cropPresets = {
    'Wheat': {
      'name': 'Sharbati Wheat',
      'variety': 'Sharbati 306 (Milling Grade)',
      'grade': 'Grade A (Milling Grade)',
      'moisture': '11.2',
      'priceQtl': '3560',
      'mspQtl': 2275,
      'mandiQtl': 3560,
      'silo': 'Silo Bay 04 (Aerated)',
      'imageCrop': 'wheat',
    },
    'Basmati Rice': {
      'name': 'Basmati 1121 Paddy',
      'variety': 'Pusa 1121 (Aromatic Export)',
      'grade': 'Super Fine Export Grade',
      'moisture': '11.0',
      'priceQtl': '4620',
      'mspQtl': 2320,
      'mandiQtl': 4620,
      'silo': 'Covered Concrete Dock B',
      'imageCrop': 'basmati rice',
    },
    'Mustard': {
      'name': 'Black Mustard (RH-749)',
      'variety': 'RH 749 (High Oil Content)',
      'grade': 'Grade A (Milling Grade)',
      'moisture': '8.8',
      'priceQtl': '5850',
      'mspQtl': 5650,
      'mandiQtl': 5850,
      'silo': 'Ventilated Bagged Bay C',
      'imageCrop': 'mustard',
    },
    'Maize': {
      'name': 'Yellow Maize (Corn)',
      'variety': 'DKC 9108 (Starch Rich)',
      'grade': 'Industrial Grade 1',
      'moisture': '12.5',
      'priceQtl': '2480',
      'mspQtl': 2090,
      'mandiQtl': 2480,
      'silo': 'Dry Storage Bay 01',
      'imageCrop': 'corn',
    },
    'Soybean': {
      'name': 'Yellow Soybean',
      'variety': 'JS 335 (High Protein)',
      'grade': 'Grade A (Milling Grade)',
      'moisture': '10.5',
      'priceQtl': '4700',
      'mspQtl': 4892,
      'mandiQtl': 4700,
      'silo': 'Aerated Bin 03',
      'imageCrop': 'soybean',
    },
  };

  @override
  void dispose() {
    _commodityController.dispose();
    _varietyController.dispose();
    _quantityController.dispose();
    _moqController.dispose();
    _pricePerQtlController.dispose();
    _moistureController.dispose();
    _storageLocationController.dispose();
    super.dispose();
  }



  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;

    // Mandatory Quality Certificate Validation for FPO listings
    if (_qualityCertificateFile == null && _qualityCertificateBytes == null) {
      _showMandatoryErrorDialog(
        title: 'Quality Certificate Required (प्रमाण-पत्र अनिवार्य)',
        message:
            'Under FPO commercial wholesale compliance, every bulk lot requires an uploaded quality certificate (NABL Lab Test / AGMARK / Weighbridge Slip).\n\nकृपया ऊपर दिए गए बॉक्स से गुणवत्ता प्रमाण-पत्र (PDF या फोटो) अवश्य अपलोड करें।',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final user = appState.currentUser;
      final fpoId = user?.id.isNotEmpty == true ? user!.id : 'fpo_karnal_01';
      final fpoName = user?.name.isNotEmpty == true ? user!.name : 'Karnal Agro Producer Co. Ltd.';

      final qtyQtl = double.tryParse(_quantityController.text.trim()) ?? 1000.0;
      final moqQtl = double.tryParse(_moqController.text.trim()) ?? 250.0;
      final priceQtl = double.tryParse(_pricePerQtlController.text.trim()) ?? 3560.0;
      final qtyMT = qtyQtl / 10.0;
      final moqMT = moqQtl / 10.0;
      final priceMT = priceQtl * 10.0;
      final moisture = double.tryParse(_moistureController.text.trim()) ?? 11.2;

      // Mandatory Inward Manifest Validation
      final totalAllocatedQtl = _farmerContributions.fold<double>(0.0, (sum, f) => sum + f.quantityQtl);
      final allocationDiff = (qtyQtl - totalAllocatedQtl).abs();

      if (_farmerContributions.isEmpty) {
        setState(() => _isSubmitting = false);
        _showMandatoryErrorDialog(
          title: 'Mandatory Farmer Sourcing Manifest Required',
          message:
              'Under AgriChain and FPO regulatory compliance, every commercial bulk lot must specify the verified member farmers who supplied this grain.\n\nPlease enter constituent farmer deposit records in the manifest below.',
        );
        return;
      }

      if (allocationDiff > 0.5) {
        setState(() => _isSubmitting = false);
        _showMandatoryErrorDialog(
          title: 'Farmer Sourcing Allocation Mismatch',
          message:
              'Total Lot Quantity: ${qtyQtl.toStringAsFixed(0)} Qtl\n'
              'Allocated to Farmers: ${totalAllocatedQtl.toStringAsFixed(0)} Qtl\n'
              'Variance: ${allocationDiff.toStringAsFixed(0)} Qtl\n\n'
              '100% of this bulk lot must be attributed to constituent farmers for transparent smart contract escrow settlement. Please balance the manifest or click "Auto-Balance to Match".',
        );
        return;
      }

      final now = DateTime.now();
      final itemId = 'INV-${now.millisecondsSinceEpoch.toString().substring(7)}';
      final listingId = 'LIST-${now.millisecondsSinceEpoch.toString().substring(7)}';

      final imgPath = _imageFile?.path;

      // 1. Create warehouse inventory record
      final inventoryItem = FpoInventoryItem(
        id: itemId,
        fpoId: fpoId,
        fpoName: fpoName,
        cropName: _commodityController.text.trim(),
        variety: _varietyController.text.trim(),
        totalQuantityMT: qtyMT,
        reservedQuantityMT: 0.0,
        soldQuantityMT: 0.0,
        unit: 'Qtl',
        qualityGrade: _selectedGrade,
        moisturePct: moisture,
        warehouseId: 'WH-01',
        warehouseName: _selectedWarehouse,
        storageLocation: _storageLocationController.text.trim(),
        pricePerMT: priceMT,
        pricePerQtl: priceQtl,
        inventoryStatus: InventoryStatus.available,
        listingStatus: ListingStatus.published,
        activeListingId: listingId,
        imageUrl: imgPath,
        createdAt: now,
        updatedAt: now,
      );

      // 2. Create B2B commercial listing with full constituent farmer attribution
      final listing = BulkCropListing(
        id: listingId,
        inventoryItemId: itemId,
        fpoId: fpoId,
        fpoName: fpoName,
        cropName: _commodityController.text.trim(),
        variety: _varietyController.text.trim(),
        listedQuantityMT: qtyMT,
        minimumOrderQuantityMT: moqMT,
        pricePerMT: priceMT,
        pricePerQtl: priceQtl,
        qualityGrade: _selectedGrade,
        moisturePct: moisture,
        warehouseName: _selectedWarehouse,
        warehouseLat: 29.6857,
        warehouseLng: 76.9905,
        dispatchLeadTimeDays: _dispatchLeadTimeDays,
        isMultiFpoEligible: _isMultiFpoEligible,
        status: ListingStatus.published,
        imageUrl: imgPath,
        farmerContributions: List.from(_farmerContributions),
        publishedAt: now,
        updatedAt: now,
      );

      await _inventoryService.createInventoryItem(inventoryItem);
      final success = await _inventoryService.publishBulkListing(listing);

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF69F0AE), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Published ${qtyQtl.toStringAsFixed(0)} Qtl of ${_commodityController.text} to B2B Institutional Market!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1B5E20),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error publishing listing.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final qtyQtl = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final priceQtl = double.tryParse(_pricePerQtlController.text.trim()) ?? 0.0;
    final totalValuation = qtyQtl * priceQtl;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGreen,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          const CustomAppBar(
            title: 'Publish Bulk Listing',
          ),
        ],
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // 1. Direct B2B Commercial Explainer Banner
              _buildExplainerBanner(),
              const SizedBox(height: 14),

              // 2. Searchable Multi-Crop Selector with Search Bar
              _buildSearchableCropSelector(),
              const SizedBox(height: 14),

              // 3. Mandatory Quality & Lab Certification Card (Replacing AI photo scan)
              _buildMandatoryQualityCertificateCard(),
              const SizedBox(height: 14),

              // 4. Market Pricing Intelligence & MSP Benchmark
              _buildMarketPricingCard(totalValuation),
              const SizedBox(height: 14),

              // 5. Commodity Specifications Card
              _buildCommoditySpecsCard(),
              const SizedBox(height: 14),

              // 6. Volume & Wholesale Pricing Card (FPO Tonnage & MOQ)
              _buildVolumeAndPricingCard(totalValuation),
              const SizedBox(height: 14),

              // 7. Warehouse & Fulfillment Terms Card
              _buildWarehouseAndLogisticsCard(),
              const SizedBox(height: 14),

              // 8. Mandatory Farmer Sourcing & Inward Manifest Card
              _buildFarmerInwardManifestCard(qtyQtl),
              const SizedBox(height: 24),

              // 9. Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplainerBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.storefront, color: Color(0xFF15803D), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Direct B2B Commercial Listing: Published lots are accessible by verified institutional bulk buyers across India with escrow protection.',
              style: TextStyle(fontSize: 12, color: Color(0xFF14532D), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchableCropSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Commodity (फसल चुनें)',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${CropBenchmark.catalog.length}+ Commodities',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openCropSearchModal(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1B5E20), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF1B5E20), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _commodityController.text.isNotEmpty ? _commodityController.text : 'Search & select crop...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _varietyController.text.isNotEmpty ? 'Variety: ${_varietyController.text}' : 'Tap to search from all agricultural commodities',
                          style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF1B5E20), size: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCropSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allCrops = CropBenchmark.catalog;
            final filtered = allCrops.where((c) {
              final q = searchQuery.toLowerCase().trim();
              if (q.isEmpty) return true;
              return c.name.toLowerCase().contains(q) ||
                  c.hindiName.toLowerCase().contains(q) ||
                  c.category.toLowerCase().contains(q) ||
                  c.defaultVariety.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Crop from Catalog',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search crop (e.g. Wheat, Tomato, सरसों, मक्का)...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5E20)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        setModalState(() => searchQuery = val);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final crop = filtered[idx];
                        final isCurrent = _commodityController.text.toLowerCase().contains(crop.name.toLowerCase().split(' ').first);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                            child: const Icon(Icons.eco, color: Color(0xFF1B5E20), size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(crop.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 6),
                              Text('(${crop.hindiName})', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                          subtitle: Text(
                            '${crop.category} • MSP: ₹${crop.mspPerQtl.toInt()}/Qtl • Modal Avg: ₹${crop.mandiAvgPrice.toInt()}/Qtl',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          trailing: isCurrent ? const Icon(Icons.check_circle, color: Color(0xFF1B5E20), size: 20) : null,
                          onTap: () {
                            setState(() {
                              _selectedPreset = crop.name;
                              _commodityController.text = crop.name;
                              _varietyController.text = crop.defaultVariety;
                              _pricePerQtlController.text = crop.mandiAvgPrice.toInt().toString();
                              _moistureController.text = crop.standardMoisture.replaceAll(RegExp(r'[^0-9.]'), '');
                              _populateDefaultFarmerContributions();
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMandatoryQualityCertificateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(
          color: (_qualityCertificateFile != null || _qualityCertificateBytes != null)
              ? const Color(0xFF1B5E20)
              : const Color(0xFFE2E8F0),
          width: (_qualityCertificateFile != null || _qualityCertificateBytes != null) ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Color(0xFF1B5E20), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Quality Certification (अनिवार्य प्रमाण-पत्र)',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'MANDATORY',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'FPOs must attach an accredited testing report (NABL Lab, AGMARK grade certificate, or Mandi weighbridge slip) to ratify lot purity and moisture.',
            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600, height: 1.35),
          ),
          const SizedBox(height: 12),

          // Certificate Type Selector
          DropdownButtonFormField<String>(
            initialValue: _certificateType,
            decoration: InputDecoration(
              labelText: 'Certificate Authority Type',
              labelStyle: GoogleFonts.inter(fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF1B5E20), size: 18),
            ),
            items: _certificateTypes.map((t) {
              return DropdownMenuItem<String>(
                value: t,
                child: Text(t, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _certificateType = val);
            },
          ),
          const SizedBox(height: 12),

          // Upload or Display Box
          if (_qualityCertificateFile != null || _qualityCertificateBytes != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15803D),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _qualityCertificateFile?.name ?? 'Quality_Certificate_Document.pdf',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF14532D)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verified: $_certificateType (Ready for Escrow)',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF166534), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    tooltip: 'Remove Certificate',
                    onPressed: () {
                      setState(() {
                        _qualityCertificateFile = null;
                        _qualityCertificateBytes = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            InkWell(
              onTap: _pickCertificate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.upload_file, color: Color(0xFF15803D), size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Upload Quality Certificate / Lab Report',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF, JPG or PNG (NABL Test, AGMARK, or Weighbridge)',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickCertificate() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _qualityCertificateFile = picked;
          _qualityCertificateBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Certificate picker error: $e');
    }
  }

  Widget _buildMarketPricingCard(double totalValuation) {
    final preset = _cropPresets[_selectedPreset];
    final msp = preset?['mspQtl'] ?? 2275;
    final mandi = preset?['mandiQtl'] ?? 3560;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Wholesale Pricing Benchmark (Haryana)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Live Mandi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Govt MSP Benchmark', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  Text('₹$msp / qtl', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Mandi Wholesale Spot', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  Text('₹$mandi / qtl', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total Lot Valuation', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  Text(
                    '₹${(totalValuation / 100000).toStringAsFixed(2)} L',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommoditySpecsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grain, color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 8),
              Text(
                'Commodity Specifications',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const Divider(height: 20),
          TextFormField(
            controller: _commodityController,
            decoration: InputDecoration(
              labelText: 'Commodity Name *',
              hintText: 'e.g. Sharbati Wheat, Basmati Paddy',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _varietyController,
            decoration: InputDecoration(
              labelText: 'Variety / Specification *',
              hintText: 'e.g. Sharbati 306, Pusa 1121',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedGrade,
            decoration: InputDecoration(
              labelText: 'Quality Grade Standard *',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            items: _gradeOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _selectedGrade = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _moistureController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Certified Moisture Level (%) *',
              suffixText: '%',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeAndPricingCard(double totalValuation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.scale, color: Color(0xFF2E7D32), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Volume & Wholesale Pricing',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₹${(totalValuation / 100000).toStringAsFixed(2)} L Lot Value',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Total Quantity (Qtl) *',
                    suffixText: 'Qtl',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _moqController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Min Order Qty (MOQ) *',
                    suffixText: 'Qtl',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pricePerQtlController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Wholesale Rate per Quintal (₹/Qtl) *',
              prefixText: '₹ ',
              helperText: 'Standard mandi wholesale rate (1 Quintal = 100 kg)',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseAndLogisticsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warehouse, color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 8),
              Text(
                'Warehouse & Fulfillment Terms',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const Divider(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedWarehouse,
            decoration: InputDecoration(
              labelText: 'Origin Warehouse Silo *',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            items: _warehouseOptions.map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _selectedWarehouse = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _storageLocationController,
            decoration: InputDecoration(
              labelText: 'Storage Location / Bay *',
              hintText: 'e.g. Silo Bay 04 (Aerated)',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dispatch Lead Time:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              DropdownButton<int>(
                value: _dispatchLeadTimeDays,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 Day (Immediate)')),
                  DropdownMenuItem(value: 2, child: Text('2 Days (Standard)')),
                  DropdownMenuItem(value: 4, child: Text('4 Days (Custom Call)')),
                ],
                onChanged: (v) => setState(() => _dispatchLeadTimeDays = v!),
              ),
            ],
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('7 km Multi-FPO Pooling Eligible', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: const Text('Permit neighboring FPOs to aggregate inventory with this lot for large institutional demand', style: TextStyle(fontSize: 11)),
            activeThumbColor: const Color(0xFF2E7D32),
            value: _isMultiFpoEligible,
            onChanged: (v) => setState(() => _isMultiFpoEligible = v),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerInwardManifestCard(double declaredQtyQtl) {
    final totalAllocatedQtl = _farmerContributions.fold<double>(0.0, (sum, f) => sum + f.quantityQtl);
    final diff = declaredQtyQtl - totalAllocatedQtl;
    final isBalanced = diff.abs() <= 0.5 && declaredQtyQtl > 0;
    final isUnder = diff > 0.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(
          color: isBalanced
              ? const Color(0xFF2E7D32).withValues(alpha: 0.5)
              : (isUnder ? const Color(0xFFE53935).withValues(alpha: 0.5) : const Color(0xFFF59E0B)),
          width: isBalanced ? 1.5 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.diversity_3_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Farmer Inward Manifest',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Mandatory Provenance & Smart Contract DBT Attribution',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isBalanced
                      ? const Color(0xFFDCFCE7)
                      : (isUnder ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isBalanced
                        ? const Color(0xFF16A34A)
                        : (isUnder ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                  ),
                ),
                child: Text(
                  isBalanced ? 'MANDATORY: 100% BALANCED' : (isUnder ? 'SHORTAGE' : 'OVER-ALLOCATED'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isBalanced
                        ? const Color(0xFF15803D)
                        : (isUnder ? const Color(0xFFB91C1C) : const Color(0xFFB45309)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.gavel_outlined, color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Indian Agricultural Trade Norm: Every quintal listed must declare who harvested it, date received at godown, and agreed base payout.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tally Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isBalanced
                    ? [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)]
                    : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isBalanced ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Declared Lot Size', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    const SizedBox(height: 2),
                    Text(
                      '${declaredQtyQtl.toStringAsFixed(0)} Qtl',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Container(width: 1, height: 26, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Text('Farmer Deposits', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    const SizedBox(height: 2),
                    Text(
                      '${totalAllocatedQtl.toStringAsFixed(0)} Qtl',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isBalanced ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 26, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Text('Variance', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    const SizedBox(height: 2),
                    Text(
                      isBalanced
                          ? '0 Qtl'
                          : (isUnder ? '-${diff.toStringAsFixed(0)} Qtl' : '+${(-diff).toStringAsFixed(0)} Qtl'),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isBalanced ? const Color(0xFF15803D) : (isUnder ? Colors.red : Colors.orange),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Farmer list
          Text(
            'Verified Constituent Farmers (${_farmerContributions.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),

          if (_farmerContributions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.person_off_outlined, color: Colors.grey, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'No member farmers attributed yet.\nClick below to add deposits or auto-balance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _farmerContributions.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final f = _farmerContributions[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                        child: Text(
                          f.farmerName.isNotEmpty ? f.farmerName.substring(0, 1).toUpperCase() : 'K',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    f.farmerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${f.quantityQtl.toStringAsFixed(0)} Qtl (${f.quantityMT.toStringAsFixed(1)} MT)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${f.village} • ${f.farmerPhone}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                Text(
                                  'Inward: ${DateFormat('dd MMM yyyy').format(f.depositDate)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Rate: ₹${f.procurementPricePerQtl.toStringAsFixed(0)}/Qtl',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                ),
                                Text(
                                  'Receipt: ${f.receiptNumber}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                        onPressed: () {
                          setState(() {
                            _farmerContributions.removeAt(i);
                          });
                        },
                        tooltip: 'Remove farmer deposit',
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddFarmerDialog(declaredQtyQtl),
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('+ Add Farmer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1B5E20),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _populateDefaultFarmerContributions(declaredQtyQtl);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Auto-balanced member farmer contributions to match declared lot!'),
                        backgroundColor: Color(0xFF1B5E20),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.balance, size: 16, color: Colors.white),
                  label: const Text('Auto-Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddFarmerDialog(double declaredQtyQtl) {
    final nameCtrl = TextEditingController(text: 'Dharampal Verma');
    final phoneCtrl = TextEditingController(text: '+91 94165 99312');
    final villageCtrl = TextEditingController(text: 'Kachhwa, Karnal');
    final qtyCtrl = TextEditingController(text: '200');
    final rateCtrl = TextEditingController(text: _pricePerQtlController.text.trim());
    DateTime selectedDate = DateTime.now().subtract(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add, color: Color(0xFF15803D), size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Add Farmer Consignment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Farmer Full Name *', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Mobile / Kisan ID *', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: villageCtrl,
                  decoration: const InputDecoration(labelText: 'Village / Tehsil *', isDense: true),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity (Qtl) *', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: rateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Procurement Rate (₹/Qtl) *', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF2E7D32)),
                  title: Text('Inward Deposit Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}'),
                  trailing: const Text('Change', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 90)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                final rate = double.tryParse(rateCtrl.text.trim()) ?? 3500.0;
                if (nameCtrl.text.trim().isEmpty || qty <= 0) {
                  return;
                }
                final now = DateTime.now();
                final receiptNo = 'INW-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}';
                setState(() {
                  _farmerContributions.add(
                    FarmerInwardConsignment(
                      farmerId: 'farmer_${nameCtrl.text.trim().toLowerCase().replaceAll(' ', '_')}',
                      farmerName: nameCtrl.text.trim(),
                      farmerPhone: phoneCtrl.text.trim(),
                      village: villageCtrl.text.trim(),
                      commodity: _commodityController.text.trim(),
                      variety: _varietyController.text.trim(),
                      quantityQtl: qty,
                      procurementPricePerQtl: rate,
                      depositDate: selectedDate,
                      moisturePct: double.tryParse(_moistureController.text.trim()) ?? 11.2,
                      qualityGrade: _selectedGrade,
                      receiptNumber: receiptNo,
                      status: 'pooled_in_listing',
                    ),
                  );
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Consignment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMandatoryErrorDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            child: const Text('Understood & Balance Manifest'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSubmitting ? null : _submitListing,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Publish Bulk Listing to B2B Market',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
