import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../services/database_service.dart';
import '../../utils/crop_image_helper.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';
import 'retail_checkout_screen.dart';

class RetailBuyerHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const RetailBuyerHomeScreen({super.key, this.onNavigateTab});

  @override
  State<RetailBuyerHomeScreen> createState() => _RetailBuyerHomeScreenState();
}

class _RetailBuyerHomeScreenState extends State<RetailBuyerHomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Wheat',
    'Rice',
    'Mustard',
    'Maize',
    'Chana',
    'Cotton',
    'Soybean',
    'Potato',
    'Vegetables',
    'Fruits',
    'Pulses',
  ];

  static final List<Map<String, String>> _cropDropdownCatalog = [
    {'key': 'All', 'label': 'All Crops (सभी फसलें)', 'icon': '🌾'},
    {'key': 'Wheat', 'label': 'Wheat (गेहूं)', 'icon': '🌾'},
    {'key': 'Rice', 'label': 'Rice / Basmati (चावल)', 'icon': '🍚'},
    {'key': 'Mustard', 'label': 'Mustard / Sarson (सरसों)', 'icon': '🟡'},
    {'key': 'Maize', 'label': 'Maize / Makka (मक्का)', 'icon': '🌽'},
    {'key': 'Chana', 'label': 'Gram / Chana (चना)', 'icon': '🟤'},
    {'key': 'Cotton', 'label': 'Cotton (कपास)', 'icon': '☁️'},
    {'key': 'Soybean', 'label': 'Soybean (सोयाबीन)', 'icon': '🌱'},
    {'key': 'Potato', 'label': 'Potato (आलू)', 'icon': '🥔'},
    {'key': 'Vegetables', 'label': 'Vegetables (सब्जियां)', 'icon': '🥗'},
    {'key': 'Fruits', 'label': 'Fruits (फल)', 'icon': '🍎'},
    {'key': 'Pulses', 'label': 'Pulses (दालें)', 'icon': '🥣'},
  ];

  @override
  void initState() {
    super.initState();
    _dbService.seedSampleRetailBuyerDataIfEmpty();
  }

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
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('AgriChain Retail', 'एग्रीचेन खुदरा बाजार'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            Text(
              context.tr('Buy Fresh Directly from Local Farmers', 'सीधे स्थानीय किसानों से ताजी फसल खरीदें'),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Center(child: LanguageSwitcherPill(isDark: false)),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: AppTheme.darkGreen),
            tooltip: context.tr('Saved Wishlist', 'पसंदीदा सूची'),
            onPressed: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(3); // Navigate to Saved Tab
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: AppTheme.darkGreen),
            tooltip: context.tr('My Orders', 'मेरे ऑर्डर'),
            onPressed: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(2); // Navigate to Orders Tab
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dbService.streamAllAvailableCrops(),
        builder: (context, snapshot) {
          final streamedCrops = snapshot.data ?? [];
          final localCrops = appState.crops.map((c) => c.toFirestore()).toList();
          final Set<String> seenIds = {};
          final List<Map<String, dynamic>> allFarmerCrops = [];

          for (final c in [...streamedCrops, ...localCrops]) {
            final id = c['id']?.toString() ?? c['name']?.toString() ?? '';
            if (id.isEmpty || seenIds.add(id)) {
              allFarmerCrops.add(c);
            }
          }

          // Filter by category if selected
          final filteredCrops = allFarmerCrops.where((crop) {
            final qty = _toDouble(crop['quantity']);
            if (qty <= 0) return false;
            if (_selectedCategory == 'All') return true;
            final name = (crop['name'] ?? crop['cropName'] ?? '').toString().toLowerCase();
            final category = (crop['category'] ?? '').toString().toLowerCase();
            final selected = _selectedCategory.toLowerCase();
            return name.contains(selected) || category.contains(selected);
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await _dbService.seedSampleRetailBuyerDataIfEmpty();
              setState(() {});
            },
            color: AppTheme.primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Search Bar Header
                  _buildSearchBar(context),
                  const SizedBox(height: 16),

                  // 2. Banner CTA: Direct from Farmers
                  _buildHeroCtaBanner(context, filteredCrops.length),
                  const SizedBox(height: 20),

                  // 3. Category Horizontal Pills
                  _buildCategorySelector(),
                  const SizedBox(height: 24),

                  // 4. Today's Offers Section
                  _buildSectionHeader(
                    title: "Live Farmer Harvests 🌾",
                    subtitle: 'Freshly listed produce directly from farms',
                    onSeeAll: () => widget.onNavigateTab?.call(1),
                  ),
                  const SizedBox(height: 12),
                  _buildOffersCarousel(filteredCrops),
                  const SizedBox(height: 24),

                  // 5. Nearby Crops Section (< 10 km)
                  _buildSectionHeader(
                    title: 'Nearby Farmer Produce 📍',
                    subtitle: 'Verified local harvests available for immediate procurement',
                    onSeeAll: () => widget.onNavigateTab?.call(1),
                  ),
                  const SizedBox(height: 12),
                  _buildNearbyCropsList(filteredCrops),
                  const SizedBox(height: 24),

                  // 6. Trust Banner
                  _buildDirectFarmerTrustCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(1); // Go to Find Tab
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppTheme.primaryGreen, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search for crops, grains, fruits, farmers...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 14, color: AppTheme.primaryGreen),
                  const SizedBox(width: 4),
                  Text(
                    'Filters',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  '100% FARMER DIRECT',
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
                  '$totalAvailable Active Listings',
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
            'Cut the Middlemen.\nEmpower Local Kisaans.',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Smart Escrow guarantees quality testing, transparent pricing, and instant bank settlement.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 16, color: AppTheme.primaryGreen),
                const SizedBox(width: 6),
                Text(
                  'Select Crop / फसल चयन',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ],
            ),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _categories.contains(_selectedCategory) ? _selectedCategory : 'All',
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.primaryGreen),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGreen,
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                  items: _cropDropdownCatalog.map((item) {
                    return DropdownMenuItem<String>(
                      value: item['key'],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item['icon'] ?? '🌾', style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(item['label'] ?? item['key']!),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
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
        ),
      ],
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
                'See All',
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

  Widget _buildOffersCarousel(List<Map<String, dynamic>> crops) {
    if (crops.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'No crops listed in this category yet.',
          style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    return SizedBox(
      height: 245,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: crops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final crop = crops[index];
          final name = crop['name'] ?? crop['cropName'] ?? 'Fresh Crop';
          final farmerName = crop['farmerName'] ?? 'Local Farmer';
          final price = _toDouble(crop['price']);
          final quantity = _toDouble(crop['quantity']);
          final location = crop['location'] ?? 'Haryana';
          final isNFT = crop['isNFT'] as bool? ?? false;
          final imageUrl = crop['imageUrl']?.toString() ?? '';

          return InkWell(
            onTap: () => _showCropDetailsModal(context, crop),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 250,
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
                          imageUrl,
                          name,
                          height: 105,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (isNFT)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 10, color: Color(0xFF69F0AE)),
                                SizedBox(width: 2),
                                Text(
                                  'NFT Verified',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGreen,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        '₹${price.toStringAsFixed(0)} / kg',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${quantity.toStringAsFixed(0)} kg left',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$farmerName • $location',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showQuickBuyModal(context, crop),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Buy',
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

  Widget _buildNearbyCropsList(List<Map<String, dynamic>> crops) {
    if (crops.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'No nearby farmer produce found for this category.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      children: crops.map((crop) {
        final name = crop['name'] ?? crop['cropName'] ?? 'Crop';
        final farmerName = crop['farmerName'] ?? 'Farmer';
        final price = _toDouble(crop['price']);
        final qty = _toDouble(crop['quantity']);
        final grade = crop['qualityGrade']?.toString() ?? 'Grade A';
        final location = crop['location'] ?? 'Karnal Cluster';
        final imageUrl = crop['imageUrl']?.toString() ?? '';

        return InkWell(
          onTap: () => _showCropDetailsModal(context, crop),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: CropImageHelper.buildCropImage(
                      imageUrl,
                      name,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGreen,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              grade,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${price.toStringAsFixed(0)} / kg • ${qty.toStringAsFixed(0)} kg available',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.near_me, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'From $farmerName, $location',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _showQuickBuyModal(context, crop),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Buy',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showCropDetailsModal(BuildContext context, Map<String, dynamic> crop) {
    final name = crop['name'] ?? crop['cropName'] ?? 'Crop Details';
    final farmerName = crop['farmerName'] ?? 'Local Farmer';
    final price = _toDouble(crop['price']);
    final quantity = _toDouble(crop['quantity']);
    final location = crop['location'] ?? 'Haryana Farm Cluster';
    final variety = crop['variety'] ?? 'Grade 1 Certified';
    final grade = crop['qualityGrade']?.toString() ?? 'Grade A';
    final isNFT = crop['isNFT'] as bool? ?? false;
    final imageUrl = crop['imageUrl']?.toString() ?? crop['image']?.toString() ?? '';
    final description = crop['description']?.toString() ??
        'Pure, laboratory-tested farm harvest direct from $farmerName. Certified under AgriChain digital contracts with instant farmer settlement.';

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
                      if (isNFT)
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
                                Icon(Icons.verified, size: 14, color: Color(0xFF69F0AE)),
                                SizedBox(width: 4),
                                Text(
                                  'NFT Passport Verified',
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
                            grade,
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
                              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
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
                            '${quantity.toStringAsFixed(0)} kg Available',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // AI Quality Assays Card
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
                              'AI Assayed Quality Parameters',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkGreen),
                            ),
                          ],
                        ),
                        const Divider(height: 16, color: Color(0xFFDCFCE7)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildAssayBadge('Moisture', '11.8%', 'Optimal'),
                            _buildAssayBadge('Broken Grain', '1.2%', 'Grade A'),
                            _buildAssayBadge('Foreign Matter', '0.4%', 'Pure'),
                            _buildAssayBadge('AI Purity', '98.6%', 'Verified'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'About this harvest',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const Divider(height: 24),

                  // Farmer Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              farmerName,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              location,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 12, color: Color(0xFF15803D)),
                            SizedBox(width: 4),
                            Text('Verified Kisaan', style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Order CTA
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showQuickBuyModal(context, crop);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Buy Now (₹${price.toStringAsFixed(0)} / kg)',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
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

  Widget _buildDirectFarmerTrustCard() {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.verified_user, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Farm-Direct Verified',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Zero middlemen fees. Every crop is AI-tested for moisture & quality with instant blockchain provenance.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssayBadge(String label, String value, String sub) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkGreen)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        Text(sub, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
      ],
    );
  }

  void _showQuickBuyModal(BuildContext context, Map<String, dynamic> crop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RetailCheckoutScreen(
          crop: crop,
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }

}
