import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/database_service.dart';
import '../../utils/crop_image_helper.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';
import '../../services/smart_contract_pdf_service.dart';
import 'add_crop_screen.dart';

class MyCropsScreen extends StatefulWidget {
  const MyCropsScreen({super.key});

  @override
  State<MyCropsScreen> createState() => _MyCropsScreenState();
}

class _MyCropsScreenState extends State<MyCropsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final str = val.toString().trim();
    final direct = double.tryParse(str);
    if (direct != null) return direct;
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(str);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final farmerId = user?.id ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGreen,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CustomAppBar(
            title: context.tr('My Crops & Orders', 'मेरी फसलें और लिस्टिंग'),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: LanguageSwitcherPill(isDark: true)),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  _buildMyCropsHeader(),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF1B5E20),
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: const Color(0xFF1B5E20),
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      tabs: [
                        Tab(text: context.tr('Active Listings', 'सक्रिय लिस्टिंग')),
                        Tab(text: context.tr('Completed Sales', 'पूर्ण बिक्री')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildCropsStreamTab(farmerId, 'active'),
            _buildCropsStreamTab(farmerId, 'sold'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCropScreen()),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.tr('Sell Crop', 'फसल बेचें'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMyCropsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.agriculture, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Manage Your Produce Inventory', 'अपनी फसल उपज व स्टॉक प्रबंधित करें'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(
                    'Live stock is automatically synced with direct retail buyers in real time.',
                    'लाइव स्टॉक सीधे खुदरा खरीदारों के साथ रीयल-टाइम में सिंक होता है।',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropsStreamTab(String farmerId, String filterType) {
    final appState = Provider.of<AppState>(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamFarmerCrops(farmerId),
      builder: (context, snapshot) {
        final streamedCrops = snapshot.data ?? [];
        final localCrops = appState.myCrops.map((c) => c.toFirestore()).toList();
        final Set<String> seenIds = {};
        final List<Map<String, dynamic>> allCrops = [];

        for (final c in [...streamedCrops, ...localCrops]) {
          final cropFarmerId = (c['farmerId'] ?? c['userId'] ?? '').toString();
          if (!appState.isDemoAccount && cropFarmerId.isNotEmpty && cropFarmerId != farmerId) {
            continue;
          }
          final id = c['id']?.toString() ?? c['name']?.toString() ?? '';
          if (id.isEmpty || seenIds.add(id)) {
            allCrops.add(c);
          }
        }

        final filteredCrops = allCrops.where((c) {
          final qty = _toDouble(c['quantity']);
          final status = (c['status'] ?? 'active').toString().toLowerCase();
          final isActive = c['isActive'] as bool? ?? true;

          if (filterType == 'active') {
            return isActive && qty > 0 && status != 'sold' && status != 'expired';
          } else if (filterType == 'sold') {
            return qty == 0 || status == 'sold' || status == 'fulfilled';
          } else if (filterType == 'expired') {
            return !isActive || status == 'expired';
          }
          return true;
        }).toList();

        if (filteredCrops.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.grass_outlined,
                    size: 60,
                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    filterType == 'active'
                        ? context.tr('No Active Crop Listings', 'कोई सक्रिय फसल लिस्टिंग नहीं')
                        : (filterType == 'sold'
                            ? context.tr('No Sold Harvests', 'कोई बेची गई उपज नहीं')
                            : context.tr('No Expired Crops', 'कोई समाप्त फसल नहीं')),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    filterType == 'active'
                        ? context.tr(
                            'List your harvested crops to start selling to Retail Buyers & FPOs.',
                            'खुदरा खरीदारों और एफपीओ को बेचने के लिए अपनी फसल सूचीबद्ध करें।',
                          )
                        : context.tr(
                            'Your crop history for this category will appear here.',
                            'इस श्रेणी के लिए आपका फसल इतिहास यहां दिखाई देगा।',
                          ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  if (filterType == 'active') ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddCropScreen()),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(context.tr('Add First Crop', 'पहली फसल जोड़ें')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: filteredCrops.length,
          itemBuilder: (context, index) {
            final crop = filteredCrops[index];
            return _buildFarmerCropCard(crop);
          },
        );
      },
    );
  }

  // Individual Crop Card matching the retail buyer design with uploaded photo
  Widget _buildFarmerCropCard(Map<String, dynamic> crop) {
    final name = crop['name'] ?? crop['cropName'] ?? 'Crop Item';
    final variety = crop['variety'] ?? 'Grade 1';
    final totalQty = _toDouble(crop['quantity']);
    final price = _toDouble(crop['price']);
    final sellingDestination = 'Direct Retail Buyers';
    final qualityGrade = crop['qualityGrade'] ?? 'Grade A';
    final imageUrl = crop['imageUrl']?.toString() ?? crop['image']?.toString() ?? '';
    final availableQty = crop.containsKey('availableQuantity') ? _toDouble(crop['availableQuantity']) : totalQty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _showFarmerCropDetailsModal(context, crop),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Photo Banner with Floating Badges (matching retail buyer card)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: CropImageHelper.buildCropImage(
                    imageUrl,
                    name,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront, size: 12, color: Color(0xFF69F0AE)),
                            SizedBox(width: 4),
                            Text(
                              'Direct Sale',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          qualityGrade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: const Text(
                      'Active Listing',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco, color: Color(0xFF69F0AE), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Certified Organic • AI Assayed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 2. Crop Details Content Area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              variety,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${price.toStringAsFixed(0)} / kg',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          Text(
                            '${availableQty.toStringAsFixed(0)} kg available',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Destination & Available Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Selling to:', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                Text(
                                  sellingDestination,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF15803D)),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Total Harvest:', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                Text(
                                  '${totalQty.toStringAsFixed(0)} kg',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Action Buttons Row (matching retail buyer card)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showFarmerCropDetailsModal(context, crop),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: Text(
                            'View Details',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.darkGreen,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showCropOrdersModal(context, crop),
                          icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                          label: Text(
                            'Orders',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
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
  }

  void _showFarmerCropDetailsModal(BuildContext context, Map<String, dynamic> crop) {
    final name = crop['name'] ?? crop['cropName'] ?? 'Crop Details';
    final variety = crop['variety'] ?? 'Grade 1';
    final totalQty = _toDouble(crop['quantity']);
    final price = _toDouble(crop['price']);
    const sellingDestination = 'Direct Retail Buyers';
    final qualityGrade = crop['qualityGrade'] ?? 'Grade A';
    final imageUrl = crop['imageUrl']?.toString() ?? crop['image']?.toString() ?? '';
    final location = crop['location'] ?? 'Karnal Cluster, Haryana';
    final description = crop['description']?.toString() ??
        'Pure, laboratory-tested farm harvest. Certified under AgriChain digital contracts with instant farmer settlement.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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

                  // Hero Image
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CropImageHelper.buildCropImage(
                          imageUrl,
                          name,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF69F0AE)),
                              SizedBox(width: 4),
                              Text(
                                'Direct Retail Listing',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            qualityGrade,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title & Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              variety,
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${price.toStringAsFixed(0)} / kg',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                          ),
                          Text(
                            '${totalQty.toStringAsFixed(0)} kg Available',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // AI Quality Assaying Parameters
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: AppTheme.primaryGreen, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'AI Quality Assaying Parameters',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkGreen),
                            ),
                          ],
                        ),
                        const Divider(height: 16, color: Color(0xFFDCFCE7)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildAssayCol('Moisture', '11.8%', 'Optimal'),
                            _buildAssayCol('Broken Grain', '1.2%', 'Grade A'),
                            _buildAssayCol('Foreign Matter', '0.4%', 'Clean'),
                            _buildAssayCol('AI Purity', '98.6%', 'Verified'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Destination Details Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Procurement Channel:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              Text(
                                sellingDestination,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          location,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Description
                  Text(
                    'Harvest Description',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // Orders Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showCropOrdersModal(context, crop);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'View Orders for this Crop',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCropOrdersModal(BuildContext context, Map<String, dynamic> crop) {
    final cropId = crop['id']?.toString() ?? '';
    final name = crop['name'] ?? crop['cropName'] ?? 'Crop';
    final remainingStock = _toDouble(crop['availableQuantity'] ?? crop['quantity']);
    final price = _toDouble(crop['price']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_bag, color: AppTheme.primaryGreen, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Orders: $name',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                          ),
                          Text(
                            '${remainingStock.toStringAsFixed(0)} kg available • ₹${price.toStringAsFixed(0)}/kg',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _dbService.streamCropOrders(cropId: cropId, cropName: name),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
                    }
                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No Orders Received Yet',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'When retail buyers purchase this crop, order details, payment escrow, and delivery OTP will appear here in real time.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        final orderId = order['id'] ?? 'ORD-#${index + 101}';
                        final buyerName = order['buyerName'] ?? 'Retail Buyer';
                        final buyerPhone = order['buyerPhone'] ?? '+91 98765 43210';
                        final qty = _toDouble(order['quantityKg'] ?? order['quantity']);
                        final total = _toDouble(order['totalAmount'] ?? order['price']);
                        final status = (order['status'] ?? 'pending').toString();
                        final isDelivered = status.toLowerCase() == 'delivered';
                        final isInTransit = status.toLowerCase() == 'in_transit';
                        final deliveryOtp = order['deliveryOtp'] ?? '7294';

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order #$orderId',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDelivered
                                            ? const Color(0xFFDCFCE7)
                                            : (isInTransit ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isDelivered
                                            ? 'DELIVERED'
                                            : (isInTransit ? 'IN TRANSIT' : 'ACTIVE ORDER'),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDelivered
                                              ? const Color(0xFF15803D)
                                              : (isInTransit ? const Color(0xFF1D4ED8) : const Color(0xFFB45309)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          buyerName,
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '₹${total.toStringAsFixed(0)}',
                                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Purchased: ${qty.toStringAsFixed(0)} kg • Phone: $buyerPhone',
                                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    if (order['deliveryAddress'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Delivery: ${order['deliveryAddress']}',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Delivery OTP: $deliveryOtp',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: () {
                                            SmartContractPdfService.autoDownloadOrPreviewContract(
                                              context: context,
                                              order: order,
                                            );
                                          },
                                          icon: const Icon(Icons.picture_as_pdf, size: 14, color: AppTheme.primaryGreen),
                                          label: const Text('View Contract', style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
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
  }

  Widget _buildAssayCol(String label, String value, String sub) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkGreen)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        Text(sub, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
      ],
    );
  }
}
