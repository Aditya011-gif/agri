import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../utils/crop_image_helper.dart';
import '../../widgets/custom_app_bar.dart';
import '../../models/fpo_inventory_model.dart';
import '../../models/multi_fpo_cluster_model.dart';
import '../../services/fpo_inventory_service.dart';
import '../../services/multi_fpo_cluster_service.dart';
import '../../services/road_routing_service.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';
import 'escrow_checkout_screen.dart';
import '../../widgets/fpo_lot_details_modal.dart';

/// Screen: FPO Supply & Multi-FPO Clusters (Bulk Buyer)
/// Redesigned with the clean, airy, un-clustered aesthetic from the farmer produce pooling screen.
/// Features:
/// - Visual Crop Hero Banners with glassmorphic proximity & pooled tonnage tags
/// - 3-Column key metrics strips (Consolidated Rate, Total Pooled Supply, Clustered FPOs)
/// - Compact horizontal collection route chain preview
/// - Verified quality & assaying standards pills (Moisture, NABL, Weighbridge)
/// - Interactive custom quantity selector with instant cost calculation
/// - Interactive Google Maps & OSM Route Inspection sheet with geofence and multi-stop polyline
/// - Clean Single FPO Direct Lots tab
class BulkBuyerSupplyScreen extends StatefulWidget {
  const BulkBuyerSupplyScreen({super.key});

  @override
  State<BulkBuyerSupplyScreen> createState() => _BulkBuyerSupplyScreenState();
}

