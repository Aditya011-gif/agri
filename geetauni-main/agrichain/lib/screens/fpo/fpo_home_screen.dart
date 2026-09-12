import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/language_switcher.dart';
import '../../utils/crop_image_helper.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/fpo_lot_details_modal.dart';
import '../../models/fpo_inventory_model.dart';
import '../../services/fpo_inventory_service.dart';
import '../../services/database_service.dart';
import 'fpo_add_crop_screen.dart';
import 'fpo_recurring_orders_screen.dart';
import 'fpo_member_directory_screen.dart';

class FpoHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const FpoHomeScreen({super.key, this.onNavigateTab});

  @override
  State<FpoHomeScreen> createState() => _FpoHomeScreenState();
}

class _FpoHomeScreenState extends State<FpoHomeScreen> {
  final FpoInventoryService _inventoryService = FpoInventoryService();
  final DatabaseService _dbService = DatabaseService();

  void _showLotPassportModal(Map<String, dynamic> crop) {
    FpoLotDetailsModal.show(
      context,
      cropName: crop['name'] as String,
      variety: crop['variety'] as String,
      siloLocation: crop['silo'] as String,
      totalMt: (crop['totalMt'] as num?)?.toDouble() ?? 0.0,
      availableMt: (crop['availableMt'] as num?)?.toDouble() ?? 0.0,
      reservedMt: (crop['reservedMt'] as num?)?.toDouble() ?? 0.0,
      pricePerQtl: (crop['pricePerQtl'] as num?)?.toDouble() ?? 0.0,
      pricePerMt: (crop['pricePerMt'] as num?)?.toDouble() ?? 0.0,
      qualityGrade: crop['grade'] as String? ?? 'Grade A',
      moistureText: '${crop['moisture']} (Optimal)',
      imageCrop: crop['imageCrop'] as String?,
      onRunAiAssay: () {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(1); // Go to Inventory tab
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final fpoId = user?.id.isNotEmpty == true ? user!.id : 'fpo_karnal_01';
    final fpoName = (user != null && user.name.isNotEmpty && user.name != 'Demo User')
        ? user.name
        : 'Karnal Agro Producer Co.';
    final location = (user?.location != null && user!.location!.isNotEmpty)
        ? user.location!
        : 'Karnal, Haryana (NH-44)';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGreen,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CustomAppBar(
            title: context.tr('FPO Command Center', 'एफपीओ कमांड सेंटर'),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: LanguageSwitcherPill(isDark: true)),
              ),
            ],
          ),
        ],
        body: StreamBuilder<List<FpoInventoryItem>>(
          stream: _inventoryService.streamFpoInventory(fpoId),
          builder: (context, invSnapshot) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _dbService.streamFpoOrders(fpoId: fpoId.isNotEmpty ? fpoId : null),
              builder: (context, orderSnapshot) {
                final dbItems = invSnapshot.data ?? [];
                final allOrders = orderSnapshot.data ?? [];
                final fpoOrders = allOrders.where((o) {
                  final isMyFpo = (o['fpoId'] == fpoId) ||
                      (o['fpoName']?.toString().contains(fpoName) ?? false);
                  return isMyFpo || o['isMultiFpo'] == true;
                }).toList();

                final activeCrops = dbItems.map((item) => {
                  'name': item.cropName,
                  'variety': item.variety,
                  'imageCrop': item.cropName.toLowerCase(),
                  'totalQtl': item.totalQuantityQtl,
                  'availableQtl': item.availableQuantityQtl,
                  'reservedQtl': item.reservedQuantityQtl,
                  'totalMt': item.totalQuantityMT,
                  'availableMt': item.availableQuantityMT,
                  'reservedMt': item.reservedQuantityMT,
                  'pricePerQtl': item.pricePerQtl,
                  'pricePerMt': item.pricePerMT,
                  'silo': item.storageLocation,
                  'grade': item.qualityGrade,
                  'moisture': '${item.moisturePct}%',
                }).toList();

                final totalStockQtl = dbItems.fold<double>(0, (sum, i) => sum + i.totalQuantityQtl);
                final availableStockQtl = dbItems.fold<double>(0, (sum, i) => sum + i.availableQuantityQtl);

                final confirmedSales = fpoOrders.where((o) => o['status'] != 'cancelled').fold<double>(
                  0,
                  (sum, o) => sum + ((o['totalAmount'] as num?)?.toDouble() ?? 0.0),
                );
                final salesText = confirmedSales > 0
                    ? (confirmedSales >= 100000
                        ? '₹${(confirmedSales / 100000).toStringAsFixed(1)} L'
                        : '₹${confirmedSales.toStringAsFixed(0)}')
                    : '₹0';

                final hasActivePooledOrder = fpoOrders.any((o) =>
                    o['isMultiFpo'] == true &&
                    o['status'] != 'completed' &&
                    o['status'] != 'cancelled');

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    // 1. FPO Greeting & Verification Card
                    _buildFpoGreetingCard(fpoName, location),
                    const SizedBox(height: 14),

                    // 2. PRIMARY 64px CTA BUTTON: ADD BULK CROP LOT
                    _buildPrimaryAddCropButton(),
                    const SizedBox(height: 12),

                    // 2b. 12-WEEK RECURRING CONTRACTS BANNER
                    _buildRecurringContractsBanner(),
                    const SizedBox(height: 12),

                    // 2c. MEMBER FARMER DIRECTORY & EXCEL IMPORT BANNER
                    _buildMemberDirectoryBanner(),
                    const SizedBox(height: 14),

                    // 3. Simple Stats Overview (Stock in Qtl, Available, Confirmed Sales)
                    _buildStockStatsOverview(totalStockQtl, availableStockQtl, salesText),
                    const SizedBox(height: 16),

                    // 4. Multi-FPO Cluster Active Order Banner (Only if real pooled order exists!)
                    if (hasActivePooledOrder) ...[
                      _buildMultiFpoClusterBanner(),
                      const SizedBox(height: 20),
                    ],

                    // 5. Section: What's In Your Warehouse (Live Database Items!)
                    _buildWarehouseCropsSection(activeCrops),
                    const SizedBox(height: 20),

                    // 6. Recent Active Orders Strip
                    _buildRecentOrdersSection(fpoOrders),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFpoGreetingCard(String name, String location) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.12),
            child: const Icon(Icons.corporate_fare, color: Color(0xFF2E7D32), size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${context.tr('Namaste', 'नमस्ते')}, $name',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: Color(0xFF2563EB), size: 16),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.tr('SFAC & NABARD Verified Cooperative', 'SFAC और नाबार्ड सत्यापित सहकारी समिति'),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryAddCropButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FpoAddCropScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.add_business, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Add Bulk Crop Lot', 'थोक फसल लॉट जोड़ें'),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          context.tr('List warehouse silos or harvest to bulk buyers', 'थोक खरीदारों के लिए साइलो या कटाई जोड़ें'),
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecurringContractsBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FpoRecurringOrdersScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.repeat, color: Color(0xFFB45309), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            context.tr('12-Week Recurring Supply', '12-सप्ताह नियमित आपूर्ति'),
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.tr('NEW', 'नया'),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'Review incoming corporate buyer proposals & Monday dispatches',
                          'कॉर्पोरेट खरीदार प्रस्ताव व साप्ताहिक डिस्पैच देखें',
                        ),
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Color(0xFF94A3B8), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberDirectoryBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FpoMemberDirectoryScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.people_alt, color: Color(0xFF15803D), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            context.tr('Member Farmer Directory', 'सदस्य किसान प्रबंधन'),
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DBT Ready',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'Excel/CSV bulk onboarding, verified bank accounts & pro-rata DBT',
                          'एक्सेल रोस्टर आयात, सत्यापित बैंक खाते और आनुपातिक डीबीटी',
                        ),
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Color(0xFF94A3B8), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockStatsOverview(double totalStockQtl, double availableStockQtl, String confirmedSalesText) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(context.tr('Warehouse Stock', 'गोदाम स्टॉक'), '${totalStockQtl.toStringAsFixed(0)} Qtl', Icons.warehouse, const Color(0xFF2E7D32)),
          _buildStatItem(context.tr('Available to Sell', 'बिक्री योग्य'), '${availableStockQtl.toStringAsFixed(0)} Qtl', Icons.check_circle_outline, const Color(0xFF2563EB)),
          _buildStatItem(context.tr('Confirmed Sales', 'पुष्ट बिक्री'), confirmedSalesText, Icons.currency_rupee, const Color(0xFFD97706)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMultiFpoClusterBanner() {
    return InkWell(
      onTap: () {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(2); // Go to Orders tab
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
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
                color: const Color(0xFF00796B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.hub, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Multi-FPO Order Active',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '3,000 QTL POOL',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Your Share: 1,200 Qtl • Pooled with Taraori & Gharaunda FPOs',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseCropsSection(List<Map<String, dynamic>> crops) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, color: Color(0xFF2E7D32), size: 20),
                const SizedBox(width: 8),
                Text(
                  context.tr('What You Have in Stock', 'आपके गोदाम में उपलब्ध स्टॉक'),
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(1); // Go to Inventory tab
                }
              },
              child: Text(
                context.tr('View All Silos', 'सभी साइलो देखें'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (crops.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.warehouse_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 10),
                Text(context.tr('No Warehouse Crops Listed Yet', 'अभी तक कोई गोदाम फसल सूचीबद्ध नहीं'), style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(context.tr('Tap "Add Bulk Crop Lot" above to publish your first lot to the database.', 'पहला लॉट प्रकाशित करने के लिए ऊपर "थोक फसल लॉट जोड़ें" पर टैप करें।'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          )
        else
          // CROP CARDS WITH PICTURES!
          ...crops.map((crop) => _buildCropPhotoCard(crop)),
      ],
    );
  }

  Widget _buildCropPhotoCard(Map<String, dynamic> crop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLotPassportModal(crop),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Crop Picture Banner with Floating Badge
              Stack(
                children: [
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: CropImageHelper.buildCropImage(
                      null,
                      crop['imageCrop'] as String,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, color: Color(0xFF64FFDA), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            crop['grade'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        crop['silo'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, color: Color(0xFF69F0AE), size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Tap for Details',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Crop Information Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          crop['name'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '₹${(crop['pricePerQtl'] as double).toStringAsFixed(0)} / Qtl',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${crop['variety']} • Moisture: ${crop['moisture']}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),

                    // Volume Progress / Tonnage Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total In Silo', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              Text(
                                '${((crop['totalQtl'] ?? ((crop['totalMt'] as double) * 10)) as double).toStringAsFixed(0)} Qtl',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Available to Sell', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              Text(
                                '${((crop['availableQtl'] ?? ((crop['availableMt'] as double) * 10)) as double).toStringAsFixed(0)} Qtl',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Wholesale Rate', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              Text(
                                '₹${(crop['pricePerQtl'] as double).toStringAsFixed(0)} / Qtl',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Interactive Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showLotPassportModal(crop),
                            icon: const Icon(Icons.info_outline, size: 15),
                            label: const Text('Lot Passport & Specs', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (widget.onNavigateTab != null) {
                              widget.onNavigateTab!(1); // Switch to inventory/AI Assaying
                            }
                          },
                          icon: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                          label: const Text('AI Assaying', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
      ),
    );
  }

  Widget _buildRecentOrdersSection(List<Map<String, dynamic>> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, color: Color(0xFF2E7D32), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recent Institutional Orders',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            if (orders.isNotEmpty)
              TextButton(
                onPressed: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(2); // Go to Orders tab
                  }
                },
                child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 44, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text('No Institutional Orders Yet', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('When bulk buyers place orders for your lots, they will appear here.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          )
        else
          ...orders.take(3).map((order) {
            final buyerName = order['buyerName'] ?? order['buyer'] ?? 'Institutional Buyer';
            final commodity = order['commodity'] ?? order['crop'] ?? 'Commodity';
            final qtyQtl = ((order['totalQuantityQtl'] ??
                (order['totalQuantityMT'] != null ? (order['totalQuantityMT'] as num) * 10 : 0)) as num).toStringAsFixed(0);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.softShadow,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.hub, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(buyerName.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('$qtyQtl Qtl $commodity', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(2);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('View Order', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
