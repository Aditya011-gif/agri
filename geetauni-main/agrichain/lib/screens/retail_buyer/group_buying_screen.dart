import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../models/farmer_cluster_model.dart';
import '../../services/database_service.dart';
import '../../services/farmer_clustering_service.dart';
import '../../services/road_routing_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/crop_image_helper.dart';
import 'retail_checkout_screen.dart';

/// Screen: Farmer Produce Pooling & Direct Market
/// Features Two Clear Sections:
/// 1. Single Farmer: Direct farm listings from individual verified smallholders with zero middlemen.
/// 2. 7km Clusters: Hyperlocal proximity clusters with TSP route optimization & 15% wholesale discount.
class FarmerGroupingScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const FarmerGroupingScreen({super.key, this.onNavigateTab});

  @override
  State<FarmerGroupingScreen> createState() => _FarmerGroupingScreenState();
}

/// Backward compatibility alias
typedef GroupBuyingScreen = FarmerGroupingScreen;

class _FarmerGroupingScreenState extends State<FarmerGroupingScreen> {
  final DatabaseService _dbService = DatabaseService();
  final FarmerClusteringService _clusteringService = FarmerClusteringService();

  // Section Selector: 0 = Single Farmer, 1 = 7km Clusters
  int _selectedSection = 0;

  // Filters for Section 1 (Single Farmer)
  String _singleCategoryFilter = 'All';
  final Map<String, double> _singleQuantities = {};

  // Filters for Section 2 (7km Clusters)
  String _clusterTagFilter = 'All Clusters';
  final Map<String, double> _clusterQuantities = {};

  double _getSingleQuantity(String cropId, double fallback) {
    return _singleQuantities[cropId] ?? fallback;
  }

  void _setSingleQuantity(String cropId, double newQty) {
    setState(() {
      _singleQuantities[cropId] = newQty.clamp(1.0, 5000.0);
    });
  }

  double _getClusterQuantity(String clusterId, double fallback) {
    return _clusterQuantities[clusterId] ?? fallback;
  }

