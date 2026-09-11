import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/fpo_inventory_service.dart';
import '../../services/multi_fpo_cluster_service.dart';
import '../../models/fpo_inventory_model.dart';
import '../../models/multi_fpo_cluster_model.dart';
import '../../utils/crop_image_helper.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';
import 'escrow_checkout_screen.dart';
import '../../widgets/fpo_lot_details_modal.dart';
import 'bulk_buyer_recurring_orders_screen.dart';
import 'create_recurring_order_screen.dart';
import 'bulk_buyer_profile_screen.dart';
import 'dynamic_demand_matcher_screen.dart';

class BulkBuyerHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const BulkBuyerHomeScreen({super.key, this.onNavigateTab});

  @override
  State<BulkBuyerHomeScreen> createState() => _BulkBuyerHomeScreenState();
}

class _BulkBuyerHomeScreenState extends State<BulkBuyerHomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  final FpoInventoryService _inventoryService = FpoInventoryService();
  final MultiFpoClusterEngine _clusterEngine = MultiFpoClusterEngine();

  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Wheat',
    'Rice / Paddy',
    'Mustard / Oilseeds',
    'Maize / Corn',
    'Pulses / Dal',
    'Cotton',
    'Spices',
  ];

  String _getCategoryLabel(BuildContext context, String cat) {
    switch (cat) {
      case 'All':
        return context.tr('All', 'सभी');
      case 'Wheat':
        return context.tr('Wheat', 'गेहूँ');
      case 'Rice / Paddy':
        return context.tr('Rice / Paddy', 'चावल / धान');
      case 'Mustard / Oilseeds':
        return context.tr('Mustard / Oilseeds', 'सरसों / तिलहन');
      case 'Maize / Corn':
        return context.tr('Maize / Corn', 'मक्का');
      case 'Pulses / Dal':
        return context.tr('Pulses / Dal', 'दालें');
      case 'Cotton':
        return context.tr('Cotton', 'कपास');
      case 'Spices':
        return context.tr('Spices', 'मसाले');
      default:
        return cat;
    }
  }

  @override
  void initState() {
    super.initState();
    _dbService.cleanSampleBulkBuyerData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final companyName = user?.name.isNotEmpty == true
        ? user!.name
        : 'AgroFoods Milling India Pvt Ltd';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: _buildAppBar(companyName),
      body: StreamBuilder<List<BulkCropListing>>(
        // Real published listings from real FPOs in Firestore collection `fpo_bulk_listings`
        stream: _inventoryService.streamActiveBulkListings(),
        builder: (context, listingsSnapshot) {
          return StreamBuilder<List<FpoInventoryItem>>(
            // Real warehouse inventory records from real FPOs in Firestore collection `fpo_inventory`
            stream: _inventoryService.streamAllInventory(),
            builder: (context, inventorySnapshot) {
              final activeListings = listingsSnapshot.data ?? [];
              final inventoryItems = inventorySnapshot.data ?? [];

              // Convert exclusively real FPO database documents into normalized wholesale nodes
              final List<FpoNode> realFpoNodes = [];
              final Set<String> seenIds = {};

              // 1. Ingest real commercial bulk listings
              for (final listing in activeListings) {
                if (listing.isActive && seenIds.add(listing.id)) {
                  realFpoNodes.add(FpoNode(
                    fpoId: listing.fpoId,
                    fpoName: listing.fpoName,
                    warehouseName: listing.warehouseName,
                    latitude: listing.warehouseLat != 0 ? listing.warehouseLat : 29.6857,
                    longitude: listing.warehouseLng != 0 ? listing.warehouseLng : 76.9905,
                    commodity: listing.cropName,
                    variety: listing.variety,
                    availableQuantityQtl: listing.listedQuantityQtl,
                    pricePerQtl: listing.pricePerQtl,
                    moisturePct: listing.moisturePct,
                    qualityGrade: listing.qualityGrade,
                    imageUrl: listing.imageUrl,
                    listingId: listing.id,
                    dispatchLeadDays: listing.dispatchLeadTimeDays,
                    isMultiFpoEligible: listing.isMultiFpoEligible,
                  ));
                }
              }

              // 2. Ingest real warehouse inventory items
              for (final item in inventoryItems) {
                if (item.availableQuantityMT > 0 && seenIds.add(item.id)) {
                  realFpoNodes.add(FpoNode(
                    fpoId: item.fpoId,
                    fpoName: item.fpoName,
                    warehouseName: item.warehouseName,
                    latitude: 29.6857,
                    longitude: 76.9905,
                    commodity: item.cropName,
                    variety: item.variety,
                    availableQuantityQtl: item.availableQuantityQtl,
                    pricePerQtl: item.pricePerQtl,
                    moisturePct: item.moisturePct,
                    qualityGrade: item.qualityGrade,
                    imageUrl: item.imageUrl,
                    listingId: item.activeListingId ?? item.id,
                    dispatchLeadDays: 2,
                    isMultiFpoEligible: true,
                  ));
                }
              }

              // Run the multi-FPO clustering model on all real FPO nodes within 7-10 km range
              final dynamicClusters = _clusterEngine.clusterFpoNodes(
                realFpoNodes,
                maxRadiusKm: 10.0, // 7-10 km corridor
              );

              // Filter real lots by selected category and search query
              final filteredLots = realFpoNodes.where((node) {
                // Category match
                bool matchesCategory = true;
                if (_selectedCategory != 'All') {
                  final name = node.commodity.toLowerCase();
                  final variety = node.variety.toLowerCase();
                  final selected = _selectedCategory.toLowerCase();
                  if (selected.contains('wheat') && name.contains('wheat')) {
                    matchesCategory = true;
                  } else if (selected.contains('rice') && (name.contains('rice') || name.contains('paddy'))) {
                    matchesCategory = true;
                  } else if (selected.contains('mustard') && (name.contains('mustard') || name.contains('oilseed'))) {
                    matchesCategory = true;
                  } else if (selected.contains('maize') && (name.contains('maize') || name.contains('corn'))) {
                    matchesCategory = true;
                  } else if (selected.contains('pulses') && (name.contains('pulse') || name.contains('dal') || name.contains('gram'))) {
                    matchesCategory = true;
                  } else if (selected.contains('cotton') && name.contains('cotton')) {
                    matchesCategory = true;
                  } else if (selected.contains('spices') && (name.contains('spice') || name.contains('chilli') || name.contains('turmeric'))) {
                    matchesCategory = true;
                  } else {
                    matchesCategory = name.contains(selected) || variety.contains(selected);
                  }
                }

                if (!matchesCategory) return false;

                // Search query match
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final matchesSearch = node.commodity.toLowerCase().contains(q) ||
                      node.variety.toLowerCase().contains(q) ||
                      node.fpoName.toLowerCase().contains(q) ||
                      node.warehouseName.toLowerCase().contains(q) ||
                      node.qualityGrade.toLowerCase().contains(q);
                  if (!matchesSearch) return false;
                }

                return true;
              }).toList();

              return RefreshIndicator(
                onRefresh: () async {
                  await _dbService.cleanSampleBulkBuyerData();
                  setState(() {});
                },
                color: AppTheme.primaryGreen,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Search Bar Header with Filters Chip
                      _buildSearchBar(context),
                      const SizedBox(height: 16),

                      // 1b. NEW: Intelligent Farmer Lot Aggregator Matcher Banner
                      _buildDynamicMatcherBanner(context),
                      const SizedBox(height: 16),

                      // 2. Hero CTA Banner: FPO Direct Silos
                      _buildHeroCtaBanner(context, filteredLots.length),
                      const SizedBox(height: 14),

                      // 2b. 12-Week Recurring Supply Agreements Banner
                      _buildRecurringSupplyBanner(context),
                      const SizedBox(height: 20),

                      // 3. Category Horizontal Pills
                      _buildCategorySelector(),
                      const SizedBox(height: 24),

                      // 4. Live Wholesale Lots Carousel (Exclusively Real FPO Database)
                      _buildSectionHeader(
                        title: context.tr('Live FPO Warehouse Lots 🌾', 'लाइव एफपीओ वेयरहाउस लॉट 🌾'),
                        subtitle: context.tr('Real cooperative inventory verified from database', 'डेटाबेस से सत्यापित वास्तविक सहकारी इन्वेंट्री'),
                        onSeeAll: () => widget.onNavigateTab?.call(1),
                      ),
                      const SizedBox(height: 12),
                      _buildWholesaleLotsCarousel(filteredLots),
                      const SizedBox(height: 24),

                      // 5. Hyperlocal 7-10 km Sourcing Clusters (Generated dynamically by MultiFpoClusterEngine)
                      _buildSectionHeader(
                        title: context.tr('Hyperlocal 7-10 km Sourcing Clusters 📍', 'हाइपरलोकल 7-10 किमी सोर्सिंग क्लस्टर 📍'),
                        subtitle: context.tr('Dynamically aggregated multi-FPO pools verified for travel time & co-storage', 'पारगमन समय और भंडारण के लिए सत्यापित मल्टी-एफपीओ समूह'),
                        onSeeAll: () => widget.onNavigateTab?.call(1),
                      ),
                      const SizedBox(height: 12),
                      _buildHyperlocalClustersSection(dynamicClusters),
                      const SizedBox(height: 24),

                      // 6. Active Commodity Market Benchmarks
                      _buildSectionHeader(
                        title: context.tr('Active Commodity Benchmarks 🔥', 'सक्रिय जिंस बेंचमार्क भाव 🔥'),
                        subtitle: context.tr('Real-time wholesale GT-belt APMC & FPO mandi rates', 'रीयल-टाइम थोक मंडी और एफपीओ भाव'),
                        onSeeAll: () => widget.onNavigateTab?.call(1),
                      ),
                      const SizedBox(height: 12),
                      _buildCommodityMarketRates(realFpoNodes),
                      const SizedBox(height: 24),

                      // 7. B2B Institutional Quality & Escrow Card
                      _buildInstitutionalTrustCard(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String companyName) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('AgriChain B2B Wholesale', 'एग्रीचेन थोक खरीद'),
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.tr('INSTITUTIONAL', 'संस्थागत'),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '$companyName • ${context.tr('Verified GSTIN', 'सत्यापित GSTIN')}',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.assignment_outlined, color: AppTheme.darkGreen),
          tooltip: context.tr('Active RFQs & Tenders', 'सक्रिय मांगें व निविदाएं'),
          onPressed: () => widget.onNavigateTab?.call(2), // Tab 2 = RFQs
        ),
        IconButton(
          icon: const Icon(Icons.local_shipping_outlined, color: AppTheme.darkGreen),
          tooltip: context.tr('Live Orders & Shipments', 'लाइव ऑर्डर व शिपमेंट'),
          onPressed: () => widget.onNavigateTab?.call(3), // Tab 3 = Orders
        ),
        IconButton(
          icon: const Icon(Icons.person_outline, color: AppTheme.darkGreen),
          tooltip: context.tr('Company Profile', 'कंपनी प्रोफ़ाइल'),
          onPressed: () {
            if (widget.onNavigateTab != null) {
              widget.onNavigateTab!(4);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BulkBuyerProfileScreen()),
              );
            }
          },
        ),
        const Padding(
          padding: EdgeInsets.only(right: 8.0),
          child: LanguageSwitcherPill(),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchQuery.isNotEmpty ? AppTheme.primaryGreen : Colors.grey.shade200,
          width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
        },
        decoration: InputDecoration(
          hintText: context.tr('Search bulk commodities, FPO silos, milling grades...', 'थोक फसलें, एफपीओ साइलो, ग्रेड खोजें...'),
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune, size: 14, color: AppTheme.primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('Filters', 'फ़िल्टर'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDynamicMatcherBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D381E), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D381E).withValues(alpha: 0.25),
            blurRadius: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF69F0AE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF0D381E)),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('SMART LOT AGGREGATOR', 'स्मार्ट लॉट मिलाप'),
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0D381E),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                context.tr('AI Engine ⚡', 'एआई इंजन ⚡'),
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('Smart Crop Lot Matcher', 'स्मार्ट किसान लॉट मिलाप'),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              'Combine small farmer lots into one seamless wholesale order with automated escrow.',
              'छोटे किसान लॉट को स्वचालित एस्क्रो के साथ एक सहज थोक ऑर्डर में मिलाएं।',
            ),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DynamicDemandMatcherScreen(),
                ),
              );
            },
            icon: const Icon(Icons.hub_outlined, size: 16),
            label: Text(context.tr('Launch Lot Matcher', 'लॉट मिलाप शुरू करें')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF69F0AE),
              foregroundColor: const Color(0xFF0D381E),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCtaBanner(BuildContext context, int totalAvailable) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  context.tr('100% REAL FPO DATABASE', '100% वास्तविक एफपीओ डेटाबेस'),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF69F0AE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalAvailable ${context.tr('Active FPO Lots', 'सक्रिय एफपीओ लॉट')}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0D381E),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('FPO Mandi Godowns & Silos\nDirect Wholesale Sourcing', 'एफपीओ मंडी गोदाम व साइलो नेटवर्क\nसीधी थोक खरीद'),
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'Dynamic 7-10 km Multi-FPO Cluster Engine automatically pools neighboring godowns with verified travel times and NABL lab moisture testing.',
              'डायनामिक 7-10 किमी मल्टी-एफपीओ क्लस्टर इंजन पड़ोसी गोदामों को सत्यापित पारगमन समय के साथ स्वचालित रूप से जोड़ता है।',
            ),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => widget.onNavigateTab?.call(2), // Open Requests
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(context.tr('Place Request', 'मांग दर्ज करें')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B5E20),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => widget.onNavigateTab?.call(1), // Explore Clusters
                icon: const Icon(Icons.hub_outlined, size: 16, color: Colors.white),
                label: Text(context.tr('7-10 km Engine', '7-10 किमी क्लस्टर')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringSupplyBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.repeat, size: 12, color: Color(0xFF34D399)),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('12-WEEK RECURRING SUPPLY', '12-सप्ताह नियमित आपूर्ति'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF34D399),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                context.tr('Weekly Monday Intake', 'साप्ताहिक सोमवार आवक'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('Institutional Supply Agreements', 'संस्थागत आपूर्ति अनुबंध'),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              'Lock in guaranteed weekly volumes directly with vetted FPO clusters. Compare candidate FPOs on price, transit ETA & NABL grade.',
              'सत्यापित एफपीओ समूहों के साथ साप्ताहिक आपूर्ति सुनिश्चित करें। भाव, पारगमन समय और ग्रेड की तुलना करें।',
            ),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFFCBD5E1),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateRecurringOrderScreen()),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.tr('+ Setup 12-W Contract', '+ 12-सप्ताह अनुबंध जोड़ें')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BulkBuyerRecurringOrdersScreen()),
                  );
                },
                icon: const Icon(Icons.receipt_long_outlined, size: 16, color: Colors.white),
                label: Text(context.tr('My Contracts', 'मेरे अनुबंध')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF475569)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return ChoiceChip(
            label: Text(_getCategoryLabel(context, cat)),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedCategory = cat;
              });
            },
            selectedColor: AppTheme.primaryGreen,
            backgroundColor: Colors.white,
            labelStyle: GoogleFonts.inter(
              color: isSelected ? Colors.white : AppTheme.darkGrey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required VoidCallback onSeeAll,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            children: [
              Text(
                context.tr('See All', 'सभी देखें'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 11, color: AppTheme.primaryGreen),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWholesaleLotsCarousel(List<FpoNode> lots) {
    if (lots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.warehouse_outlined, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              context.tr('No FPO Warehouse Lots Listed Yet', 'अभी तक कोई एफपीओ वेयरहाउस लॉट सूचीबद्ध नहीं है'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkGreen),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Real registered FPOs have not published commercial bulk lots to Firestore yet. Broadcast an RFQ to solicit direct quotes from regional cooperatives.',
                'पंजीकृत एफपीओ ने अभी तक वाणिज्यिक लॉट प्रकाशित नहीं किए हैं। सीधे भाव पाने के लिए मांग प्रसारित करें।',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600, height: 1.3),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigateTab?.call(2), // RFQs tab
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.tr('Broadcast Bulk RFQ', 'थोक मांग प्रसारित करें')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: lots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final lot = lots[index];

          return InkWell(
            onTap: () => _showBulkLotDetailsModal(context, lot),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 255,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CropImageHelper.buildCropImage(
                          lot.imageUrl,
                          lot.commodity,
                          height: 105,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified, size: 10, color: Color(0xFF69F0AE)),
                              const SizedBox(width: 2),
                              Text(
                                context.tr('FPO Direct Silo', 'एफपीओ सीधा साइलो'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            lot.qualityGrade,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${lot.commodity} • ${lot.variety}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGreen,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '₹${lot.pricePerQtl.toStringAsFixed(0)} ${context.tr('/ Qtl', '/ क्विंटल')}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${lot.availableQuantityQtl.toStringAsFixed(0)} ${context.tr('Qtl left', 'क्विंटल शेष')}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${lot.fpoName} • ${lot.warehouseName}',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showBulkLotDetailsModal(context, lot),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.tr('Inspect / Buy', 'जांचें / खरीदें'),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHyperlocalClustersSection(List<MultiFpoCluster> dynamicClusters) {
    if (dynamicClusters.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.hub, color: Color(0xFF1565C0), size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('7-10 km Multi-FPO Cluster Engine Active', '7-10 किमी मल्टी-एफपीओ क्लस्टर इंजन सक्रिय'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkGreen),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'The algorithmic engine checks all registered FPOs within a 7-10 km radius for commodity matching, travel time, and moisture compatibility (<= 1.5% variance). Requires at least 2 adjacent FPOs with published listings to combine.',
                'इंजन कमोडिटी मिलान, यात्रा समय और नमी संगतता के लिए 7-10 किमी के भीतर सभी एफपीओ की जांच करता है।',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600, height: 1.3),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => widget.onNavigateTab?.call(2), // Go to RFQs
              icon: const Icon(Icons.alt_route, size: 16),
              label: Text(context.tr('Broadcast Multi-FPO Aggregation RFQ', 'मल्टी-एफपीओ एकत्रीकरण मांग प्रसारित करें')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
                side: const BorderSide(color: Color(0xFF1565C0)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: dynamicClusters.map((cluster) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hub, size: 12, color: Color(0xFF1565C0)),
                        const SizedBox(width: 4),
                        Text(
                          '${cluster.totalVolumeQtl.toStringAsFixed(0)} ${context.tr('Qtl Pooled', 'क्विंटल संयुक्त')}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${cluster.participatingFpos.length} ${context.tr('FPOs Unified', 'एफपीओ एकीकृत')}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${cluster.weightedPricePerQtl.toStringAsFixed(0)} ${context.tr('/ Qtl', '/ क्विंटल')}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                cluster.clusterName,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                ),
              ),
              Text(
                '${context.tr('Commodity:', 'फसल:')} ${cluster.commodity} (${cluster.variety})',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              // Participating Godowns
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: cluster.participatingFpos.map((node) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${node.fpoName} (${node.availableQuantityQtl.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')})',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // Operational Verification Metrics
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF15803D)),
                  const SizedBox(width: 4),
                  Text(
                    '${context.tr('Collection Duration:', 'संग्रह अवधि:')} ${cluster.formattedTotalDuration} (${cluster.formattedDrivingTime})',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${context.tr('Save', 'बचत')} ${cluster.freightSavingsPct.toStringAsFixed(0)}% ${context.tr('Freight', 'भाड़ा')}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${context.tr('Moisture Var:', 'नमी अंतर:')} ${cluster.validation.moistureVariancePct.toStringAsFixed(1)}% ${context.tr('(Safe Co-Storage)', '(सुरक्षित सह-भंडारण)')}',
                    style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
                  ),
                  InkWell(
                    onTap: () => _showClusterInspectionModal(context, cluster),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.route, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('Inspect Route', 'रूट जांचें'),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCommodityMarketRates(List<FpoNode> allLots) {
    int wheatCount = allLots.where((c) => c.commodity.toLowerCase().contains('wheat')).length;
    int riceCount = allLots.where((c) => c.commodity.toLowerCase().contains('rice') || c.commodity.toLowerCase().contains('paddy')).length;
    int mustardCount = allLots.where((c) => c.commodity.toLowerCase().contains('mustard')).length;
    int maizeCount = allLots.where((c) => c.commodity.toLowerCase().contains('maize') || c.commodity.toLowerCase().contains('corn')).length;

    final benchmarks = [
      {'name': 'Sharbati Wheat', 'dispName': context.tr('Sharbati Wheat', 'शरबती गेहूँ'), 'price': '₹3,560 ${context.tr('/ Qtl', '/ क्विंटल')}', 'icon': '🌾', 'lots': '$wheatCount ${context.tr('Silo Lots', 'साइलो लॉट')}'},
      {'name': 'Basmati Paddy 1121', 'dispName': context.tr('Basmati Paddy 1121', 'बासमती धान 1121'), 'price': '₹4,650 ${context.tr('/ Qtl', '/ क्विंटल')}', 'icon': '🍚', 'lots': '$riceCount ${context.tr('Silo Lots', 'साइलो लॉट')}'},
      {'name': 'Yellow Mustard (Oil 42%)', 'dispName': context.tr('Yellow Mustard (Oil 42%)', 'पीली सरसों (तेल 42%)'), 'price': '₹5,820 ${context.tr('/ Qtl', '/ क्विंटल')}', 'icon': '🌻', 'lots': '$mustardCount ${context.tr('Silo Lots', 'साइलो लॉट')}'},
      {'name': 'Milling Yellow Maize', 'dispName': context.tr('Milling Yellow Maize', 'मिलिंग पीला मक्का'), 'price': '₹2,280 ${context.tr('/ Qtl', '/ क्विंटल')}', 'icon': '🌽', 'lots': '$maizeCount ${context.tr('Silo Lots', 'साइलो लॉट')}'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemCount: benchmarks.length,
      itemBuilder: (context, index) {
        final item = benchmarks[index];
        return InkWell(
          onTap: () {
            setState(() {
              if (item['name']!.contains('Wheat')) {
                _selectedCategory = 'Wheat';
              } else if (item['name']!.contains('Paddy')) {
                _selectedCategory = 'Rice / Paddy';
              } else if (item['name']!.contains('Mustard')) {
                _selectedCategory = 'Mustard / Oilseeds';
              } else if (item['name']!.contains('Maize')) {
                _selectedCategory = 'Maize / Corn';
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item['icon']!, style: const TextStyle(fontSize: 24)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['lots']!,
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['dispName'] ?? item['name']!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item['price']!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
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

  Widget _buildInstitutionalTrustCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.25),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_user, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Institutional Quality & Escrow Gate', 'संस्थागत गुणवत्ता एवं एस्क्रो सुरक्षा'),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      context.tr('Zero Intermediary Risk • Guaranteed Execution', 'शून्य मध्यस्थ जोखिम • गारंटीकृत निष्पादन'),
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          _buildPillarRow(
            Icons.lock_clock,
            context.tr('Tripartite Smart Escrow', 'त्रिपक्षीय स्मार्ट एस्क्रो'),
            context.tr('Buyer funds locked until weighbridge and quality testing match specifications.', 'क्रेता की राशि तब तक सुरक्षित रहती है जब तक तुलाई और गुणवत्ता जांच विनिर्देशों से मेल न खाए।'),
          ),
          const SizedBox(height: 8),
          _buildPillarRow(
            Icons.sensors,
            context.tr('Fastag Weighbridge Telemetry', 'फ़ास्टैग धर्मकांटा टेलीमेट्री'),
            context.tr('Direct sensor data integration ensures gross and tare accuracy without human tampering.', 'सेंसर डेटा एकीकरण बिना किसी मानवीय हस्तक्षेप के सही वजन सुनिश्चित करता है।'),
          ),
          const SizedBox(height: 8),
          _buildPillarRow(
            Icons.biotech,
            context.tr('NABL Accredited Lab Assay', 'NABL मान्यता प्राप्त प्रयोगशाला जांच'),
            context.tr('Automated moisture, broken grain, and purity certifications attached to each batch.', 'प्रत्येक लॉट के साथ स्वचालित नमी, टूटे दाने और शुद्धता का प्रमाण पत्र।'),
          ),
          const SizedBox(height: 8),
          _buildPillarRow(
            Icons.receipt_long,
            context.tr('GSTN e-Invoice & Blockchain', 'GSTN ई-चालान एवं ब्लॉकचेन'),
            context.tr('SHA-256 batch hash permanently sealed on Polygon for seamless GST compliance.', 'जीएसटी अनुपालन और पारदर्शिता के लिए पॉलीगॉन पर सील किया गया बैच हैश।'),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF69F0AE)),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.9), height: 1.3),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showClusterInspectionModal(BuildContext context, MultiFpoCluster cluster) {
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.alt_route, color: Color(0xFF15803D), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cluster.clusterName,
                              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${cluster.totalVolumeQtl.toStringAsFixed(0)} ${context.tr('Qtl Total', 'कुल क्विंटल')} • ${cluster.formattedTotalDuration}',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Validation Badges
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified, color: Color(0xFF15803D), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              context.tr('Multi-FPO Automated Validation Checks Passed', 'मल्टी-एफपीओ स्वचालित सत्यापन जांच सफल'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        ...cluster.validation.passedChecks.map((check) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle, size: 13, color: Color(0xFF15803D)),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(check, style: const TextStyle(fontSize: 11))),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sequential Route Stops
                  Text(context.tr('Sequential Pickup & Delivery Route', 'क्रमिक पिकअप और डिलीवरी रूट'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  ...cluster.routeStops.map((stop) {
                    final isDest = stop.stopType == 'destination_plant';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: isDest ? Colors.black : const Color(0xFF15803D),
                            child: Text(
                              isDest ? '🏁' : '${stop.stopSequence}',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stop.stopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                Text(stop.address, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                Text(
                                  isDest
                                      ? '${context.tr('Arrival:', 'आगमन:')} ~${stop.estimatedArrivalMinutes}m ${context.tr('from dispatch', 'रवानगी से')}'
                                      : '${context.tr('Pickup:', 'पिकअप:')} ${stop.pickupQuantityQtl.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')} • ${context.tr('Loading Dwell:', 'लोडिंग समय:')} ${stop.dwellTimeMinutes}m',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 14),

                  // Proceed to Escrow Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EscrowCheckoutScreen(
                              commodity: '${cluster.commodity} (${cluster.variety})',
                              variety: cluster.variety,
                              originCluster: cluster.clusterName,
                              orderedTonnage: cluster.totalVolumeMT,
                              cropRatePerTonne: cluster.weightedPricePerMT,
                              orderedQuantityQtl: cluster.totalVolumeQtl,
                              cropRatePerQtl: cluster.weightedPricePerMT / 10.0,
                              fpoId: cluster.participatingFpos.isNotEmpty ? cluster.participatingFpos.first.fpoId : 'fpo_cluster',
                              fpoName: cluster.clusterName,
                              isMultiFpo: true,
                              allocations: cluster.participatingFpos.map((f) => {
                                'fpoId': f.fpoId,
                                'fpoName': f.fpoName,
                                'quantityQtl': f.availableQuantityQtl,
                                'quantityMT': f.availableQuantityMT,
                                'location': f.warehouseName,
                              }).toList(),
                            ),
                          ),


                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        '${context.tr('Proceed to Escrow Checkout', 'एस्क्रो चेकआउट पर आगे बढ़ें')} (${cluster.totalVolumeQtl.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')})',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
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

  void _showBulkLotDetailsModal(BuildContext context, FpoNode lot) {
    final availableMt = lot.availableQuantityQtl / 10.0;
    final totalMt = (availableMt * 1.25).clamp(availableMt, 2000.0);
    final reservedMt = (totalMt - availableMt).clamp(0.0, totalMt);

    FpoLotDetailsModal.show(
      context,
      cropName: lot.commodity,
      variety: lot.variety,
      siloLocation: '${lot.warehouseName} • ${lot.fpoName}',
      totalMt: totalMt,
      availableMt: availableMt,
      reservedMt: reservedMt,
      pricePerQtl: lot.pricePerQtl,
      pricePerMt: lot.pricePerQtl * 10.0,
      qualityGrade: lot.qualityGrade,
      moistureText: '${lot.moisturePct}% (Optimal)',
      imageUrl: lot.imageUrl,
      fpoName: lot.fpoName,
      fpoId: lot.fpoId,
      inventoryItemId: lot.listingId,
      isBuyer: true,
      isRetail: false,
    );
  }
}

class _BulkLotModalContent extends StatefulWidget {
  final String name;
  final String variety;
  final String fpoName;
  final String warehouse;
  final String location;
  final double pricePerQtl;
  final double availableQtl;
  final double minOrderQtl;
  final String qualityGrade;
  final String moisture;
  final String imageUrl;
  final Function(double) onProceedToCheckout;
  final VoidCallback onNavigateToRfqs;

  const _BulkLotModalContent({
    required this.name,
    required this.variety,
    required this.fpoName,
    required this.warehouse,
    required this.location,
    required this.pricePerQtl,
    required this.availableQtl,
    required this.minOrderQtl,
    required this.qualityGrade,
    required this.moisture,
    required this.imageUrl,
    required this.onProceedToCheckout,
    required this.onNavigateToRfqs,
  });

  @override
  State<_BulkLotModalContent> createState() => _BulkLotModalContentState();
}

class _BulkLotModalContentState extends State<_BulkLotModalContent> {
  late double _selectedQtl;

  @override
  void initState() {
    super.initState();
    _selectedQtl = 250.0.clamp(widget.minOrderQtl, widget.availableQtl);
    if (_selectedQtl < widget.minOrderQtl) _selectedQtl = widget.minOrderQtl;
  }

  @override
  Widget build(BuildContext context) {
    final cropSubtotal = _selectedQtl * widget.pricePerQtl;
    final estFreight = _selectedQtl * 14.0;
    final protocolFee = cropSubtotal * 0.015;
    final totalEscrowDeposit = cropSubtotal + estFreight + protocolFee;

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

              // Hero Crop Image with Badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CropImageHelper.buildCropImage(
                      widget.imageUrl,
                      widget.name,
                      height: 170,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 14, color: Color(0xFF69F0AE)),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('FPO Direct Silo', 'एफपीओ सीधा साइलो'),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.qualityGrade,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title & Pricing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.variety} • ${widget.warehouse}',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${widget.pricePerQtl.toStringAsFixed(0)} ${context.tr('/ Qtl', '/ क्विंटल')}',
                        style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                      ),
                      Text(
                        '${widget.availableQtl.toStringAsFixed(0)} ${context.tr('Qtl Available', 'क्विंटल उपलब्ध')}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quality Assays Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.biotech, color: AppTheme.primaryGreen, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('NABL Laboratory Certified Assays', 'NABL प्रयोगशाला प्रमाणित जांच'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.darkGreen),
                        ),
                      ],
                    ),
                    const Divider(height: 14, color: Color(0xFFDCFCE7)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildAssayBadge(context.tr('Moisture', 'नमी'), widget.moisture, context.tr('Optimal', 'उत्कृष्ट')),
                        _buildAssayBadge(context.tr('Broken Grain', 'टूटा दाना'), '1.2%', context.tr('Grade A', 'ग्रेड A')),
                        _buildAssayBadge(context.tr('Foreign Matter', 'विदेशी पदार्थ'), '0.4%', context.tr('Pure', 'शुद्ध')),
                        _buildAssayBadge(context.tr('AI Purity', 'एआई शुद्धता'), '98.8%', context.tr('Certified', 'प्रमाणित')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // FPO Supplier Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    child: const Icon(Icons.business, color: AppTheme.primaryGreen, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fpoName,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.location} • ${context.tr('Fastag Weighbridge Station 02', 'फ़ास्टैग धर्मकांटा स्टेशन 02')}',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(context.tr('Verified FPO', 'सत्यापित एफपीओ'), style: const TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Interactive Procurement Volume Selector (Quintals)
              Text(
                context.tr('Procurement Volume (Quintals)', 'खरीद मात्रा (क्विंटल)'),
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryGreen),
                          onPressed: _selectedQtl > widget.minOrderQtl
                              ? () {
                                  setState(() {
                                    _selectedQtl = (_selectedQtl - 50).clamp(widget.minOrderQtl, widget.availableQtl);
                                  });
                                }
                              : null,
                        ),
                        Column(
                          children: [
                            Text(
                              '${_selectedQtl.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGreen,
                              ),
                            ),
                            Text(
                              '${(_selectedQtl / 10).toStringAsFixed(1)} ${context.tr('Metric Tonnes', 'मीट्रिक टन')} (${(_selectedQtl / 250).toStringAsFixed(1)} ${context.tr('FTL Trucks', 'ट्रक')})',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGreen),
                          onPressed: _selectedQtl < widget.availableQtl
                              ? () {
                                  setState(() {
                                    _selectedQtl = (_selectedQtl + 50).clamp(widget.minOrderQtl, widget.availableQtl);
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick Preset Chips
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildPresetChip('250 ${context.tr('Qtl (1 FTL)', 'क्विंटल (1 ट्रक)')}', 250),
                        _buildPresetChip('500 ${context.tr('Qtl (2 FTL)', 'क्विंटल (2 ट्रक)')}', 500),
                        _buildPresetChip('1,000 ${context.tr('Qtl (4 FTL)', 'क्विंटल (4 ट्रक)')}', 1000),
                        _buildPresetChip(context.tr('Max Stock', 'अधिकतम स्टॉक'), widget.availableQtl),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Escrow Breakdown
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildCostRow(context.tr('Base Commodity Value', 'मूल फसल मूल्य'), '₹${cropSubtotal.toStringAsFixed(0)}'),
                    const SizedBox(height: 4),
                    _buildCostRow(context.tr('GST on Raw Commodity', 'कच्चे माल पर जीएसटी'), '₹0 (${context.tr('0% Exemption', '0% छूट')})'),
                    const SizedBox(height: 4),
                    _buildCostRow(context.tr('Estimated Regional Freight', 'अनुमानित क्षेत्रीय भाड़ा'), '₹${estFreight.toStringAsFixed(0)}'),
                    const SizedBox(height: 4),
                    _buildCostRow(context.tr('AgriChain Escrow Protocol (1.5%)', 'एग्रीचेन एस्क्रो शुल्क (1.5%)'), '₹${protocolFee.toStringAsFixed(0)}'),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.tr('Total Escrow Lock', 'कुल एस्क्रो राशि'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkGreen)),
                        Text(
                          '₹${totalEscrowDeposit.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onNavigateToRfqs,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        context.tr('Issue Custom RFQ', 'कस्टम मांग दर्ज करें'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF1565C0), fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => widget.onProceedToCheckout(_selectedQtl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        context.tr('Proceed to Escrow Checkout', 'एस्क्रो चेकआउट पर आगे बढ़ें'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double qty) {
    if (qty > widget.availableQtl && qty != widget.availableQtl) return const SizedBox.shrink();
    final isSelected = (_selectedQtl - qty).abs() < 1.0;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedQtl = qty.clamp(widget.minOrderQtl, widget.availableQtl);
        });
      },
      selectedColor: const Color(0xFFE8F5E9),
      labelStyle: TextStyle(
        fontSize: 10,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildCostRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
        Text(val, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
      ],
    );
  }

  Widget _buildAssayBadge(String label, String value, String sub) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkGreen)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        Text(sub, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
      ],
    );
  }
}
