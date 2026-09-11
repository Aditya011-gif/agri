import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/database_service.dart';
import 'farmer_fpo_consignment_dashboard_screen.dart';

class FarmerSellToFpoScreen extends StatefulWidget {
  const FarmerSellToFpoScreen({super.key});

  @override
  State<FarmerSellToFpoScreen> createState() => _FarmerSellToFpoScreenState();
}

class _FarmerSellToFpoScreenState extends State<FarmerSellToFpoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  final List<Map<String, dynamic>> _sampleNearbyFpos = [
    {
      'id': 'fpo_karnal_01',
      'name': 'Karnal Agro Farmer Producer Co.',
      'distance': '4.2 km away',
      'location': 'Main Silo Yard, GT Road, Karnal',
      'buyingCommodities': ['Wheat (Sharbati/1121)', 'Basmati Paddy', 'Mustard'],
      'buyingPriceRange': '₹2,450 - ₹3,600 / Qtl',
      'verified': true,
      'membersCount': 850,
      'rating': 4.9,
    },
    {
      'id': 'fpo_panipat_02',
      'name': 'Panipat Organic Growers Collective',
      'distance': '9.5 km away',
      'location': 'Warehouse Complex, Panipat Industrial Area',
      'buyingCommodities': ['Organic Wheat', 'Soybean', 'Pulses / Dal'],
      'buyingPriceRange': '₹3,200 - ₹4,800 / Qtl',
      'verified': true,
      'membersCount': 420,
      'rating': 4.8,
    },
    {
      'id': 'fpo_hisar_03',
      'name': 'Haryana Krishi Vikas FPO Ltd.',
      'distance': '16.0 km away',
      'location': 'Near Anaj Mandi, Hisar',
      'buyingCommodities': ['Cotton (BT)', 'Maize / Corn', 'Bajra'],
      'buyingPriceRange': '₹2,100 - ₹6,800 / Qtl',
      'verified': true,
      'membersCount': 1200,
      'rating': 4.7,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    final farmerName = user?.name.isNotEmpty == true ? user!.name : 'Member Farmer';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGreen,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          const CustomAppBar(
            title: 'Sell to FPO',
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  _buildFpoSellBanner(),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primaryColor,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.business_outlined, size: 18),
                          text: 'Nearby FPOs',
                        ),
                        Tab(
                          icon: Icon(Icons.outbox_outlined, size: 18),
                          text: 'My FPO Offers',
                        ),
                        Tab(
                          icon: Icon(Icons.alt_route_outlined, size: 18),
                          text: 'Collection Route',
                        ),
                        Tab(
                          icon: Icon(Icons.receipt_long_outlined, size: 18),
                          text: 'Procurement History',
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
            _buildNearbyFposTab(farmerId, farmerName),
            _buildMyOffersTab(farmerId),
            _buildCollectionRouteTab(),
            _buildProcurementHistoryTab(farmerId),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSubmitOfferDialog(farmerId, farmerName),
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.local_shipping_outlined, color: Colors.white),
        label: const Text(
          'Send Offer to FPO',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFpoSellBanner() {
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
            child: const Icon(Icons.storefront, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Guaranteed FPO Bulk Procurement',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Sell directly to nearby FPOs with fair MSP pricing, instant weighbridge receipts, and farmgate collection.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FarmerFpoConsignmentDashboardScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dashboard_customize_outlined, size: 15, color: Color(0xFF1B5E20)),
                        SizedBox(width: 6),
                        Text(
                          'Track My FPO Consignments & Lab Passports',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF1B5E20)),
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

  // TAB 1: Nearby FPOs List
  Widget _buildNearbyFposTab(String farmerId, String farmerName) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: _sampleNearbyFpos.length,
      itemBuilder: (context, index) {
        final fpo = _sampleNearbyFpos[index];
        final name = fpo['name'] as String;
        final distance = fpo['distance'] as String;
        final location = fpo['location'] as String;
        final commodities = (fpo['buyingCommodities'] as List<String>);
        final priceRange = fpo['buyingPriceRange'] as String;
        final rating = fpo['rating'] as double;
        final members = fpo['membersCount'] as int;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.softShadow,
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.corporate_fare, color: Color(0xFF2E7D32), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.verified, color: Color(0xFF2563EB), size: 15),
                                  ],
                                ),
                                Text(
                                  location,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.near_me, size: 12, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(distance, style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: Color(0xFFB45309)),
                          const SizedBox(width: 4),
                          Text('$rating ($members Members)', style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                const Text('Currently Procuring:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: commodities.map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(c, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Procurement Rate', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        Text(
                          priceRange,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showSubmitOfferDialog(
                        farmerId,
                        farmerName,
                        prefilledFpoName: name,
                      ),
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('Send Offer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // TAB 2: My Submitted Offers to FPOs
  Widget _buildMyOffersTab(String farmerId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamFarmerProcurementOffers(farmerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final offers = snapshot.data ?? [];

        if (offers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.outbox_outlined, size: 60, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  const Text(
                    'No FPO Offers Submitted Yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Browse nearby FPOs in Tab 1 and tap "Send Offer" to offer your harvest at guaranteed rates.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index];
            final cropName = offer['cropName'] ?? 'Crop';
            final fpoName = offer['fpoName'] ?? 'Central FPO';
            final qty = _toDouble(offer['quantity']);
            final unit = offer['unit'] ?? 'kg';
            final price = _toDouble(offer['pricePerUnit']);
            final total = offer['totalAmount'] != null ? _toDouble(offer['totalAmount']) : (qty * price);
            final status = offer['status'] ?? 'pending';
            final slipNumber = offer['weighbridgeSlipNumber'] ?? '';
            final dateStr = offer['createdAt'] != null ? offer['createdAt'].toString().split('T').first : 'Recent';

            Color statusBg = const Color(0xFFFEF3C7);
            Color statusText = const Color(0xFFB45309);
            String statusLabel = 'Offer Under Review';

            if (status == 'accepted' || status == 'procured') {
              statusBg = const Color(0xFFDCFCE7);
              statusText = const Color(0xFF15803D);
              statusLabel = 'Accepted & Weighbridge Slip Issued';
            } else if (status == 'rejected') {
              statusBg = const Color(0xFFFEE2E2);
              statusText = const Color(0xFFB91C1C);
              statusLabel = 'Offer Declined';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
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
                        cropName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(statusLabel, style: TextStyle(color: statusText, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('FPO: $fpoName • Date: $dateStr', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  if (slipNumber.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Weighbridge Pass: $slipNumber', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ],
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Volume: $qty $unit @ ₹$price', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('Total: ₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2E7D32))),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // TAB 3: Farmgate Collection Route Recommendation
  Widget _buildCollectionRouteTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
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
                  const Row(
                    children: [
                      Icon(Icons.alt_route, color: Color(0xFF2E7D32), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Farmgate Cluster Pickup',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Recommended Route', style: TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'FPO collection trucks visit village aggregation points weekly. Bring your harvest to the nearest stop for free on-the-spot weighing and payout.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Divider(height: 20),
              _buildRouteStop('1', 'Your Farmgate / Village Mandi Point', 'Collection Truck: 09:30 AM (Wednesday)'),
              _buildRouteStop('2', 'Cluster Weighbridge & Silo Intake', 'Estimated Arrival: 11:30 AM'),
              _buildRouteStop('3', 'Instant Digital Weighbridge Slip & IMPS Settlement', 'Automatic Payout'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF16A34A), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Note: This collection route is a recommendation only. You may also self-deliver to the FPO central silo at any time during operating hours.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRouteStop(String step, String name, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFF2E7D32),
            child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 4: Procurement History & Weighbridge Receipts
  Widget _buildProcurementHistoryTab(String farmerId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamFarmerOrders(farmerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allOrders = snapshot.data ?? [];
        final fpoOrders = allOrders.where((o) => o['orderType'] == 'fpo_procurement').toList();

        if (fpoOrders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  const Text(
                    'No Completed FPO Orders Yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'When an FPO procures your harvest, your official weighbridge receipts and payouts will be archived here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: fpoOrders.length,
          itemBuilder: (context, index) {
            final order = fpoOrders[index];
            final cropName = order['cropName'] ?? 'Commodity';
            final buyerName = order['buyerName'] ?? 'FPO';
            final qty = _toDouble(order['quantity']);
            final price = _toDouble(order['price']);
            final total = order['totalPrice'] != null ? _toDouble(order['totalPrice']) : (qty * price);
            final slipNumber = order['weighbridgeSlipNumber'] ?? 'WB-REC-${order['id']?.toString().substring(0, 5)}';
            final dateStr = order['createdAt'] != null ? order['createdAt'].toString().split('T').first : 'Recent';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
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
                        cropName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Settled & Paid', style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Buyer: $buyerName • Slip: $slipNumber • $dateStr', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Procured: $qty kg @ ₹$price', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32))),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // DIALOG: Submit Offer to FPO
  void _showSubmitOfferDialog(String farmerId, String farmerName, {String? prefilledFpoName}) {
    final cropController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    String selectedFpo = prefilledFpoName ?? 'Karnal Agro Farmer Producer Co.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Submit Procurement Offer to FPO',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Offer your harvest directly to your chosen FPO for bulk procurement.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text('Target FPO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: selectedFpo,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _sampleNearbyFpos.map((f) => DropdownMenuItem(value: f['name'] as String, child: Text(f['name'] as String, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) selectedFpo = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cropController,
                decoration: InputDecoration(
                  labelText: 'Crop Commodity & Variety (e.g. Sharbati Wheat)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      decoration: InputDecoration(
                        labelText: 'Quantity (kg)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: 'Asking Rate (₹/kg)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (cropController.text.trim().isEmpty ||
                        qtyController.text.trim().isEmpty ||
                        priceController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields.')),
                      );
                      return;
                    }

                    final qty = double.tryParse(qtyController.text.trim()) ?? 0.0;
                    final price = double.tryParse(priceController.text.trim()) ?? 0.0;

                    final offerData = {
                      'farmerId': farmerId,
                      'farmerName': farmerName,
                      'fpoName': selectedFpo,
                      'cropName': cropController.text.trim(),
                      'quantity': qty,
                      'unit': 'kg',
                      'pricePerUnit': price,
                      'totalAmount': qty * price,
                      'status': 'pending',
                      'createdAt': DateTime.now().toIso8601String(),
                    };

                    final success = await _dbService.createProcurementOffer(offerData);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Offer submitted to $selectedFpo!' : 'Failed to submit offer.'),
                          backgroundColor: success ? const Color(0xFF2E7D32) : AppTheme.error,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit Offer to FPO', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
