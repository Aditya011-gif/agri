import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/smart_contract_pdf_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/language_switcher.dart';
import '../../utils/translation_helper.dart';
import '../fpo/fpo_order_shipment_screen.dart';
import 'b2b_contract_screen.dart';
import '../retail_buyer/rating_screen.dart';
import '../../models/firestore_models.dart';

class BulkBuyerOrdersScreen extends StatefulWidget {
  const BulkBuyerOrdersScreen({super.key});

  @override
  State<BulkBuyerOrdersScreen> createState() => _BulkBuyerOrdersScreenState();
}

class _BulkBuyerOrdersScreenState extends State<BulkBuyerOrdersScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;

  final List<String> _tabs = [
    'Active',
    'In Transit',
    'Inspection',
    'Completed',
    'Disputed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CustomAppBar(
            title: context.tr('Procurement Orders', 'थोक खरीद ऑर्डर'),
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
                  _buildOrdersOverviewBanner(),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primaryColor,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: [
                        Tab(text: context.tr('Active', 'सक्रिय')),
                        Tab(text: context.tr('In Transit', 'मार्ग में')),
                        Tab(text: context.tr('Inspection', 'निरीक्षण')),
                        Tab(text: context.tr('Completed', 'पूर्ण')),
                        Tab(text: context.tr('Disputed', 'विवादित')),
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
            _buildOrdersList(statusFilter: 'all_active'),
            _buildOrdersList(statusFilter: 'in_transit'),
            _buildOrdersList(statusFilter: 'inspection'),
            _buildOrdersList(statusFilter: 'completed'),
            _buildOrdersList(statusFilter: 'disputed'),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersOverviewBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('100% Escrow & Quality Gate', '100% एस्क्रो व गुणवत्ता सुरक्षा'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr(
                    'Funds are held safely in escrow until you inspect and approve the grain lot at destination.',
                    'गंतव्य पर अनाज लॉट का निरीक्षण व सत्यापन होने तक भुगतान एस्क्रो में सुरक्षित रहता है।',
                  ),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList({required String statusFilter}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamFpoOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allOrders = snapshot.data ?? [];
        final orders = allOrders.where((o) {
          final status = (o['status'] ?? 'active').toString().toLowerCase();
          if (statusFilter == 'all_active') {
            return status != 'completed' && status != 'cancelled';
          }
          if (statusFilter == 'in_transit') {
            return status == 'in_transit' || status == 'shipped';
          }
          if (statusFilter == 'inspection') {
            return status == 'inspection' || status == 'pending_lab';
          }
          if (statusFilter == 'completed') {
            return status == 'completed' || status == 'delivered';
          }
          if (statusFilter == 'disputed') {
            return status == 'disputed' || status == 'issue';
          }
          return status == statusFilter;
        }).toList();

        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 60,
                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('No Orders in this category', 'इस श्रेणी में कोई ऑर्डर नहीं है'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'Confirmed purchase orders with live shipment tracking will appear here.',
                      'लाइव शिपमेंट ट्रैकिंग के साथ पुष्ट खरीद ऑर्डर यहां दिखाई देंगे।',
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['orderId'] ?? order['id'] ?? 'BPO-84920';
    final commodity = order['commodity'] ?? 'Commodity';
    final totalQtl = _toDouble(order['totalQuantityQtl'] ?? (_toDouble(order['totalQuantityMT']) * 10 > 0 ? _toDouble(order['totalQuantityMT']) * 10 : (_toDouble(order['quantity']) / 100)));
    final fpoName = order['fpoName'] ?? order['sellerName'] ?? 'Clustered FPOs';
    final totalAmount = _toDouble(order['totalAmount'] ?? order['totalPrice']);
    final status = (order['status'] ?? 'in_transit').toString().toLowerCase();
    final eta = order['eta'] ?? 'Today, 6:30 PM';
    final escrowStatus = order['escrowStatus'] ?? 'Funded & Protected';
    final isMultiFpo = order['isMultiFpo'] as bool? ?? true;
    final allocations = (order['fpoAllocations'] as List<dynamic>?) ?? [];

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
          // Header
          InkWell(
            onTap: () => _showOrderDetailDialog(order),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#$orderId • ${totalQtl > 0 ? totalQtl.toStringAsFixed(0) : '3,000'} ${context.tr('Qtl', 'क्विंटल')} $commodity',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        fpoName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'completed'
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status == 'in_transit'
                        ? context.tr('IN TRANSIT', 'मार्ग में')
                        : (status == 'completed' ? context.tr('COMPLETED', 'पूर्ण') : status.toUpperCase()),
                    style: TextStyle(
                      color: status == 'completed'
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Financials & Escrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Total Purchase Value', 'कुल खरीद मूल्य'),
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                        Text(
                          '₹${(totalAmount / 100000).toStringAsFixed(2)} ${context.tr('Lakh', 'लाख')}',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, size: 12, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 4),
                          Text(
                            escrowStatus,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Shipment ETA
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping, color: Color(0xFFF57F17), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${context.tr('Shipment ETA', 'आगमन अनुमान')}: $eta (${context.tr('3 Heavy Trucks Fleet', '3 भारी ट्रकों का बेड़ा')})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF57F17),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Multi-FPO Allocation Checklist
                if (isMultiFpo || allocations.isNotEmpty) ...[
                  Text(
                    context.tr('Multi-FPO Cluster Allocation & Dispatch Status:', 'मल्टी-एफपीओ क्लस्टर आवंटन और प्रेषण स्थिति:'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: allocations.isNotEmpty
                          ? allocations.map((a) {
                              final name = a['fpoName'] ?? 'FPO';
                              final qtyVal = _toDouble(a['quantityQtl'] ?? (_toDouble(a['quantityMT']) * 10 > 0 ? _toDouble(a['quantityMT']) * 10 : 1000));
                              final isDone = a['completed'] == true;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Icon(
                                      isDone ? Icons.check_circle : Icons.arrow_circle_right_outlined,
                                      color: isDone ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        name.toString(),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Text(
                                      '${qtyVal.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')} ${isDone ? '✓' : '→'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDone ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList()
                          : [
                              _buildStaticAllocationItem('Karnal Agro Producer Co.', '1,200 ${context.tr('Qtl', 'क्विंटल')}', true),
                              _buildStaticAllocationItem('Taraori Kisan Producer Co.', '1,000 ${context.tr('Qtl', 'क्विंटल')}', true),
                              _buildStaticAllocationItem('Gharaunda Farmers Producer Co.', '800 ${context.tr('Qtl', 'क्विंटल')}', false),
                            ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => B2bContractScreen(orderId: orderId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.description_outlined, size: 14),
                        label: Text(context.tr('Contract', 'अनुबंध'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Download Tripartite Smart Contract PDF',
                      child: InkWell(
                        onTap: () async {
                          final contract = await _dbService.getB2bContract(orderId.toString());
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
                              MaterialPageRoute(builder: (_) => B2bContractScreen(orderId: orderId.toString())),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFF1565C0)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showTrackingDetailsModal(order),
                        icon: const Icon(Icons.navigation_outlined, size: 14),
                        label: Text(context.tr('Track Fleet', 'फ्लीट ट्रैक करें'), style: const TextStyle(fontSize: 11.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (status != 'completed') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmReleaseEscrow(orderId, fpoName, totalAmount),
                          icon: const Icon(Icons.check_circle_outline, size: 14),
                          label: Text(context.tr('Release Payout', 'भुगतान जारी करें'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GiveRatingScreen(
                                  toUserId: (order['fpoId'] ?? 'fpo_karnal').toString(),
                                  toUserName: fpoName,
                                  ratingType: RatingType.seller,
                                  transactionId: orderId.toString(),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.star, size: 14),
                          label: Text(context.tr('Rate FPO', 'रेटिंग दें'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticAllocationItem(String name, String qty, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.arrow_circle_right_outlined,
            color: done ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '$qty ${done ? '✓' : '→'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: done ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }

  void _showTrackingDetailsModal(Map<String, dynamic> order) {
    final orderId = (order['orderId'] ?? order['id'] ?? 'BPO-84920').toString();
    final buyerName = (order['buyerCompany'] ?? order['buyerName'] ?? 'AgroFoods Milling India Pvt Ltd').toString();
    final commodity = (order['commodity'] ?? order['crop'] ?? '3,000 Qtl Sharbati Wheat').toString();
    final destination = (order['destination'] ?? order['deliveryLocation'] ?? 'Industrial Processing Plant, NCR Hub').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FpoOrderShipmentScreen(
          orderId: orderId,
          buyerName: buyerName,
          commodity: commodity,
          destination: destination,
        ),
      ),
    );
  }

  void _showOrderDetailDialog(Map<String, dynamic> order) {
    final orderId = (order['orderId'] ?? order['id'] ?? 'BPO-84920').toString();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${context.tr('Order', 'ऑर्डर')} #$orderId ${context.tr('Details & Escrow', 'विवरण और एस्क्रो')}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dialogCtx.tr('• Escrow Account: Axis Tripartite #9921', '• एस्क्रो खाता: एक्सिस त्रिपक्षीय #9921')),
              Text(dialogCtx.tr('• Weighbridge Pass: Digital Fastag Verified', '• वेब्रिज पास: डिजिटल फास्टैग सत्यापित')),
              Text(dialogCtx.tr('• Moisture Level: 11.2% (Target < 12.0%)', '• नमी स्तर: 11.2% (लक्ष्य < 12.0%)')),
              Text(dialogCtx.tr('• Tax Invoice: Form GST B2B #INV-4921', '• कर चालान: फॉर्म जीएसटी बी2बी #INV-4921')),
              const SizedBox(height: 12),
              Text(
                dialogCtx.tr(
                  'Funds are automatically released to FPO bank accounts upon factory gate moisture & weighbridge clearance.',
                  'फैक्ट्री गेट पर नमी और वेब्रिज क्लीयरेंस के बाद धनराशि स्वचालित रूप से एफपीओ बैंक खातों में जारी कर दी जाती है।',
                ),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
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
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: Text(dialogCtx.tr('Contract PDF', 'अनुबंध पीडीएफ')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('Dispute Ticket Raised for Quality Inspection.', 'गुणवत्ता निरीक्षण के लिए विवाद टिकट दर्ज किया गया।'))),
              );
            },
            child: Text(dialogCtx.tr('Raise Quality Dispute', 'गुणवत्ता विवाद दर्ज करें'), style: const TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            child: Text(dialogCtx.tr('Close', 'बंद करें')),
          ),
        ],
      ),
    );
  }

  void _confirmReleaseEscrow(String orderId, String fpoName, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified, color: Color(0xFF2E7D32), size: 24),
            const SizedBox(width: 8),
            Text(ctx.tr('Release Escrow Payout', 'एस्क्रो भुगतान जारी करें'), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${ctx.tr('Order', 'ऑर्डर')}: #$orderId', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${ctx.tr('Beneficiary FPO', 'लाभार्थी एफपीओ')}: $fpoName', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            Text(
              '${ctx.tr('Payout Amount', 'भुगतान राशि')}: ₹${amount.toStringAsFixed(0)}',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 12),
            Text(
              ctx.tr(
                'By authorizing release, you certify that computerized weighbridge slips and NABL assay quality checks are satisfied. Funds will be directly credited to the FPO account via RTGS.',
                'भुगतान की अनुमति देकर आप प्रमाणित करते हैं कि वेब्रिज पर्चियां और एनएबीएल परीक्षण गुणवत्ता जांच संतुष्ट हैं। राशि आरटीजीएस द्वारा सीधे एफपीओ खाते में जमा की जाएगी।',
              ),
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('Cancel', 'रद्द करें'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final utr = 'UTR2026${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
              await _dbService.releaseB2bEscrow(orderId: orderId, utrNumber: utr);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ ${context.tr('Escrow Released!', 'एस्क्रो जारी!')} ₹${amount.toStringAsFixed(0)} credited to $fpoName (UTR: $utr)'),
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: Text(ctx.tr('Confirm Release Payout', 'भुगतान जारी करने की पुष्टि करें'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

