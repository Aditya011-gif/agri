import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/database_service.dart';
import '../../services/smart_contract_pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/crop_image_helper.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';
import 'fpo_order_shipment_screen.dart';
import '../bulk_buyer/b2b_contract_screen.dart';

/// Screen 3: FPO Bulk Orders
/// Simple 2-tab view:
/// - Tab 1: Multi-FPO Pooled Orders (Your Share vs Other FPOs' Share + Route & Details)
/// - Tab 2: Single FPO Direct Orders (Independent orders fulfilled exclusively by your FPO)
class FpoOrdersScreen extends StatefulWidget {
  const FpoOrdersScreen({super.key});

  @override
  State<FpoOrdersScreen> createState() => _FpoOrdersScreenState();
}

class _FpoOrdersScreenState extends State<FpoOrdersScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;
  bool _yourBatchDispatched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final fpoId = user?.id.isNotEmpty == true ? user!.id : 'fpo_karnal_01';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamFpoOrders(fpoId: fpoId),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? [];
        final multiOrders = orders.where((o) => o['isMultiFpo'] == true || o['isPooled'] == true).toList();
        final directOrders = orders.where((o) => o['isMultiFpo'] != true && o['isPooled'] != true).toList();

        return Scaffold(
          backgroundColor: AppTheme.backgroundGreen,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              CustomAppBar(
                title: context.tr('Bulk Buyer Orders', 'थोक खरीदार ऑर्डर'),
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
                      _buildOrdersHeaderBanner(multiCount: multiOrders.length, directCount: directOrders.length),
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
                          labelStyle: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                          tabs: [
                            Tab(
                              icon: const Icon(Icons.groups_outlined, size: 18),
                              text: '${context.tr('Multi-FPO Pooled', 'मल्टी-एफपीओ पूल्ड')} (${multiOrders.length})',
                            ),
                            Tab(
                              icon: const Icon(Icons.store_outlined, size: 18),
                              text: '${context.tr('Direct', 'प्रत्यक्ष')} (${directOrders.length})',
                            ),
                            Tab(
                              icon: const Icon(Icons.campaign_outlined, size: 18),
                              text: context.tr('Buyer Demands', 'खरीदार मांगें'),
                            ),
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
                _buildMultiFpoOrdersTab(multiOrders),
                _buildSingleFpoOrdersTab(directOrders),
                _buildBuyerDemandsTab(fpoId),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersHeaderBanner({required int multiCount, required int directCount}) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2E7D32), size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Active Commercial Orders', 'सक्रिय वाणिज्यिक ऑर्डर'),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    context.tr(
                      '$multiCount Shared Pooled • $directCount Direct Orders',
                      '$multiCount साझा पूल्ड • $directCount प्रत्यक्ष ऑर्डर',
                    ),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Text(
              context.tr('Escrow Verified', 'एस्क्रो सत्यापित'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 1: Multi-FPO Pooled Orders
  Widget _buildMultiFpoOrdersTab(List<Map<String, dynamic>> multiOrders) {
    if (multiOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  size: 56,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('No Multi-FPO Clusters Active', 'कोई मल्टी-एफपीओ क्लस्टर सक्रिय नहीं'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'There are currently no multi-FPO pooled cluster tenders. When large institutional buyers place orders pooled across multiple neighboring FPOs, they will appear here.',
                  'वर्तमान में कोई मल्टी-एफपीओ पूल्ड क्लस्टर टेंडर सक्रिय नहीं है। जब बड़े खरीदार आसपास के कई एफपीओ से संयुक्त ऑर्डर देंगे, तो वे यहां दिखाई देंगे।',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.store_outlined, size: 18),
                label: Text(context.tr('View Single FPO Direct Orders', 'प्रत्यक्ष एफपीओ ऑर्डर देखें')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info explanation card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF047857), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(
                      'Shared Bulk Order: Multiple nearby FPOs combine stock to satisfy a large institutional requirement.',
                      'साझा थोक ऑर्डर: आसपास के कई एफपीओ बड़ी संस्थागत मांग पूरी करने के लिए स्टॉक मिलाते हैं।',
                    ),
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Render pooled orders
          ...multiOrders.map((order) => _buildMultiFpoOrderCard(order)),
        ],
      ),
    );
  }

  Widget _buildMultiFpoOrderCard([Map<String, dynamic>? order]) {
    final orderId = (order?['orderId'] ?? order?['id'] ?? 'PO-ITC-3000QTL').toString();
    final crop = (order?['commodity'] ?? order?['crop'] ?? 'Sharbati Wheat').toString();
    final buyer = (order?['buyerCompany'] ?? order?['buyerName'] ?? 'ITC Agri Business Division').toString();
    final totalAmt = (order?['totalAmount'] as num?)?.toDouble() ?? 7350000.0;

    final rawAllocs = (order?['fpoAllocations'] as List<dynamic>?) ??
        (order?['contributions'] as List<dynamic>?);

    double totalQtl = 3000.0;
    if (order != null) {
      final qtl = (order['quantityQtl'] as num?)?.toDouble() ??
          (order['totalQuantityQtl'] as num?)?.toDouble() ??
          ((order['quantityMT'] as num?)?.toDouble() != null ? (order['quantityMT'] as num).toDouble() * 10 : null) ??
          ((order['totalQuantityMT'] as num?)?.toDouble() != null ? (order['totalQuantityMT'] as num).toDouble() * 10 : null);
      if (qtl != null && qtl > 0) totalQtl = qtl;
    }

    // Identify user's FPO (Karnal or first allocation)
    Map<String, dynamic>? yourAlloc;
    final List<Map<String, dynamic>> otherAllocs = [];

    if (rawAllocs != null && rawAllocs.isNotEmpty) {
      for (final a in rawAllocs) {
        final aMap = Map<String, dynamic>.from(a as Map);
        final name = (aMap['fpoName'] ?? '').toString();
        final id = (aMap['fpoId'] ?? '').toString();
        if (id.contains('karnal') || name.contains('Karnal') || yourAlloc == null) {
          if (yourAlloc == null) {
            yourAlloc = aMap;
          } else {
            otherAllocs.add(aMap);
          }
        } else {
          otherAllocs.add(aMap);
        }
      }
    }

    final yourQtyQtl = (yourAlloc?['quantityQtl'] as num?)?.toDouble() ??
        ((yourAlloc?['quantityMT'] as num?)?.toDouble() != null ? (yourAlloc!['quantityMT'] as num).toDouble() * 10 : 1200.0);
    final yourPayout = (totalAmt > 0 && totalQtl > 0) ? (totalAmt * (yourQtyQtl / totalQtl)) : 2940000.0;
    final yourPct = (totalQtl > 0) ? ((yourQtyQtl / totalQtl) * 100).round() : 40;

    double otherTotalQtyQtl = 0.0;
    double otherTotalPayout = 0.0;
    if (otherAllocs.isNotEmpty) {
      for (final o in otherAllocs) {
        final q = (o['quantityQtl'] as num?)?.toDouble() ??
            ((o['quantityMT'] as num?)?.toDouble() != null ? (o['quantityMT'] as num).toDouble() * 10 : 0.0);
        otherTotalQtyQtl += q;
      }
      otherTotalPayout = (totalAmt > 0 && totalQtl > 0) ? (totalAmt * (otherTotalQtyQtl / totalQtl)) : (totalAmt - yourPayout);
    } else {
      otherTotalQtyQtl = 1800.0;
      otherTotalPayout = 4410000.0;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image & Header Banner
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: CropImageHelper.buildCropImage(
                  '',
                  'Wheat',
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hub, size: 14, color: Color(0xFF69F0AE)),
                      const SizedBox(width: 6),
                      Text(
                        '${rawAllocs != null && rawAllocs.isNotEmpty ? rawAllocs.length : 3} FPOs Pooled Order (7 km Cluster)',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    orderId,
                    style: const TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$crop • Grade A • ${totalQtl.toStringAsFixed(0)} Qtl Pool',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Buyer info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            buyer,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Text(
                            'Delivery: Kundli Industrial Area, Sonipat • NH-44',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${totalAmt.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        Text(
                          '₹${(totalAmt / (totalQtl > 0 ? totalQtl : 1)).toStringAsFixed(0)} / Qtl',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // HIGHLIGHT: YOUR SHARE VS OTHER FPOs' SHARE
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Volume Contribution Breakdown',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${totalQtl.toStringAsFixed(0)} Qtl Total Target',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Visual Split Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: yourPct.clamp(10, 90),
                              child: Container(
                                height: 12,
                                color: const Color(0xFF1B5E20),
                              ),
                            ),
                            Expanded(
                              flex: (100 - yourPct).clamp(10, 90),
                              child: Container(
                                height: 12,
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 1. Your FPO's Share
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1B5E20),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'YOUR SHARE (${yourAlloc?['fpoName'] ?? 'Karnal FPO'})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF14532D),
                                      ),
                                    ),
                                    Text(
                                      'Silo #1 • $yourPct% of Order',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${yourQtyQtl.toStringAsFixed(0)} Qtl',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                                ),
                                Text(
                                  '₹${yourPayout.toStringAsFixed(0)} Payout',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 2. Other FPOs' Share
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'OTHER FPOs (COMBINED)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                ),
                                Text(
                                  '${otherTotalQtyQtl.toStringAsFixed(0)} Qtl • ₹${otherTotalPayout.toStringAsFixed(0)} (${100 - yourPct}%)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            if (otherAllocs.isNotEmpty) ...[
                              for (int i = 0; i < otherAllocs.length; i++) ...[
                                if (i > 0) const SizedBox(height: 4),
                                _buildFpoSubRow(
                                  otherAllocs[i]['fpoName']?.toString() ?? 'Partner FPO',
                                  '${((otherAllocs[i]['quantityQtl'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} Qtl',
                                  '₹${((otherAllocs[i]['payout'] as num?)?.toDouble() ?? (totalAmt * (((otherAllocs[i]['quantityQtl'] as num?)?.toDouble() ?? 0) / (totalQtl > 0 ? totalQtl : 1)))).toStringAsFixed(0)}',
                                  i % 2 == 0 ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                                ),
                              ],
                            ] else ...[
                              _buildFpoSubRow('Taraori Kisan Producer Co.', '1,000 Qtl (33.3%)', '₹24,50,000', const Color(0xFF0284C7)),
                              const SizedBox(height: 4),
                              _buildFpoSubRow('Gharaunda Farmers Co.', '800 Qtl (26.7%)', '₹19,60,000', const Color(0xFFD97706)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Multi-Stop Collection Route Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alt_route, color: Color(0xFF334155), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Route: Karnal (${yourQtyQtl.toStringAsFixed(0)} Qtl) → Neighboring Hubs (${otherTotalQtyQtl.toStringAsFixed(0)} Qtl) → Kundli Factory Gate',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => B2bContractScreen(orderId: orderId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.description_outlined, size: 13),
                        label: const Text('Contract', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B5E20),
                          side: const BorderSide(color: Color(0xFF1B5E20)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Download Smart Contract PDF',
                      child: InkWell(
                        onTap: () async {
                          final contract = await _dbService.getB2bContract(orderId);
                          if (!mounted) return;
                          if (contract != null) {
                            SmartContractPdfService.autoDownloadOrPreviewB2bContract(
                              context: context,
                              contract: contract,
                              openDirectly: true,
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => B2bContractScreen(orderId: orderId)),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFF15803D)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showMultiFpoRouteModal(),
                        icon: const Icon(Icons.map_outlined, size: 13),
                        label: const Text('Route', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FpoOrderShipmentScreen(
                                orderId: orderId,
                                commodity: crop,
                                buyerName: buyer,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.local_shipping, size: 14),
                        label: const Text('Live Track Fleet', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _yourBatchDispatched = !_yourBatchDispatched;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _yourBatchDispatched
                                    ? 'Your batch marked as Ready & Loaded! Weighbridge pass generated.'
                                    : 'Dispatch status reverted to Staging.',
                              ),
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          );
                        },
                        icon: Icon(_yourBatchDispatched ? Icons.check_circle : Icons.upload, size: 14),
                        label: Text(
                          _yourBatchDispatched ? 'Batch Ready ✓' : 'Dispatch Batch',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _yourBatchDispatched ? const Color(0xFF15803D) : const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
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
    );
  }

  Widget _buildFpoSubRow(String name, String weight, String payout, Color dotColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(name, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
          ],
        ),
        Text('$weight • $payout', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }

  /// Tab 2: Single FPO Direct Orders
  Widget _buildSingleFpoOrdersTab(List<Map<String, dynamic>> directOrders) {
    if (directOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 64,
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('No Direct Orders Yet', 'कोई प्रत्यक्ष ऑर्डर नहीं'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'Direct commercial purchase orders issued to your FPO by millers and institutional buyers will appear here.',
                  'मिलर्स और बड़े खरीदारों द्वारा आपकी एफपीओ को दिए गए प्रत्यक्ष खरीद ऑर्डर यहां दिखाई देंगे।',
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: directOrders.length,
      itemBuilder: (context, index) {
        final order = directOrders[index];
        return _buildDirectOrderCard(order);
      },
    );
  }

  Widget _buildDirectOrderCard(Map<String, dynamic> order) {
    final id = (order['id'] ?? order['orderId'] ?? 'PO-B2B').toString();
    final crop = (order['crop'] ?? order['cropName'] ?? 'Commodity').toString();
    final buyer = (order['buyer'] ?? order['buyerName'] ?? 'Institutional Buyer').toString();
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final qtyMT = (order['quantityMT'] as num?)?.toDouble() ??
        (((order['quantityQtl'] as num?)?.toDouble() ?? 0.0) / 10.0);
    final qtyQtl = (order['quantityQtl'] as num?)?.toDouble() ?? (qtyMT * 10.0);
    final status = (order['status'] ?? 'Active').toString();
    final silo = (order['silo'] ?? order['warehouseName'] ?? 'Central Silo').toString();
    final destination = (order['destination'] ?? order['deliveryLocation'] ?? 'Processing Terminal').toString();

    final Color statusColor = order['statusColor'] is Color
        ? order['statusColor'] as Color
        : (status.toLowerCase().contains('transit')
            ? const Color(0xFF0284C7)
            : (status.toLowerCase().contains('delivered') || status.toLowerCase().contains('settled')
                ? const Color(0xFF64748B)
                : const Color(0xFF15803D)));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront, color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      id,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF334155)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status == 'Active'
                        ? context.tr('Active', 'सक्रिय')
                        : (status.toLowerCase().contains('transit')
                            ? context.tr('In Transit', 'मार्ग में')
                            : (status.toLowerCase().contains('delivered')
                                ? context.tr('Delivered', 'वितरित')
                                : status)),
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Crop & Buyer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crop,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Text(
                        buyer,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32)),
                    ),
                    Text(
                      '${qtyQtl.toStringAsFixed(0)} ${context.tr("Qtl", "क्विंटल")}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Location Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${context.tr("Origin", "स्रोत")}: $silo • ${context.tr("Dest", "गंतव्य")}: $destination',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => B2bContractScreen(orderId: id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined, size: 14),
                    label: Text(context.tr('Contract', 'अनुबंध'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: context.tr('Download Smart Contract PDF', 'स्मार्ट अनुबंध PDF डाउनलोड करें'),
                  child: InkWell(
                    onTap: () async {
                      final contract = await _dbService.getB2bContract(id);
                      if (!mounted) return;
                      if (contract != null) {
                        SmartContractPdfService.autoDownloadOrPreviewB2bContract(
                          context: context,
                          contract: contract,
                          openDirectly: true,
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => B2bContractScreen(orderId: id)),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFF15803D)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FpoOrderShipmentScreen(
                            orderId: id,
                            commodity: crop,
                            buyerName: buyer,
                            destination: destination,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_shipping, size: 15),
                    label: Text(context.tr('Track & Gate Pass', 'ट्रैक व गेट पास'), style: const TextStyle(fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  void _showMultiFpoRouteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: controller,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Multi-FPO Inter-Hub Route',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const Text(
                    'Order: PO-ITC-3000QTL • Total 3 Stops along NH-44',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const Divider(height: 24),

                  _buildStopCard('Stop 1: Karnal Silo Complex (You)', '1,200 Qtl Wheat Loaded • Weighbridge 60T Valid', '09:00 AM', true),
                  _buildStopCard('Stop 2: Taraori Kisan Hub (FPO B)', '1,000 Qtl Staged & Ready • 7.2 km north', '10:30 AM', false),
                  _buildStopCard('Stop 3: Gharaunda Agro Co. (FPO C)', '800 Qtl Staged & Ready • 14.5 km south', '12:00 PM', false),
                  _buildStopCard('Destination: ITC Kundli Plant Gate', 'Unloading, Weighing & 24h Assaying', '03:30 PM', false),

                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FpoOrderShipmentScreen(
                            orderId: 'PO-ITC-3000QTL',
                            buyerName: 'ITC Agri Business Division',
                            commodity: '3,000 Qtl Sharbati Wheat (Milling Quality)',
                            destination: 'Kundli Food Processing Terminal, Sonipat',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation, size: 16),
                    label: const Text('Open Live Fleet GPS & Road Tracking Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close Route Inspection'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStopCard(String title, String subtitle, String time, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCurrent ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(
            isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCurrent ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? const Color(0xFF14532D) : const Color(0xFF0F172A),
                  ),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildBuyerDemandsTab(String fpoId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamBulkRfqs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }

        final rfqs = snapshot.data ?? [];

        if (rfqs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 64,
                    color: AppTheme.textSecondary.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Open Buyer Demands Right Now',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'When institutional bulk buyers post procurement tenders or RFQs, they will appear here in real time for your FPO to fulfill.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: rfqs.length,
          itemBuilder: (context, index) {
            final rfq = rfqs[index];
            return _buildBuyerDemandCard(rfq, fpoId);
          },
        );
      },
    );
  }

  Widget _buildBuyerDemandCard(Map<String, dynamic> rfq, String fpoId) {
    final buyer = rfq['buyerName'] ?? rfq['companyName'] ?? 'AgroFoods Milling India';
    final crop = rfq['commodity'] ?? 'Wheat';
    final variety = rfq['variety'] ?? 'Standard Milling';
    final grade = rfq['qualityGrade'] ?? 'Grade A';
    final qtyQtl = (rfq['quantityQtl'] as num?)?.toDouble() ??
        ((rfq['requiredQuantityQtl'] as num?)?.toDouble() ?? 50.0);
    final targetPriceQtl = (rfq['targetPricePerQtl'] as num?)?.toDouble() ??
        ((rfq['maxPricePerQtl'] as num?)?.toDouble() ?? 3200.0);
    final location = rfq['deliveryLocation'] ?? 'Karnal Central Hub';
    final rfqId = rfq['id'] ?? 'RFQ-${DateTime.now().millisecondsSinceEpoch}';
    final status = rfq['status'] ?? 'open';
    final totalAmount = qtyQtl * targetPriceQtl;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      buyer,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status == 'MATCHED_ESCROW_LOCKED'
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status == 'MATCHED_ESCROW_LOCKED' ? 'ESCROW LOCKED' : 'OPEN DEMAND',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: status == 'MATCHED_ESCROW_LOCKED'
                          ? const Color(0xFF15803D)
                          : const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$crop ($variety)',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkGreen,
                          ),
                        ),
                        Text(
                          'Target: ${qtyQtl.toStringAsFixed(0)} Qtl • $grade',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${totalAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        Text(
                          '₹${targetPriceQtl.toStringAsFixed(0)} / Qtl',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Delivery: $location',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptBuyerDemand(rfqId, fpoId, buyer, crop, qtyQtl, targetPriceQtl),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Accept Order (स्वीकारें)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCounterQuoteDialog(rfqId, fpoId, buyer, crop, targetPriceQtl),
                        icon: const Icon(Icons.edit_note, size: 16),
                        label: const Text('Quote Rate (कोट करें)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.darkGreen,
                          side: const BorderSide(color: AppTheme.primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
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
    );
  }

  Future<void> _acceptBuyerDemand(String rfqId, String fpoId, String buyer, String crop, double qtyQtl, double priceQtl) async {
    try {
      await _dbService.submitRfqQuote(rfqId, {
        'fpoId': fpoId,
        'fpoName': 'Karnal Farmers Cooperative Society',
        'status': 'ACCEPTED',
        'quotedPricePerQtl': priceQtl,
        'offeredQuantityQtl': qtyQtl,
        'acceptedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1B5E20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Buyer order for $crop ($qtyQtl Qtl) accepted! Contract generated.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCounterQuoteDialog(String rfqId, String fpoId, String buyer, String crop, double defaultPrice) {
    final priceCtrl = TextEditingController(text: defaultPrice.toStringAsFixed(0));
    final qtyCtrl = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Submit FPO Quote for $crop', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buyer: $buyer', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 14),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Your Quoted Price (₹ / Qtl)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Available Quantity to Supply (Qtl)',
                border: OutlineInputBorder(),
                suffixText: 'Qtl',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () async {
              final p = double.tryParse(priceCtrl.text) ?? defaultPrice;
              final q = double.tryParse(qtyCtrl.text) ?? 50.0;
              Navigator.pop(ctx);
              await _dbService.submitRfqQuote(rfqId, {
                'fpoId': fpoId,
                'fpoName': 'Karnal Farmers Cooperative',
                'quotedPricePerQtl': p,
                'offeredQuantityQtl': q,
                'status': 'QUOTED',
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quote submitted to buyer successfully!'),
                    backgroundColor: Color(0xFF1B5E20),
                  ),
                );
              }
            },
            child: const Text('Send Quote (भेजें)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