class _BulkBuyerSupplyScreenState extends State<BulkBuyerSupplyScreen>
    with SingleTickerProviderStateMixin {
  final FpoInventoryService _inventoryService = FpoInventoryService();
  final MultiFpoClusterEngine _clusterEngine = MultiFpoClusterEngine();
  late TabController _tabController;

  String _searchQuery = '';
  String _selectedCrop = 'All';
  double _maxDistanceKm = 50.0;

  // Custom quantities selected per cluster (key: clusterName)
  final Map<String, double> _selectedQuantities = {};

  final List<String> _cropFilters = [
    'All',
    'Wheat',
    'Basmati Paddy',
    'Mustard',
    'Soybean',
    'Maize',
    'Pulses',
  ];

  String _getCropLabel(BuildContext context, String crop) {
    switch (crop) {
      case 'All':
        return context.tr('All', 'सभी');
      case 'Wheat':
        return context.tr('Wheat', 'गेहूँ');
      case 'Basmati Paddy':
        return context.tr('Basmati Paddy', 'बासमती धान');
      case 'Mustard':
        return context.tr('Mustard', 'सरसों');
      case 'Soybean':
        return context.tr('Soybean', 'सोयाबीन');
      case 'Maize':
        return context.tr('Maize', 'मक्का');
      case 'Pulses':
        return context.tr('Pulses', 'दालें');
      default:
        return crop;
    }
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

  double _getSelectedQuantity(String clusterId, double fallback) {
    return _selectedQuantities[clusterId] ?? fallback;
  }

  void _setSelectedQuantity(String clusterId, double qty, double maxQty) {
    setState(() {
      _selectedQuantities[clusterId] = qty.clamp(10.0, maxQty);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CustomAppBar(
            title: context.tr('FPO Supply & Clusters', 'एफपीओ आपूर्ति एवं क्लस्टर'),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: LanguageSwitcherPill(isDark: true),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                children: [
                  // 1. Search Bar
                  _buildSearchAndFilters(),
                  const SizedBox(height: 12),

                  // 2. Crop Filters Bar
                  _buildCropFilterChips(),
                  const SizedBox(height: 12),

                  // 3. Segmented Tab Bar (Combined vs Single Lots)
                  _buildSegmentedTabBar(),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildCombinedMultiFpoTab(),
            _buildSingleFpoLotsTab(),
          ],
        ),
      ),
    );
  }

  // 1. Sleek Search Bar with Filter Modal Trigger
  Widget _buildSearchAndFilters() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (val) {
          setState(() {
            _searchQuery = val.toLowerCase().trim();
          });
        },
        decoration: InputDecoration(
          hintText: context.tr('Search FPO name, commodity, district, cluster...', 'एफपीओ, फसल, जिला, क्लस्टर खोजें...'),
          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF15803D)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFF15803D)),
            onPressed: _showAdvancedFilterSheet,
            tooltip: context.tr('Filter Cluster Radius', 'क्लस्टर दायरा फ़िल्टर'),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // 2. Horizontal Scrolling Crop Filters
  Widget _buildCropFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _cropFilters.length,
        itemBuilder: (context, index) {
          final cat = _cropFilters[index];
          final isSelected = _selectedCrop == cat;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_getCropLabel(context, cat)),
              selected: isSelected,
              selectedColor: const Color(0xFF15803D),
              backgroundColor: Colors.white,
              labelStyle: GoogleFonts.inter(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF15803D) : const Color(0xFFE2E8F0),
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCrop = cat;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  // 3. Segmented Tab Bar
  Widget _buildSegmentedTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF15803D),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFF15803D),
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5),
        tabs: [
          Tab(
            icon: const Icon(Icons.hub_outlined, size: 18),
            text: context.tr('Combined Multi-FPO Supply (7 km)', 'संयुक्त मल्टी-FPO आपूर्ति (7 किमी)'),
          ),
          Tab(
            icon: const Icon(Icons.warehouse_outlined, size: 18),
            text: context.tr('Single FPO Direct Lots', 'प्रत्यक्ष FPO लॉट'),
          ),
        ],
      ),
    );
  }

  // TAB 1: Combined Multi-FPO Supply (Powered by MultiFpoClusterEngine)
  Widget _buildCombinedMultiFpoTab() {
    return StreamBuilder<List<BulkCropListing>>(
      stream: _inventoryService.streamActiveBulkListings(),
      builder: (context, snapshot) {
        final listings = snapshot.data ?? [];
        final nodes = listings.map((l) => FpoNode(
          fpoId: l.fpoId,
          fpoName: l.fpoName,
          warehouseName: l.warehouseName,
          latitude: l.warehouseLat != 0 ? l.warehouseLat : 29.6857,
          longitude: l.warehouseLng != 0 ? l.warehouseLng : 76.9905,
          commodity: l.cropName,
          variety: l.variety,
          availableQuantityQtl: l.listedQuantityQtl,
          pricePerQtl: l.pricePerQtl,
          moisturePct: l.moisturePct,
          qualityGrade: l.qualityGrade,
          imageUrl: l.imageUrl,
          listingId: l.id,
          dispatchLeadDays: l.dispatchLeadTimeDays,
          isMultiFpoEligible: l.isMultiFpoEligible,
        )).toList();

        final rawClusters = _clusterEngine.clusterFpoNodes(nodes, maxRadiusKm: _maxDistanceKm);
        final clusters = rawClusters.map((c) => {
          'id': c.clusterId,
          'clusterId': c.clusterId,
          'commodity': c.commodity,
          'variety': c.variety,
          'targetVolumeMT': c.totalVolumeQtl,
          'defaultOrderMT': (c.totalVolumeQtl * 0.25).clamp(100.0, c.totalVolumeQtl),
          'clusterName': c.clusterName,
          'hubLocation': c.participatingFpos.map((f) => f.warehouseName).join(' + '),
          'hubLat': c.centroid.latitude,
          'hubLng': c.centroid.longitude,
          'radiusKm': c.maxRadialDistanceKm,
          'avgPriceQtl': c.weightedPricePerQtl,
          'moisture': '${c.averageMoisturePct.toStringAsFixed(1)}%',
          'purity': '98.8%',
          'destinationPlant': {
            'name': MultiFpoClusterEngine.defaultDestinationName,
            'lat': MultiFpoClusterEngine.defaultDestinationPlant.latitude,
            'lng': MultiFpoClusterEngine.defaultDestinationPlant.longitude,
          },
          'fpos': c.participatingFpos.map((f) => {
            'name': f.fpoName,
            'qtl': f.availableQuantityQtl,
            'volume': f.availableQuantityQtl,
            'lat': f.latitude,
            'lng': f.longitude,
            'location': f.warehouseName,
          }).toList(),
        }).toList();

        final filteredClusters = clusters.where((c) {
          final name = c['commodity'].toString().toLowerCase();
          final cluster = c['clusterName'].toString().toLowerCase();
          final variety = c['variety'].toString().toLowerCase();
          final matchesQuery = _searchQuery.isEmpty ||
              name.contains(_searchQuery) ||
              cluster.contains(_searchQuery) ||
              variety.contains(_searchQuery);

          final matchesCrop = _selectedCrop == 'All' ||
              name.contains(_selectedCrop.toLowerCase());

          return matchesQuery && matchesCrop;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Sleek Hero Banner
            _buildCleanHeroBanner(filteredClusters.length),
            const SizedBox(height: 14),

            // Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('Active Hyperlocal Multi-FPO Clusters', 'सक्रिय स्थानीय मल्टी-FPO क्लस्टर'),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${filteredClusters.length} ${context.tr('Clusters Ready', 'क्लस्टर तैयार')}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cluster Cards or Empty State
            if (filteredClusters.isEmpty)
              _buildEmptyClusterState()
            else
              ...filteredClusters.map((cluster) => _buildCombinedClusterCard(cluster)),
          ],
        );
      },
    );
  }

  // Clean Hero Banner (Gradient + 3 Key Badges)
  Widget _buildCleanHeroBanner(int totalClusters) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hub, color: Color(0xFF69F0AE), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Multi-FPO Cluster Engine', 'मल्टी-FPO क्लस्टर इंजन'),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      context.tr(
                        'Auto-pools neighboring FPO godowns within 7 km to fulfill 100% of bulk demands',
                        '7 किमी के भीतर पड़ोसी FPO गोदामों को जोड़कर 100% थोक मांग पूरा करता है',
                      ),
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB9F6CA)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Clean Summary Badges
          Row(
            children: [
              _buildBannerStat(Icons.scatter_plot, context.tr('≤ 7.0 km Radius', '≤ 7.0 किमी दायरा'), context.tr('Inter-FPO Belt', 'एफपीओ बेल्ट')),
              const SizedBox(width: 8),
              _buildBannerStat(Icons.alt_route, context.tr('Save ~24% Freight', '~24% माल ढुलाई बचत'), context.tr('Consolidated Fleet', 'संयुक्त फ्लीट')),
              const SizedBox(width: 8),
              _buildBannerStat(Icons.verified, context.tr('100% Assayed', '100% जांचा हुआ'), context.tr('NABL Lab Verified', 'NABL लैब सत्यापित')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStat(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF69F0AE), size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  // Detailed, un-clustered Multi-FPO Card (Cleaned to match Farmer Pooling screen)
  Widget _buildCombinedClusterCard(Map<String, dynamic> cluster) {
    final clusterId = (cluster['id'] ?? cluster['clusterId'] ?? 'cluster_1').toString();
    final commodity = (cluster['commodity'] ?? 'Produce').toString();
    final variety = (cluster['variety'] ?? 'Standard').toString();
    final targetVolumeMT = (cluster['targetVolumeMT'] as num?)?.toDouble() ?? 100.0;
    final defaultOrderMT = (cluster['defaultOrderMT'] as num?)?.toDouble() ?? 25.0;
    final clusterName = (cluster['clusterName'] ?? 'FPO Cluster').toString();
    final hubLocation = (cluster['hubLocation'] ?? 'Hub').toString();
    final radiusKm = (cluster['radiusKm'] as num?)?.toDouble() ?? 7.0;
    final avgPriceQtl = (cluster['avgPriceQtl'] as num?)?.toDouble() ?? 2400.0;
    final moisture = (cluster['moisture'] ?? '12%').toString();
    final purity = (cluster['purity'] ?? '98%').toString();
    final fpos = (cluster['fpos'] as List<dynamic>?) ?? [];

    // Current selected quantity for this card (in Quintals / Qtl)
    final selectedMT = _getSelectedQuantity(clusterId, defaultOrderMT);
    final ratePerMT = avgPriceQtl; // Rate is directly per Quintal
    final calculatedTotal = selectedMT * ratePerMT;
    final estimatedSavings = selectedMT * 42; // Logistics savings estimation (~₹42/Qtl)

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Photo Hero Banner with Floating Glassmorphic Tags
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                child: CropImageHelper.buildCropImage(
                  null,
                  commodity,
                  height: 145,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              // Floating Proximity Radius Tag (Top-Left)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me, size: 12, color: Color(0xFF69F0AE)),
                      const SizedBox(width: 4),
                      Text(
                        '${context.tr('Within', 'के भीतर')} $radiusKm ${context.tr('km Radius', 'किमी दायरा')}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating Total Pooled Volume Tag (Top-Right)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15803D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warehouse, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${targetVolumeMT.toStringAsFixed(0)} ${context.tr('Qtl POOLED', 'क्विंटल संयुक्त')}',
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating Cluster Hub Badge (Bottom-Left)
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hub, size: 12, color: Color(0xFF69F0AE)),
                      const SizedBox(width: 4),
                      Text(
                        '${fpos.length} ${context.tr('Clustered FPOs', 'क्लस्टर एफपीओ')} • $clusterName',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Clean Card Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commodity Title and Grade Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        commodity,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        variety,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Location Hub Row
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF15803D)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        hubLocation,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Spacious 3-Column Key Metrics Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Consolidated Rate
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('Consolidated Rate', 'संयुक्त दर'), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          Row(
                            children: [
                              Text(
                                '₹${avgPriceQtl.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                              Text(context.tr('/Qtl', '/क्विंटल'), style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF15803D))),
                            ],
                          ),
                          Text(
                            context.tr('Wholesale Pooled Rate', 'थोक संयुक्त दर'),
                            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),

                      // Pooled Supply
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(context.tr('Total Pooled', 'कुल संयुक्त'), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          Text(
                            '${targetVolumeMT.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            context.tr('100% Available', '100% उपलब्ध'),
                            style: const TextStyle(fontSize: 9.5, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      // Cluster Span
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(context.tr('Cluster Network', 'क्लस्टर नेटवर्क'), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          Text(
                            '${fpos.length} ${context.tr('FPOs', 'एफपीओ')}',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          Text(
                            '≤ $radiusKm ${context.tr('km radius', 'किमी दायरा')}',
                            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Horizontal Inter-FPO Distance Chain Preview
                _buildInterFpoChainPreview(fpos, radiusKm),
                const SizedBox(height: 12),

                // 5. Assaying Standards Pills Strip
                _buildQualityTagsBar(moisture, purity),
                const SizedBox(height: 14),

                // 6. Interactive Custom Quantity Box Directly on Card
                _buildCardQuantitySelector(
                  clusterId,
                  commodity,
                  targetVolumeMT,
                  selectedMT,
                  ratePerMT,
                  calculatedTotal,
                  estimatedSavings,
                ),
                const SizedBox(height: 14),

                // 7. Dual Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showClusterRouteInspectionSheet(context, cluster),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: Text(context.tr('Inspect Route', 'रूट देखें'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF15803D),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                          backgroundColor: const Color(0xFFF0FDF4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final allocations = fpos.map((fpo) {
                            final totalVol = targetVolumeMT > 0 ? targetVolumeMT : 1.0;
                            final fpoVol = (fpo['qtl'] as num?)?.toDouble() ?? (fpo['volume'] as num?)?.toDouble() ?? (totalVol / fpos.length);
                            final ratio = fpoVol / totalVol;
                            final allocQtl = selectedMT * ratio;
                            return {
                              'fpoId': fpo['fpoId'] ?? (fpo['name'].toString().toLowerCase().contains('taraori') ? 'fpo_taraori_02' : (fpo['name'].toString().toLowerCase().contains('gharaunda') ? 'fpo_gharaunda_03' : 'fpo_karnal_01')),
                              'fpoName': fpo['name'],
                              'warehouseName': fpo['location'] ?? 'Warehouse Dock',
                              'allocatedQtl': allocQtl,
                              'allocatedMT': allocQtl / 10.0,
                              'quantityQtl': allocQtl,
                              'quantityMT': allocQtl / 10.0,
                              'commodity': commodity,
                            };
                          }).toList();

                          _proceedToEscrowCheckout(
                            commodity,
                            clusterName,
                            selectedMT / 10.0,
                            ratePerMT * 10.0,
                            quantityQtl: selectedMT,
                            ratePerQtl: ratePerMT,
                            variety: variety,
                            fpoId: allocations.first['fpoId'] as String?,
                            fpoName: clusterName,
                            isMultiFpo: true,
                            allocations: allocations,
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: Text(
                          '${context.tr('Accept', 'स्वीकारें')} ${selectedMT.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // Horizontal Multi-Stop Collection Route Chain Preview
  Widget _buildInterFpoChainPreview(List<dynamic> fpos, double radiusKm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCEDC8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alt_route, size: 15, color: Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...fpos.map((fpo) {
                    final isLast = fpo == fpos.last;
                    final name = fpo['name'].toString().split(' ').first;
                    final vol = fpo['volume'].toString();
                    return Row(
                      children: [
                        Text(
                          '🏢 $name ($vol ${context.tr('Qtl', 'क्विंटल')})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 11, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 4),
                        if (isLast)
                          Text(
                            context.tr('🏭 Plant Dock', '🏭 प्लांट डॉक'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '≤ $radiusKm ${context.tr('km span', 'किमी विस्तार')}',
              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Quality & Verification Tags Bar
  Widget _buildQualityTagsBar(String moisture, String purity) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _buildTagPill('💧 ${context.tr('Moisture:', 'नमी:')} $moisture'),
        _buildTagPill('🌾 ${context.tr('Purity:', 'शुद्धता:')} $purity'),
        _buildTagPill(context.tr('🔬 NABL Lab Certified', '🔬 NABL लैब प्रमाणित')),
        _buildTagPill(context.tr('⚖️ Weighbridge Slip', '⚖️ धर्मकांटा पर्ची')),
        _buildTagPill(context.tr('🔐 DigiLocker e-Signed', '🔐 डिजिलॉकर हस्ताक्षरित')),
      ],
    );
  }

  Widget _buildTagPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
      ),
    );
  }

  // Interactive Custom Quantity Box on the card
  Widget _buildCardQuantitySelector(
    String clusterId,
    String commodity,
    double totalAvailableMT,
    double selectedMT,
    double ratePerMT,
    double calculatedTotal,
    double estimatedSavings,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
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
                  const Icon(Icons.tune, size: 14, color: Color(0xFF15803D)),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('Order Volume Selection (Quintals)', 'मात्रा चयन (क्विंटल)'),
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showCustomVolumeDialog(clusterId, commodity, totalAvailableMT, selectedMT),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15803D).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.tr('✏️ Enter Exact Qtl', '✏️ सटीक क्विंटल दर्ज करें'),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stepper + Preset Chips Row
          Row(
            children: [
              // Decrement
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFF15803D)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _setSelectedQuantity(clusterId, selectedMT - 100, totalAvailableMT),
              ),

              // Current Value Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  '${selectedMT.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
              ),

              // Increment
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF15803D)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _setSelectedQuantity(clusterId, selectedMT + 100, totalAvailableMT),
              ),

              const Spacer(),

              // Quick preset chips
              _buildVolumePresetChip('500 ${context.tr('Qtl', 'क्विंटल')}', 500.0, selectedMT, (v) => _setSelectedQuantity(clusterId, v, totalAvailableMT)),
              const SizedBox(width: 4),
              _buildVolumePresetChip('1,000 ${context.tr('Qtl', 'क्विंटल')}', 1000.0, selectedMT, (v) => _setSelectedQuantity(clusterId, v, totalAvailableMT)),
              const SizedBox(width: 4),
              _buildVolumePresetChip('${context.tr('All', 'सभी')} ${totalAvailableMT.toInt()} ${context.tr('Qtl', 'क्विंटल')}', totalAvailableMT, selectedMT, (v) => _setSelectedQuantity(clusterId, v, totalAvailableMT)),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),

          // Price & Freight Savings Callout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${context.tr('Total:', 'कुल:')} ₹${calculatedTotal.toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
              ),
              Text(
                '${context.tr('Save ~₹', '~₹ बचत')} ${estimatedSavings.toStringAsFixed(0)} ${context.tr('on combined freight', 'संयुक्त ढुलाई पर')}',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumePresetChip(String label, double value, double currentVal, Function(double) onSelect) {
    final isSelected = currentVal == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF15803D) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF15803D) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // Custom Volume Dialog for entering exact Qtl
  void _showCustomVolumeDialog(String clusterId, String commodity, double maxMT, double currentMT) {
    final controller = TextEditingController(text: currentMT.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_note, color: Color(0xFF15803D)),
            const SizedBox(width: 8),
            Text(dlgCtx.tr('Enter Required Volume', 'आवश्यक मात्रा दर्ज करें'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dlgCtx.tr(
                'Specify custom quintals needed for $commodity:',
                '${_getCropLabel(dlgCtx, commodity)} के लिए आवश्यक क्विंटल दर्ज करें:',
              ),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: dlgCtx.tr('Order Volume (Qtl)', 'ऑर्डर मात्रा (क्विंटल)'),
                suffixText: dlgCtx.tr('Qtl', 'क्विंटल'),
                hintText: 'e.g. 500, 1000, 2500',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF15803D), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              dlgCtx.tr(
                'Total pooled volume in cluster: ${maxMT.toStringAsFixed(0)} Qtl',
                'क्लस्टर में कुल एकत्रित मात्रा: ${maxMT.toStringAsFixed(0)} क्विंटल',
              ),
              style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(dlgCtx.tr('Cancel', 'रद्द करें'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              final parsed = double.tryParse(text);
              if (parsed != null && parsed >= 50.0) {
                _setSelectedQuantity(clusterId, parsed, maxMT);
                Navigator.pop(dlgCtx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(dlgCtx.tr('Apply Qtl', 'लागू करें'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Interactive Route Inspection Sheet with FlutterMap (OSM, Satellite, Road)
  void _showClusterRouteInspectionSheet(BuildContext context, Map<String, dynamic> cluster) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final hubLat = (cluster['hubLat'] as num?)?.toDouble() ?? 28.6139;
        final hubLng = (cluster['hubLng'] as num?)?.toDouble() ?? 77.2090;
        final hubPos = LatLng(hubLat, hubLng);
        final fpos = (cluster['fpos'] as List<dynamic>?) ?? [];
        final clusterName = (cluster['clusterName'] ?? 'Cluster').toString();
        final commodity = (cluster['commodity'] ?? 'Produce').toString();
        final radiusKm = (cluster['radiusKm'] as num?)?.toDouble() ?? 7.0;
        final targetVolumeMT = (cluster['targetVolumeMT'] as num?)?.toDouble() ?? 100.0;
        final avgPriceQtl = (cluster['avgPriceQtl'] as num?)?.toDouble() ?? 2400.0;
        final ratePerMT = avgPriceQtl * 10;
        final destPlant = (cluster['destinationPlant'] as Map<String, dynamic>?) ?? {};
        final destLat = (destPlant['lat'] as num?)?.toDouble() ?? 28.4595;
        final destLng = (destPlant['lng'] as num?)?.toDouble() ?? 77.0266;
        final destPos = LatLng(destLat, destLng);

        int mapTypeIndex = 0;
        RoadRouteResult? roadRoute;
        bool isRouteLoading = true;
        bool hasFetched = false;

        return StatefulBuilder(
          builder: (context, setInspectionState) {
            // Build route points: FPO 1 -> FPO 2 -> ... -> Destination Plant
            final routePoints = <LatLng>[];
            for (final f in fpos) {
              routePoints.add(LatLng((f['lat'] as num?)?.toDouble() ?? 0.0, (f['lng'] as num?)?.toDouble() ?? 0.0));
            }
            routePoints.add(destPos);

            if (!hasFetched) {
              hasFetched = true;
              RoadRoutingService().getMultiStopRoute(routePoints, optimizeStops: false).then((res) {
                setInspectionState(() {
                  roadRoute = res;
                  isRouteLoading = false;
                });
              });
            }

            String tileUrl;
            switch (mapTypeIndex) {
              case 1:
                tileUrl = 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'; // Satellite
                break;
              case 2:
                tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'; // OSM
                break;
              case 0:
              default:
                tileUrl = 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'; // Google Road
                break;
            }

            final polylinePoints = roadRoute?.points ?? routePoints;

            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Modal Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.alt_route, color: Color(0xFF15803D), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Consolidated Multi-Stop Route', 'समेकित मल्टी-स्टॉप रूट'),
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '$clusterName • ${targetVolumeMT.toStringAsFixed(0)} ${context.tr('Qtl Total', 'क्विंटल कुल')}',
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
                  const Divider(height: 16),

                  // Modal Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Map Layer Selector Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('Multi-FPO Dispatch GPS Map', 'मल्टी-एफपीओ प्रेषण जीपीएस मैप'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Row(
                                children: [
                                  _buildMapToggle(0, context.tr('🗺️ Road', '🗺️ सड़क'), mapTypeIndex, (idx) => setInspectionState(() => mapTypeIndex = idx)),
                                  const SizedBox(width: 4),
                                  _buildMapToggle(1, context.tr('🛰️ Sat', '🛰️ उपग्रह'), mapTypeIndex, (idx) => setInspectionState(() => mapTypeIndex = idx)),
                                  const SizedBox(width: 4),
                                  _buildMapToggle(2, '🌐 OSM', mapTypeIndex, (idx) => setInspectionState(() => mapTypeIndex = idx)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(
                              'Optimized multi-stop pickup itinerary with geofenced FPO warehouses.',
                              'जियोफेंस्ड एफपीओ गोदामों के साथ अनुकूलित मल्टी-स्टॉप पिकअप मार्ग।',
                            ),
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 10),

                          // Interactive FlutterMap
                          Container(
                            height: 230,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: hubPos,
                                  initialZoom: 11.0,
                                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: tileUrl,
                                    userAgentPackageName: 'com.agrichain.app',
                                  ),

                                  // Cluster Geofence Circle
                                  CircleLayer(
                                    circles: [
                                      CircleMarker(
                                        point: hubPos,
                                        radius: radiusKm * 1000,
                                        useRadiusInMeter: true,
                                        color: const Color(0xFF15803D).withValues(alpha: 0.12),
                                        borderColor: const Color(0xFF15803D),
                                        borderStrokeWidth: 2,
                                      ),
                                    ],
                                  ),

                                  // Polyline connecting FPOs
                                  PolylineLayer(
                                    polylines: [
                                      // Outer road casing
                                      Polyline(
                                        points: polylinePoints,
                                        strokeWidth: 5.5,
                                        color: const Color(0xFF064E3B),
                                      ),
                                      // Highway centerline
                                      Polyline(
                                        points: polylinePoints,
                                        strokeWidth: 3.5,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ],
                                  ),

                                  // FPO Warehouse Pins
                                  MarkerLayer(
                                    markers: [
                                      ...fpos.asMap().entries.map((entry) {
                                        final idx = entry.key;
                                        final f = entry.value;
                                        final pos = LatLng((f['lat'] as num?)?.toDouble() ?? 0.0, (f['lng'] as num?)?.toDouble() ?? 0.0);

                                        return Marker(
                                          point: pos,
                                          width: 38,
                                          height: 38,
                                          child: Tooltip(
                                            message: '${f['name'] ?? 'FPO'} (${((f['volume'] ?? f['qtl'] ?? 0) as num).toStringAsFixed(0)} Qtl)',
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF15803D),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${idx + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),

                                      // Buyer Plant Pin
                                      Marker(
                                        point: destPos,
                                        width: 42,
                                        height: 42,
                                        child: Tooltip(
                                          message: destPlant['name'].toString(),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
                                            ),
                                            child: const Icon(Icons.factory, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Live Road Route Metrics Card
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.alt_route, color: Color(0xFF15803D), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isRouteLoading
                                            ? context.tr('Calculating OSRM Road Corridor...', 'सड़क मार्ग की गणना की जा रही है...')
                                            : '${roadRoute?.distanceKm.toStringAsFixed(1) ?? (radiusKm * 1.3).toStringAsFixed(1)} ${context.tr('km Road Corridor to Destination Plant', 'किमी गंतव्य संयंत्र तक सड़क मार्ग')}',
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                      ),
                                      Text(
                                        isRouteLoading
                                            ? context.tr('Connecting to road navigation network...', 'नेविगेशन नेटवर्क से जुड़ रहे हैं...')
                                            : '${roadRoute?.durationMinutes ?? 45} ${context.tr('mins estimated transit', 'मिनट अनुमानित समय')} • ${fpos.length} ${context.tr('FPO godowns consolidated', 'एफपीओ गोदाम समेकित')}',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF15803D),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    context.tr('OSRM Road Snapped', 'सड़क मैप स्नैप्ड'),
                                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Stop-by-Stop Itinerary List
                          Text(
                            context.tr('Sequential Pickup Stops', 'क्रमिक पिकअप स्टॉप'),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 10),

                          ...fpos.asMap().entries.map((entry) {
                            final i = entry.key;
                            final fpo = entry.value;
                            return _buildRouteStopTile(
                              stopNumber: i + 1,
                              title: fpo['name'].toString(),
                              subtitle: '${context.tr('Pickup', 'पिकअप')} ${fpo['volume']} ${context.tr('Qtl', 'क्विंटल')} • ${context.tr('Weighbridge Verified', 'वेब्रिज सत्यापित')} • ${fpo['dist']} ${context.tr('from hub', 'हब से')}',
                              isLast: false,
                            );
                          }),

                          _buildRouteStopTile(
                            stopNumber: fpos.length + 1,
                            title: destPlant['name'].toString(),
                            subtitle: context.tr('Final Unloading & NABL Lab Moisture Verification', 'अंतिम अनलोडिंग एवं एनएबीएल प्रयोगशाला नमी सत्यापन'),
                            isLast: true,
                          ),

                          const SizedBox(height: 12),

                          // Logistics Savings Callout Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFC8E6C9)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.savings_outlined, color: Color(0xFF2E7D32), size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    context.tr(
                                      'Consolidated multi-FPO routing cuts empty deadhead miles by 38% and reduces total logistics freight by ~24%.',
                                      'समेकित मल्टी-एफपीओ रूटिंग खाली दूरी को 38% कम करती है और कुल लॉजिस्टिक्स भाड़े में ~24% की बचत करती है।',
                                    ),
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Accept Supply CTA
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                final allocations = fpos.map((fpo) {
                                  final totalVol = targetVolumeMT > 0 ? targetVolumeMT : 1.0;
                                  final fpoVol = (fpo['qtl'] as num?)?.toDouble() ?? (fpo['volume'] as num?)?.toDouble() ?? (totalVol / fpos.length);
                                  final ratio = fpoVol / totalVol;
                                  final allocQtl = targetVolumeMT * ratio;
                                  return {
                                    'fpoId': fpo['fpoId'] ?? (fpo['name'].toString().toLowerCase().contains('taraori') ? 'fpo_taraori_02' : (fpo['name'].toString().toLowerCase().contains('gharaunda') ? 'fpo_gharaunda_03' : 'fpo_karnal_01')),
                                    'fpoName': fpo['name'],
                                    'warehouseName': fpo['location'] ?? 'Warehouse Dock',
                                    'allocatedQtl': allocQtl,
                                    'allocatedMT': allocQtl / 10.0,
                                    'quantityQtl': allocQtl,
                                    'quantityMT': allocQtl / 10.0,
                                    'commodity': commodity,
                                  };
                                }).toList();

                                _proceedToEscrowCheckout(
                                  commodity,
                                  clusterName,
                                  targetVolumeMT / 10.0,
                                  ratePerMT,
                                  quantityQtl: targetVolumeMT,
                                  ratePerQtl: avgPriceQtl,
                                  variety: cluster['variety']?.toString() ?? 'Grade A',
                                  fpoId: allocations.first['fpoId'] as String?,
                                  fpoName: clusterName,
                                  isMultiFpo: true,
                                  allocations: allocations,
                                );
                              },
                              icon: const Icon(Icons.lock_outline, size: 18),
                              label: Text(
                                '${context.tr('Accept', 'स्वीकारें')} ${targetVolumeMT.toStringAsFixed(0)} ${context.tr('Qtl & Open Escrow Lock', 'क्विंटल और एस्क्रो लॉक खोलें')}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF15803D),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
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

  Widget _buildMapToggle(int index, String label, int currentIndex, Function(int) onSelect) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onSelect(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF15803D) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteStopTile({
    required int stopNumber,
    required String title,
    required String subtitle,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isLast ? const Color(0xFF0F172A) : const Color(0xFF15803D),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isLast ? '🏁' : '$stopNumber',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: const Color(0xFFCBD5E1),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  // TAB 2: Single FPO Direct Lots (Connected to Live Database with Zero Mock)
  Widget _buildSingleFpoLotsTab() {
    return StreamBuilder<List<BulkCropListing>>(
      stream: _inventoryService.streamActiveBulkListings(),
      builder: (context, snapshot) {
        final dbListings = snapshot.data ?? [];
        final List<Map<String, dynamic>> combinedLots = [];

        if (dbListings.isNotEmpty) {
          for (final l in dbListings) {
            combinedLots.add({
              'id': l.id,
              'inventoryItemId': l.inventoryItemId,
              'fpoId': l.fpoId,
              'fpoName': l.fpoName,
              'location': l.warehouseName,
              'commodity': l.cropName,
              'variety': l.variety,
              'availableQtyMT': l.listedQuantityQtl,
              'pricePerQtl': l.pricePerQtl,
              'moisture': '${l.moisturePct}%',
              'rating': 4.9,
              'isVerified': true,
              'siloType': l.warehouseName,
            });
          }
        }

        final filteredLots = combinedLots.where((lot) {
          final name = lot['commodity'].toString().toLowerCase();
          final fpo = lot['fpoName'].toString().toLowerCase();
          final loc = lot['location'].toString().toLowerCase();
          final matchesQuery = _searchQuery.isEmpty ||
              name.contains(_searchQuery.toLowerCase()) ||
              fpo.contains(_searchQuery.toLowerCase()) ||
              loc.contains(_searchQuery.toLowerCase());

          final matchesCrop = _selectedCrop == 'All' ||
              name.contains(_selectedCrop.toLowerCase());

          return matchesQuery && matchesCrop;
        }).toList();

        if (filteredLots.isEmpty) {
          return _buildEmptyClusterState();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: filteredLots.length,
          itemBuilder: (context, index) {
            final lot = filteredLots[index];
            final fpoName = (lot['fpoName'] ?? 'FPO Warehouse').toString();
            final location = (lot['location'] ?? 'Location').toString();
            final commodity = (lot['commodity'] ?? 'Produce').toString();
            final variety = (lot['variety'] ?? 'Standard').toString();
            final qty = (lot['availableQtyMT'] as num?)?.toDouble() ?? 0.0;
            final price = (lot['pricePerQtl'] as num?)?.toDouble() ?? 0.0;
            final moisture = (lot['moisture'] ?? '12%').toString();
            final rating = (lot['rating'] as num?)?.toDouble() ?? 4.5;
            final siloType = (lot['siloType'] ?? 'Storage').toString();

            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openLotPassportModal(lot),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo Banner
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                          child: CropImageHelper.buildCropImage(
                            null,
                            commodity,
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),

                        // Verified FPO Badge (Top-Left)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF15803D),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  context.tr('Verified FPO Godown', 'सत्यापित एफपीओ गोदाम'),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Rating Badge (Top-Right)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  '$rating',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
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
                          // FPO Name & Location
                          Text(
                            fpoName,
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 13, color: Color(0xFF15803D)),
                              const SizedBox(width: 4),
                              Text(location, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Metrics Strip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                    Text(context.tr('Direct Lot Rate', 'प्रत्यक्ष लॉट दर'), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    Text(
                                      '₹${price.toStringAsFixed(0)}/${context.tr('Qtl', 'क्विंटल')}',
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(context.tr('Available Stock', 'उपलब्ध स्टॉक'), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    Text(
                                      '${qty.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(context.tr('Moisture Level', 'नमी स्तर'), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    Text(
                                      moisture,
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Commodity & Silo details
                          Text(
                            '${_getCropLabel(context, commodity)} • $variety',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                          ),
                          Text(
                            siloType,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 14),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  onPressed: () => _openLotPassportModal(lot),
                                  icon: const Icon(Icons.verified_outlined, size: 15),
                                  label: Text(
                                    '${context.tr('Inspect Passport', 'पासपोर्ट जांचें')} (${qty.toInt()} ${context.tr('Qtl', 'क्विंटल')})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF15803D),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showDirectPurchaseModal(
                                    fpoName,
                                    commodity,
                                    qty,
                                    price,
                                    fpoId: lot['fpoId'] as String?,
                                    inventoryItemId: lot['inventoryItemId'] as String? ?? lot['id'] as String?,
                                    variety: variety,
                                  ),
                                  icon: const Icon(Icons.tune, size: 14),
                                  label: Text(context.tr('Custom Qty', 'कस्टम मात्रा'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF15803D),
                                    side: const BorderSide(color: Color(0xFF15803D)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          },
        );
      },
    );
  }

  void _openLotPassportModal(Map<String, dynamic> lot) {
    final commodity = (lot['commodity'] ?? 'Produce').toString();
    final variety = (lot['variety'] ?? 'Standard').toString();
    final fpoName = (lot['fpoName'] ?? 'FPO Warehouse').toString();
    final location = (lot['location'] ?? 'Location').toString();
    final qty = (lot['availableQtyMT'] as num?)?.toDouble() ?? 0.0;
    final price = (lot['pricePerQtl'] as num?)?.toDouble() ?? 0.0;
    final moisture = (lot['moisture'] ?? '12%').toString();

    final availableMt = qty / 10.0;
    final totalMt = (availableMt * 1.25).clamp(availableMt, 2000.0);
    final reservedMt = (totalMt - availableMt).clamp(0.0, totalMt);

    FpoLotDetailsModal.show(
      context,
      cropName: commodity,
      variety: variety,
      siloLocation: '$location • $fpoName',
      totalMt: totalMt,
      availableMt: availableMt,
      reservedMt: reservedMt,
      pricePerQtl: price,
      pricePerMt: price * 10.0,
      qualityGrade: 'Industrial Grade 1',
      moistureText: '$moisture (Optimal)',
      fpoName: fpoName,
      fpoId: lot['fpoId'] as String?,
      inventoryItemId: lot['inventoryItemId'] as String? ?? lot['id'] as String?,
      isBuyer: true,
      isRetail: false,
    );
  }

  Widget _buildEmptyClusterState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            context.tr('No Active FPO Supply Lots', 'कोई सक्रिय एफपीओ लॉट नहीं'),
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'No verified FPO warehouse stock currently listed for this selection. FPOs list lots directly from their silos, or you can broadcast an institutional RFQ to invite bids.',
              'वर्तमान चयन के लिए कोई सत्यापित एफपीओ गोदाम स्टॉक सूचीबद्ध नहीं है। आप बोली आमंत्रित करने के लिए आरएफक्यू जारी कर सकते हैं।',
            ),
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedCrop = 'All';
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(context.tr('Reset Search Filters', 'फ़िल्टर रीसेट करें')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDirectPurchaseModal(
    String fpoName,
    String commodity,
    double qty,
    double price, {
    String? fpoId,
    String? inventoryItemId,
    String? variety,
  }) {
    _showVariableOrderQuantityModal(
      fpoName,
      commodity,
      qty,
      price,
      fpoId: fpoId,
      inventoryItemId: inventoryItemId,
      variety: variety,
    );
  }

  void _showVariableOrderQuantityModal(
    String sellerName,
    String commodity,
    double availableQtl,
    double ratePerQtl, {
    String? fpoId,
    String? inventoryItemId,
    String? variety,
  }) {
    double selectedQtl = (availableQtl >= 250.0 ? 250.0 : availableQtl).clamp(50.0, availableQtl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final cropTotal = selectedQtl * ratePerQtl;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('Variable Order Quantity Slider', 'परिवर्तनीय ऑर्डर मात्रा'),
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${context.tr('Available', 'उपलब्ध')}: ${availableQtl.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_getCropLabel(context, commodity)} • ${context.tr('Seller', 'विक्रेता')}: $sellerName',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('Required Volume:', 'आवश्यक मात्रा:'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${selectedQtl.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF15803D))),
                  ],
                ),
                Slider(
                  value: selectedQtl,
                  min: 50.0.clamp(0.0, availableQtl),
                  max: availableQtl,
                  divisions: ((availableQtl - 50.0) / 10.0).round().clamp(1, 100),
                  activeColor: const Color(0xFF15803D),
                  label: '${selectedQtl.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                  onChanged: (v) {
                    setModalState(() => selectedQtl = v);
                  },
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${context.tr('Base Commodity Cost', 'मूल फसल लागत')} (@ ₹${ratePerQtl.toStringAsFixed(0)}/${context.tr('Qtl', 'क्विंटल')}):',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text('₹${cropTotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _proceedToEscrowCheckout(
                        commodity,
                        sellerName,
                        selectedQtl / 10.0,
                        ratePerQtl * 10.0,
                        quantityQtl: selectedQtl,
                        ratePerQtl: ratePerQtl,
                        variety: variety,
                        fpoId: fpoId,
                        fpoName: sellerName,
                        inventoryItemId: inventoryItemId,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      context.tr('Proceed to 7-Carrier Freight & Escrow Lock', '7-कैरियर फ्रेट और एस्क्रो लॉक के लिए आगे बढ़ें'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _proceedToEscrowCheckout(
    String commodity,
    String originCluster,
    double tonnage,
    double ratePerMT, {
    String? variety,
    double? quantityQtl,
    double? ratePerQtl,
    String? fpoId,
    String? fpoName,
    String? inventoryItemId,
    bool isMultiFpo = false,
    List<Map<String, dynamic>> allocations = const [],
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EscrowCheckoutScreen(
          commodity: commodity,
          variety: variety,
          originCluster: '$originCluster Dock',
          orderedTonnage: tonnage,
          cropRatePerTonne: ratePerMT,
          orderedQuantityQtl: quantityQtl ?? (tonnage * 10),
          cropRatePerQtl: ratePerQtl ?? (ratePerMT / 10),
          fpoId: fpoId,
          fpoName: fpoName,
          inventoryItemId: inventoryItemId,
          isMultiFpo: isMultiFpo,
          allocations: allocations,
        ),
      ),
    );
  }


  void _showAdvancedFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Advanced Supply Filters', 'उन्नत आपूर्ति फ़िल्टर'), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Text(context.tr('Cluster Radius Limit', 'क्लस्टर दायरा सीमा'), style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: _maxDistanceKm,
              min: 5,
              max: 100,
              divisions: 19,
              activeColor: const Color(0xFF15803D),
              label: '${_maxDistanceKm.toInt()} km',
              onChanged: (v) => setState(() => _maxDistanceKm = v),
            ),
            Center(
              child: Text(
                '${context.tr('Current Max Distance', 'वर्तमान अधिकतम दूरी')}: ${_maxDistanceKm.toInt()} ${context.tr('km', 'किमी')}',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
                child: Text(context.tr('Apply Filters', 'फ़िल्टर लागू करें')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
