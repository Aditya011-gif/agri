import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/language_switcher.dart';
import '../../utils/translation_helper.dart';
import '../../models/fpo_inventory_model.dart';
import '../../services/fpo_inventory_service.dart';
import '../../utils/crop_image_helper.dart';
import '../../widgets/fpo_lot_details_modal.dart';
import 'fpo_add_crop_screen.dart';

/// Screen 2: FPO Warehouse Crops Inventory & AI Quality Analysis
/// Simple, visual, and friendly layout inspired by the Farmer module.
class FpoInventoryScreen extends StatefulWidget {
  const FpoInventoryScreen({super.key});

  @override
  State<FpoInventoryScreen> createState() => _FpoInventoryScreenState();
}

class _FpoInventoryScreenState extends State<FpoInventoryScreen> {
  final FpoInventoryService _inventoryService = FpoInventoryService();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final fpoId = user?.id.isNotEmpty == true ? user!.id : 'fpo_karnal_01';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGreen,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CustomAppBar(
            title: context.tr('Crops & Warehouse Stock', 'फसलें और गोदाम स्टॉक'),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: LanguageSwitcherPill(isDark: true)),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                children: [
                  _buildWarehouseHeaderCard(fpoId),
                ],
              ),
            ),
          ),
        ],
        body: _buildCropsInventoryTab(fpoId),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FpoAddCropScreen()),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.tr('Add Bulk Crop Lot', 'थोक फसल लॉट जोड़ें'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Silo capacity and health overview
  Widget _buildWarehouseHeaderCard(String fpoId) {
    return StreamBuilder<List<FpoInventoryItem>>(
      stream: _inventoryService.streamFpoInventory(fpoId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final totalStockQtl = items.fold<double>(
          0.0,
          (sum, item) => sum + (item.totalQuantityMT * 10.0),
        );
        final reservedQtl = items.fold<double>(
          0.0,
          (sum, item) => sum + (item.reservedQuantityMT * 10.0),
        );
        final availableQtl = (totalStockQtl - reservedQtl).clamp(0.0, totalStockQtl);
        final capacityBase = totalStockQtl > 0 ? totalStockQtl : 5000.0;
        final utilizationPct = totalStockQtl > 0 ? ((totalStockQtl / capacityBase) * 100).round() : 0;

        final availFlex = totalStockQtl > 0 ? (availableQtl * 10).round() : 0;
        final resFlex = totalStockQtl > 0 ? (reservedQtl * 10).round() : 0;
        final freeFlex = totalStockQtl > 0 ? 100 : 1000;

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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.warehouse, color: Color(0xFF2E7D32), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Central Silo Complex', 'केंद्रीय साइलो कॉम्प्लेक्स'),
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            totalStockQtl > 0
                                ? '${totalStockQtl.toStringAsFixed(0)} Qtl ${context.tr('Active Warehouse Stock', 'सक्रिय गोदाम स्टॉक')}'
                                : context.tr('0 Qtl Deposited • Ready for Inflow', '0 क्विंटल जमा • भंडारण हेतु तैयार'),
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: totalStockQtl > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: totalStockQtl > 0 ? const Color(0xFFBBF7D0) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Text(
                      '$utilizationPct% ${context.tr('Utilized', 'प्रयुक्त')}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: totalStockQtl > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    if (availFlex > 0)
                      Expanded(
                        flex: availFlex,
                        child: Container(height: 8, color: const Color(0xFF2E7D32)),
                      ),
                    if (resFlex > 0)
                      Expanded(
                        flex: resFlex,
                        child: Container(height: 8, color: const Color(0xFFF59E0B)),
                      ),
                    Expanded(
                      flex: freeFlex > 0 ? freeFlex : 1,
                      child: Container(height: 8, color: const Color(0xFFE2E8F0)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLegendDot(
                    '${context.tr('Available', 'उपलब्ध')}: ${availableQtl.toStringAsFixed(0)} Qtl',
                    const Color(0xFF2E7D32),
                  ),
                  _buildLegendDot(
                    '${context.tr('Locked', 'आरक्षित')}: ${reservedQtl.toStringAsFixed(0)} Qtl',
                    const Color(0xFFF59E0B),
                  ),
                  _buildLegendDot(
                    totalStockQtl > 0 ? context.tr('Allocated', 'आवंटित') : context.tr('Ready for Deposits', 'जमा हेतु तैयार'),
                    const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendDot(String text, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  /// Tab 1: Warehouse Crops Cards (Matching Farmer Crop Card style with Real Photos)
  Widget _buildCropsInventoryTab(String fpoId) {
    return StreamBuilder<List<FpoInventoryItem>>(
      stream: _inventoryService.streamFpoInventory(fpoId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
        }

        final List<FpoInventoryItem> displayItems = items;

        if (displayItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warehouse_outlined,
                    size: 60,
                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('No Warehouse Crops Deposited Yet', 'अभी तक कोई गोदाम फसल जमा नहीं की गई'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'Tap "+ Add Bulk Crop Lot" below to record inventory and list lots for bulk buyers.',
                      'थोक खरीदारों के लिए इन्वेंटरी रिकॉर्ड करने और लॉट सूचीबद्ध करने के लिए नीचे "+ थोक फसल लॉट जोड़ें" पर टैप करें।',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final item = displayItems[index];
            return _buildCropInventoryCard(item);
          },
        );
      },
    );
  }

  Widget _buildCropInventoryCard(FpoInventoryItem item) {
    final isPartiallyReserved = item.reservedQuantityMT > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLotDetailsModal(item),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // 1. Photo with Badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: CropImageHelper.buildCropImage(
                  '',
                  item.cropName,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warehouse, size: 12, color: Color(0xFF69F0AE)),
                      const SizedBox(width: 4),
                      Text(
                        item.storageLocation,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPartiallyReserved
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPartiallyReserved
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFBBF7D0),
                    ),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Text(
                    isPartiallyReserved
                        ? '${(item.reservedQuantityMT * 10).toStringAsFixed(0)} Qtl Reserved'
                        : '100% Available',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isPartiallyReserved
                          ? const Color(0xFFB45309)
                          : const Color(0xFF15803D),
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
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, color: Color(0xFF69F0AE), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${item.qualityGrade} • Moisture ${item.moisturePct}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Details Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.cropName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.variety,
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
                          '₹${item.pricePerQtl.toStringAsFixed(0)} / Qtl',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        Text(
                          '₹${item.pricePerQtl.toStringAsFixed(0)} / Quintal',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tonnage Breakdown Box
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Warehouse Stock', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            '${(item.totalQuantityMT * 10).toStringAsFixed(0)} Qtl',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 26, color: Colors.grey.shade300),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Available to Sell', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            '${(item.availableQuantityMT * 10).toStringAsFixed(0)} Qtl',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 26, color: Colors.grey.shade300),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Locked Orders', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            '${(item.reservedQuantityMT * 10).toStringAsFixed(0)} Qtl',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: item.reservedQuantityMT > 0 ? const Color(0xFFD97706) : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showLotDetailsModal(item),
                    icon: const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF15803D)),
                    label: const Text(
                      'View Lot Details & Quality Passport',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                      backgroundColor: const Color(0xFFF0FDF4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
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

  void _showLotDetailsModal(FpoInventoryItem item) {
    FpoLotDetailsModal.show(
      context,
      cropName: item.cropName,
      variety: item.variety,
      siloLocation: '${item.warehouseName} • ${item.storageLocation}',
      totalMt: item.totalQuantityMT,
      availableMt: item.availableQuantityMT,
      reservedMt: item.reservedQuantityMT,
      pricePerQtl: item.pricePerQtl,
      pricePerMt: item.pricePerMT,
      qualityGrade: item.qualityGrade,
      moistureText: '${item.moisturePct}% (Optimal)',
    );
  }
}
