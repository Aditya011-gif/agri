import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/b2b_contract_model.dart';
import '../../models/fpo_inventory_model.dart';
import '../../providers/app_state.dart';
import '../../services/fpo_inventory_service.dart';
import '../../services/smart_contract_pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/crop_image_helper.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/database_service.dart';

/// Screen: Dedicated Farmer FPO Consignments & Sales Dashboard (Bilingual Hindi + English)
/// Provides simple, friendly transparency for farmers depositing produce with FPOs:
/// - Inward deposit receipt, weight, and procurement rate
/// - Simple 3-step progress tracker (Godown -> Sold to Buyer -> Money in Bank)
/// - Plain-language quality checks (Moisture %, Grade A/B)
/// - Real-time pro-rata bank payout status
class FarmerFpoConsignmentDashboardScreen extends StatefulWidget {
  final bool isRootHome;
  const FarmerFpoConsignmentDashboardScreen({super.key, this.isRootHome = false});

  @override
  State<FarmerFpoConsignmentDashboardScreen> createState() =>
      _FarmerFpoConsignmentDashboardScreenState();
}

class _FarmerFpoConsignmentDashboardScreenState
    extends State<FarmerFpoConsignmentDashboardScreen> {
  final FpoInventoryService _inventoryService = FpoInventoryService();
  final DatabaseService _dbService = DatabaseService();
  String _selectedFilter = 'all'; // 'all', 'active', 'settled'
  bool _isHindi = true; // Default to Hindi for farmer friendliness

  String _t(String en, String hi) => _isHindi ? hi : en;

  Future<void> _showLogoutDialog(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              _t('Switch / Sign Out', 'अकाउंट से बाहर जाएं / रोल बदलें'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          _t(
            'Are you sure you want to log out from your FPO Member Farmer account?',
            'क्या आप अपने एफपीओ सदस्य किसान खाते से बाहर जाना चाहते हैं?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Cancel', 'रद्द करें')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('Sign Out', 'बाहर जाएं')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      await appState.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final farmerId = user?.id.isNotEmpty == true ? user!.id : 'farmer_ramesh_01';
    final farmerName = user?.name.isNotEmpty == true ? user!.name : 'Rameshwar Singh';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGreen,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CustomAppBar(
            title: widget.isRootHome
                ? _t('FPO Member Portal', 'एफपीओ किसान सेवा केंद्र')
                : _t('My FPO Consignments', 'मेरी जमा फसल व भुगतान'),
            subtitle: widget.isRootHome
                ? _t('Godown Receipts & Bank Payments', 'गोदाम रसीद व बैंक में आया पैसा')
                : _t('Direct Bank Transfer Tracking', 'सीधे बैंक खाते में भुगतान हिसाब'),
            showBackButton: !widget.isRootHome,
            actions: [
              // 1-Tap Bilingual Toggle Chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: InkWell(
                    onTap: () => setState(() => _isHindi = !_isHindi),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isHindi ? '🇮🇳 हिन्दी' : '🇬🇧 English',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: _t('Refresh', 'ताज़ा करें'),
                onPressed: () => setState(() {}),
              ),
              if (widget.isRootHome)
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  tooltip: _t('Logout', 'बाहर जाएं'),
                  onPressed: () => _showLogoutDialog(context),
                ),
            ],
          ),
        ],
        body: StreamBuilder<List<FarmerInwardConsignment>>(
          stream: _inventoryService.streamFarmerConsignments(farmerId: farmerId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
              );
            }

            final consignments = snapshot.data ?? [];
            final filteredConsignments = _applyFilter(consignments);

            // Compute summary metrics
            final totalQuantityQtl = consignments.fold<double>(
                0.0, (sum, item) => sum + item.quantityQtl);
            final totalValueRealized = consignments.fold<double>(
                0.0, (sum, item) => sum + item.totalSettlementAmount);
            final activeBatches = consignments
                .where((c) => c.status != 'settled_dbt')
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // 1. Kisan Transparency Banner
                _buildTransparencyBanner(farmerName),
                const SizedBox(height: 16),

                // 2. Summary KPI Metrics (Big Friendly Numbers)
                _buildSummaryKpiGrid(
                  totalQuantityQtl: totalQuantityQtl,
                  totalValueRealized: totalValueRealized,
                  activeBatches: activeBatches,
                  totalBatches: consignments.length,
                ),
                const SizedBox(height: 18),

                // 3. Status Filter Pills
                _buildFilterRow(consignments),
                const SizedBox(height: 16),

                // 3b. Live Institutional Buyer Demands (थोक खरीदारों की मांगें)
                _buildLiveBuyerDemandsSection(farmerId, farmerName),
                const SizedBox(height: 18),

                // 4. Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_t("Deposited Produce Receipts", "गोदाम में जमा फसल पर्चियां")} (${filteredConsignments.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _t('100% BANK DBT PROTECTED', '100% बैंक गारंटी'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. Consignments List
                if (filteredConsignments.isEmpty)
                  _buildEmptyState()
                else
                  ...filteredConsignments.map(
                    (consignment) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildConsignmentCard(consignment),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<FarmerInwardConsignment> _applyFilter(
      List<FarmerInwardConsignment> list) {
    if (_selectedFilter == 'active') {
      return list.where((c) => c.status != 'settled_dbt').toList();
    }
    if (_selectedFilter == 'settled') {
      return list.where((c) => c.status == 'settled_dbt').toList();
    }
    return list;
  }

  Widget _buildTransparencyBanner(String farmerName) {
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
            color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
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
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 28),
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
                        _t('Welcome, $farmerName', 'स्वागत है, $farmerName जी'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _t('FPO MEMBER', 'सदस्य किसान'),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    'Track every bag deposited with your FPO. Once sold in bulk, pro-rata payments are sent directly to your bank account.',
                    'गोदाम में जमा आपकी एक-एक बोरी का पूरा हिसाब। जब कंपनी को थोक माल बिकेगा, आपका पैसा सीधे आपके बैंक खाते में जमा होगा।',
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFE2E8F0),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildMemberInfoBadge(Icons.badge_outlined, _t('ID: FPO-KNL-0842', 'किसान आईडी: KNL-0842')),
                    _buildMemberInfoBadge(Icons.account_balance_outlined, _t('DBT: SBI A/c **4921', 'बैंक: SBI खाता **4921')),
                    _buildMemberInfoBadge(Icons.verified_user_outlined, _t('100% NABL Quality', '100% NABL लैब पास')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberInfoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF86EFAC)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryKpiGrid({
    required double totalQuantityQtl,
    required double totalValueRealized,
    required int activeBatches,
    required int totalBatches,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            title: _t('Total Deposited Produce', 'कुल जमा फसल'),
            value: '${totalQuantityQtl.toStringAsFixed(0)} ${_t("Qtl", "क्विंटल")}',
            subtext: '${(totalQuantityQtl / 10).toStringAsFixed(1)} ${_t("Metric Tonnes", "मीट्रिक टन")}',
            icon: Icons.grain,
            iconColor: const Color(0xFF15803D),
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCard(
            title: _t('Money Received in Bank', 'खाते में मिला कुल पैसा'),
            value: '₹${NumberFormat('#,##,###').format(totalValueRealized.toInt())}',
            subtext: '$totalBatches ${_t("Receipts Tracked", "पर्चियों का हिसाब")}',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFF0F9FF),
            borderColor: const Color(0xFFBAE6FD),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(List<FarmerInwardConsignment> allItems) {
    final activeCount = allItems.where((c) => c.status != 'settled_dbt').length;
    final settledCount = allItems.where((c) => c.status == 'settled_dbt').length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('all', '${_t("All Receipts", "सभी पर्चियां")} (${allItems.length})'),
          const SizedBox(width: 8),
          _buildFilterChip('active', '${_t("In Process", "बिक्री प्रक्रिया में")} ($activeCount)'),
          const SizedBox(width: 8),
          _buildFilterChip('settled', '${_t("Payment Done (Bank)", "खाते में पैसा आया")} ($settledCount)'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected ? AppTheme.softShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildConsignmentCard(FarmerInwardConsignment item) {
    final isSettled = item.status == 'settled_dbt';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(
          color: isSettled ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: isSettled ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Card Top Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CropImageHelper.buildCropImage(
                  null,
                  item.commodity,
                  width: 52,
                  height: 52,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.commodity} (${item.variety})',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(item.status),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_t("Receipt #", "रसीद नं.")}${item.receiptNumber} • ${item.village}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.event_available,
                              size: 13, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 4),
                          Text(
                            '${_t("Deposited on", "जमा तारीख:")} ${DateFormat('dd MMM yyyy').format(item.depositDate)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
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

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 2. Quantity & Settlement Rate Highlights
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCol(
                  _t('Quantity Deposited', 'जमा वजन'),
                  '${item.quantityQtl.toStringAsFixed(0)} ${_t("Qtl", "क्विंटल")}',
                  '${item.quantityMT.toStringAsFixed(1)} ${_t("MT", "टन")}',
                ),
                _buildMetricCol(
                  _t('Agreed Rate', 'तय भाव'),
                  '₹${item.procurementPricePerQtl.toStringAsFixed(0)} / ${_t("Qtl", "क्विंटल")}',
                  _t('Base Rate', 'बेस रेट'),
                ),
                _buildMetricCol(
                  _t('Total Payment', 'कुल भुगतान'),
                  '₹${NumberFormat('#,##,###').format(item.totalSettlementAmount.toInt())}',
                  isSettled
                      ? _t('Credited to Bank', 'खाते में क्रेडिट हुआ')
                      : _t('In Escrow Protocol', 'एस्क्रो में सुरक्षित'),
                  isHighlight: true,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 3. Simple 3-Step Kisan Lifecycle Tracker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _t('Produce Sale & Payment Steps', 'फसल बिक्री व भुगतान के 3 चरण'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    if (item.buyerName != null)
                      Text(
                        '${_t("Buyer: ", "खरीदार: ")}${item.buyerName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSimpleKisanStepper(item),
              ],
            ),
          ),

          // 4. Quality Check Passport Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildQualityPassportSnippet(item),
          ),

          // 5. Actions Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showLabPassportModal(item),
                    icon: const Icon(Icons.verified_outlined, size: 16),
                    label: Text(
                      _t('Quality Report', 'जांच रिपोर्ट (ग्रेड)'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B5E20),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openContractPdf(item),
                    icon: const Icon(Icons.description_outlined,
                        size: 16, color: Colors.white),
                    label: Text(
                      _t('Sale Agreement', 'सौदा पर्ची / एग्रीमेंट'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildMetricCol(String label, String value, String sub,
      {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? const Color(0xFF15803D)
                : const Color(0xFF0F172A),
          ),
        ),
        Text(
          sub,
          style: TextStyle(
            fontSize: 9.5,
            color: isHighlight
                ? const Color(0xFF16A34A)
                : const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'settled_dbt':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = _t('PAID IN BANK', '✅ खाते में आ गया');
        break;
      case 'in_transit':
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
        label = _t('TRUCK ON WAY', '🚚 ट्रक रवाना');
        break;
      case 'contract_executed':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = _t('SOLD TO BUYER', '🤝 कंपनी को बिका');
        break;
      case 'pooled_in_listing':
        bg = const Color(0xFFEDE9FE);
        text = const Color(0xFF6D28D9);
        label = _t('STORED IN GODOWN', '📦 गोदाम में सुरक्षित');
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        label = _t('GODOWN INTAKE', 'गोदाम में जमा');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  /// Simple 3-Step Kisan Lifecycle Stepper (Clear & Easy to Understand)
  Widget _buildSimpleKisanStepper(FarmerInwardConsignment item) {
    // Current step index (0: Godown, 1: Sold, 2: Paid in Bank)
    int currentStep = 0;
    if (item.status == 'contract_executed' || item.status == 'in_transit') {
      currentStep = 1;
    } else if (item.status == 'settled_dbt') {
      currentStep = 2;
    }

    final steps = [
      {
        'title': _t('1. Stored in Godown', '१. गोदाम में जमा'),
        'desc': _t('Weighed & Certified', 'वजन व रसीद पक्की'),
        'icon': Icons.warehouse_rounded,
      },
      {
        'title': _t('2. Sold to Company', '२. कंपनी को बिका'),
        'desc': _t('Bulk Contract Ratified', 'थोक सौदा तय हुआ'),
        'icon': Icons.handshake_rounded,
      },
      {
        'title': _t('3. Money in Bank', '३. खाते में पैसा आया'),
        'desc': item.status == 'settled_dbt'
            ? 'UTR: ${item.dbtUtrNumber ?? "SBI-9021"}'
            : _t('Pending Dispatch', 'सौदा पूरा होते ही'),
        'icon': Icons.check_circle_rounded,
      },
    ];

    return Row(
      children: List.generate(steps.length, (idx) {
        final isCompleted = idx <= currentStep;
        final isCurrent = idx == currentStep;
        final step = steps[idx];

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isCompleted
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFFE2E8F0),
                      child: Icon(
                        step['icon'] as IconData,
                        size: 16,
                        color: isCompleted ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      step['title'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                        color: isCompleted
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step['desc'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isCompleted
                            ? const Color(0xFF047857)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (idx < steps.length - 1)
                Container(
                  width: 20,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 24),
                  color: idx < currentStep
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFFE2E8F0),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildQualityPassportSnippet(FarmerInwardConsignment item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified, color: Color(0xFF15803D), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_t("Crop Quality & Grade:", "फसल जांच व ग्रेड:")} ${item.qualityGrade}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_t("Moisture:", "नमी:")} ${item.moisturePct}% (${_t("Safe / Optimal", "सुरक्षित")}) • ${_t("Foreign Matter: 0.6%", "कचरा: 0.6%")} • ${_t("Lab Cert #", "प्रमाणपत्र #")}${item.labCertificateId ?? 'NABL-LAB-8912'}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLabPassportModal(FarmerInwardConsignment item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.biotech, color: Color(0xFF15803D), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Official Quality Passport', 'आधिकारिक फसल जांच प्रमाण-पत्र'),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'NABL Accredited • Receipt #${item.receiptNumber}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _modalRow(_t('Commodity & Variety', 'फसल व किस्म'), '${item.commodity} (${item.variety})'),
                  _modalRow(_t('Certified Quality Grade', 'क्वालिटी ग्रेड'), item.qualityGrade),
                  _modalRow(_t('Grain Moisture %', 'नमी प्रतिशत'), '${item.moisturePct}% (${_t("Optimal Storage Spec", "सुरक्षित भंडारण")})'),
                  _modalRow(_t('Foreign Matter / Impurities', 'कचरा / मिट्टी'), '0.6% (${_t("Within AGMARK Grade A", "ग्रेड A मानक")})'),
                  _modalRow(_t('Weighbridge Verified Weight', 'कांटा वजन (धर्मकांटा)'), '${item.quantityQtl.toStringAsFixed(0)} ${_t("Qtl", "क्विंटल")}'),
                  _modalRow(_t('Accredited Laboratory', 'जांच प्रयोगशाला'), 'Haryana State NABL Agri Assay Centre #08'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_t('Close Quality Passport', 'बंद करें (Close)')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openContractPdf(FarmerInwardConsignment item) async {
    final contract = B2bContractModel.generateDefault(
      orderId: 'ORD-B2B-0841',
      buyerId: 'demo_buyer_001',
      buyerName: 'AgroFoods Milling India Pvt Ltd',
      buyerCompany: 'AgroFoods Milling Division',
      fpoId: 'fpo_karnal_01',
      fpoName: 'Karnal Agro Producer Co-operative Ltd',
      commodity: item.commodity,
      variety: item.variety,
      qualityGrade: item.qualityGrade,
      quantityQtl: item.quantityQtl,
      pricePerQtl: item.procurementPricePerQtl,
      freightAmount: 8500.0,
      carrierName: 'Kisan Express Fleet Logistics',
      originLocation: 'Taraori Silo Complex, Karnal',
      destinationFactory: 'Sonepat Processing Plant, Sector 38, HSIIDC',
      farmerBeneficiaries: [item.toMap()],
    );

    final pdfBytes = await SmartContractPdfService.generateB2bTripartiteContractPdf(
      contract: contract,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            '✅ Official Sale Agreement PDF Generated (${pdfBytes.length} bytes)',
            '✅ आधिकारिक बिक्री समझौता पर्ची तैयार हुई (${pdfBytes.length} bytes)',
          )),
          backgroundColor: const Color(0xFF1B5E20),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _t('No produce records found under this filter.', 'इस फ़िल्टर में कोई फसल रसीद नहीं मिली।'),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBuyerDemandsSection(String farmerId, String farmerName) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamBulkRfqs(),
      builder: (context, snapshot) {
        final rfqs = snapshot.data ?? [];
        if (rfqs.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      const Icon(Icons.campaign, color: AppTheme.primaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _t('Live Wholesale Buyer Demands', 'थोक खरीदारों की मांगें'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${rfqs.length} ${_t("Open Requests", "मांगें")}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _t(
                  'Bulk buyers want to purchase directly from farmers and FPOs. Supply your lot below:',
                  'बड़ी कंपनियाँ व मिलें सीधे किसानों से माल खरीदना चाहती हैं। अपनी फसल का लॉट जोड़ें:',
                ),
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),

              ...rfqs.take(3).map((rfq) {
                final buyer = rfq['buyerName'] ?? rfq['companyName'] ?? 'AgroFoods Milling India';
                final crop = rfq['commodity'] ?? 'Wheat';
                final qtyQtl = (rfq['quantityQtl'] as num?)?.toDouble() ??
                    ((rfq['requiredQuantityQtl'] as num?)?.toDouble() ?? 50.0);
                final priceQtl = (rfq['targetPricePerQtl'] as num?)?.toDouble() ??
                    ((rfq['maxPricePerQtl'] as num?)?.toDouble() ?? 3200.0);
                final pricePerKg = priceQtl / 100.0;
                final rfqId = rfq['id'] ?? 'RFQ-01';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        child: const Icon(Icons.store, color: AppTheme.primaryGreen, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$crop • ${qtyQtl.toStringAsFixed(0)} Qtl Demand',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '$buyer • ₹${pricePerKg.toStringAsFixed(2)}/kg (₹${priceQtl.toStringAsFixed(0)}/Qtl)',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _showParticipateSheet(rfqId, crop, pricePerKg, farmerId, farmerName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          _t('Supply Lot', 'माल दें'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showParticipateSheet(String rfqId, String crop, double pricePerKg, String farmerId, String farmerName) {
    final qtyCtrl = TextEditingController(text: '150');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('Supply $crop Lot to Buyer', '$crop का लॉट खरीदार को दें'),
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _t('Guaranteed Rate: ₹${pricePerKg.toStringAsFixed(2)}/kg', 'निश्चित दर: ₹${pricePerKg.toStringAsFixed(2)} प्रति किलो'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _t('Quantity to supply (kg)', 'देने योग्य मात्रा (किलो)'),
                border: const OutlineInputBorder(),
                suffixText: 'kg',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final qty = double.tryParse(qtyCtrl.text) ?? 150.0;
                  final total = qty * pricePerKg;
                  Navigator.pop(ctx);
                  await _dbService.submitRfqQuote(rfqId, {
                    'farmerId': farmerId,
                    'farmerName': farmerName,
                    'offeredQuantityKg': qty,
                    'offeredPricePerKg': pricePerKg,
                    'totalEarnings': total,
                    'status': 'FARMER_LOT_CONTRIBUTED',
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1B5E20),
                        content: Text(_t(
                          'Committed $qty kg of $crop! Total: ₹${total.toStringAsFixed(0)}',
                          '$crop का $qty किलो लॉट सफलतापूर्वक स्वीकृत! कुल: ₹${total.toStringAsFixed(0)}',
                        )),
                      ),
                    );
                  }
                },
                child: Text(
                  _t('Confirm Lot Supply', 'लॉट की पुष्टि करें'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