  void _setClusterQuantity(String clusterId, double newQty) {
    setState(() {
      _clusterQuantities[clusterId] = newQty.clamp(1.0, 5000.0);
    });
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final clean = val.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  List<FarmerCluster> _filterClusters(List<FarmerCluster> clusters) {
    if (_clusterTagFilter == '≤ 5 km Radius') {
      return clusters.where((c) => c.maxInterFarmDistance <= 5.0).toList();
    } else if (_clusterTagFilter == '≤ 7 km Radius') {
      return clusters.where((c) => c.maxInterFarmDistance <= 7.0).toList();
    } else if (_clusterTagFilter == 'Residue-Free GAP') {
      return clusters.where((c) {
        final cond = c.conditions['cultivationMethod']?.toString() ?? '';
        return cond.toLowerCase().contains('residue') || cond.toLowerCase().contains('gap') || cond.toLowerCase().contains('bio');
      }).toList();
    } else if (_clusterTagFilter == 'Moisture Certified') {
      return clusters.where((c) {
        final moist = c.conditions['moistureLevel']?.toString() ?? '';
        return moist.contains('%');
      }).toList();
    }
    return clusters;
  }

  List<Map<String, dynamic>> _filterSingleCrops(List<Map<String, dynamic>> crops) {
    if (_singleCategoryFilter == 'All') return crops;
    final target = _singleCategoryFilter.toLowerCase();
    return crops.where((c) {
      final name = (c['name'] ?? c['cropName'] ?? '').toString().toLowerCase();
      final cat = (c['category'] ?? '').toString().toLowerCase();
      return name.contains(target) || cat.contains(target);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF1B5E20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _selectedSection == 0 ? Icons.person : Icons.hub,
                  color: const Color(0xFF2E7D32),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _selectedSection == 0 ? 'Farmer Direct Marketplace' : 'Farmer Produce Pooling',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
            Text(
              _selectedSection == 0
                  ? 'Single Kisaan Harvests • 100% Direct • No Middlemen'
                  : '≤ 7 km Proximity Clusters • TSP Route Optimized • Wholesale Rates',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dbService.streamAllAvailableCrops(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
          }

          final rawCrops = snapshot.data ?? [];

          // 1. Process active single farmer crops and consolidate duplicate lots per farmer
          final Map<String, Map<String, dynamic>> consolidatedSingleCrops = {};
          for (final c in rawCrops) {
            final qty = _toDouble(c['availableQuantity'] ?? c['quantity']);
            final status = (c['status'] ?? 'active').toString().toLowerCase();
            final isActive = c['isActive'] as bool? ?? true;
            if (isActive && qty > 0 && status != 'sold') {
              double price = _toDouble(c['price']);
              if (price > 300) {
                price = (price / 100).roundToDouble();
              }
              if (price <= 5.0) price = 32.0;

              final farmer = (c['farmerName'] ?? 'Verified Farmer').toString().trim();
              final cropName = (c['name'] ?? c['cropName'] ?? 'Crop').toString().trim();
              final key = '${cropName.toLowerCase()}_${farmer.toLowerCase()}';

              if (consolidatedSingleCrops.containsKey(key)) {
                final existing = consolidatedSingleCrops[key]!;
                final currentTotalQty = _toDouble(existing['normalizedQuantity']) + qty;
                existing['normalizedQuantity'] = currentTotalQty;
                existing['quantity'] = currentTotalQty;
                existing['availableQuantity'] = currentTotalQty;
              } else {
                consolidatedSingleCrops[key] = {
                  ...c,
                  'normalizedPrice': price,
                  'normalizedQuantity': qty,
                };
              }
            }
          }

          final List<Map<String, dynamic>> activeSingleCrops = consolidatedSingleCrops.values.toList();

          // Fallback verified smallholders if firestore is empty
          if (activeSingleCrops.isEmpty) {
            activeSingleCrops.addAll(_getVerifiedFallbackSingleCrops());
          }

          // 2. Process 7km pooled clusters
          final allClusters = _clusteringService.clusterCrops(rawCrops);
          final filteredClusters = _filterClusters(allClusters);
          final filteredSingleCrops = _filterSingleCrops(activeSingleCrops);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Top Two-Section Switcher (1. Single Farmer vs 2. 7km Clusters)
              _buildTwoSectionSwitcher(activeSingleCrops.length, allClusters.length),
              const SizedBox(height: 12),

              // Content based on selected section
              if (_selectedSection == 0) ...[
                // SECTION 1: Single Farmer Direct
                _buildSingleFarmerHeroBanner(activeSingleCrops.length),
                const SizedBox(height: 14),
                _buildSingleCategoryChips(),
                const SizedBox(height: 16),
                _buildSectionHeader(
                  title: 'Verified Single Farmer Harvests',
                  badgeText: '${filteredSingleCrops.length} Active Lots',
                ),
                const SizedBox(height: 12),
                if (filteredSingleCrops.isEmpty)
                  _buildEmptyState('No crops matching $_singleCategoryFilter')
                else
                  ...filteredSingleCrops.map((c) => _buildSingleFarmerCard(c)),
              ] else ...[
                // SECTION 2: 7km Pooled Clusters
                _buildClusterHeroBanner(allClusters.length),
                const SizedBox(height: 14),
                _buildClusterFilterChips(),
                const SizedBox(height: 16),
                _buildSectionHeader(
                  title: 'Active ≤ 7km Hyperlocal Clusters',
                  badgeText: '${filteredClusters.length} Clusters Ready',
                ),
                const SizedBox(height: 12),
                if (filteredClusters.isEmpty)
                  _buildEmptyState('No clusters matching $_clusterTagFilter')
                else
                  ...filteredClusters.map((c) => _buildDetailedClusterCard(c)),
              ],
            ],
          );
        },
      ),
    );
  }

  // Two-Section Segmented Tab Switcher
  Widget _buildTwoSectionSwitcher(int singleCount, int clusterCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Section 1: Single Farmer
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedSection = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedSection == 0 ? const Color(0xFF15803D) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: _selectedSection == 0 ? Colors.white : const Color(0xFF15803D),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '1. Single Farmer',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _selectedSection == 0 ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$singleCount Direct Farms',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: _selectedSection == 0 ? const Color(0xFFDCFCE7) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Section 2: 7km Clusters
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedSection = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedSection == 1 ? const Color(0xFF15803D) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hub,
                          size: 16,
                          color: _selectedSection == 1 ? Colors.white : const Color(0xFF15803D),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '2. 7km Clusters',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _selectedSection == 1 ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$clusterCount Pooled Belts',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: _selectedSection == 1 ? const Color(0xFFDCFCE7) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required String badgeText}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B5E20),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeText,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
        ),
      ],
    );
  }

  // SECTION 1: Single Farmer Hero Banner
  Widget _buildSingleFarmerHeroBanner(int totalFarms) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D5C3A), Color(0xFF1B7A4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D5C3A).withValues(alpha: 0.2),
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
                child: const Icon(Icons.person, color: Color(0xFF69F0AE), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct Single Farmer Procurements',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '100% direct-to-kisaan farm harvests with certified DigiLocker e-Sign',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB9F6CA)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildBannerStat(Icons.storefront, '$totalFarms Direct Farms', 'Live Listings'),
              const SizedBox(width: 8),
              _buildBannerStat(Icons.verified, '100% Direct', 'Zero Middlemen'),
              const SizedBox(width: 8),
              _buildBannerStat(Icons.security, 'Escrow Protected', 'Instant Settlement'),
            ],
          ),
        ],
      ),
    );
  }

  // SECTION 2: 7km Cluster Hero Banner
  Widget _buildClusterHeroBanner(int totalClusters) {
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
                      'Hyperlocal Proximity Pooling (≤ 7 km)',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Neighboring farms auto-clustered for single-dispatch wholesale savings',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB9F6CA)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildBannerStat(Icons.scatter_plot, '$totalClusters Clusters', 'Agricultural Belt'),
              const SizedBox(width: 8),
              _buildBannerStat(Icons.route, '≤ 7 km Radius', 'Inter-Farm Span'),
              const SizedBox(width: 8),
              _buildBannerStat(Icons.trending_down, '15% OFF Pooled', 'Wholesale Rate'),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleCategoryChips() {
    final categories = ['All', 'Wheat', 'Rice', 'Mustard', 'Tomato', 'Onion', 'Mango'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSel = _singleCategoryFilter == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSel,
              onSelected: (selected) {
                if (selected) setState(() => _singleCategoryFilter = cat);
              },
              labelStyle: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: isSel ? Colors.white : const Color(0xFF15803D),
              ),
              selectedColor: const Color(0xFF15803D),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSel ? const Color(0xFF15803D) : Colors.grey.shade300),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClusterFilterChips() {
    final filters = ['All Clusters', '≤ 5 km Radius', '≤ 7 km Radius', 'Residue-Free GAP', 'Moisture Certified'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _clusterTagFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _clusterTagFilter = f);
              },
              labelStyle: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF1B5E20),
              ),
              selectedColor: const Color(0xFF1B5E20),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade300),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 44, color: Color(0xFF15803D)),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your selected filters to view more listings.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 1: SINGLE FARMER CARD IMPLEMENTATION
  // Refined, sleek, clickable cards with full detail modal
  // ==========================================
  Widget _buildSingleFarmerCard(Map<String, dynamic> crop) {
    final cropName = crop['name'] ?? crop['cropName'] ?? 'Farm Harvest';
    final farmerName = crop['farmerName'] ?? 'Verified Kisaan';
    final location = crop['location'] ?? 'Karnal Belt, Haryana';
    final grade = crop['qualityGrade'] ?? 'Grade A';
    final price = _toDouble(crop['normalizedPrice'] ?? crop['price']);
    final stock = _toDouble(crop['normalizedQuantity'] ?? crop['quantity']);
    final imageUrl = crop['imageUrl']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCropDetailModal(context, crop),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Crop Image (Square Rounded 100x100)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CropImageHelper.buildCropImage(
                        imageUrl.isNotEmpty ? imageUrl : null,
                        cropName,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF15803D),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '100% Direct',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // 2. Info Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Crop Name & Grade
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cropName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              grade,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Farmer Name & Location
                      Row(
                        children: [
                          const Icon(Icons.verified, size: 12, color: Color(0xFF15803D)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$farmerName • $location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Quality Tags Row
                      Row(
                        children: [
                          _buildCompactTag('💧 11.2% Moisture'),
                          const SizedBox(width: 4),
                          _buildCompactTag('🌿 Residue-Free'),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Price, Stock & Action Affordance
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '₹${price.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF15803D),
                                    ),
                                  ),
                                  Text(
                                    '/kg',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF15803D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${stock.toStringAsFixed(0)} kg available',
                                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View Details',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF15803D)),
                              ],
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
      ),
    );
  }

  Widget _buildCompactTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDetailSpecTile(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF15803D)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FULL CROP DETAIL & DIRECT PROCUREMENT MODAL
  // ==========================================
  void _showCropDetailModal(BuildContext context, Map<String, dynamic> crop) {
    final cropId = crop['id']?.toString() ?? 'crop_${DateTime.now().millisecondsSinceEpoch}';
    final cropName = crop['name'] ?? crop['cropName'] ?? 'Farm Harvest';
    final farmerName = crop['farmerName'] ?? 'Local Verified Kisaan';
    final location = crop['location'] ?? 'Karnal Village, Haryana';
    final variety = crop['variety'] ?? 'Grade 1 Quality';
    final grade = crop['qualityGrade'] ?? 'Grade A';
    final price = _toDouble(crop['normalizedPrice'] ?? crop['price']);
    final stock = _toDouble(crop['normalizedQuantity'] ?? crop['quantity']);
    final imageUrl = crop['imageUrl']?.toString() ?? '';
    final lat = (crop['lat'] as num?)?.toDouble() ?? 29.6857;
    final lng = (crop['lng'] as num?)?.toDouble() ?? 76.9905;
    final farmPos = LatLng(lat, lng);

    final cleanLotId = 'LOT-HR-KNL-${cropId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().padRight(8, '0').substring(0, 8)}';
    double modalQty = _getSingleQuantity(cropId, stock >= 25 ? 25.0 : (stock > 0 ? stock : 5.0)).clamp(1.0, stock > 0 ? stock : 5000.0);
    final qtyController = TextEditingController(text: modalQty.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalPayable = modalQty * price;

            void updateQty(double newQty) {
              final clamped = newQty.clamp(1.0, stock > 0 ? stock : 5000.0);
              setModalState(() {
                modalQty = clamped;
                _setSingleQuantity(cropId, modalQty);
                qtyController.text = modalQty.toStringAsFixed(0);
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Header bar with title and close
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                cleanLotId,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Direct Kisaan Harvest',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Hero Image & Direct Badges (Authentic Crop Photo)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: SizedBox(
                                  height: 185,
                                  width: double.infinity,
                                  child: CropImageHelper.buildCropImage(
                                    imageUrl.isNotEmpty ? imageUrl : null,
                                    cropName,
                                    height: 185,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // Top-Left Badge
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '100% Single Farm Direct',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              // Top-Right Badge
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF15803D),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'ZERO MIDDLEMEN',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              // Bottom-Left Floating Certification Badge
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified, color: Color(0xFF4ADE80), size: 14),
                                      SizedBox(width: 5),
                                      Text(
                                        'AI Assayed & Lab Certified',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 2. Crop Title, Grade & Price Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cropName,
                                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Text(
                                            '$variety • $grade',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'NABL Lab Certified',
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF15803D), fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '₹${price.toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                      ),
                                      Text('/kg', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF15803D), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Text(
                                    '₹${(price * 100).toStringAsFixed(0)} / Qtl (Direct Farm Price)',
                                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${stock.toStringAsFixed(0)} kg available',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 3. Farmer Identity & Verification Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF15803D).withValues(alpha: 0.15),
                                  child: const Icon(Icons.person, color: Color(0xFF15803D), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            farmerName,
                                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, size: 15, color: Color(0xFF15803D)),
                                        ],
                                      ),
                                      Text(
                                        '$location • Single Smallholder Kisaan',
                                        style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '🔐 DigiLocker Verified',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4. Detailed Quality Specifications & Certifications (The Lab Specs)
                          Text(
                            'Quality Specifications & Certifications',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildDetailSpecTile(Icons.water_drop, '11.2% Moisture', 'Storage standard (≤ 12%)'),
                              const SizedBox(width: 8),
                              _buildDetailSpecTile(Icons.eco, 'Residue-Free GAP', 'Zero synthetic chems'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildDetailSpecTile(Icons.grain, '99.2% Purity Score', 'Single-farm origin pure'),
                              const SizedBox(width: 8),
                              _buildDetailSpecTile(Icons.scale, '78.5 kg/hL Test Wt', 'High density food grain'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildDetailSpecTile(Icons.shield, 'Escrow Secured', 'Disbursed on delivery'),
                              const SizedBox(width: 8),
                              _buildDetailSpecTile(Icons.inventory_2, 'Hermetic Bagging', 'Moisture-barrier sealed'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 5. Farm Storage & Dispatch Logistics
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
                                const Row(
                                  children: [
                                    Icon(Icons.local_shipping_outlined, color: Color(0xFF15803D), size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Direct Farm Gate Logistics & Dispatch',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '• Dispatch Window: Within 24 Hours via Hyperlocal Courier\n• Farm Weighbridge: NABL Electronic Certified Scale\n• Direct Payment: 100% proceeds locked in smart escrow to farmer',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF166534), height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 6. Interactive Farm Location Map
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Verified Farm Location & Dispatch Radius',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              const Text(
                                '≤ 3.5 km Catchment',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: farmPos,
                                  initialZoom: 12.5,
                                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.agrichain.app',
                                  ),
                                  CircleLayer(
                                    circles: [
                                      CircleMarker(
                                        point: farmPos,
                                        radius: 3500,
                                        useRadiusInMeter: true,
                                        color: const Color(0xFF15803D).withValues(alpha: 0.12),
                                        borderColor: const Color(0xFF15803D),
                                        borderStrokeWidth: 1.5,
                                      ),
                                    ],
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: farmPos,
                                        width: 36,
                                        height: 36,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF15803D),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.agriculture, color: Colors.white, size: 18),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 7. CUSTOM QUANTITY SELECTOR (RETAIL BUYERS)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select Quantity to Procure:',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                'Max ${stock.toStringAsFixed(0)} kg available',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Stepper and Custom Quantity Input
                                Row(
                                  children: [
                                    // Minus button
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.remove, size: 18, color: Color(0xFF15803D)),
                                        onPressed: () => updateQty(modalQty - (modalQty > 10 ? 5 : 1)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Direct Editable Custom Quantity Input Field
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF15803D), width: 1.5),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: qtyController,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                                decoration: const InputDecoration(
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                                  hintText: 'Qty',
                                                ),
                                                onChanged: (val) {
                                                  final parsed = double.tryParse(val.trim());
                                                  if (parsed != null && parsed > 0) {
                                                    final clamped = parsed.clamp(1.0, stock > 0 ? stock : 5000.0);
                                                    setModalState(() {
                                                      modalQty = clamped;
                                                      _setSingleQuantity(cropId, modalQty);
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                            Text(
                                              'kg',
                                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Plus button
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.add, size: 18, color: Color(0xFF15803D)),
                                        onPressed: () => updateQty(modalQty + (modalQty >= 10 ? 5 : 1)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Smooth Interactive Slider
                                Row(
                                  children: [
                                    const Text('1 kg', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: const Color(0xFF15803D),
                                          inactiveTrackColor: const Color(0xFFDCFCE7),
                                          thumbColor: const Color(0xFF15803D),
                                          trackHeight: 4,
                                        ),
                                        child: Slider(
                                          value: modalQty.clamp(1.0, stock > 1.0 ? stock : 500.0),
                                          min: 1.0,
                                          max: stock > 1.0 ? stock : 500.0,
                                          divisions: stock > 1.0 ? (stock <= 100 ? stock.toInt() : 50) : 50,
                                          label: '${modalQty.toStringAsFixed(0)} kg',
                                          onChanged: (val) => updateQty(val),
                                        ),
                                      ),
                                    ),
                                    Text('${stock.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ],
                                ),

                                // Quick Preset Chips
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...[5.0, 10.0, 25.0, 50.0, 100.0].where((opt) => opt <= (stock > 0 ? stock : 5000.0)).map((opt) {
                                        final isSel = (modalQty - opt).abs() < 0.1;
                                        return GestureDetector(
                                          onTap: () => updateQty(opt),
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSel ? const Color(0xFF15803D) : Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isSel ? const Color(0xFF15803D) : const Color(0xFFCBD5E1)),
                                            ),
                                            child: Text(
                                              '${opt.toStringAsFixed(0)} kg',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                                color: isSel ? Colors.white : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      // Full Stock Option
                                      GestureDetector(
                                        onTap: () => updateQty(stock),
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: (modalQty - stock).abs() < 0.1 ? const Color(0xFF15803D) : Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: (modalQty - stock).abs() < 0.1 ? const Color(0xFF15803D) : const Color(0xFFCBD5E1)),
                                          ),
                                          child: Text(
                                            'Max (${stock.toStringAsFixed(0)} kg)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: (modalQty - stock).abs() < 0.1 ? Colors.white : const Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Pricing formula breakdown
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Rate: ₹${price.toStringAsFixed(0)}/kg × ${modalQty.toStringAsFixed(0)} kg',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                      Text(
                                        '₹${(modalQty * price).toStringAsFixed(0)} Total',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Sticky Checkout Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Total Payable', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            Text(
                              '₹${totalPayable.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: 21, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _proceedToSingleCheckout(crop, modalQty, totalPayable);
                            },
                            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                            label: Text(
                              'Buy Direct (${modalQty.toStringAsFixed(0)} kg • ₹${totalPayable.toStringAsFixed(0)})',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
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
    );
  }

  void _proceedToSingleCheckout(Map<String, dynamic> crop, double qty, double amount) {
    final cropMap = {
      'id': crop['id'],
      'name': crop['name'] ?? crop['cropName'] ?? 'Crop',
      'cropName': crop['name'] ?? crop['cropName'] ?? 'Crop',
      'price': _toDouble(crop['normalizedPrice'] ?? crop['price']),
      'pricePerUnit': _toDouble(crop['normalizedPrice'] ?? crop['price']),
      'quantity': '${crop['normalizedQuantity'] ?? crop['quantity']} kg',
      'availableQuantity': _toDouble(crop['normalizedQuantity'] ?? crop['quantity']),
      'unit': 'kg',
      'farmerId': crop['farmerId'] ?? 'farmer',
      'farmerName': crop['farmerName'] ?? 'Local Farmer',
      'location': crop['location'] ?? 'Karnal Village, Haryana',
      'imageUrl': crop['imageUrl'] ?? '',
      'variety': crop['variety'] ?? 'Grade 1 Quality',
      'qualityGrade': crop['qualityGrade'] ?? 'Grade A',
      'isClusterOrder': false,
      'selectedQuantity': qty,
      'orderQuantity': qty,
      'totalAmount': amount,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RetailCheckoutScreen(crop: cropMap),
      ),
    );
  }

  // ==========================================
  // SECTION 2: 7KM CLUSTERS IMPLEMENTATION
  // ==========================================
  Widget _buildDetailedClusterCard(FarmerCluster cluster) {
    final savingsPercent = ((cluster.retailMarketPrice - cluster.wholesalePrice) / cluster.retailMarketPrice * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showClusterInspectionSheet(context, cluster),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cluster Image / Emoji (100x100)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CropImageHelper.buildCropImage(
                        cluster.imageUrl.isNotEmpty ? cluster.imageUrl : null,
                        cluster.crop,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          cluster.clusterRadius,
                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$savingsPercent% OFF',
                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // 2. Info Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Crop Name & Grade
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cluster.crop,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cluster.grade,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Location & Number of neighbor farms
                      Row(
                        children: [
                          const Icon(Icons.hub, size: 12, color: Color(0xFF15803D)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${cluster.hubLocation} • ${cluster.totalFarms} Farms Pooled',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Pickup Route Summary Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F8E9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFDCEDC8)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alt_route, size: 11, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                cluster.farmers.map((f) => f.name.split(' ').first).join(' ➔ '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price, Stock & Action Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '₹${cluster.wholesalePrice.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF15803D),
                                    ),
                                  ),
                                  Text(
                                    '/kg  ',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF15803D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '₹${cluster.retailMarketPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${cluster.availableStockKg.toStringAsFixed(0)} kg pooled',
                                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Inspect & Buy',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF15803D)),
                              ],
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
      ),
    );
  }



  void _showClusterInspectionSheet(BuildContext context, FarmerCluster cluster) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final hubPos = LatLng(cluster.hubLat, cluster.hubLng);
        int mapTypeIndex = 0;
        RoadRouteResult? roadRoute;
        bool isRouteLoading = true;
        bool hasFetched = false;
        double modalQty = _getClusterQuantity(cluster.id, cluster.defaultOrderKg);
        final clusterQtyController = TextEditingController(text: modalQty.toStringAsFixed(0));

        return StatefulBuilder(
          builder: (context, setInspectionState) {
            if (!hasFetched) {
              hasFetched = true;
              final waypoints = [
                hubPos,
                ...cluster.farmers.map((f) => LatLng(f.lat, f.lng)),
                hubPos,
              ];
              RoadRoutingService().getMultiStopRoute(waypoints, optimizeStops: true).then((res) {
                setInspectionState(() {
                  roadRoute = res;
                  isRouteLoading = false;
                });
              });
            }

            String tileUrl;
            switch (mapTypeIndex) {
              case 1:
                tileUrl = 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
                break;
              case 2:
                tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
                break;
              case 0:
              default:
                tileUrl = 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
                break;
            }

            final fallbackPoints = [hubPos, ...cluster.farmers.map((f) => LatLng(f.lat, f.lng)), hubPos];
            final polylinePoints = roadRoute?.points ?? fallbackPoints;

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
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(cluster.imageEmoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cluster.crop,
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                '${cluster.hubLocation} • ${cluster.clusterRadius}',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  const Divider(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Multi-Stop Pickup Road Route',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              Row(
                                children: [
                                  _buildInspectionMapToggle(0, '🗺️ Road', mapTypeIndex, (idx) => setInspectionState(() => mapTypeIndex = idx)),
                                  const SizedBox(width: 4),
                                  _buildInspectionMapToggle(1, '🛰️ Sat', mapTypeIndex, (idx) => setInspectionState(() => mapTypeIndex = idx)),
                                  const SizedBox(width: 4),
                                  _buildInspectionMapToggle(2, '🌐 OSM', mapTypeIndex, (idx) => setInspectionState(() => mapTypeIndex = idx)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Optimized asphalt road routing across smallholder farms in this pooled belt.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 10),

                          Container(
                            height: 240,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: hubPos,
                                  initialZoom: 12.0,
                                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: tileUrl,
                                    userAgentPackageName: 'com.agrichain.app',
                                  ),
                                  CircleLayer(
                                    circles: [
                                      CircleMarker(
                                        point: hubPos,
                                        radius: (cluster.maxInterFarmDistance * 1000).clamp(2500, 7000),
                                        useRadiusInMeter: true,
                                        color: const Color(0xFF15803D).withValues(alpha: 0.10),
                                        borderColor: const Color(0xFF15803D),
                                        borderStrokeWidth: 1.5,
                                      ),
                                    ],
                                  ),
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: polylinePoints,
                                        strokeWidth: 5.5,
                                        color: const Color(0xFF064E3B),
                                      ),
                                      Polyline(
                                        points: polylinePoints,
                                        strokeWidth: 3.5,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ],
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: hubPos,
                                        width: 44,
                                        height: 44,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF15803D),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2.5),
                                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.storefront, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ),
                                      ...cluster.farmers.asMap().entries.map((entry) {
                                        final idx = entry.key + 1;
                                        final f = entry.value;
                                        return Marker(
                                          point: LatLng(f.lat, f.lng),
                                          width: 38,
                                          height: 38,
                                          child: Tooltip(
                                            message: 'Stop #$idx: ${f.name} (${f.distance} km)',
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: const Color(0xFF15803D), width: 2.5),
                                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '$idx',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF15803D),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
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
                                            ? 'Computing OSRM Road Route...'
                                            : '${roadRoute?.distanceKm.toStringAsFixed(1) ?? cluster.maxInterFarmDistance.toStringAsFixed(1)} km Total Road Pickup Route',
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                      ),
                                      Text(
                                        isRouteLoading
                                            ? 'Connecting to road navigation network...'
                                            : '${roadRoute?.durationMinutes ?? 18} mins pickup ETA • ${cluster.farmers.length} farm stops consolidated',
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
                                  child: const Text(
                                    'OSRM Road Snapped',
                                    style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          Text(
                            'Pooled Neighbor Farmers (${cluster.farmers.length})',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),

                          ...cluster.farmers.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final f = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFDCFCE7),
                                    child: Text(
                                      '#$idx',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f.name,
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${f.farmName} • ${f.village} (${f.distance == 0 ? "Hub Farm" : "${f.distance} km away"})',
                                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${f.pooledKg.toStringAsFixed(0)} kg\nPooled',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 20),

                          // Procurement Quantity Selector for Cluster
                          Container(
                            padding: const EdgeInsets.all(14),
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
                                    const Text(
                                      'Procure from Pooled Batch:',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                    ),
                                    Text(
                                      'Max ${cluster.availableStockKg.toStringAsFixed(0)} kg pooled',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Stepper and Custom Quantity Input
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.remove, size: 18, color: Color(0xFF15803D)),
                                        onPressed: () {
                                          if (modalQty > 5) {
                                            setInspectionState(() {
                                              modalQty -= (modalQty > 10 ? 5 : 1);
                                              _setClusterQuantity(cluster.id, modalQty);
                                              clusterQtyController.text = modalQty.toStringAsFixed(0);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF15803D), width: 1.5),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: clusterQtyController,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                                decoration: const InputDecoration(
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                                  hintText: 'Qty',
                                                ),
                                                onChanged: (val) {
                                                  final parsed = double.tryParse(val.trim());
                                                  if (parsed != null && parsed > 0) {
                                                    final clamped = parsed.clamp(1.0, cluster.availableStockKg);
                                                    setInspectionState(() {
                                                      modalQty = clamped;
                                                      _setClusterQuantity(cluster.id, modalQty);
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                            Text(
                                              'kg',
                                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.add, size: 18, color: Color(0xFF15803D)),
                                        onPressed: () {
                                          if (modalQty + (modalQty >= 10 ? 5 : 1) <= cluster.availableStockKg) {
                                            setInspectionState(() {
                                              modalQty += (modalQty >= 10 ? 5 : 1);
                                              _setClusterQuantity(cluster.id, modalQty);
                                              clusterQtyController.text = modalQty.toStringAsFixed(0);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Interactive Slider
                                Row(
                                  children: [
                                    const Text('1 kg', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: const Color(0xFF15803D),
                                          inactiveTrackColor: const Color(0xFFDCFCE7),
                                          thumbColor: const Color(0xFF15803D),
                                          trackHeight: 4,
                                        ),
                                        child: Slider(
                                          value: modalQty.clamp(1.0, cluster.availableStockKg > 1.0 ? cluster.availableStockKg : 500.0),
                                          min: 1.0,
                                          max: cluster.availableStockKg > 1.0 ? cluster.availableStockKg : 500.0,
                                          divisions: cluster.availableStockKg > 1.0 ? (cluster.availableStockKg <= 100 ? cluster.availableStockKg.toInt() : 50) : 50,
                                          label: '${modalQty.toStringAsFixed(0)} kg',
                                          onChanged: (val) {
                                            final clamped = val.clamp(1.0, cluster.availableStockKg);
                                            setInspectionState(() {
                                              modalQty = clamped;
                                              _setClusterQuantity(cluster.id, modalQty);
                                              clusterQtyController.text = modalQty.toStringAsFixed(0);
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    Text('${cluster.availableStockKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ],
                                ),

                                // Preset Chips
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...[10.0, 25.0, 50.0, 100.0, 250.0].where((opt) => opt <= cluster.availableStockKg).map((opt) {
                                        final isSel = (modalQty - opt).abs() < 0.1;
                                        return GestureDetector(
                                          onTap: () {
                                            setInspectionState(() {
                                              modalQty = opt.clamp(1.0, cluster.availableStockKg);
                                              _setClusterQuantity(cluster.id, modalQty);
                                              clusterQtyController.text = modalQty.toStringAsFixed(0);
                                            });
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSel ? const Color(0xFF15803D) : Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isSel ? const Color(0xFF15803D) : const Color(0xFFCBD5E1)),
                                            ),
                                            child: Text(
                                              '${opt.toStringAsFixed(0)} kg',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                                color: isSel ? Colors.white : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      GestureDetector(
                                        onTap: () {
                                          setInspectionState(() {
                                            modalQty = cluster.availableStockKg;
                                            _setClusterQuantity(cluster.id, modalQty);
                                            clusterQtyController.text = modalQty.toStringAsFixed(0);
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: (modalQty - cluster.availableStockKg).abs() < 0.1 ? const Color(0xFF15803D) : Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: (modalQty - cluster.availableStockKg).abs() < 0.1 ? const Color(0xFF15803D) : const Color(0xFFCBD5E1)),
                                          ),
                                          child: Text(
                                            'Max (${cluster.availableStockKg.toStringAsFixed(0)} kg)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: (modalQty - cluster.availableStockKg).abs() < 0.1 ? Colors.white : const Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total: ₹${(modalQty * cluster.wholesalePrice).toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                    ),
                                    Text(
                                      'Wholesale Savings: ₹${(modalQty * (cluster.retailMarketPrice - cluster.wholesalePrice)).toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _proceedToClusterCheckout(cluster, modalQty, modalQty * cluster.wholesalePrice);
                              },
                              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                              label: Text(
                                'Buy from Cluster (${modalQty.toStringAsFixed(0)} kg)',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF15803D),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
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

  Widget _buildInspectionMapToggle(int index, String label, int current, Function(int) onSelect) {
    final isSel = index == current;
    return GestureDetector(
      onTap: () => onSelect(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF15803D) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSel ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  void _proceedToClusterCheckout(FarmerCluster cluster, double qty, double amount) {
    final leadFarmer = cluster.farmers.first;

    final cropMap = {
      'id': cluster.id,
      'name': cluster.crop,
      'cropName': cluster.crop,
      'price': cluster.wholesalePrice,
      'pricePerUnit': cluster.wholesalePrice,
      'quantity': '${cluster.availableStockKg} kg',
      'availableQuantity': cluster.availableStockKg,
      'unit': 'kg',
      'farmerId': leadFarmer.farmerId,
      'farmerName': '${leadFarmer.name} (Cluster Representative)',
      'location': cluster.hubLocation,
      'village': leadFarmer.village,
      'imageUrl': cluster.imageUrl,
      'category': 'Grains',
      'variety': cluster.variety,
      'qualityGrade': cluster.grade,
      'isClusterOrder': true,
      'clusterFarmsCount': cluster.totalFarms,
      'maxInterFarmDistance': cluster.maxInterFarmDistance,
      'selectedQuantity': qty,
      'orderQuantity': qty,
      'totalAmount': amount,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RetailCheckoutScreen(crop: cropMap),
      ),
    );
  }

  // Fallback direct smallholders if firestore collection is empty
  List<Map<String, dynamic>> _getVerifiedFallbackSingleCrops() {
    return [
      {
        'id': 'SINGLE-WHT-01',
        'name': 'Sharbati Wheat (Grade A)',
        'cropName': 'Sharbati Wheat (Grade A)',
        'farmerName': 'Baldev Singh Dhillon',
        'location': 'Taraori North, Karnal Belt',
        'variety': 'Sharbati C-306 Gold',
        'qualityGrade': 'Premium Grade-1',
        'normalizedPrice': 34.0,
        'normalizedQuantity': 750.0,
        'imageUrl': 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=600',
        'lat': 29.8032,
        'lng': 76.9248,
        'category': 'Wheat',
      },
      {
        'id': 'SINGLE-RICE-02',
        'name': 'Basmati 1121 Extra Long',
        'cropName': 'Basmati 1121 Extra Long',
        'farmerName': 'Rajesh Kumar',
        'location': 'Sector 32 Rural, Karnal',
        'variety': 'Pusa 1121 Aged',
        'qualityGrade': 'Export Grade',
        'normalizedPrice': 88.0,
        'normalizedQuantity': 950.0,
        'imageUrl': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600',
        'lat': 29.6857,
        'lng': 76.9905,
        'category': 'Rice',
      },
      {
        'id': 'SINGLE-MNG-03',
        'name': 'Organic Dasheri Mangoes',
        'cropName': 'Organic Dasheri Mangoes',
        'farmerName': 'Gurpreet Singh',
        'location': 'Taraori East Orchard, Karnal',
        'variety': 'Dasheri Natural Tree Ripe',
        'qualityGrade': 'Grade A Export',
        'normalizedPrice': 55.0,
        'normalizedQuantity': 400.0,
        'imageUrl': 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=600',
        'lat': 29.8185,
        'lng': 76.9380,
        'category': 'Mango',
      },
    ];
  }
}
